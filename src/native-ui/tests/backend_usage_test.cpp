#include "backendbridge.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTimer>
#include <QtTest>

class BackendUsageTest : public QObject
{
    Q_OBJECT
private:
    QTemporaryDir directory;

    QString fixture(const QJsonObject &payload, double delay = 0.05)
    {
        const QString path = directory.filePath(QStringLiteral("backend.py"));
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly))
            return {};
        const QByteArray json = QJsonDocument(payload).toJson(QJsonDocument::Compact);
        file.write("#!/usr/bin/env python3\nimport sys, time\n");
        file.write("assert sys.argv[1:] == ['--export-installed-usage']\n");
        file.write("time.sleep(" + QByteArray::number(delay) + ")\n");
        file.write("sys.stdout.buffer.write(" + QJsonDocument(QJsonArray{QString::fromUtf8(json)}).toJson(QJsonDocument::Compact).mid(1).chopped(1) + ".encode() + b'\\n')\n");
        file.close();
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv("OMNISTORE_BACKEND", path.toUtf8());
        return path;
    }

    QJsonObject valid()
    {
        return {{"schema", "org.meo.omnistore.installed-usage"}, {"version", 1},
                {"status", "success"}, {"applicationCount", 2}, {"knownSizeBytes", 1024},
                {"unknownSizeCount", 1}, {"sources", QJsonArray{QJsonObject{{"id", "flatpak"}}}}};
    }

private slots:
    void cleanup() { qunsetenv("OMNISTORE_BACKEND"); }

    void liveReadOnlyCatalog()
    {
        const auto backend = qgetenv("OMNISTORE_LIVE_READONLY_BACKEND");
        if (backend.isEmpty())
            QSKIP("Set OMNISTORE_LIVE_READONLY_BACKEND to verify a real local backend.");
        qputenv("OMNISTORE_BACKEND", backend);
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.loadInstalled();
        QTRY_VERIFY_WITH_TIMEOUT(!finished.isEmpty(), 30000);
        QVERIFY2(finished.last().at(1).toBool(), qPrintable(bridge.errorMessage()));
        QVERIFY(!bridge.installedApps().isEmpty());
        qInfo() << "Real installed applications:" << bridge.installedApps().size();
        finished.clear();
        bridge.browseCategory("Game");
        QTRY_VERIFY_WITH_TIMEOUT(!bridge.categoryResults().isEmpty(), 30000);
        QVERIFY2(finished.last().at(1).toBool(), qPrintable(bridge.errorMessage()));
        QVERIFY(!bridge.categoryResults().isEmpty());
        qInfo() << "Real game category:" << bridge.categoryResults().size();
    }

    void latestQueuedCategoryWinsAndDoesNotReplaceSearch()
    {
        const QString path = directory.filePath("category-backend.py");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("#!/usr/bin/env python3\nimport sys,time,json\n"
                   "time.sleep(0.1)\nprint(json.dumps([{'id':sys.argv[2]}]))\n");
        file.close();
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv("OMNISTORE_BACKEND", path.toUtf8());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.search("editor");
        bridge.browseCategory("Game");
        bridge.browseCategory("Office");
        QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 2, 3000);
        QCOMPARE(bridge.searchResults().first().toMap().value("id").toString(), "editor");
        QCOMPARE(bridge.categoryResults().first().toMap().value("id").toString(), "category:Office");
    }

    void launchJsonFailureIsVisibleEvenWithZeroExitCode()
    {
        const QString path = directory.filePath("launch-backend.py");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("#!/usr/bin/env python3\n"
                   "print('{\"status\":\"error\",\"error\":\"Application is not installed\"}')\n");
        file.close();
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv("OMNISTORE_BACKEND", path.toUtf8());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.launchApp("missing", "Pacman");
        QTRY_VERIFY_WITH_TIMEOUT(!finished.isEmpty(), 3000);
        QCOMPARE(finished.first().at(1).toBool(), false);
        QCOMPARE(bridge.errorMessage(), "Application is not installed");
    }

    void queuedReadCannotOverwriteRequestStartedBetweenCompletions()
    {
        const QString path = directory.filePath("queue-backend.py");
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("#!/usr/bin/env python3\nimport sys,time,json\n"
                   "time.sleep(0.1)\nprint(json.dumps([{'id':sys.argv[2]}]))\n");
        file.close();
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv("OMNISTORE_BACKEND", path.toUtf8());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bool submitted = false;
        connect(&bridge, &BackendBridge::operationFinished, this, [&] {
            if (!submitted) {
                submitted = true;
                bridge.browseCategory("Game");
            }
        }, Qt::QueuedConnection);
        bridge.search("first");
        bridge.search("second");
        QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 3, 3000);
        QCOMPARE(bridge.searchResults().first().toMap().value("id").toString(), "second");
        QCOMPARE(bridge.categoryResults().first().toMap().value("id").toString(), "category:Game");
    }

    void successfulReadDoesNotBlockEventLoop()
    {
        QVERIFY(!fixture(valid()).isEmpty());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bool pulse = false;
        QTimer::singleShot(1, &bridge, [&pulse] { pulse = true; });
        bridge.loadInstalledUsage();
        QVERIFY(bridge.busy());
        QVERIFY(bridge.installedUsage().isEmpty());
        QTRY_VERIFY_WITH_TIMEOUT(pulse, 500);
        QTRY_VERIFY_WITH_TIMEOUT(!finished.isEmpty(), 3000);
        QCOMPARE(finished.first().at(1).toBool(), true);
        QCOMPARE(bridge.installedUsage().value("knownSizeBytes").toLongLong(), 1024);
        QVERIFY(bridge.errorMessage().isEmpty());
    }

    void invalidSnapshotsNeverBecomeZeroUsage_data()
    {
        QTest::addColumn<QJsonObject>("payload");
        QTest::newRow("empty") << QJsonObject{};
        for (const auto &key : {"version", "applicationCount", "knownSizeBytes", "unknownSizeCount"}) {
            auto payload = valid();
            payload[key] = true;
            QTest::newRow(key) << payload;
        }
        auto negative = valid(); negative["knownSizeBytes"] = -1;
        QTest::newRow("negative") << negative;
        auto fractional = valid(); fractional["applicationCount"] = 1.5;
        QTest::newRow("fractional") << fractional;
        auto inconsistent = valid(); inconsistent["unknownSizeCount"] = 3;
        QTest::newRow("inconsistent") << inconsistent;
        auto wrongSchema = valid(); wrongSchema["schema"] = "other";
        QTest::newRow("schema") << wrongSchema;
        auto failed = valid(); failed["status"] = "error";
        QTest::newRow("backend-error") << failed;
    }

    void invalidSnapshotsNeverBecomeZeroUsage()
    {
        QFETCH(QJsonObject, payload);
        QVERIFY(!fixture(payload).isEmpty());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.loadInstalledUsage();
        QTRY_VERIFY_WITH_TIMEOUT(!finished.isEmpty(), 3000);
        QCOMPARE(finished.first().at(1).toBool(), false);
        QVERIFY(bridge.installedUsage().isEmpty());
        QVERIFY(!bridge.errorMessage().isEmpty());
    }

    void hungReadIsTerminated()
    {
        QVERIFY(!fixture(valid(), 60).isEmpty());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.loadInstalledUsage();
        QVERIFY(finished.wait(35000));
        QCOMPARE(finished.first().at(1).toBool(), false);
        QVERIFY(!bridge.busy());
        QVERIFY(bridge.installedUsage().isEmpty());
        QVERIFY(!bridge.errorMessage().isEmpty());
    }

    void missingBackendDoesNotHoldTheQueue()
    {
        qputenv("OMNISTORE_BACKEND", directory.filePath("missing-backend").toUtf8());
        BackendBridge bridge;
        QSignalSpy finished(&bridge, &BackendBridge::operationFinished);
        bridge.loadInstalledUsage();
        QTRY_VERIFY_WITH_TIMEOUT(!finished.isEmpty(), 3000);
        QCOMPARE(finished.first().at(1).toBool(), false);
        QVERIFY(!bridge.busy());
        QVERIFY(!bridge.errorMessage().isEmpty());
    }
};

QTEST_GUILESS_MAIN(BackendUsageTest)
#include "backend_usage_test.moc"
