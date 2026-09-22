#pragma once

#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class BackendBridge final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString busyAction READ busyAction NOTIFY stateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QString backendDescription READ backendDescription CONSTANT)

    Q_PROPERTY(double progress READ progress NOTIFY taskChanged)
    Q_PROPERTY(QString taskStage READ taskStage NOTIFY taskChanged)
    Q_PROPERTY(QString taskSpeed READ taskSpeed NOTIFY taskChanged)
    Q_PROPERTY(QString taskLog READ taskLog NOTIFY taskChanged)

    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY dataChanged)
    Q_PROPERTY(QVariantList featuredApps READ featuredApps NOTIFY dataChanged)
    Q_PROPERTY(QVariantList trendingApps READ trendingApps NOTIFY dataChanged)
    Q_PROPERTY(QVariantList forYouApps READ forYouApps NOTIFY dataChanged)
    Q_PROPERTY(QVariantList installedApps READ installedApps NOTIFY dataChanged)
    Q_PROPERTY(QVariantList updates READ updates NOTIFY dataChanged)
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap config READ config NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap storageInfo READ storageInfo NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap selectedApp READ selectedApp NOTIFY dataChanged)

public:
    explicit BackendBridge(QObject *parent = nullptr);
    ~BackendBridge() override;

    bool busy() const { return m_process != nullptr; }
    QString busyAction() const { return m_busyAction; }
    QString statusMessage() const { return m_statusMessage; }
    QString errorMessage() const { return m_errorMessage; }
    QString backendDescription() const { return m_backendDescription; }

    double progress() const { return m_progress; }
    QString taskStage() const { return m_taskStage; }
    QString taskSpeed() const { return m_taskSpeed; }
    QString taskLog() const { return m_taskLog; }

    QVariantList searchResults() const { return m_searchResults; }
    QVariantList featuredApps() const { return m_featuredApps; }
    QVariantList trendingApps() const { return m_trendingApps; }
    QVariantList forYouApps() const { return m_forYouApps; }
    QVariantList installedApps() const { return m_installedApps; }
    QVariantList updates() const { return m_updates; }
    QVariantList plugins() const { return m_plugins; }
    QVariantMap config() const { return m_config; }
    QVariantMap storageInfo() const { return m_storageInfo; }
    QVariantMap selectedApp() const { return m_selectedApp; }

    Q_INVOKABLE void loadRecommendations();
    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void loadInstalled(bool forceRefresh = false);
    Q_INVOKABLE void loadUpdates();
    Q_INVOKABLE void loadPlugins();
    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void loadStorageInfo();
    Q_INVOKABLE void loadDetails(const QString &appId, const QString &source = {});

    Q_INVOKABLE void installApp(const QString &name, const QString &source,
                                const QString &url = {});
    Q_INVOKABLE void removeApp(const QString &name, const QString &source);
    Q_INVOKABLE void updateApp(const QString &name, const QString &source);
    Q_INVOKABLE void updateAll();
    Q_INVOKABLE void launchApp(const QString &name, const QString &source);
    Q_INVOKABLE void setPluginEnabled(const QString &pluginId, bool enabled);
    Q_INVOKABLE void cancelOperation();
    Q_INVOKABLE void clearTaskLog();
    Q_INVOKABLE void clearError();

signals:
    void stateChanged();
    void taskChanged();
    void dataChanged();
    void operationFinished(const QString &action, bool success);

private:
    enum class Operation {
        None,
        Recommendations,
        Search,
        Installed,
        Updates,
        Plugins,
        Config,
        Storage,
        Details,
        Install,
        Remove,
        Update,
        UpdateAll,
        Launch,
        PluginToggle,
    };

    struct Request {
        Operation operation = Operation::None;
        QString label;
        QStringList arguments;
        bool mutating = false;
    };

    void resolveBackend();
    void enqueueRead(Operation operation, const QString &label, const QStringList &arguments);
    void startMutation(Operation operation, const QString &label, const QStringList &arguments);
    void startRequest(const Request &request);
    void startNextQueued();
    void consumeStdout();
    void consumeStderr();
    void consumeLine(const QString &line);
    void consumeCallback(const QByteArray &json);
    void appendTaskLog(const QString &line);
    void applyResponse(Operation operation);
    void finishProcess(int exitCode, QProcess::ExitStatus exitStatus);
    QVariant payloadFromDocument(bool *ok = nullptr);
    static QVariantList asList(const QVariant &value);
    static QVariantMap asMap(const QVariant &value);
    static QString operationName(Operation operation);

    QString m_backendProgram;
    QStringList m_backendPrefixArguments;
    QString m_workingDirectory;
    QString m_backendDescription;

    QProcess *m_process = nullptr;
    QQueue<Request> m_queue;
    Request m_current;
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrBuffer;
    QByteArray m_lastJson;
    bool m_callbackError = false;

    QString m_busyAction;
    QString m_statusMessage = QStringLiteral("Ready");
    QString m_errorMessage;
    double m_progress = -1.0;
    QString m_taskStage;
    QString m_taskSpeed;
    QString m_taskLog;

    QVariantList m_searchResults;
    QVariantList m_featuredApps;
    QVariantList m_trendingApps;
    QVariantList m_forYouApps;
    QVariantList m_installedApps;
    QVariantList m_updates;
    QVariantList m_plugins;
    QVariantMap m_config;
    QVariantMap m_storageInfo;
    QVariantMap m_selectedApp;
};
