#include "transactionclient.h"
#include "backendlocator.h"
#include "friendlyerror.h"

#include <QCoreApplication>
#include <QDir>
#include <QHostAddress>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>

#include <utility>

namespace {
constexpr int PollIntervalMs = 250;
constexpr int ReconnectDelayMs = 250;
constexpr int MaxReconnectAttempts = 8;

QString sourceOrNative(const QString &source)
{
    const QString normalized = source.trimmed();
    return normalized.isEmpty() ? QStringLiteral("Native") : normalized;
}
}

TransactionClient::TransactionClient(QObject *parent)
    : QObject(parent),
      m_socketPath(resolveSocketPath())
{
    m_pollTimer.setInterval(PollIntervalMs);
    m_pollTimer.setSingleShot(false);
    connect(&m_pollTimer, &QTimer::timeout, this, [this] {
        if (m_taskId.isEmpty() || m_submitting || !busy()) {
            if (!m_submitting)
                m_pollTimer.stop();
            return;
        }
        enqueue(RequestKind::Get, {
            {QStringLiteral("action"), QStringLiteral("task.get")},
            {QStringLiteral("args"), QJsonArray{m_taskId}},
            {QStringLiteral("kwargs"), QJsonObject{}},
        });
    });

    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(ReconnectDelayMs);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &TransactionClient::reconnect);

    m_useTcp = qEnvironmentVariableIntValue("OMNISTORE_DAEMON_TCP") != 0
#ifdef Q_OS_WIN
        || true
#endif
        ;
    connect(&m_local, &QLocalSocket::connected, this, &TransactionClient::onTransportConnected);
    connect(&m_tcp, &QTcpSocket::connected, this, &TransactionClient::onTransportConnected);
    connect(&m_local, &QLocalSocket::readyRead, this, &TransactionClient::consumeSocketData);
    connect(&m_tcp, &QTcpSocket::readyRead, this, &TransactionClient::consumeSocketData);
    connect(&m_local, &QLocalSocket::disconnected, this, &TransactionClient::onTransportDisconnected);
    connect(&m_tcp, &QTcpSocket::disconnected, this, &TransactionClient::onTransportDisconnected);
    connect(&m_local, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) { onTransportError(); });
    connect(&m_tcp, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) { onTransportError(); });

    startUserService();
    QTimer::singleShot(120, this, &TransactionClient::reconnect);
}

bool TransactionClient::transportConnected() const
{
    return m_useTcp ? m_tcp.state() == QAbstractSocket::ConnectedState
                    : m_local.state() == QLocalSocket::ConnectedState;
}

bool TransactionClient::transportIdle() const
{
    return m_useTcp ? m_tcp.state() == QAbstractSocket::UnconnectedState
                    : m_local.state() == QLocalSocket::UnconnectedState;
}

void TransactionClient::transportAbort()
{
    if (m_useTcp)
        m_tcp.abort();
    else
        m_local.abort();
}

QString TransactionClient::transportError() const
{
    return m_useTcp ? m_tcp.errorString() : m_local.errorString();
}

qint64 TransactionClient::transportWrite(const QByteArray &data)
{
    return m_useTcp ? m_tcp.write(data) : m_local.write(data);
}

QByteArray TransactionClient::transportReadAll()
{
    return m_useTcp ? m_tcp.readAll() : m_local.readAll();
}

QString TransactionClient::tcpFilePath() const
{
    // Chosen here and handed to the daemon, so both sides agree without guessing.
    const QString explicitPath = qEnvironmentVariable("OMNISTORE_DAEMON_TCP_FILE").trimmed();
    if (!explicitPath.isEmpty())
        return explicitPath;
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    return base.isEmpty() ? QString{} : QDir(base).filePath(QStringLiteral("OmniStore/daemon.json"));
}

void TransactionClient::transportConnect()
{
    if (!m_useTcp) {
        m_local.connectToServer(m_socketPath, QIODevice::ReadWrite);
        return;
    }
    QFile file(tcpFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        // The daemon has not written its endpoint yet; the reconnect timer retries.
        onTransportError();
        return;
    }
    const QJsonObject endpoint = QJsonDocument::fromJson(file.readAll()).object();
    const int port = endpoint.value(QStringLiteral("port")).toInt();
    m_tcpToken = endpoint.value(QStringLiteral("token")).toString();
    if (port <= 0 || m_tcpToken.isEmpty()) {
        onTransportError();
        return;
    }
    m_tcp.connectToHost(QHostAddress::LocalHost, static_cast<quint16>(port));
}

void TransactionClient::onTransportConnected()
{
    if (m_useTcp) {
        // First line authenticates this client; the daemon drops anyone else.
        m_tcp.write(QJsonDocument(QJsonObject{{QStringLiteral("auth"), m_tcpToken}})
                        .toJson(QJsonDocument::Compact) + '\n');
    }
    m_available = true;
    m_reconnectAttempts = 0;
    m_errorMessage.clear();
    emit stateChanged();
    if (m_queue.isEmpty())
        reconnect(); // Restore tasks after initial connection or a service restart.
    else
        startNext();
}

void TransactionClient::onTransportDisconnected()
{
    m_available = false;
    m_submitting = false;
    if (m_current.kind == RequestKind::Plan && m_planning) {
        m_planning = false;
        emit stateChanged();
    }
    emit stateChanged();
    if (m_requestInFlight) {
        // Never blindly retry a mutation submit: the daemon may already own
        // the transaction even if the reply was lost. Reconnect and
        // task.list instead so the UI recovers state without duplication.
        m_requestInFlight = false;
        m_current = {};
        if (!m_queue.isEmpty())
            m_queue.dequeue();
    }
    scheduleReconnect();
}

void TransactionClient::onTransportError()
{
    m_available = false;
    // No systemd to start the service for us (macOS, Windows): launch it ourselves once.
    if (!m_daemonSpawned)
        spawnDaemon();
    if (m_reconnectAttempts >= MaxReconnectAttempts) {
        m_errorMessage = tr("OmniStore transaction service is unavailable: %1").arg(transportError());
        emit stateChanged();
    }
    scheduleReconnect();
}

void TransactionClient::spawnDaemon()
{
    if (qEnvironmentVariableIntValue("OMNISTORE_NO_DAEMON_SPAWN") != 0)
        return;
    if (m_systemdManaged)
        return;  // systemd owns the service
    const BackendCommand command = BackendLocator::locate();
    if (!command.valid())
        return;
    m_daemonSpawned = true;
    QStringList arguments = command.prefixArguments;
    arguments << QStringLiteral("--daemon");
    if (m_useTcp) {
        const QString file = tcpFilePath();
        if (file.isEmpty())
            return;
        QDir().mkpath(QFileInfo(file).absolutePath());
        arguments << QStringLiteral("--daemon-tcp-file") << file;
    } else {
        QDir().mkpath(QFileInfo(m_socketPath).absolutePath());
        arguments << QStringLiteral("--daemon-socket") << m_socketPath;
    }
    // The service must not inherit the UI's stdio (it would keep a terminal or pipe open).
    QProcess process;
    process.setProgram(command.program);
    process.setArguments(arguments);
    process.setWorkingDirectory(command.workingDirectory);
    process.setStandardInputFile(QProcess::nullDevice());
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
    process.startDetached();
}

TransactionClient::~TransactionClient()
{
    // Sockets are destroyed after the state their handlers touch; silence them first.
    QObject::disconnect(&m_local, nullptr, this, nullptr);
    QObject::disconnect(&m_tcp, nullptr, this, nullptr);
    m_pollTimer.stop();
    m_reconnectTimer.stop();
}

QString TransactionClient::resolveSocketPath() const
{
    const QString explicitPath = qEnvironmentVariable("OMNISTORE_DAEMON_SOCKET").trimmed();
    if (!explicitPath.isEmpty())
        return explicitPath;

#ifdef Q_OS_LINUX
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtime.isEmpty())
        return {};
    return QDir(runtime).filePath(QStringLiteral("omnistore/daemon.sock"));
#else
    // macOS has no per-user runtime directory; keep the path short because
    // Unix socket paths are limited (about 100 bytes).
    const QString cache = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    QString path = QDir(cache).filePath(QStringLiteral("OmniStore/daemon.sock"));
    if (cache.isEmpty() || path.toUtf8().size() > 100)
        path = QDir::temp().filePath(QStringLiteral("omnistore-%1.sock").arg(qEnvironmentVariable("USER")));
    return path;
#endif
}

void TransactionClient::startUserService()
{
#ifdef Q_OS_LINUX
    if (m_useTcp || qEnvironmentVariableIntValue("OMNISTORE_NO_SYSTEMD_START") != 0)
        return;
    // Without the packaged unit (no systemd, or a source checkout) the client starts the service itself.
    if (QStandardPaths::findExecutable(QStringLiteral("systemctl")).isEmpty()
        || !(QFile::exists(QStringLiteral("/usr/lib/systemd/user/omnistore-task.service"))
             || QFile::exists(QStringLiteral("/etc/systemd/user/omnistore-task.service"))))
        return;
    m_systemdManaged = true;
    QProcess::startDetached(QStringLiteral("systemctl"),
                            {QStringLiteral("--user"), QStringLiteral("start"),
                             QStringLiteral("omnistore-task.service")});
#endif
}

void TransactionClient::scheduleReconnect()
{
    if ((m_useTcp ? tcpFilePath() : m_socketPath).isEmpty() || m_reconnectTimer.isActive())
        return;
    if (m_reconnectAttempts >= MaxReconnectAttempts)
        return;
    ++m_reconnectAttempts;
    m_reconnectTimer.start();
}

void TransactionClient::reconnect()
{
    if ((m_useTcp ? tcpFilePath() : m_socketPath).isEmpty()) {
        m_errorMessage = tr("No user runtime directory is available for the OmniStore transaction socket.");
        emit stateChanged();
        return;
    }
    if (transportConnected()) {
        enqueue(RequestKind::List, {
            {QStringLiteral("action"), QStringLiteral("task.list")},
            {QStringLiteral("args"), QJsonArray{}},
            {QStringLiteral("kwargs"), QJsonObject{}},
        });
        return;
    }
    if (!transportIdle())
        transportAbort();
    transportConnect();
}

void TransactionClient::enqueue(RequestKind kind, const QJsonObject &payload)
{
    if (kind == RequestKind::Get) {
        if (m_current.kind == RequestKind::Get)
            return;
        for (const PendingRequest &queued : std::as_const(m_queue)) {
            if (queued.kind == RequestKind::Get)
                return;
        }
    }
    m_queue.enqueue(PendingRequest{kind, payload});
    startNext();
}

void TransactionClient::startNext()
{
    if (m_requestInFlight || m_queue.isEmpty())
        return;
    if (!transportConnected()) {
        reconnect();
        return;
    }
    m_current = m_queue.head();
    m_requestInFlight = true;
    sendCurrent();
}

void TransactionClient::sendCurrent()
{
    const QByteArray payload = QJsonDocument(m_current.payload).toJson(QJsonDocument::Compact) + '\n';
    if (transportWrite(payload) < 0) {
        if (m_current.kind == RequestKind::Plan)
            m_planning = false;
        m_errorMessage = tr("Could not send request to the OmniStore transaction service.");
        emit stateChanged();
        m_requestInFlight = false;
        m_current = {};
        if (!m_queue.isEmpty())
            m_queue.dequeue();
        scheduleReconnect();
        return;
    }
    if (m_useTcp) m_tcp.flush(); else m_local.flush();
}

void TransactionClient::consumeSocketData()
{
    m_buffer.append(transportReadAll());
    while (true) {
        const qsizetype newline = m_buffer.indexOf('\n');
        if (newline < 0)
            break;
        const QByteArray line = m_buffer.left(newline).trimmed();
        m_buffer.remove(0, newline + 1);
        if (line.isEmpty())
            continue;

        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(line, &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            if (m_current.kind == RequestKind::Plan)
                m_planning = false;
            if (m_current.kind == RequestKind::Submit)
                m_submitting = false;
            m_errorMessage = tr("The transaction service returned invalid JSON.");
            emit stateChanged();
        } else {
            handleResponse(m_current.kind, document.object());
        }

        m_requestInFlight = false;
        m_current = {};
        if (!m_queue.isEmpty())
            m_queue.dequeue();
        startNext();
    }
}

void TransactionClient::handleResponse(RequestKind kind, const QJsonObject &response)
{
    const QString topStatus = response.value(QStringLiteral("status")).toString();
    if (topStatus != QStringLiteral("success")) {
        if (kind == RequestKind::Plan)
            m_planning = false;
        if (kind == RequestKind::Submit)
            m_submitting = false;
        m_errorDetail = response.value(QStringLiteral("error")).toString();
        m_errorMessage = m_errorDetail.isEmpty() ? tr("The transaction service rejected the request.")
                                                 : FriendlyError::message(m_errorDetail);
        emit stateChanged();
        return;
    }

    const QJsonValue value = response.value(QStringLiteral("response"));
    if (kind == RequestKind::List) {
        if (!value.isArray())
            return;
        const QJsonArray tasks = value.toArray();
        QJsonObject candidate;
        for (const QJsonValue &item : tasks) {
            if (!item.isObject())
                continue;
            const QJsonObject task = item.toObject();
            const QString status = task.value(QStringLiteral("status")).toString();
            if (status == QStringLiteral("queued") || status == QStringLiteral("running")) {
                candidate = task;
                break;
            }
            if (candidate.isEmpty())
                candidate = task;
        }
        if (!candidate.isEmpty())
            applyTask(candidate);
        return;
    }

    if (kind == RequestKind::Plan) {
        m_planning = false;
        if (!value.isObject()) {
            m_errorMessage = tr("The transaction service returned an invalid install plan.");
            emit stateChanged();
            return;
        }
        m_installPlan = value.toObject();
        m_errorMessage.clear();
        emit planChanged();
        emit stateChanged();
        return;
    }

    if (kind == RequestKind::Submit)
        m_submitting = false;
    if ((kind == RequestKind::Submit || kind == RequestKind::Get) && value.isObject()) {
        const QJsonObject task = value.toObject();
        applyTask(task);
        if (kind == RequestKind::Submit && !m_installPlan.isEmpty()) {
            const QString plannedHash = m_installPlan.value(QStringLiteral("planHash")).toString();
            if (!plannedHash.isEmpty()
                && task.value(QStringLiteral("planHash")).toString() == plannedHash) {
                m_installPlan = {};
                emit planChanged();
            }
        }
    }
}

QString TransactionClient::errorCategory() const
{
    return m_errorDetail.isEmpty() ? QString{} : FriendlyError::category(m_errorDetail);
}

void TransactionClient::applyTask(const QJsonObject &task)
{
    const QString previousStatus = m_status;
    m_taskId = task.value(QStringLiteral("taskId")).toString();
    m_status = task.value(QStringLiteral("status")).toString();
    const QString kind = task.value(QStringLiteral("kind")).toString();
    const QString name = task.value(QStringLiteral("name")).toString();
    m_taskName = name;
    m_taskKind = kind;
    m_taskSource = task.value(QStringLiteral("source")).toString();
    if (kind == QStringLiteral("update_all"))
        m_actionName = tr("Update all software");
    else if (kind == QStringLiteral("update"))
        m_actionName = tr("Update %1").arg(name);
    else if (kind == QStringLiteral("install"))
        m_actionName = tr("Install %1").arg(name);
    else if (kind == QStringLiteral("remove"))
        m_actionName = tr("Remove %1").arg(name);
    else
        m_actionName = name.isEmpty() ? kind : QStringLiteral("%1 %2").arg(kind, name);
    m_stage = task.value(QStringLiteral("stage")).toString();
    m_sourceUpdates = task.value(QStringLiteral("sourceUpdates")).toArray().toVariantList();
    m_authenticationPrompt = busy()
        ? task.value(QStringLiteral("authenticationPrompt")).toString() : QString{};
    m_speed = task.value(QStringLiteral("speed")).toString();
    m_log = task.value(QStringLiteral("log")).toString();
    m_progress = task.contains(QStringLiteral("progress"))
        ? task.value(QStringLiteral("progress")).toDouble(-1.0) : -1.0;
    m_errorDetail = task.value(QStringLiteral("error")).toString();
    m_errorMessage = m_errorDetail.isEmpty() ? QString{} : FriendlyError::message(m_errorDetail, kind, name);
    m_available = true;

    emit taskChanged();
    emit stateChanged();

    if (busy()) {
        if (!m_pollTimer.isActive())
            m_pollTimer.start();
        return;
    }

    m_pollTimer.stop();
    if (!previousStatus.isEmpty() && previousStatus != m_status && terminalStatus(m_status))
        emit operationFinished(m_actionName, m_status == QStringLiteral("succeeded"));
}

void TransactionClient::planInstall(const QString &name, const QString &source, const QString &url)
{
    if (busy()) {
        m_errorMessage = tr("Finish the current package transaction before reviewing another install.");
        emit stateChanged();
        return;
    }
    if (m_planning)
        return;

    m_installPlan = {};
    emit planChanged();

    QJsonObject kwargs{
        {QStringLiteral("kind"), QStringLiteral("install")},
        {QStringLiteral("name"), name.trimmed()},
        {QStringLiteral("source"), sourceOrNative(source)},
    };
    if (!url.trimmed().isEmpty())
        kwargs.insert(QStringLiteral("url"), url.trimmed());

    m_errorMessage.clear();
    m_planning = true;
    emit stateChanged();
    enqueue(RequestKind::Plan, {
        {QStringLiteral("action"), QStringLiteral("transaction.plan")},
        {QStringLiteral("args"), QJsonArray{}},
        {QStringLiteral("kwargs"), kwargs},
    });
}

void TransactionClient::applyInstallPlan()
{
    if (busy()) {
        m_errorMessage = tr("Finish the current package transaction before starting another one.");
        emit stateChanged();
        return;
    }
    if (m_installPlan.isEmpty()) {
        m_errorMessage = tr("Review an install plan before applying it.");
        emit stateChanged();
        return;
    }
    if (!m_installPlan.value(QStringLiteral("canApply")).toBool(false)) {
        m_errorMessage = tr("This install plan cannot be applied with the current source state.");
        emit stateChanged();
        return;
    }

    const QString planHash = m_installPlan.value(QStringLiteral("planHash")).toString().trimmed();
    if (planHash.isEmpty()) {
        m_errorMessage = tr("The reviewed install plan is missing its identity hash.");
        emit stateChanged();
        return;
    }

    m_errorMessage.clear();
    m_submitting = true;
    m_stage = tr("Sending request…");
    m_progress = -1.0;
    emit taskChanged();
    emit stateChanged();
    enqueue(RequestKind::Submit, {
        {QStringLiteral("action"), QStringLiteral("task.submit")},
        {QStringLiteral("args"), QJsonArray{}},
        {QStringLiteral("kwargs"), QJsonObject{
            {QStringLiteral("plan_hash"), planHash},
        }},
    });
}

void TransactionClient::clearInstallPlan()
{
    if (m_installPlan.isEmpty())
        return;
    m_installPlan = {};
    emit planChanged();
}

void TransactionClient::submit(const QString &kind, const QString &name,
                               const QString &source, const QString &url)
{
    if (busy()) {
        m_errorMessage = tr("Finish the current package transaction before starting another one.");
        emit stateChanged();
        return;
    }

    QJsonObject kwargs{
        {QStringLiteral("kind"), kind},
        {QStringLiteral("name"), name.trimmed()},
        {QStringLiteral("source"), sourceOrNative(source)},
    };
    if (!url.trimmed().isEmpty())
        kwargs.insert(QStringLiteral("url"), url.trimmed());

    m_errorMessage.clear();
    m_submitting = true;
    m_stage = tr("Sending request…");
    m_progress = -1.0;
    emit taskChanged();
    emit stateChanged();
    enqueue(RequestKind::Submit, {
        {QStringLiteral("action"), QStringLiteral("task.submit")},
        {QStringLiteral("args"), QJsonArray{}},
        {QStringLiteral("kwargs"), kwargs},
    });
}

void TransactionClient::removeApp(const QString &name, const QString &source)
{
    submit(QStringLiteral("remove"), name, source);
}

void TransactionClient::updateApp(const QString &name, const QString &source)
{
    submit(QStringLiteral("update"), name, source);
}

void TransactionClient::updateAll()
{
    submit(QStringLiteral("update_all"), QStringLiteral("all"), QStringLiteral("all"));
}

void TransactionClient::clearError()
{
    if (m_errorMessage.isEmpty())
        return;
    m_errorMessage.clear();
    emit stateChanged();
}

bool TransactionClient::terminalStatus(const QString &status)
{
    return status == QStringLiteral("succeeded")
        || status == QStringLiteral("failed")
        || status == QStringLiteral("cancelled");
}
