#pragma once

#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QVariantMap>

class RepositoryBridge final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap repositories READ repositories NOTIFY repositoriesChanged)

public:
    explicit RepositoryBridge(QObject *parent = nullptr);
    ~RepositoryBridge() override;

    bool busy() const { return m_process != nullptr; }
    QString statusMessage() const { return m_statusMessage; }
    QString errorMessage() const { return m_errorMessage; }
    QVariantMap repositories() const { return m_repositories; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void addRepository(const QString &type, const QString &name, const QString &url);
    Q_INVOKABLE void removeRepository(const QString &type, const QString &identity);
    Q_INVOKABLE void clearError();

signals:
    void stateChanged();
    void repositoriesChanged();

private:
    enum class Action { None, Refresh, Add, Remove };

    void resolveBackend();
    void start(Action action, const QStringList &arguments, const QString &status);
    void consumeOutput();
    void finish(int exitCode, QProcess::ExitStatus exitStatus);
    static bool validType(const QString &type);
    static bool basicNameValid(const QString &name);
    static bool basicUrlValid(const QString &url);

    QString m_backendProgram;
    QStringList m_backendPrefixArguments;
    QString m_workingDirectory;
    QProcess *m_process = nullptr;
    Action m_action = Action::None;
    QByteArray m_stdout;
    QByteArray m_stderr;
    QVariantMap m_repositories;
    QString m_statusMessage = QStringLiteral("Ready");
    QString m_errorMessage;
};
