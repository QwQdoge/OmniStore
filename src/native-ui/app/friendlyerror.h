#pragma once

#include <QCoreApplication>
#include <QString>

// Turns raw backend or package-manager text into the standard store error
// wording (MeoUI STORE_FEEDBACK.md section 4). The raw text is never shown;
// callers keep it as the collapsed detail / task log.
namespace FriendlyError {

inline QString tr(const char *text)
{
    return QCoreApplication::translate("FriendlyError", text);
}

// True when the raw text says the source or network could not be reached.
inline bool isNetwork(const QString &raw)
{
    const QString text = raw.toLower();
    for (const char *needle : {"failed retrieving", "could not resolve", "network", "unreachable",
                               "connection", "failed to connect", "name or service not known", "timed out"})
        if (text.contains(QLatin1String(needle)))
            return true;
    return false;
}

// Coarse category of a raw failure, for choosing the follow-up action in the UI.
// One of: space, network, cancelled, locked, service, missing, unknown.
inline QString category(const QString &raw)
{
    const QString text = raw.toLower();
    auto has = [&](std::initializer_list<const char *> needles) {
        for (const char *needle : needles)
            if (text.contains(QLatin1String(needle)))
                return true;
        return false;
    };
    if (has({"no space left", "not enough space", "disk full", "insufficient space"})) return QStringLiteral("space");
    if (isNetwork(raw)) return QStringLiteral("network");
    if (has({"authorization denied", "authentication failed", "not authorized", "dismissed", "cancelled", "canceled"}))
        return QStringLiteral("cancelled");
    if (has({"unable to lock", "database is locked", "another transaction"})) return QStringLiteral("locked");
    if (has({"transaction service", "backend is unavailable", "backend could not start"})) return QStringLiteral("service");
    if (has({"target not found", "no such package", "nothing matches"})) return QStringLiteral("missing");
    return QStringLiteral("unknown");
}

// kind: install | remove | update | update_all | "" (unknown); subject: the app name.
inline QString message(const QString &raw, const QString &kind = {}, const QString &subject = {})
{
    const QString text = raw.toLower();
    auto has = [&](std::initializer_list<const char *> needles) {
        for (const char *needle : needles)
            if (text.contains(QLatin1String(needle)))
                return true;
        return false;
    };

    QString noun = subject.trimmed();
    QString failed;
    QString cancelled;
    if (kind == QLatin1String("install")) {
        failed = noun.isEmpty() ? tr("Couldn't install the app.") : tr("Couldn't install %1.").arg(noun);
        cancelled = tr("Installation was cancelled.");
    } else if (kind == QLatin1String("remove")) {
        failed = noun.isEmpty() ? tr("Couldn't remove the app.") : tr("Couldn't remove %1.").arg(noun);
        cancelled = tr("Removal was cancelled.");
    } else if (kind == QLatin1String("update") || kind == QLatin1String("update_all")) {
        failed = noun.isEmpty() ? tr("Couldn't update.") : tr("Couldn't update %1.").arg(noun);
        cancelled = tr("The update was cancelled.");
    } else {
        failed = tr("Couldn't complete that action.");
        cancelled = tr("The action was cancelled.");
    }

    if (has({"transaction service", "backend is unavailable", "backend could not start", "no user runtime directory"}))
        return tr("The store service isn't running.");
    if (has({"another transaction", "unable to lock", "database is locked", "waiting for another",
             "finish the current", "finish or cancel"}))
        return tr("Waiting for another change to finish.");
    if (has({"authorization denied", "authentication failed", "not authorized", "dismissed", "cancelled",
             "canceled", "request dismissed"}))
        return cancelled;
    if (has({"is not installed", "not installed"}))
        return tr("That app isn't installed.");
    if (has({"no space left", "not enough space", "disk full", "insufficient space"}))
        return failed + QLatin1Char(' ') + tr("There isn't enough free space.");
    if (has({"target not found", "no such package", "not found in", "could not find", "nothing matches"}))
        return failed + QLatin1Char(' ') + tr("It wasn't found in this source.");
    if (has({"timed out", "timeout"}))
        return failed + QLatin1Char(' ') + tr("The source took too long to respond.");
    if (has({"failed retrieving", "could not resolve", "network", "unreachable", "connection",
             "failed to connect", "name or service not known"}))
        return failed + QLatin1Char(' ') + tr("Couldn't reach the source. Check your connection.");
    if (has({"requires administrator", "no sudo-compatible", "askpass"}))
        return failed + QLatin1Char(' ') + tr("OmniStore couldn't ask for administrator permission.");
    if (raw.trimmed().isEmpty())
        return failed;
    return failed + QLatin1Char(' ') + tr("Try again, or open the log.");
}

} // namespace FriendlyError
