#include "transactionclient.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>

#include <utility>

namespace {
constexpr int PollIntervalMs = 650;
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
        if (m_taskId.isEmpty() || !busy()) {
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

    connect(&m_socket, &QLocalSocket::connected, this, [this] {
        m_available = true;
        m_reconnectAttempts = 0;
        m_errorMessage.clear();
        emit stateChanged();
        startNext();
    });
    connect(&m_socket, &QLocalSocket::readyRead, this, &TransactionClient::consumeSocketData);
    connect(&m_socket, &QLocalSocket::disconnected, this, [this] {
        m_available = false;
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
    });
    connect(&m_socket, &QLocalSocket::errorOccurred, this,
            [this](QLocalSocket::LocalSocketError) {
        m_available = false;
        if (m_reconnectAttempts >= MaxReconnectAttempts) {
            m_errorMessage = tr("OmniStore transaction service is unavailable: %1")
                                 .arg(m_socket.errorString());
            emit stateChanged();
        }
        scheduleReconnect();
    });

    startUserService();
    QTimer::singleShot(120, this, &TransactionClient::reconnect);
}

QString TransactionClient::resolveSocketPath() const
{
    const QString explicitPath = qEnvironmentVariable("OMNISTORE_DAEMON_SOCKET").trimmed();
    if (!explicitPath.isEmpty())
        return explicitPath;

    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtime.isEmpty())
        return {};
    return QDir(runtime).filePath(QStringLiteral("omnistore/daemon.sock"));
}

void TransactionClient::startUserService()
{
    if (qEnvironmentVariableIntValue("OMNISTORE_NO_SYSTEMD_START") != 0)
        return;
    QProcess::startDetached(QStringLiteral("systemctl"),
                            {QStringLiteral("--user"), QStringLiteral("start"),
                             QStringLiteral("omnistore-task.service")});
}

void TransactionClient::scheduleReconnect()
{
    if (m_socketPath.isEmpty() || m_reconnectTimer.isActive())
        return;
    if (m_reconnectAttempts >= MaxReconnectAttempts)
        return;
    ++m_reconnectAttempts;
    m_reconnectTimer.start();
}

void TransactionClient::reconnect()
{
    if (m_socketPath.isEmpty()) {
        m_errorMessage = tr("No user runtime directory is available for the OmniStore transaction socket.");
        emit stateChanged();
        return;
    }
    if (m_socket.state() == QLocalSocket::ConnectedState) {
        enqueue(RequestKind::List, {
            {QStringLiteral("action"), QStringLiteral("task.list")},
            {QStringLiteral("args"), QJsonArray{}},
            {QStringLiteral("kwargs"), QJsonObject{}},
        });
        return;
    }
    if (m_socket.state() != QLocalSocket::UnconnectedState)
        m_socket.abort();
    m_socket.connectToServer(m_socketPath, QIODevice::ReadWrite);
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
    if (m_socket.state() != QLocalSocket::ConnectedState) {
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
    if (m_socket.write(payload) < 0) {
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
    m_socket.flush();
}

void TransactionClient::consumeSocketData()
{
    m_buffer.append(m_socket.readAll());
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
        m_errorMessage = response.value(QStringLiteral("error")).toString();
        if (m_errorMessage.isEmpty())
            m_errorMessage = tr("The transaction service rejected the request.");
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

void TransactionClient::applyTask(const QJsonObject &task)
{
    const QString previousStatus = m_status;
    m_taskId = task.value(QStringLiteral("taskId")).toString();
    m_status = task.value(QStringLiteral("status")).toString();
    const QString kind = task.value(QStringLiteral("kind")).toString();
    const QString name = task.value(QStringLiteral("name")).toString();
    m_actionName = name.isEmpty() ? kind : QStringLiteral("%1 %2").arg(kind, name);
    m_stage = task.value(QStringLiteral("stage")).toString();
    m_speed = task.value(QStringLiteral("speed")).toString();
    m_log = task.value(QStringLiteral("log")).toString();
    m_progress = task.contains(QStringLiteral("progress"))
        ? task.value(QStringLiteral("progress")).toDouble(-1.0) : -1.0;
    m_errorMessage = task.value(QStringLiteral("error")).toString();
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
