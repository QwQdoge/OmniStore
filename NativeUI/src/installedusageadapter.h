#pragma once

#include <QList>
#include <QString>
#include <QVariantMap>

struct InstalledUsageSource {
    QString id;
    QString name;
    qint64 applicationCount = 0;
    qint64 knownSizeBytes = 0;
    qint64 unknownSizeCount = 0;
};

struct InstalledUsageApplication {
    QString name;
    QString sourceId;
    QString sourceName;
    QString sizeKind;
    qint64 sizeBytes = 0;
};

struct InstalledUsageSnapshot {
    QString generatedAt;
    qint64 applicationCount = 0;
    qint64 knownSizeBytes = 0;
    qint64 unknownSizeCount = 0;
    QList<InstalledUsageSource> sources;
    QList<InstalledUsageApplication> applications;
};

class InstalledUsageAdapter {
public:
    static constexpr qint64 maximumDocumentBytes = 4LL * 1024 * 1024;
    static constexpr int exporterTimeoutMs = 45 * 1000;

    explicit InstalledUsageAdapter(QString exporterPath =
                                       QStringLiteral("/usr/bin/omnistore-apps-export"));

    bool loadFromExporter(InstalledUsageSnapshot *snapshot, QString *error) const;
    bool loadFromFile(const QString &path, InstalledUsageSnapshot *snapshot,
                      QString *error) const;

    static bool parse(const QByteArray &document, InstalledUsageSnapshot *snapshot,
                      QString *error);
    static QVariantMap toVariantMap(const InstalledUsageSnapshot &snapshot);

private:
    QString m_exporterPath;
};
