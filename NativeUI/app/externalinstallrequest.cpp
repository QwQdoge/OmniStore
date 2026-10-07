#include "externalinstallrequest.h"

#include <QHash>
#include <QRegularExpression>

ExternalInstallRequest ExternalInstallRequest::parse(const QStringList &arguments)
{
    ExternalInstallRequest result;
    if (arguments.isEmpty() || arguments.first() != QStringLiteral("install"))
        return result;
    result.status = Status::Rejected;
    result.error = QStringLiteral("Usage: omnistore install <package-id> [--source <source>]");
    if ((arguments.size() != 2 && arguments.size() != 4)
        || (arguments.size() == 4 && arguments.at(2) != QStringLiteral("--source")))
        return result;

    static const QHash<QString, QString> sources = {
        {QStringLiteral("native"), QStringLiteral("Native")},
        {QStringLiteral("pacman"), QStringLiteral("Native")},
        {QStringLiteral("aur"), QStringLiteral("AUR")},
        {QStringLiteral("flatpak"), QStringLiteral("Flatpak")},
        {QStringLiteral("github"), QStringLiteral("GitHub")},
        {QStringLiteral("bitu"), QStringLiteral("Bitu")},
    };
    const QString key = arguments.size() == 4 ? arguments.at(3).toLower() : QStringLiteral("native");
    const QString source = sources.value(key);
    if (source.isEmpty()) {
        result.error = QStringLiteral("Unsupported OmniStore source.");
        return result;
    }
    static const QRegularExpression native(QStringLiteral("\\A[a-z0-9][a-z0-9@._+\\-]{0,127}\\z"));
    static const QRegularExpression flatpak(QStringLiteral("\\A[A-Za-z0-9][A-Za-z0-9._\\-]{1,191}\\z"));
    static const QRegularExpression repository(QStringLiteral("\\A[A-Za-z0-9][A-Za-z0-9_.\\-]{0,127}/[A-Za-z0-9][A-Za-z0-9_.\\-]{0,127}\\z"));
    const QString id = arguments.at(1);
    const auto &pattern = source == QStringLiteral("Native") || source == QStringLiteral("AUR")
        ? native : source == QStringLiteral("Flatpak") ? flatpak : repository;
    if (!pattern.match(id).hasMatch()) {
        result.error = QStringLiteral("Invalid package identifier for the selected source.");
        return result;
    }
    result.status = Status::Accepted;
    result.packageId = id;
    result.source = source;
    result.error.clear();
    return result;
}
