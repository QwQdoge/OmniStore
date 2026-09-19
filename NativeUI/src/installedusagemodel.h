#pragma once

#include "installedusageadapter.h"

#include <QAbstractListModel>

class InstalledUsageModel final : public QAbstractListModel {
    Q_OBJECT

public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        SourceIdRole,
        SourceNameRole,
        SizeKindRole,
        SizeBytesRole,
        SizeTextRole,
    };

    explicit InstalledUsageModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setApplications(QList<InstalledUsageApplication> applications);

private:
    static QString formatBytes(qint64 bytes);

    QList<InstalledUsageApplication> m_applications;
};
