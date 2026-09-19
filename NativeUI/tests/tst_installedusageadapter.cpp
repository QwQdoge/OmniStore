#include "installedusageadapter.h"

#include <QFile>
#include <QTest>

class InstalledUsageAdapterTest final : public QObject {
    Q_OBJECT

private slots:
    void acceptsVersionOneFixture();
    void rejectsUnsupportedVersion();
    void rejectsCountMismatch();
};

namespace {

QString fixturePath(const QString &name)
{
    return QStringLiteral(OMNISTORE_NATIVE_SOURCE_DIR)
        + QStringLiteral("/tests/fixtures/") + name;
}

QByteArray readFixture(const QString &name)
{
    QFile file(fixturePath(name));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return file.readAll();
}

} // namespace

void InstalledUsageAdapterTest::acceptsVersionOneFixture()
{
    InstalledUsageAdapter adapter;
    InstalledUsageSnapshot snapshot;
    QString error;

    QVERIFY2(adapter.loadFromFile(fixturePath(QStringLiteral("installed-usage-v1.json")),
                                  &snapshot, &error),
             qPrintable(error));
    QCOMPARE(snapshot.applicationCount, 2);
    QCOMPARE(snapshot.sources.size(), 1);
    QCOMPARE(snapshot.applications.at(1).name, QStringLiteral("OmniStore"));

    const QVariantMap map = InstalledUsageAdapter::toVariantMap(snapshot);
    QCOMPARE(map.value(QStringLiteral("sourceCount")).toInt(), 1);
    QVERIFY(map.value(QStringLiteral("knownSizeText")).toString().contains(QStringLiteral("MiB")));
}

void InstalledUsageAdapterTest::rejectsUnsupportedVersion()
{
    InstalledUsageSnapshot snapshot;
    QString error;

    QVERIFY(!InstalledUsageAdapter::parse(readFixture(QStringLiteral("invalid-usage.json")),
                                          &snapshot, &error));
    QVERIFY(!error.isEmpty());
}

void InstalledUsageAdapterTest::rejectsCountMismatch()
{
    QByteArray document = readFixture(QStringLiteral("installed-usage-v1.json"));
    document.replace("\"applicationCount\": 2", "\"applicationCount\": 3");

    InstalledUsageSnapshot snapshot;
    QString error;
    QVERIFY(!InstalledUsageAdapter::parse(document, &snapshot, &error));
    QVERIFY(error.contains(QStringLiteral("count"), Qt::CaseInsensitive));
}

QTEST_MAIN(InstalledUsageAdapterTest)

#include "tst_installedusageadapter.moc"
