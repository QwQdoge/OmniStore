#pragma once
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class AccountAiBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList connections READ connections NOTIFY changed)
    Q_PROPERTY(QString connectionId MEMBER m_connectionId NOTIFY changed)
    Q_PROPERTY(bool rememberedConsent READ rememberedConsent NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY changed)
    Q_PROPERTY(QString resultText READ resultText NOTIFY changed)
    Q_PROPERTY(QVariantMap requestSummary READ requestSummary NOTIFY changed)
    Q_PROPERTY(QVariantMap consent READ consent NOTIFY changed)
    Q_PROPERTY(QVariantList recommendedApps READ recommendedApps NOTIFY changed)
public:
    explicit AccountAiBridge(QObject *parent = nullptr);
    QVariantList connections() const { return m_connections; }
    bool rememberedConsent() const;
    bool busy() const { return m_busy; }
    QString errorMessage() const { return m_error; }
    QString resultText() const { return m_text; }
    QVariantMap requestSummary() const { return m_arguments; }
    QVariantMap consent() const { return m_consent; }
    QVariantList recommendedApps() const { return m_recommended; }
    Q_INVOKABLE void refreshConnections();
    Q_INVOKABLE void clearPresentation();
    Q_INVOKABLE void prepare(const QString &mode, const QString &query, const QVariantList &candidates);
    Q_INVOKABLE void decide(bool approved, bool remember = false);
    Q_INVOKABLE void revokeRememberedConsent();
    static QVariantList groundedRecommendations(const QString &text, const QVariantList &candidates);
signals:
    void changed();
    void searchSuggested(const QString &query);
private:
    void start(const QString &action);
    void poll();
    void fail(const QString &message);
    QTimer m_poll;
    QVariantList m_connections, m_candidates, m_recommended;
    QVariantMap m_arguments, m_consent;
    QString m_connectionId, m_requestId, m_action, m_mode, m_error, m_text;
    bool m_busy = false, m_pollPending = false;
    int m_ticks = 0;
};
