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
};

QTEST_GUILESS_MAIN(BackendUsageTest)
#include "backend_usage_test.moc"
