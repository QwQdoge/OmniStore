#include "externalinstallrequest.h"
#include <QtTest>

class ExternalInstallRequestTest : public QObject {
    Q_OBJECT
private slots:
    void accepted_data() {
        QTest::addColumn<QStringList>("args");
        QTest::addColumn<QString>("id");
        QTest::addColumn<QString>("source");
        QTest::newRow("native-default") << QStringList{"install", "example+pkg"} << QString("example+pkg") << QString("Native");
        QTest::newRow("native-alias") << QStringList{"install", "example", "--source", "PACMAN"} << QString("example") << QString("Native");
        QTest::newRow("aur") << QStringList{"install", "example-bin", "--source", "aur"} << QString("example-bin") << QString("AUR");
        QTest::newRow("flatpak") << QStringList{"install", "org.example.App", "--source", "flatpak"} << QString("org.example.App") << QString("Flatpak");
        QTest::newRow("github") << QStringList{"install", "Owner/repo.name", "--source", "GitHub"} << QString("Owner/repo.name") << QString("GitHub");
        QTest::newRow("bitu") << QStringList{"install", "Owner/repo", "--source", "bitu"} << QString("Owner/repo") << QString("Bitu");
    }
    void accepted() {
        QFETCH(QStringList, args); QFETCH(QString, id); QFETCH(QString, source);
        const auto request = ExternalInstallRequest::parse(args);
        QCOMPARE(request.status, ExternalInstallRequest::Status::Accepted);
        QCOMPARE(request.packageId, id); QCOMPARE(request.source, source);
        QVERIFY(request.error.isEmpty());
    }
    void rejected_data() {
        QTest::addColumn<QStringList>("args");
        QTest::newRow("missing") << QStringList{"install"};
        QTest::newRow("extra") << QStringList{"install", "example", "--yes"};
        QTest::newRow("wrong-option") << QStringList{"install", "example", "--url", "native"};
        QTest::newRow("unknown-source") << QStringList{"install", "example", "--source", "all"};
        QTest::newRow("leading-option") << QStringList{"install", "--noconfirm"};
        QTest::newRow("shell") << QStringList{"install", "example;whoami"};
        QTest::newRow("newline") << QStringList{"install", "example\n"};
        QTest::newRow("nul") << QStringList{"install", QString("example") + QChar(0)};
        QTest::newRow("path") << QStringList{"install", "../example"};
        QTest::newRow("url") << QStringList{"install", "https://example.invalid/repo", "--source", "github"};
        QTest::newRow("repo-option") << QStringList{"install", "Owner/--help", "--source", "github"};
        QTest::newRow("repo-dotdot") << QStringList{"install", "Owner/..", "--source", "github"};
        QTest::newRow("repo-segments") << QStringList{"install", "Owner/repo/path", "--source", "github"};
        QTest::newRow("native-oversize") << QStringList{"install", QString(129, 'a')};
        QTest::newRow("flatpak-oversize") << QStringList{"install", QString(193, 'a'), "--source", "flatpak"};
        QTest::newRow("repo-oversize") << QStringList{"install", "Owner/" + QString(129, 'a'), "--source", "github"};
    }
    void rejected() {
        QFETCH(QStringList, args);
        const auto request = ExternalInstallRequest::parse(args);
        QCOMPARE(request.status, ExternalInstallRequest::Status::Rejected);
        QVERIFY(!request.error.isEmpty());
        QVERIFY(request.packageId.isEmpty()); QVERIFY(request.source.isEmpty());
    }
    void unrelatedArguments() {
        for (const auto &args : {QStringList{}, QStringList{"omnistore://auth/callback?code=example"}, QStringList{"--help"}})
            QCOMPARE(ExternalInstallRequest::parse(args).status, ExternalInstallRequest::Status::Ignored);
    }
};
QTEST_APPLESS_MAIN(ExternalInstallRequestTest)
#include "external_install_request_test.moc"
