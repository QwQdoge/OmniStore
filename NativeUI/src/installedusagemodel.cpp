#include "installedusagemodel.h"

#include <QLocale>

InstalledUsageModel::InstalledUsageModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int InstalledUsageModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_applications.size();
}

QVariant InstalledUsageModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_applications.size())
        return {};

    const InstalledUsageApplication &application = m_applications.at(index.row());
    switch (role) {
    case NameRole:
        return application.name;
    case SourceIdRole:
        return application.sourceId;
    case SourceNameRole:
        return application.sourceName;
    case SizeKindRole:
        return application.sizeKind;
    case SizeBytesRole:
        return application.sizeBytes;
    case SizeTextRole:
        return formatBytes(application.sizeBytes);
    default:
        return {};
    }
}

QHash<int, QByteArray> InstalledUsageModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {SourceIdRole, "sourceId"},
        {SourceNameRole, "sourceName"},
        {SizeKindRole, "sizeKind"},
        {SizeBytesRole, "sizeBytes"},
        {SizeTextRole, "sizeText"},
    };
}

void InstalledUsageModel::setApplications(QList<InstalledUsageApplication> applications)
{
    beginResetModel();
    m_applications = std::move(applications);
    endResetModel();
}

QString InstalledUsageModel::formatBytes(qint64 bytes)
{
    if (bytes < 1024)
        return QStringLiteral("%1 B").arg(bytes);
    if (bytes < 1024 * 1024)
        return QStringLiteral("%1 KiB").arg(QLocale().toString(bytes / 1024.0, 'f', 1));
    if (bytes < 1024LL * 1024 * 1024)
        return QStringLiteral("%1 MiB").arg(QLocale().toString(bytes / (1024.0 * 1024.0), 'f', 1));
    return QStringLiteral("%1 GiB").arg(QLocale().toString(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 1));
}
