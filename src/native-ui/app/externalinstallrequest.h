#pragma once

#include <QStringList>

struct ExternalInstallRequest {
    enum class Status { Ignored, Accepted, Rejected };
    Status status = Status::Ignored;
    QString packageId;
    QString source;
    QString error;

    // Arguments exclude the executable. Parsing never starts a transaction.
    static ExternalInstallRequest parse(const QStringList &arguments);
};
