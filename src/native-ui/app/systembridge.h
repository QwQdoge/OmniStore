#pragma once

#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QStringList>
#include <QVariantMap>

class SystemBridge final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap channelState READ channelState NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap updateState READ updateState NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap updatePlan READ updatePlan NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap environmentState READ environmentState NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap stablePreview READ stablePreview NOTIFY dataChanged)

public:
    explicit SystemBridge(QObject *parent = nullptr);
    ~SystemBridge() override;

    bool busy() const { return m_process != nullptr; }
    QString statusMessage() const { return m_statusMessage; }
    QString errorMessage() const { return m_errorMessage; }
    QVariantMap channelState() const { return m_channelState; }
    QVariantMap updateState() const { return m_updateState; }
    QVariantMap updatePlan() const { return m_updatePlan; }
    QVariantMap environmentState() const { return m_environmentState; }
    QVariantMap stablePreview() const { return m_stablePreview; }

    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void refreshChannel();
    Q_INVOKABLE void refreshUpdateState();
    Q_INVOKABLE void refreshUpdatePlan();
    Q_INVOKABLE void refreshEnvironment();
    Q_INVOKABLE void bootstrapEnvironment();
    Q_INVOKABLE void switchBeta();
    Q_INVOKABLE void switchStable();
    Q_INVOKABLE void confirmStable(const QString &planHash);
    Q_INVOKABLE void clearStablePreview();
    Q_INVOKABLE void clearError();

signals:
    void stateChanged();
    void dataChanged();

private:
    enum class Action {
        None,
        ChannelStatus,
        UpdateState,
        UpdatePlan,
        Environment,
        Bootstrap,
        SwitchBeta,
        SwitchStable,
        ConfirmStable,
    };

    struct Request {
        Action action = Action::None;
        QStringList arguments;
        QString status;
        bool mutating = false;
    };

    void resolveBackend();
    void enqueue(const Request &request);
    void start(const Request &request);
    void startNext();
    void readOutput();
    void finish(int exitCode, QProcess::ExitStatus exitStatus);
    QVariantMap lastJsonObject() const;
    void apply(Action action, const QVariantMap &payload);
    static bool validPlanHash(const QString &hash);

    QString m_backendProgram;
    QStringList m_backendPrefixArguments;
    QString m_workingDirectory;
    QProcess *m_process = nullptr;
    QQueue<Request> m_queue;
    Request m_current;
    QByteArray m_stdout;
    QByteArray m_stderr;
    QString m_statusMessage = QStringLiteral("Ready");
    QString m_errorMessage;
    QVariantMap m_channelState;
    QVariantMap m_updateState;
    QVariantMap m_updatePlan;
    QVariantMap m_environmentState;
    QVariantMap m_stablePreview;
};
