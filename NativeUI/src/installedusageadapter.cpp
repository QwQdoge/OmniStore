#include "installedusageadapter.h"

#include <QElapsedTimer>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLocale>
#include <QProcess>

#include <cmath>
#include <limits>

namespace {

bool fail(QString *error, const QString &message)
{
    if (error)
        *error = message;
    return false;
}

QString translated(const char *sourceText)
{
    return QCoreApplication::translate("InstalledUsageAdapter", sourceText);
}

bool readRequiredText(const QJsonObject &object, const QString &key, QString *result,
                      QString *error)
{
    const QJsonValue value = object.value(key);
    if (!value.isString() || value.toString().trimmed().isEmpty())
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "Missing required text: %1")).arg(key));
    *result = value.toString();
    return true;
}

bool readNonNegativeInteger(const QJsonObject &object, const QString &key,
                            qint64 *result, QString *error)
{
    const QJsonValue value = object.value(key);
    const double number = value.toDouble(std::numeric_limits<double>::quiet_NaN());
    if (!value.isDouble() || !std::isfinite(number) || number < 0
        || number > static_cast<double>(std::numeric_limits<qint64>::max())
        || std::floor(number) != number) {
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "%1 must be a non-negative whole number")).arg(key));
    }
    *result = static_cast<qint64>(number);
    return true;
}

QString formatBytes(qint64 bytes)
{
    static const QList<QString> units = {
        QStringLiteral("B"), QStringLiteral("KiB"), QStringLiteral("MiB"),
        QStringLiteral("GiB"), QStringLiteral("TiB")};

    double value = static_cast<double>(bytes);
    int unitIndex = 0;
    while (value >= 1024.0 && unitIndex < units.size() - 1) {
        value /= 1024.0;
        ++unitIndex;
    }
    const int decimals = unitIndex == 0 ? 0 : 1;
    return QStringLiteral("%1 %2").arg(QLocale().toString(value, 'f', decimals),
                                         units.at(unitIndex));
}

} // namespace

InstalledUsageAdapter::InstalledUsageAdapter(QString exporterPath)
    : m_exporterPath(std::move(exporterPath))
{
}

bool InstalledUsageAdapter::loadFromExporter(InstalledUsageSnapshot *snapshot,
                                             QString *error) const
{
    if (!snapshot)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "No destination was supplied")));

    QProcess process;
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.setProgram(m_exporterPath);
    process.setArguments({});
    process.start();

    if (!process.waitForStarted(5000))
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library source could not start")));

    QElapsedTimer elapsed;
    elapsed.start();
    QByteArray standardOutput;
    while (process.state() != QProcess::NotRunning) {
        const int remainingMs = exporterTimeoutMs - static_cast<int>(elapsed.elapsed());
        if (remainingMs <= 0) {
            process.kill();
            process.waitForFinished(1000);
            return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library source took too long to respond")));
        }

        process.waitForReadyRead(qMin(200, remainingMs));
        standardOutput.append(process.readAllStandardOutput());
        if (standardOutput.size() > maximumDocumentBytes) {
            process.kill();
            process.waitForFinished(1000);
            return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information was too large to read")));
        }
    }
    standardOutput.append(process.readAllStandardOutput());

    if (standardOutput.size() > maximumDocumentBytes)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information was too large to read")));
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library source did not finish successfully")));

    return parse(standardOutput, snapshot, error);
}

bool InstalledUsageAdapter::loadFromFile(const QString &path,
                                         InstalledUsageSnapshot *snapshot,
                                         QString *error) const
{
    if (!snapshot)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "No destination was supplied")));

    const QFileInfo info(path);
    if (!info.exists() || !info.isFile())
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The preview data file is not available")));
    if (info.size() > maximumDocumentBytes)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The preview data file is too large to read")));

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The preview data file could not be read")));
    return parse(file.read(maximumDocumentBytes + 1), snapshot, error);
}

bool InstalledUsageAdapter::parse(const QByteArray &document,
                                  InstalledUsageSnapshot *snapshot,
                                  QString *error)
{
    if (!snapshot)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "No destination was supplied")));
    if (document.size() > maximumDocumentBytes)
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information was too large to read")));

    QJsonParseError parseError;
    const QJsonDocument json = QJsonDocument::fromJson(document, &parseError);
    if (parseError.error != QJsonParseError::NoError || !json.isObject())
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information is not in the expected format")));

    const QJsonObject root = json.object();
    QString schema;
    QString status;
    QString generatedAt;
    qint64 version = 0;
    if (!readRequiredText(root, QStringLiteral("schema"), &schema, error)
        || schema != QStringLiteral("org.meo.omnistore.installed-usage")
        || !readNonNegativeInteger(root, QStringLiteral("version"), &version, error)
        || version != 1
        || !readRequiredText(root, QStringLiteral("status"), &status, error)
        || status != QStringLiteral("success")
        || !readRequiredText(root, QStringLiteral("generatedAt"), &generatedAt, error)) {
        if (error && error->isEmpty())
            *error = translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information is not supported by this preview"));
        return false;
    }

    InstalledUsageSnapshot candidate;
    candidate.generatedAt = generatedAt;
    if (!readNonNegativeInteger(root, QStringLiteral("applicationCount"),
                                &candidate.applicationCount, error)
        || !readNonNegativeInteger(root, QStringLiteral("knownSizeBytes"),
                                   &candidate.knownSizeBytes, error)
        || !readNonNegativeInteger(root, QStringLiteral("unknownSizeCount"),
                                   &candidate.unknownSizeCount, error)) {
        return false;
    }

    const QJsonValue sourcesValue = root.value(QStringLiteral("sources"));
    const QJsonValue applicationsValue = root.value(QStringLiteral("applications"));
    if (!sourcesValue.isArray() || !applicationsValue.isArray())
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The local library information is incomplete")));

    for (const QJsonValue &value : sourcesValue.toArray()) {
        if (!value.isObject())
            return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "A library source entry is not in the expected format")));
        const QJsonObject sourceObject = value.toObject();
        InstalledUsageSource source;
        if (!readRequiredText(sourceObject, QStringLiteral("id"), &source.id, error)
            || !readRequiredText(sourceObject, QStringLiteral("name"), &source.name, error)
            || !readNonNegativeInteger(sourceObject, QStringLiteral("applicationCount"),
                                       &source.applicationCount, error)
            || !readNonNegativeInteger(sourceObject, QStringLiteral("knownSizeBytes"),
                                       &source.knownSizeBytes, error)
            || !readNonNegativeInteger(sourceObject, QStringLiteral("unknownSizeCount"),
                                       &source.unknownSizeCount, error)) {
            return false;
        }
        candidate.sources.append(source);
    }

    for (const QJsonValue &value : applicationsValue.toArray()) {
        if (!value.isObject())
            return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "An application entry is not in the expected format")));
        const QJsonObject applicationObject = value.toObject();
        InstalledUsageApplication application;
        if (!readRequiredText(applicationObject, QStringLiteral("name"), &application.name, error)
            || !readRequiredText(applicationObject, QStringLiteral("sourceId"),
                                 &application.sourceId, error)
            || !readRequiredText(applicationObject, QStringLiteral("sourceName"),
                                 &application.sourceName, error)
            || !readRequiredText(applicationObject, QStringLiteral("sizeKind"),
                                 &application.sizeKind, error)
            || !readNonNegativeInteger(applicationObject, QStringLiteral("sizeBytes"),
                                       &application.sizeBytes, error)) {
            return false;
        }
        candidate.applications.append(application);
    }

    if (candidate.applicationCount != candidate.applications.size())
        return fail(error, translated(QT_TRANSLATE_NOOP("InstalledUsageAdapter", "The application count does not match the application entries")));

    *snapshot = candidate;
    return true;
}

QVariantMap InstalledUsageAdapter::toVariantMap(const InstalledUsageSnapshot &snapshot)
{
    QVariantList sources;
    for (const InstalledUsageSource &source : snapshot.sources) {
        const QVariantMap sourceMap{
            {QStringLiteral("id"), source.id},
            {QStringLiteral("name"), source.name},
            {QStringLiteral("applicationCount"), source.applicationCount},
            {QStringLiteral("knownSizeBytes"), source.knownSizeBytes},
            {QStringLiteral("unknownSizeCount"), source.unknownSizeCount},
        };
        sources.append(sourceMap);
    }

    return {
        {QStringLiteral("available"), true},
        {QStringLiteral("generatedAt"), snapshot.generatedAt},
        {QStringLiteral("applicationCount"), snapshot.applicationCount},
        {QStringLiteral("knownSizeBytes"), snapshot.knownSizeBytes},
        {QStringLiteral("knownSizeText"), formatBytes(snapshot.knownSizeBytes)},
        {QStringLiteral("unknownSizeCount"), snapshot.unknownSizeCount},
        {QStringLiteral("sourceCount"), snapshot.sources.size()},
        {QStringLiteral("sources"), sources},
    };
}
