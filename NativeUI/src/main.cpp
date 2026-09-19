#include "installedusageadapter.h"
#include "installedusagemodel.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDir>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStringList>
#include <QTimer>
#include <QTranslator>
#include <QVariant>

namespace {

QString normalizedUiLanguage(const QString &requestedLanguage)
{
    const QLocale requestedLocale(requestedLanguage.trimmed().isEmpty()
                                      ? QLocale::system()
                                      : QLocale(requestedLanguage));
    if (requestedLocale.language() == QLocale::Chinese)
        return QStringLiteral("zh_CN");

    const QString name = requestedLocale.name();
    return name == QStringLiteral("C") ? QStringLiteral("en_US") : name;
}

bool installCatalog(QGuiApplication &application,
                    QTranslator &translator,
                    const QString &catalog,
                    const QStringList &paths)
{
    for (const QString &path : paths) {
        if (!path.isEmpty() && translator.load(catalog, path)) {
            application.installTranslator(&translator);
            return true;
        }
    }
    return false;
}

QStringList nativeTranslationPaths()
{
    QStringList paths;
    const QString configured = qEnvironmentVariable("OMNISTORE_NATIVE_TRANSLATIONS").trimmed();
    if (!configured.isEmpty())
        paths.append(configured);
#ifdef OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR
    paths.append(QString::fromUtf8(OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR));
#endif
#ifdef OMNISTORE_NATIVE_TRANSLATIONS_INSTALL_DIR
    paths.append(QString::fromUtf8(OMNISTORE_NATIVE_TRANSLATIONS_INSTALL_DIR));
#endif
    paths.append(QDir(QCoreApplication::applicationDirPath())
                     .filePath(QStringLiteral("../share/omnistore-native/translations")));
    return paths;
}

QStringList meoUiTranslationPaths()
{
    QStringList paths;
    const QString configured = qEnvironmentVariable("MEOUI_TRANSLATIONS").trimmed();
    if (!configured.isEmpty())
        paths.append(configured);
#ifdef MEOUI_TRANSLATIONS_DEVELOPMENT_DIR
    paths.append(QString::fromUtf8(MEOUI_TRANSLATIONS_DEVELOPMENT_DIR));
#endif
#ifdef MEOUI_TRANSLATIONS_INSTALL_DIR
    paths.append(QString::fromUtf8(MEOUI_TRANSLATIONS_INSTALL_DIR));
#endif
    paths.append(QDir(QCoreApplication::applicationDirPath())
                     .filePath(QStringLiteral("../share/meoui-qml/translations")));
    return paths;
}

QVariantMap unavailableSummary(const QString &reason)
{
    return {
        {QStringLiteral("available"), false},
        {QStringLiteral("error"), reason},
        {QStringLiteral("applicationCount"), 0},
        {QStringLiteral("knownSizeBytes"), 0},
        {QStringLiteral("knownSizeText"), QStringLiteral("0 B")},
        {QStringLiteral("unknownSizeCount"), 0},
        {QStringLiteral("sourceCount"), 0},
    };
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication application(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("OmniStore NativeUI Phase-0 preview"));
    parser.addHelpOption();
    const QCommandLineOption fixtureOption(
        QStringLiteral("fixture"),
        QStringLiteral("Read a deterministic installed-usage JSON fixture instead of the exporter."),
        QStringLiteral("path"));
    const QCommandLineOption screenshotOption(
        QStringLiteral("screenshot"),
        QStringLiteral("Save one preview screenshot and exit."),
        QStringLiteral("path"));
    const QCommandLineOption uiLanguageOption(
        QStringLiteral("ui-language"),
        QStringLiteral("Use an explicit UI language for development and validation."),
        QStringLiteral("locale"));
    parser.addOption(fixtureOption);
    parser.addOption(screenshotOption);
    parser.addOption(uiLanguageOption);
    parser.process(application);

    // This choice only affects the preview process. The normal path follows
    // the device locale; it neither creates a setting nor changes an Account
    // or Plasma/session preference.
    const QLocale uiLocale(normalizedUiLanguage(parser.value(uiLanguageOption)));
    QLocale::setDefault(uiLocale);
    QTranslator nativeTranslator;
    QTranslator meoUiTranslator;
    if (uiLocale.name() == QStringLiteral("zh_CN")) {
        installCatalog(application, nativeTranslator,
                       QStringLiteral("omnistore_native_zh_CN"), nativeTranslationPaths());
        installCatalog(application, meoUiTranslator,
                       QStringLiteral("meoui_zh_CN"), meoUiTranslationPaths());
    }

    InstalledUsageAdapter adapter;
    InstalledUsageSnapshot snapshot;
    QString error;
    const bool loaded = parser.isSet(fixtureOption)
                            ? adapter.loadFromFile(parser.value(fixtureOption), &snapshot, &error)
                            : adapter.loadFromExporter(&snapshot, &error);

    InstalledUsageModel applications;
    const QVariantMap summary = loaded ? InstalledUsageAdapter::toVariantMap(snapshot)
                                        : unavailableSummary(error);
    if (loaded)
        applications.setApplications(snapshot.applications);

    QQmlApplicationEngine engine;
    engine.setUiLanguage(uiLocale.bcp47Name());
    engine.setInitialProperties({
        {QStringLiteral("installedUsageSummary"), summary},
        {QStringLiteral("installedUsageModel"), QVariant::fromValue(static_cast<QObject *>(&applications))},
    });
    engine.loadFromModule("org.meo.omnistore.native", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    if (!parser.isSet(screenshotOption))
        return application.exec();

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!window)
        return 2;
    const QString screenshotPath = parser.value(screenshotOption);
    QTimer::singleShot(600, window, [window, screenshotPath, &application]() {
        const QImage image = window->grabWindow();
        application.exit(image.isNull() || !image.save(screenshotPath) ? 3 : 0);
    });
    return application.exec();
}
