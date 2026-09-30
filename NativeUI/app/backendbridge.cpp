#include "backendbridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcessEnvironment>
#include <QTimer>

namespace {
constexpr qsizetype MaxTaskLog = 256 * 1024;
constexpr qsizetype MaxJsonLine = 16 * 1024 * 1024;

QString sourceOrNative(const QString &source)
{
    const QString normalized = source.trimmed();
    return normalized.isEmpty() ? QStringLiteral("Native") : normalized;
}
}

BackendBridge::BackendBridge(QObject *parent)
    : QObject(parent)
{
    resolveBackend();
}

BackendBridge::~BackendBridge()
{
    if (!m_process)
        return;
    m_process->terminate();
    if (!m_process->waitForFinished(800)) {
        m_process->kill();
        m_process->waitForFinished(800);
    }
}

void BackendBridge::resolveBackend()
{
    const QString explicitBackend = qEnvironmentVariable("OMNISTORE_BACKEND").trimmed();
    if (!explicitBackend.isEmpty()) {
        m_backendProgram = explicitBackend;
        m_workingDirectory = QFileInfo(explicitBackend).absolutePath();
        m_backendDescription = QStringLiteral("OMNISTORE_BACKEND · %1").arg(explicitBackend);
        return;
    }

    const QString bundled = QStringLiteral("/opt/omnistore/backends/python_server");
    if (QFileInfo(bundled).isExecutable()) {
        m_backendProgram = bundled;
        m_workingDirectory = QStringLiteral("/opt/omnistore");
        m_backendDescription = QStringLiteral("Bundled Python backend");
        return;
    }

#ifdef OMNISTORE_SOURCE_ROOT
    const QString sourceRoot = QString::fromUtf8(OMNISTORE_SOURCE_ROOT);
    const QString sourceBackend = QDir(sourceRoot).absoluteFilePath(QStringLiteral("python/main.py"));
    if (QFileInfo(sourceBackend).isFile()) {
        QString python = qEnvironmentVariable("OMNISTORE_PYTHON").trimmed();
        if (python.isEmpty())
            python = QStringLiteral("/usr/bin/python3");
        m_backendProgram = python;
        m_backendPrefixArguments = {sourceBackend};
        m_workingDirectory = sourceRoot;
        m_backendDescription = QStringLiteral("Source Python backend · %1").arg(sourceBackend);
        return;
    }
#endif

    m_backendDescription = QStringLiteral("Backend unavailable");
    m_errorMessage = QStringLiteral(
        "OmniStore could not find its backend. Install the release backend or set OMNISTORE_BACKEND.");
}

void BackendBridge::enqueueRead(Operation operation, const QString &label,
                                const QStringList &arguments)
{
    Request request{operation, label, arguments, false};
    if (m_process) {
        for (const Request &queued : std::as_const(m_queue)) {
            if (queued.operation == operation)
                return;
        }
        m_queue.enqueue(request);
        return;
    }
    startRequest(request);
}

void BackendBridge::startMutation(Operation operation, const QString &label,
                                  const QStringList &arguments)
{
    if (m_process) {
        m_errorMessage = tr("Finish or cancel the current operation before starting another package action.");
        emit stateChanged();
        return;
    }
    m_queue.clear();
    startRequest(Request{operation, label, arguments, true});
}

void BackendBridge::startRequest(const Request &request)
{
    if (m_backendProgram.isEmpty()) {
        if (m_errorMessage.isEmpty())
            m_errorMessage = tr("OmniStore backend is unavailable.");
        emit stateChanged();
        return;
    }

    m_current = request;
    m_busyAction = request.label;
    m_statusMessage = tr("Running %1…").arg(request.label);
    m_errorMessage.clear();
    m_stdoutBuffer.clear();
    m_stderrBuffer.clear();
    m_lastJson.clear();
    m_callbackError = false;
    if (request.mutating) {
        m_progress = -1.0;
        m_taskStage.clear();
        m_taskSpeed.clear();
        appendTaskLog(tr("Starting %1").arg(request.label));
    }

    auto *process = new QProcess(this);
    m_process = process;
    process->setProcessChannelMode(QProcess::SeparateChannels);
    if (!m_workingDirectory.isEmpty())
        process->setWorkingDirectory(m_workingDirectory);

    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("PYTHONUNBUFFERED"), QStringLiteral("1"));
    process->setProcessEnvironment(environment);

    connect(process, &QProcess::readyReadStandardOutput, this, &BackendBridge::consumeStdout);
    connect(process, &QProcess::readyReadStandardError, this, &BackendBridge::consumeStderr);
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (m_process != process || error != QProcess::FailedToStart)
            return;
        m_errorMessage = tr("The OmniStore backend could not start: %1").arg(process->errorString());
        appendTaskLog(m_errorMessage);
        emit stateChanged();
        emit taskChanged();
    });
    connect(process, &QProcess::finished, this, &BackendBridge::finishProcess);

    QStringList arguments = m_backendPrefixArguments;
    arguments.append(request.arguments);
    process->start(m_backendProgram, arguments);
    emit stateChanged();
}

void BackendBridge::startNextQueued()
{
    if (m_process || m_queue.isEmpty())
        return;
    const Request next = m_queue.dequeue();
    QTimer::singleShot(0, this, [this, next] { startRequest(next); });
}

void BackendBridge::consumeStdout()
{
    if (!m_process)
        return;
    m_stdoutBuffer.append(m_process->readAllStandardOutput());
    while (true) {
        const qsizetype newline = m_stdoutBuffer.indexOf('\n');
        if (newline < 0)
            break;
        const QByteArray line = m_stdoutBuffer.left(newline);
        m_stdoutBuffer.remove(0, newline + 1);
        consumeLine(QString::fromUtf8(line).trimmed());
    }
    if (m_stdoutBuffer.size() > MaxJsonLine) {
        m_errorMessage = tr("Backend output exceeded the safe single-line JSON limit.");
        m_callbackError = true;
        m_stdoutBuffer.clear();
        emit stateChanged();
    }
}

void BackendBridge::consumeStderr()
{
    if (!m_process)
        return;
    m_stderrBuffer.append(m_process->readAllStandardError());
    while (true) {
        const qsizetype newline = m_stderrBuffer.indexOf('\n');
        if (newline < 0)
            break;
        const QByteArray line = m_stderrBuffer.left(newline);
        m_stderrBuffer.remove(0, newline + 1);
        const QString text = QString::fromUtf8(line).trimmed();
        if (!text.isEmpty())
            appendTaskLog(text);
    }
    if (m_stderrBuffer.size() > 64 * 1024)
        m_stderrBuffer = m_stderrBuffer.right(64 * 1024);
}

void BackendBridge::consumeLine(const QString &line)
{
    if (line.isEmpty())
        return;
    static const QString callbackPrefix = QStringLiteral("[CALLBACK] ");
    if (line.startsWith(callbackPrefix)) {
        consumeCallback(line.mid(callbackPrefix.size()).toUtf8());
        return;
    }

    const QByteArray utf8 = line.toUtf8();
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(utf8, &error);
    if (error.error == QJsonParseError::NoError && (document.isObject() || document.isArray())) {
        m_lastJson = utf8;
        return;
    }

    appendTaskLog(line);
}

void BackendBridge::consumeCallback(const QByteArray &json)
{
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(json, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) {
        appendTaskLog(QString::fromUtf8(json));
        return;
    }

    const QJsonObject object = document.object();
    const QString type = object.value(QStringLiteral("type")).toString();
    if (type == QStringLiteral("progress")) {
        const QJsonValue value = object.value(QStringLiteral("progress"));
        bool ok = false;
        double progressValue = value.isDouble() ? value.toDouble()
                                                : value.toString().toDouble(&ok);
        if (value.isDouble() || ok) {
            if (progressValue > 1.0)
                progressValue /= 100.0;
            m_progress = qBound(0.0, progressValue, 1.0);
        }
    } else if (type == QStringLiteral("stage")) {
        m_taskStage = object.value(QStringLiteral("stage")).toString();
        appendTaskLog(m_taskStage);
    } else if (type == QStringLiteral("speed")) {
        m_taskSpeed = object.value(QStringLiteral("speed")).toString();
    } else {
        const QString message = object.value(QStringLiteral("message")).toString();
        if (!message.isEmpty())
            appendTaskLog(message);
        if (type == QStringLiteral("error")) {
            m_callbackError = true;
            if (!message.isEmpty())
                m_errorMessage = message;
        }
    }
    emit taskChanged();
    emit stateChanged();
}

void BackendBridge::appendTaskLog(const QString &line)
{
    if (line.trimmed().isEmpty())
        return;
    if (!m_taskLog.isEmpty())
        m_taskLog.append(QLatin1Char('\n'));
    m_taskLog.append(line.left(8192));
    if (m_taskLog.size() > MaxTaskLog)
        m_taskLog = m_taskLog.right(MaxTaskLog);
    emit taskChanged();
}

QVariant BackendBridge::payloadFromDocument(bool *ok)
{
    if (ok)
        *ok = false;
    if (m_lastJson.isEmpty())
        return {};

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(m_lastJson, &error);
    if (error.error != QJsonParseError::NoError)
        return {};

    if (document.isArray()) {
        if (ok)
            *ok = true;
        return document.array().toVariantList();
    }

    const QJsonObject object = document.object();
    if (object.contains(QStringLiteral("status"))) {
        const QString status = object.value(QStringLiteral("status")).toString();
        if (status == QStringLiteral("error")) {
            m_errorMessage = object.value(QStringLiteral("message")).toString();
            if (m_errorMessage.isEmpty())
                m_errorMessage = object.value(QStringLiteral("error")).toString();
            if (m_errorMessage.isEmpty())
                m_errorMessage = tr("The backend reported an error.");
            return {};
        }
        if (object.contains(QStringLiteral("response"))) {
            if (ok)
                *ok = true;
            return object.value(QStringLiteral("response")).toVariant();
        }
    }

    if (ok)
        *ok = true;
    return object.toVariantMap();
}

QVariantList BackendBridge::asList(const QVariant &value)
{
    return value.canConvert<QVariantList>() ? value.toList() : QVariantList{};
}

QVariantMap BackendBridge::asMap(const QVariant &value)
{
    return value.canConvert<QVariantMap>() ? value.toMap() : QVariantMap{};
}

void BackendBridge::applyResponse(Operation operation)
{
    bool ok = false;
    const QVariant payload = payloadFromDocument(&ok);
    if (!ok)
        return;

    switch (operation) {
    case Operation::Recommendations: {
        const QVariantMap response = asMap(payload);
        m_featuredApps = response.value(QStringLiteral("featured")).toList();
        m_trendingApps = response.value(QStringLiteral("trending")).toList();
        m_forYouApps = response.value(QStringLiteral("for_you")).toList();
        break;
    }
    case Operation::Search:
        m_searchResults = asList(payload);
        break;
    case Operation::Installed:
        m_installedApps = asList(payload);
        break;
    case Operation::Updates:
        m_updates = asList(payload);
        break;
    case Operation::Plugins:
        m_plugins = asList(payload);
        break;
    case Operation::Config:
        m_config = asMap(payload);
        break;
    case Operation::Storage:
        m_storageInfo = asMap(payload);
        break;
    case Operation::Details:
        m_selectedApp = asMap(payload);
        break;
    default:
        break;
    }
    emit dataChanged();
}

void BackendBridge::finishProcess(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_process)
        return;

    consumeStdout();
    consumeStderr();
    if (!m_stdoutBuffer.trimmed().isEmpty())
        consumeLine(QString::fromUtf8(m_stdoutBuffer).trimmed());
    if (!m_stderrBuffer.trimmed().isEmpty())
        appendTaskLog(QString::fromUtf8(m_stderrBuffer).trimmed());
    m_stdoutBuffer.clear();
    m_stderrBuffer.clear();

    const Request finished = m_current;
    const bool processSucceeded = exitStatus == QProcess::NormalExit && exitCode == 0;
    if (!finished.mutating && processSucceeded)
        applyResponse(finished.operation);

    bool success = processSucceeded && !m_callbackError && m_errorMessage.isEmpty();
    if (!processSucceeded && m_errorMessage.isEmpty()) {
        m_errorMessage = exitStatus == QProcess::CrashExit
            ? tr("The OmniStore backend process crashed.")
            : tr("The OmniStore backend exited with code %1.").arg(exitCode);
    }

    if (finished.mutating) {
        m_progress = success ? 1.0 : m_progress;
        m_statusMessage = success ? tr("%1 finished.").arg(finished.label)
                                  : tr("%1 failed.").arg(finished.label);
        appendTaskLog(m_statusMessage);
    } else {
        m_statusMessage = success ? tr("%1 is ready.").arg(finished.label)
                                  : tr("%1 could not be loaded.").arg(finished.label);
    }

    QProcess *process = m_process;
    m_process = nullptr;
    m_busyAction.clear();
    process->deleteLater();
    m_current = {};

    emit stateChanged();
    emit taskChanged();
    emit operationFinished(finished.label, success);

    if (success) {
        if (finished.operation == Operation::Install || finished.operation == Operation::Remove) {
            enqueueRead(Operation::Installed, tr("installed apps"),
                        {QStringLiteral("--list-installed"), QStringLiteral("--force-refresh"),
                         QStringLiteral("--json")});
            enqueueRead(Operation::Updates, tr("updates"),
                        {QStringLiteral("--check-updates"), QStringLiteral("--json")});
        } else if (finished.operation == Operation::Update || finished.operation == Operation::UpdateAll) {
            enqueueRead(Operation::Updates, tr("updates"),
                        {QStringLiteral("--check-updates"), QStringLiteral("--json")});
            enqueueRead(Operation::Installed, tr("installed apps"),
                        {QStringLiteral("--list-installed"), QStringLiteral("--json")});
        } else if (finished.operation == Operation::PluginToggle) {
            enqueueRead(Operation::Plugins, tr("sources"),
                        {QStringLiteral("--list-plugins"), QStringLiteral("--json")});
        }
    }
    startNextQueued();
}

QString BackendBridge::operationName(Operation operation)
{
    switch (operation) {
    case Operation::Recommendations: return QStringLiteral("recommendations");
    case Operation::Search: return QStringLiteral("search");
    case Operation::Installed: return QStringLiteral("installed");
    case Operation::Updates: return QStringLiteral("updates");
    case Operation::Plugins: return QStringLiteral("plugins");
    case Operation::Config: return QStringLiteral("config");
    case Operation::Storage: return QStringLiteral("storage");
    case Operation::Details: return QStringLiteral("details");
    case Operation::Install: return QStringLiteral("install");
    case Operation::Remove: return QStringLiteral("remove");
    case Operation::Update: return QStringLiteral("update");
    case Operation::UpdateAll: return QStringLiteral("update-all");
    case Operation::Launch: return QStringLiteral("launch");
    case Operation::PluginToggle: return QStringLiteral("plugin-toggle");
    default: return QStringLiteral("idle");
    }
}

void BackendBridge::loadRecommendations()
{
    enqueueRead(Operation::Recommendations, tr("recommendations"),
                {QStringLiteral("--recommend"), QStringLiteral("--json")});
}

void BackendBridge::search(const QString &query)
{
    const QString normalized = query.trimmed();
    if (normalized.isEmpty()) {
        m_searchResults.clear();
        emit dataChanged();
        return;
    }
    enqueueRead(Operation::Search, tr("search"),
                {QStringLiteral("--search"), normalized, QStringLiteral("--json")});
}

void BackendBridge::loadInstalled(bool forceRefresh)
{
    QStringList arguments{QStringLiteral("--list-installed"), QStringLiteral("--json")};
    if (forceRefresh)
        arguments.insert(1, QStringLiteral("--force-refresh"));
    enqueueRead(Operation::Installed, tr("installed apps"), arguments);
}

void BackendBridge::loadUpdates()
{
    enqueueRead(Operation::Updates, tr("updates"),
                {QStringLiteral("--check-updates"), QStringLiteral("--json")});
}

void BackendBridge::loadPlugins()
{
    enqueueRead(Operation::Plugins, tr("sources"),
                {QStringLiteral("--list-plugins"), QStringLiteral("--json")});
}

void BackendBridge::loadConfig()
{
    enqueueRead(Operation::Config, tr("settings"),
                {QStringLiteral("--get-config"), QStringLiteral("--json")});
}

void BackendBridge::loadStorageInfo()
{
    enqueueRead(Operation::Storage, tr("storage information"),
                {QStringLiteral("--storage-info"), QStringLiteral("--json")});
}

void BackendBridge::loadDetails(const QString &appId, const QString &source)
{
    const QString id = appId.trimmed();
    if (id.isEmpty())
        return;
    QStringList arguments{QStringLiteral("--details"), id};
    if (!source.trimmed().isEmpty())
        arguments.append({QStringLiteral("--source"), source.trimmed()});
    arguments.append(QStringLiteral("--json"));
    enqueueRead(Operation::Details, tr("app details"), arguments);
}

void BackendBridge::installApp(const QString &name, const QString &source, const QString &url)
{
    QStringList arguments{QStringLiteral("--install"), name.trimmed(),
                          QStringLiteral("--source"), sourceOrNative(source)};
    if (!url.trimmed().isEmpty())
        arguments.append({QStringLiteral("--url"), url.trimmed()});
    arguments.append(QStringLiteral("--json"));
    startMutation(Operation::Install, tr("install %1").arg(name.trimmed()), arguments);
}

void BackendBridge::removeApp(const QString &name, const QString &source)
{
    startMutation(Operation::Remove, tr("remove %1").arg(name.trimmed()),
                  {QStringLiteral("--remove"), name.trimmed(), QStringLiteral("--source"),
                   sourceOrNative(source), QStringLiteral("--json")});
}

void BackendBridge::updateApp(const QString &name, const QString &source)
{
    startMutation(Operation::Update, tr("update %1").arg(name.trimmed()),
                  {QStringLiteral("--update"), name.trimmed(), QStringLiteral("--source"),
                   sourceOrNative(source), QStringLiteral("--json")});
}

void BackendBridge::updateAll()
{
    startMutation(Operation::UpdateAll, tr("update all apps"),
                  {QStringLiteral("--update"), QStringLiteral("all"), QStringLiteral("--source"),
                   QStringLiteral("all"), QStringLiteral("--json")});
}

void BackendBridge::launchApp(const QString &name, const QString &source)
{
    startMutation(Operation::Launch, tr("launch %1").arg(name.trimmed()),
                  {QStringLiteral("--launch"), name.trimmed(), QStringLiteral("--source"),
                   sourceOrNative(source), QStringLiteral("--json")});
}

void BackendBridge::setPluginEnabled(const QString &pluginId, bool enabled)
{
    const QString value = pluginId.trimmed() + QLatin1Char('=')
        + (enabled ? QStringLiteral("true") : QStringLiteral("false"));
    startMutation(Operation::PluginToggle, tr("change source %1").arg(pluginId.trimmed()),
                  {QStringLiteral("--set-plugin-enabled"), value, QStringLiteral("--json")});
}

void BackendBridge::cancelOperation()
{
    if (!m_process)
        return;
    m_queue.clear();
    m_callbackError = true;
    m_errorMessage = tr("Operation cancelled by the user.");
    appendTaskLog(m_errorMessage);
    QProcess *process = m_process;
    process->terminate();
    QTimer::singleShot(1200, process, [process] {
        if (process->state() != QProcess::NotRunning)
            process->kill();
    });
    emit stateChanged();
}

void BackendBridge::clearTaskLog()
{
    m_taskLog.clear();
    m_progress = -1.0;
    m_taskStage.clear();
    m_taskSpeed.clear();
    emit taskChanged();
}

void BackendBridge::clearError()
{
    if (m_errorMessage.isEmpty())
        return;
    m_errorMessage.clear();
    emit stateChanged();
}
