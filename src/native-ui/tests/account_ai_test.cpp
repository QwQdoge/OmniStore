#include "accountaibridge.h"
#include <QCoreApplication>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusArgument>
#include <QTest>

class FakeBroker : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.meo.Accounts1")
public:
    int invocations = 0, denials = 0;
    QVariantMap arguments;
    QString action;
    QVariantMap grant;
public slots:
    QVariantList ListAvailableLocalAiConnections(const QString &) {
        return {QVariantMap{{"id", "connection"}, {"defaultModel", "model"}, {"enabled", true},
            {"provider", "ollama"}, {"endpoint", "http://127.0.0.1:11434"}, {"catalogAdviceGrant", grant}}};
    }
    QString StartLocalAiOperation(const QString &, const QString &nextAction, const QVariantMap &args) {
        action = nextAction; arguments = args;
        if (action == "invoke") {
            ++invocations;
            const auto consent = qdbus_cast<QVariantMap>(arguments.value("consent").value<QDBusArgument>());
            if (consent.value("remember").toBool()) grant = {{"enabled", true}, {"version", 1},
                {"clientId", "org.meo.OmniStore"}, {"model", "model"},
                {"provider", "ollama"}, {"endpoint", "http://127.0.0.1:11434"}};
        }
        if (action == "revoke_catalog_consent") grant.clear();
        if (action == "deny_inference") ++denials;
        return "request";
    }
    QVariantMap GetRequest(const QString &) {
        if (action == "prepare_inference") return {{"state", "completed"}, {"consent", QVariantMap{
            {"clientId", "org.meo.OmniStore"}, {"connectionId", "connection"}, {"model", "model"},
            {"purpose", arguments.value("purpose")}, {"confirmationVersion", 1},
            {"requestId", "one-time-consent"}, {"payloadSha256", QString(64, 'a')},
            {"dataCategories", arguments.value("dataCategories")},
            {"promptCharacters", arguments.value("systemPrompt").toString().size() + arguments.value("userPrompt").toString().size()},
            {"destination", "https://provider.example/v1/chat/completions"},
            {"expiresAt", QDateTime::currentDateTimeUtc().addSecs(300).toString(Qt::ISODateWithMs)}}}};
        return {{"state", action == "deny_inference" ? "denied" : "completed"},
                {"text", "{\"summary\":\"Best match\",\"recommendations\":[{\"candidateIndex\":0,\"reason\":\"matches\"}]}"}};
    }
};
class AccountAiTest : public QObject {
    Q_OBJECT
private slots:
    void groundedCatalog() {
        QVariantList catalog{QVariantMap{{"id", "real"}, {"source", "Pacman"}}};
        const auto result = AccountAiBridge::groundedRecommendations(
            R"({"recommendations":[{"candidateIndex":999},{"candidateIndex":0.5},{"candidateIndex":0,"id":"invented"},{"candidateIndex":0}]})", catalog);
        QCOMPARE(result.size(), 1);
        QCOMPARE(result[0].toMap().value("id").toString(), QString("real"));
        QCOMPARE(result[0].toMap().value("source").toString(), QString("Pacman"));
        QVERIFY(AccountAiBridge::groundedRecommendations("not JSON", catalog).isEmpty());
    }
    void explicitConsent() {
        FakeBroker fake;
        auto bus = QDBusConnection::sessionBus();
        QVERIFY(bus.registerService("org.meo.Accounts1"));
        QVERIFY(bus.registerObject("/org/meo/Accounts1", &fake, QDBusConnection::ExportAllSlots));
        AccountAiBridge ai;
        ai.refreshConnections();
        QTRY_COMPARE(ai.connections().size(), 1);
        const QVariantList catalog{QVariantMap{{"id", "demo"}, {"source", "Pacman"}}};
        ai.prepare("rank", "editor", catalog);
        QTRY_VERIFY(!ai.consent().isEmpty());
        QCOMPARE(fake.invocations, 0);
        ai.decide(false);
        QTRY_VERIFY(!ai.busy());
        QCOMPARE(fake.invocations, 0);
        QCOMPARE(fake.denials, 1);
        ai.prepare("rank", "editor", catalog);
        QTRY_VERIFY(!ai.consent().isEmpty());
        ai.decide(true, true);
        QTRY_VERIFY(!ai.busy());
        QCOMPARE(fake.invocations, 1);
        QCOMPARE(ai.recommendedApps().size(), 1);
        QCOMPARE(ai.recommendedApps().first().toMap().value("id").toString(), QString("demo"));
        QVERIFY(fake.arguments.contains("consent"));
        QVERIFY(qdbus_cast<QVariantMap>(fake.arguments.value("consent").value<QDBusArgument>()).value("remember").toBool());
        QVERIFY(!fake.arguments.contains("api_key"));
        QTRY_VERIFY(ai.rememberedConsent());
        ai.prepare("rank", "editor", catalog);
        QTRY_VERIFY(!ai.busy());
        QCOMPARE(fake.invocations, 2);
        QVERIFY(ai.consent().isEmpty());
        ai.revokeRememberedConsent();
        QTRY_VERIFY(!ai.busy());
        QTRY_VERIFY(!ai.rememberedConsent());
        bus.unregisterObject("/org/meo/Accounts1");
        bus.unregisterService("org.meo.Accounts1");
    }
};
QTEST_GUILESS_MAIN(AccountAiTest)
#include "account_ai_test.moc"
