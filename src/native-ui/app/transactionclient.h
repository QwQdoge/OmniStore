#pragma once

#include <QObject>
#include <QJsonObject>
#include <QLocalSocket>
#include <QQueue>
#include <QString>
#include <QTimer>
#include <QVariantMap>

class TransactionClient final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool planning READ planning NOTIFY stateChanged)
    Q_PROPERTY(bool hasInstallPlan READ hasInstallPlan NOTIFY planChanged)
    Q_PROPERTY(QVariantMap installPlan READ installPlan NOTIFY planChanged)
    Q_PROPERTY(QString taskId READ taskId NOTIFY taskChanged)
    Q_PROPERTY(QString status READ status NOTIFY taskChanged)
    Q_PROPERTY(QString actionName READ actionName NOTIFY taskChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY taskChanged)
    Q_PROPERTY(QVariantList sourceUpdates READ sourceUpdates NOTIFY taskChanged)
    Q_PROPERTY(QString authenticationPrompt READ authenticationPrompt NOTIFY taskChanged)
    Q_PROPERTY(QString speed READ speed NOTIFY taskChanged)
    Q_PROPERTY(QString log READ log NOTIFY taskChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY taskChanged)

public:
    explicit TransactionClient(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool busy() const { return m_status == QStringLiteral("queued") || m_status == QStringLiteral("running"); }
    bool planning() const { return m_planning; }
    bool hasInstallPlan() const { return !m_installPlan.isEmpty(); }
    QVariantMap installPlan() const { return m_installPlan.toVariantMap(); }
    QString taskId() const { return m_taskId; }
    QString status() const { return m_status; }
    QString actionName() const { return m_actionName; }
    QString stage() const { return m_stage; }
    QVariantList sourceUpdates() const { return m_sourceUpdates; }
    QString authenticationPrompt() const { return m_authenticationPrompt; }
    QString speed() const { return m_speed; }
    QString log() const { return m_log; }
    QString errorMessage() const { return m_errorMessage; }
    double progress() const { return m_progress; }

    Q_INVOKABLE void reconnect();
    Q_INVOKABLE void planInstall(const QString &name, const QString &source,
                                 const QString &url = {});
    Q_INVOKABLE void applyInstallPlan();
    Q_INVOKABLE void clearInstallPlan();
    Q_INVOKABLE void removeApp(const QString &name, const QString &source);
    Q_INVOKABLE void updateApp(const QString &name, const QString &source);
    Q_INVOKABLE void updateAll();
    Q_INVOKABLE void clearError();

signals:
    void stateChanged();
    void planChanged();
    void taskChanged();
    void operationFinished(const QString &action, bool success);

private:
    enum class RequestKind { None, List, Plan, Submit, Get };

    struct PendingRequest {
        RequestKind kind = RequestKind::None;
        QJsonObject payload;
    };

    QString resolveSocketPath() const;
    void startUserService();
    void enqueue(RequestKind kind, const QJsonObject &payload);
    void startNext();
    void sendCurrent();
    void consumeSocketData();
    void handleResponse(RequestKind kind, const QJsonObject &response);
    void applyTask(const QJsonObject &task);
    void scheduleReconnect();
    void submit(const QString &kind, const QString &name,
                const QString &source, const QString &url = {});
    static bool terminalStatus(const QString &status);

    QLocalSocket m_socket;
    QTimer m_pollTimer;
    QTimer m_reconnectTimer;
    QQueue<PendingRequest> m_queue;
    PendingRequest m_current;
    QByteArray m_buffer;
    QString m_socketPath;

    bool m_available = false;
    bool m_requestInFlight = false;
    bool m_planning = false;
    int m_reconnectAttempts = 0;

    QJsonObject m_installPlan;
    QString m_taskId;
    QString m_status;
    QString m_actionName;
    QString m_stage;
    QVariantList m_sourceUpdates;
    QString m_authenticationPrompt;
    QString m_speed;
    QString m_log;
    QString m_errorMessage;
    double m_progress = -1.0;
};
