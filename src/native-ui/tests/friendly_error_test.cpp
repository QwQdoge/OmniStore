#include "friendlyerror.h"
#include <QtTest>

class FriendlyErrorTest : public QObject {
    Q_OBJECT
private slots:
    void maps_known_failures_data() {
        QTest::addColumn<QString>("raw"); QTest::addColumn<QString>("kind");
        QTest::addColumn<QString>("expected");
        QTest::newRow("space") << "error: No space left on device" << "install"
            << "Couldn't install Firefox. There isn't enough free space.";
        QTest::newRow("notfound") << "error: target not found: firefox" << "install"
            << "Couldn't install Firefox. It wasn't found in this source.";
        QTest::newRow("network") << "Failed retrieving file 'x' from mirror" << "update"
            << "Couldn't update Firefox. Couldn't reach the source. Check your connection.";
        QTest::newRow("cancel") << "Authorization denied" << "install" << "Installation was cancelled.";
        QTest::newRow("lock") << "unable to lock database" << "remove" << "Waiting for another change to finish.";
        QTest::newRow("absent") << "Application is not installed" << "" << "That app isn't installed.";
        QTest::newRow("service") << "OmniStore transaction service is unavailable: x" << "install"
            << "The store service isn't running.";
    }
    void maps_known_failures() {
        QFETCH(QString, raw); QFETCH(QString, kind); QFETCH(QString, expected);
        QCOMPARE(FriendlyError::message(raw, kind, "Firefox"), expected);
    }
    void never_leaks_raw_text() {
        const QString out = FriendlyError::message("Traceback (most recent call last): ValueError 0xdeadbeef", "install", "App");
        QVERIFY(!out.contains("Traceback")); QVERIFY(!out.contains("0xdeadbeef"));
        QCOMPARE(out, QString("Couldn't install App. Try again, or open the log."));
    }
    void detects_network_failures() {
        QVERIFY(FriendlyError::isNetwork("Could not resolve host: flathub.org"));
        QVERIFY(!FriendlyError::isNetwork("target not found: firefox"));
    }
    void categorizes() {
        QCOMPARE(FriendlyError::category("No space left on device"), QString("space"));
        QCOMPARE(FriendlyError::category("Could not resolve host"), QString("network"));
        QCOMPARE(FriendlyError::category("Authorization denied"), QString("cancelled"));
        QCOMPARE(FriendlyError::category("???"), QString("unknown"));
    }
    void no_subject_and_empty() {
        QCOMPARE(FriendlyError::message("", "install"), QString("Couldn't install the app."));
        QCOMPARE(FriendlyError::message("weird", ""), QString("Couldn't complete that action. Try again, or open the log."));
    }
};
QTEST_APPLESS_MAIN(FriendlyErrorTest)
#include "friendly_error_test.moc"
