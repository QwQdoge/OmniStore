#pragma once

#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class BackendBridge final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString busyAction READ busyAction NOTIFY stateChanged)
    Q_PROPERTY(bool offline READ offline NOTIFY stateChanged)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY stateChanged)
    Q_PROPERTY(QString busyOperation READ busyOperation NOTIFY stateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorDetail READ errorDetail NOTIFY stateChanged)
    Q_PROPERTY(QString backendDescription READ backendDescription CONSTANT)

    Q_PROPERTY(double progress READ progress NOTIFY taskChanged)
    Q_PROPERTY(QString taskStage READ taskStage NOTIFY taskChanged)
    Q_PROPERTY(QString taskSpeed READ taskSpeed NOTIFY taskChanged)
    Q_PROPERTY(QString taskLog READ taskLog NOTIFY taskChanged)

    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchChanged)
    Q_PROPERTY(QVariantList categoryResults READ categoryResults NOTIFY categoryChanged)
    Q_PROPERTY(QVariantList featuredApps READ featuredApps NOTIFY recommendationsChanged)
    Q_PROPERTY(QVariantList trendingApps READ trendingApps NOTIFY recommendationsChanged)
    Q_PROPERTY(QVariantList forYouApps READ forYouApps NOTIFY recommendationsChanged)
    Q_PROPERTY(QVariantList installedApps READ installedApps NOTIFY installedChanged)
    Q_PROPERTY(QVariantMap installedUsage READ installedUsage NOTIFY usageChanged)
    Q_PROPERTY(QVariantList updates READ updates NOTIFY updatesChanged)
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY pluginsChanged)
    Q_PROPERTY(QVariantMap bottles READ bottles NOTIFY bottlesChanged)
    Q_PROPERTY(QVariantMap appPreferences READ appPreferences NOTIFY preferencesChanged)
    Q_PROPERTY(QVariantMap config READ config NOTIFY configChanged)
    Q_PROPERTY(QVariantMap storageInfo READ storageInfo NOTIFY storageChanged)
    Q_PROPERTY(QVariantMap selectedApp READ selectedApp NOTIFY selectedChanged)

public:
    explicit BackendBridge(QObject *parent = nullptr);
    ~BackendBridge() override;

    bool busy() const { return m_process != nullptr; }
    bool offline() const { return m_offline; }
    QString lastUpdated() const { return m_lastUpdated; }
    QString busyAction() const { return m_busyAction; }
    // Stable machine name of the running read/mutation ("installed", "search", ...);
    // pages compare this, never the translated busyAction label.
    QString busyOperation() const { return busy() ? operationName(m_current.operation) : QString{}; }
    QString statusMessage() const { return m_statusMessage; }
    QString errorMessage() const { return m_errorMessage; }
    QString errorDetail() const { return m_errorDetail; }
    QString backendDescription() const { return m_backendDescription; }

    double progress() const { return m_progress; }
    QString taskStage() const { return m_taskStage; }
    QString taskSpeed() const { return m_taskSpeed; }
    QString taskLog() const { return m_taskLog; }

    QVariantList searchResults() const { return m_searchResults; }
    QVariantList categoryResults() const { return m_categoryResults; }
    QVariantList featuredApps() const { return m_featuredApps; }
    QVariantList trendingApps() const { return m_trendingApps; }
    QVariantList forYouApps() const { return m_forYouApps; }
    QVariantList installedApps() const { return m_installedApps; }
    QVariantMap installedUsage() const { return m_installedUsage; }
    QVariantList updates() const { return m_updates; }
    QVariantList plugins() const { return m_plugins; }
    QVariantMap bottles() const { return m_bottles; }
    QVariantMap appPreferences() const { return m_appPreferences; }
    QVariantMap config() const { return m_config; }
    QVariantMap storageInfo() const { return m_storageInfo; }
    QVariantMap selectedApp() const { return m_selectedApp; }

    Q_INVOKABLE void loadRecommendations();
    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void browseCategory(const QString &category);
    Q_INVOKABLE void locateApp(const QString &name, const QString &source);
    Q_INVOKABLE void loadInstalled(bool forceRefresh = false);
    Q_INVOKABLE void loadInstalledUsage();
    Q_INVOKABLE void loadUpdates();
    Q_INVOKABLE void loadPlugins();
    Q_INVOKABLE void loadBottles();
    Q_INVOKABLE void loadAppPreferences();
    // Sources, Bottles and preferences in a single backend start (each start costs ~0.3-0.5 s).
    Q_INVOKABLE void loadSettingsSnapshot();
    // key: autoUpdate | notifyUpdates (bool) or cacheLimitMb (int); applied by the backend.
    Q_INVOKABLE void setAppPreference(const QString &key, const QVariant &value);
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
    Q_INVOKABLE void addCatalog(const QString &url);
    Q_INVOKABLE void setBottleListed(const QString &bottle, bool listed);
    Q_INVOKABLE void cancelOperation();
    Q_INVOKABLE void clearTaskLog();
    Q_INVOKABLE void clearError();
    // Re-resolves the backend, clears the last failure and reloads the
    // read-only views. Backs the "Start backend" button.
    Q_INVOKABLE void startBackend();

signals:
    void stateChanged();
    void taskChanged();
    // Each list notifies on its own so a refresh of one (say sources) does not
    // rebuild the delegates of another (say Installed). dataChanged remains the
    // aggregate for listeners that need any change.
    void searchChanged();
    void categoryChanged();
    void recommendationsChanged();
    void installedChanged();
    void usageChanged();
    void updatesChanged();
    void pluginsChanged();
    void bottlesChanged();
    void preferencesChanged();
    void configChanged();
    void storageChanged();
    void selectedChanged();
    void dataChanged();
    void operationFinished(const QString &action, bool success);

private:
    enum class Operation {
        None,
        Recommendations,
        Search,
        Category,
        Installed,
        InstalledUsage,
        Updates,
        Plugins,
        Bottles,
        AppPrefs,
        SettingsSnapshot,
        Config,
        Storage,
        Details,
        Install,
        Remove,
        Update,
        UpdateAll,
        Launch,
        Locate,
        PluginToggle,
        BottleListed,
        AppPrefsSet,
        CatalogAdd,
    };

    struct Request {
        Operation operation = Operation::None;
        QString label;
        QStringList arguments;
        bool mutating = false;
        int attempt = 0;
    };

    void resolveBackend();
    void enqueueRead(Operation operation, const QString &label, const QStringList &arguments,
                     int attempt = 0);
    void scheduleRetry(const Request &failed);
    void autoRefresh();
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
    void emitDataChanged(Operation operation);

    QString m_backendProgram;
    QStringList m_backendPrefixArguments;
    QString m_workingDirectory;
    QString m_backendDescription;

    QProcess *m_process = nullptr;
    QQueue<Request> m_queue;
    QTimer m_autoRefreshTimer;
    bool m_readFailedSinceRefresh = false;
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
    QVariantList m_categoryResults;
    QVariantList m_featuredApps;
    QVariantList m_trendingApps;
    QVariantList m_forYouApps;
    QVariantList m_installedApps;
    QVariantMap m_installedUsage;
    QVariantList m_updates;
    QString m_errorDetail;
    bool m_offline = false;
    QString m_lastUpdated;  // localized time of the last successful read
    QVariantList m_plugins;
    QVariantMap m_bottles;
    QVariantMap m_appPreferences;
    QVariantMap m_config;
    QVariantMap m_storageInfo;
    QVariantMap m_selectedApp;
};
