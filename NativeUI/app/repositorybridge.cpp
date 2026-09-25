#include "repositorybridge.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QRegularExpression>

namespace {
constexpr qsizetype MaxOutput = 4 * 1024 * 1024;
}

RepositoryBridge::RepositoryBridge(QObject *parent)
    : QObject(parent)
{
    resolveBackend();
}

RepositoryBridge::~RepositoryBridge()
{
    if (!m_process)
        return;
    m_process->terminate();
    if (!m_process->waitForFinished(800)) {
        m_process->kill();
        m_process->waitForFinished(800);
    }
}

void RepositoryBridge::resolveBackend()
{
    const QString explicitBackend = qEnvironmentVariable("OMNISTORE_BACKEND").trimmed();
    if (!explicitBackend.isEmpty()) {
        m_backendProgram = explicitBackend;
        m_workingDirectory = QFileInfo(explicitBackend).absolutePath();
        return;
    }

    const QString bundled = QStringLiteral("/opt/omnistore/backends/python_server");
    if (QFileInfo(bundled).isExecutable()) {
        m_backendProgram = bundled;
        m_workingDirectory = QStringLiteral("/opt/omnistore");
        return;
    }

#ifdef OMNISTORE_SOURCE_ROOT
    const QString root = QString::fromUtf8(OMNISTORE_SOURCE_ROOT);
    const QString script = QDir(root).absoluteFilePath(QStringLiteral("python/main.py"));
    if (QFileInfo(script).isFile()) {
        m_backendProgram = qEnvironmentVariable("OMNISTORE_PYTHON").trimmed();
        if (m_backendProgram.isEmpty())
            m_backendProgram = QStringLiteral("/usr/bin/python3");
        m_backendPrefixArguments = {script};
        m_workingDirectory = root;
        return;
    }
#endif

    m_errorMessage = tr("OmniStore backend is unavailable.");
}

bool RepositoryBridge::validType(const QString &type)
{
    return type == QStringLiteral("flatpak")
        || type == QStringLiteral("pacman")
        || type == QStringLiteral("appimage");
}

bool RepositoryBridge::basicNameValid(const QString &name)
{
    static const QRegularExpression allowed(QStringLiteral("^[A-Za-z0-9@._+:-]{1,128}$"));
    return allowed.match(name.trimmed()).hasMatch();
}

bool RepositoryBridge::basicUrlValid(const QString &url)
{
    const QString value = url.trimmed();
    return value.size() <= 2048
        && (value.startsWith(QStringLiteral("https://"))
            || value.startsWith(QStringLiteral("http://"))
            || value.startsWith(QStringLiteral("file://")));
}

void RepositoryBridge::start(Action action, const QStringList &arguments, const QString &status)
{
    if (m_process) {
        m_errorMessage = tr("Finish the current repository action first.");
        emit stateChanged();
        return;
    }
    if (m_backendProgram.isEmpty()) {
        if (m_errorMessage.isEmpty())
            m_errorMessage = tr("OmniStore backend is unavailable.");
        emit stateChanged();
        return;
    }

    m_action = action;
    m_statusMessage = status;
    m_errorMessage.clear();
    m_stdout.clear();
    m_stderr.clear();

    auto *process = new QProcess(this);
    m_process = process;
    process->setProcessChannelMode(QProcess::SeparateChannels);
    if (!m_workingDirectory.isEmpty())
        process->setWorkingDirectory(m_workingDirectory);
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("PYTHONUNBUFFERED"), QStringLiteral("1"));
    process->setProcessEnvironment(environment);

    connect(process, &QProcess::readyReadStandardOutput, this, &RepositoryBridge::consumeOutput);
    connect(process, &QProcess::readyReadStandardError, this, [this] {
        if (!m_process)
            return;
        m_stderr.append(m_process->readAllStandardError());
        if (m_stderr.size() > MaxOutput)
            m_stderr = m_stderr.right(MaxOutput);
    });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (m_process != process || error != QProcess::FailedToStart)
            return;
        m_errorMessage = tr("Repository backend could not start: %1").arg(process->errorString());
        m_statusMessage = tr("Repository action failed.");
        m_process = nullptr;
        m_action = Action::None;
        process->deleteLater();
        emit stateChanged();
    });
    connect(process, &QProcess::finished, this, &RepositoryBridge::finish);

    QStringList finalArguments = m_backendPrefixArguments;
    finalArguments.append(arguments);
    process->start(m_backendProgram, finalArguments);
    emit stateChanged();
}

void RepositoryBridge::consumeOutput()
{
    if (!m_process)
        return;
    m_stdout.append(m_process->readAllStandardOutput());
    if (m_stdout.size() > MaxOutput) {
        m_errorMessage = tr("Repository response exceeded the safe output limit.");
        m_stdout = m_stdout.right(MaxOutput);
        emit stateChanged();
    }
}

void RepositoryBridge::finish(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_process)
        return;
    consumeOutput();
    m_stderr.append(m_process->readAllStandardError());

    const Action finishedAction = m_action;
    bool success = exitStatus == QProcess::NormalExit && exitCode == 0;
    QByteArray finalJsonLine;
    for (const QByteArray &raw : m_stdout.split('\n')) {
        const QByteArray line = raw.trimmed();
        if (line.isEmpty() || line.startsWith("[CALLBACK]"))
            continue;
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isObject())
            finalJsonLine = line;
    }

    if (!finalJsonLine.isEmpty()) {
        const QJsonObject object = QJsonDocument::fromJson(finalJsonLine).object();
        if (finishedAction == Action::Refresh
            && object.contains(QStringLiteral("flatpak"))
            && object.contains(QStringLiteral("pacman"))
            && object.contains(QStringLiteral("appimage"))) {
            m_repositories = object.toVariantMap();
            emit repositoriesChanged();
        } else if (finishedAction != Action::Refresh && object.contains(QStringLiteral("status"))) {
            success = success && object.value(QStringLiteral("status")).toString() == QStringLiteral("success");
        }
    } else if (finishedAction == Action::Refresh) {
        success = false;
    }

    if (!success && m_errorMessage.isEmpty()) {
        QString detail = QString::fromUtf8(m_stderr).trimmed();
        if (detail.size() > 800)
            detail = detail.right(800);
        m_errorMessage = detail.isEmpty()
            ? tr("The repository operation failed.") : detail;
    }
    m_statusMessage = success ? tr("Repository state is up to date.")
                              : tr("Repository action failed.");

    QProcess *process = m_process;
    m_process = nullptr;
    m_action = Action::None;
    process->deleteLater();
    emit stateChanged();

    if (success && finishedAction != Action::Refresh)
        refresh();
}

void RepositoryBridge::refresh()
{
    start(Action::Refresh,
          {QStringLiteral("--list-custom-repos")},
          tr("Loading custom repositories…"));
}

void RepositoryBridge::addRepository(const QString &type, const QString &name, const QString &url)
{
    const QString normalizedType = type.trimmed().toLower();
    const QString normalizedName = name.trimmed();
    const QString normalizedUrl = url.trimmed();
    if (!validType(normalizedType) || !basicNameValid(normalizedName) || !basicUrlValid(normalizedUrl)) {
        m_errorMessage = tr("Enter a valid repository type, safe name, and http(s)/file URL.");
        emit stateChanged();
        return;
    }
    if (normalizedType == QStringLiteral("pacman") && !normalizedUrl.startsWith(QStringLiteral("https://"))) {
        m_errorMessage = tr("Pacman custom repositories require HTTPS.");
        emit stateChanged();
        return;
    }

    const QString payload = normalizedType + QLatin1Char(',') + normalizedName
        + QLatin1Char(',') + normalizedUrl;
    start(Action::Add,
          {QStringLiteral("--add-custom-repo"), payload, QStringLiteral("--json")},
          tr("Adding %1 repository…").arg(normalizedName));
}

void RepositoryBridge::removeRepository(const QString &type, const QString &identity)
{
    const QString normalizedType = type.trimmed().toLower();
    const QString normalizedIdentity = identity.trimmed();
    if (!validType(normalizedType) || normalizedIdentity.isEmpty() || normalizedIdentity.size() > 2048) {
        m_errorMessage = tr("The repository identifier is invalid.");
        emit stateChanged();
        return;
    }
    if (normalizedType != QStringLiteral("appimage") && !basicNameValid(normalizedIdentity)) {
        m_errorMessage = tr("The repository name is invalid.");
        emit stateChanged();
        return;
    }
    if (normalizedType == QStringLiteral("appimage") && !basicUrlValid(normalizedIdentity)) {
        m_errorMessage = tr("The AppImage feed URL is invalid.");
        emit stateChanged();
        return;
    }

    const QString payload = normalizedType + QLatin1Char(',') + normalizedIdentity;
    start(Action::Remove,
          {QStringLiteral("--remove-custom-repo"), payload, QStringLiteral("--json")},
          tr("Removing repository…"));
}

void RepositoryBridge::clearError()
{
    if (m_errorMessage.isEmpty())
        return;
    m_errorMessage.clear();
    emit stateChanged();
}
