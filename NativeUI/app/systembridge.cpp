#include "systembridge.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QRegularExpression>

namespace {
constexpr qsizetype MaxOutput = 8 * 1024 * 1024;
}

SystemBridge::SystemBridge(QObject *parent)
    : QObject(parent)
{
    resolveBackend();
}

SystemBridge::~SystemBridge()
{
    if (!m_process)
        return;
    m_process->terminate();
    if (!m_process->waitForFinished(800)) {
        m_process->kill();
        m_process->waitForFinished(800);
    }
}

void SystemBridge::resolveBackend()
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

bool SystemBridge::validPlanHash(const QString &hash)
{
    static const QRegularExpression expression(QStringLiteral("^[0-9a-f]{64}$"));
    return expression.match(hash.trimmed()).hasMatch();
}

void SystemBridge::enqueue(const Request &request)
{
    if (request.mutating) {
        if (m_process) {
            m_errorMessage = tr("Finish the current system action before changing the update channel.");
            emit stateChanged();
            return;
        }
        m_queue.clear();
        start(request);
        return;
    }

    if (m_process) {
        for (const Request &queued : std::as_const(m_queue)) {
            if (queued.action == request.action)
                return;
        }
        m_queue.enqueue(request);
        return;
    }
    start(request);
}

void SystemBridge::start(const Request &request)
{
    if (m_backendProgram.isEmpty()) {
        if (m_errorMessage.isEmpty())
            m_errorMessage = tr("OmniStore backend is unavailable.");
        emit stateChanged();
        return;
    }

    m_current = request;
    m_statusMessage = request.status;
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

    connect(process, &QProcess::readyReadStandardOutput, this, &SystemBridge::readOutput);
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
        m_errorMessage = tr("System backend could not start: %1").arg(process->errorString());
        m_statusMessage = tr("System status action failed.");
        m_process = nullptr;
        m_current = {};
        process->deleteLater();
        emit stateChanged();
        startNext();
    });
    connect(process, &QProcess::finished, this, &SystemBridge::finish);

    QStringList arguments = m_backendPrefixArguments;
    arguments.append(request.arguments);
    process->start(m_backendProgram, arguments);
    emit stateChanged();
}

void SystemBridge::startNext()
{
    if (m_process || m_queue.isEmpty())
        return;
    const Request request = m_queue.dequeue();
    start(request);
}

void SystemBridge::readOutput()
{
    if (!m_process)
        return;
    m_stdout.append(m_process->readAllStandardOutput());
    if (m_stdout.size() > MaxOutput) {
        m_errorMessage = tr("System status response exceeded the safe output limit.");
        m_stdout = m_stdout.right(MaxOutput);
        emit stateChanged();
    }
}

QVariantMap SystemBridge::lastJsonObject() const
{
    QVariantMap result;
    for (const QByteArray &raw : m_stdout.split('\n')) {
        const QByteArray line = raw.trimmed();
        if (line.isEmpty() || line.startsWith("[CALLBACK]"))
            continue;
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(line, &error);
        if (error.error == QJsonParseError::NoError && document.isObject())
            result = document.object().toVariantMap();
    }
    return result;
}

void SystemBridge::apply(Action action, const QVariantMap &payload)
{
    switch (action) {
    case Action::ChannelStatus:
    case Action::SwitchBeta:
        m_channelState = payload;
        if (payload.value(QStringLiteral("status")).toString() == QStringLiteral("success"))
            m_stablePreview.clear();
        break;
    case Action::SwitchStable:
        if (payload.value(QStringLiteral("status")).toString() == QStringLiteral("confirmation_required"))
            m_stablePreview = payload;
        else {
            m_channelState = payload;
            m_stablePreview.clear();
        }
        break;
    case Action::ConfirmStable:
        m_channelState = payload;
        m_stablePreview.clear();
        break;
    case Action::UpdateState:
        m_updateState = payload;
        break;
    case Action::UpdatePlan:
        m_updatePlan = payload;
        break;
    case Action::Environment:
        m_environmentState = payload;
        break;
    case Action::Bootstrap:
    case Action::None:
        break;
    }
    emit dataChanged();
}

void SystemBridge::finish(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_process)
        return;
    readOutput();
    m_stderr.append(m_process->readAllStandardError());

    const Request finished = m_current;
    const QVariantMap payload = lastJsonObject();
    bool success = exitStatus == QProcess::NormalExit && exitCode == 0 && !payload.isEmpty();
    const QString payloadStatus = payload.value(QStringLiteral("status")).toString();
    if (payloadStatus == QStringLiteral("error"))
        success = false;

    if (success)
        apply(finished.action, payload);
    else if (m_errorMessage.isEmpty()) {
        QString detail = payload.value(QStringLiteral("error")).toString();
        if (detail.isEmpty())
            detail = QString::fromUtf8(m_stderr).trimmed();
        if (detail.size() > 1000)
            detail = detail.right(1000);
        m_errorMessage = detail.isEmpty()
            ? tr("The system status operation failed.") : detail;
    }

    m_statusMessage = success ? tr("System status is up to date.")
                              : tr("System status action failed.");
    QProcess *process = m_process;
    m_process = nullptr;
    m_current = {};
    process->deleteLater();
    emit stateChanged();

    if (success && finished.action == Action::Bootstrap)
        refreshEnvironment();
    if (success && (finished.action == Action::SwitchBeta
                    || finished.action == Action::ConfirmStable)) {
        refreshChannel();
        refreshUpdateState();
    }
    startNext();
}

void SystemBridge::refreshAll()
{
    refreshChannel();
    refreshUpdateState();
    refreshUpdatePlan();
    refreshEnvironment();
}

void SystemBridge::refreshChannel()
{
    enqueue({Action::ChannelStatus,
             {QStringLiteral("--meo-channel"), QStringLiteral("status"), QStringLiteral("--json")},
             tr("Reading Meo update channel…"), false});
}

void SystemBridge::refreshUpdateState()
{
    enqueue({Action::UpdateState,
             {QStringLiteral("--update-status"), QStringLiteral("--json")},
             tr("Reading update state…"), false});
}

void SystemBridge::refreshUpdatePlan()
{
    enqueue({Action::UpdatePlan,
             {QStringLiteral("--update-plan"), QStringLiteral("--json")},
             tr("Checking unified update plan…"), false});
}

void SystemBridge::refreshEnvironment()
{
    enqueue({Action::Environment,
             {QStringLiteral("--check-env"), QStringLiteral("--json")},
             tr("Checking OmniStore environment…"), false});
}

void SystemBridge::bootstrapEnvironment()
{
    enqueue({Action::Bootstrap,
             {QStringLiteral("--bootstrap"), QStringLiteral("--json")},
             tr("Preparing OmniStore environment…"), true});
}

void SystemBridge::switchBeta()
{
    enqueue({Action::SwitchBeta,
             {QStringLiteral("--meo-channel"), QStringLiteral("beta"), QStringLiteral("--json")},
             tr("Switching to Meo Beta…"), true});
}

void SystemBridge::switchStable()
{
    enqueue({Action::SwitchStable,
             {QStringLiteral("--meo-channel"), QStringLiteral("stable"), QStringLiteral("--json")},
             tr("Preparing Meo Stable…"), true});
}

void SystemBridge::confirmStable(const QString &planHash)
{
    const QString normalized = planHash.trimmed();
    if (!validPlanHash(normalized)) {
        m_errorMessage = tr("The Stable rollback preview has an invalid plan hash. Refresh and review it again.");
        emit stateChanged();
        return;
    }
    enqueue({Action::ConfirmStable,
             {QStringLiteral("--meo-channel"), QStringLiteral("stable"),
              QStringLiteral("--confirm-meo-stable-downgrades"),
              QStringLiteral("--meo-stable-plan-hash"), normalized,
              QStringLiteral("--json")},
             tr("Applying the reviewed Stable rollback plan…"), true});
}

void SystemBridge::clearStablePreview()
{
    if (m_stablePreview.isEmpty())
        return;
    m_stablePreview.clear();
    emit dataChanged();
}

void SystemBridge::clearError()
{
    if (m_errorMessage.isEmpty())
        return;
    m_errorMessage.clear();
    emit stateChanged();
}
