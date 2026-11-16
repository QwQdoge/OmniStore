#include "backendbridge.h"
#include "accountaibridge.h"
#include "externalinstallrequest.h"
#include "repositorybridge.h"
#include "systembridge.h"
#include "transactionclient.h"

#include <QCoreApplication>
#include <QEventLoop>
#include <QFile>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QStandardPaths>
#include <QTranslator>
#include <QVariantMap>
#include <cstdio>

#ifndef OMNISTORE_RELEASE_VERSION
#define OMNISTORE_RELEASE_VERSION "development"
#endif

// About reads the license files the package actually installed rather than a
// list compiled into QML; an empty result is shown as "not available".
static QString installedLicenseFile(const QString &name)
{
    const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                QStringLiteral("licenses/omnistore-bin/") + name);
    QFile file(path);
    if (path.isEmpty() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    const auto request = ExternalInstallRequest::parse(app.arguments().mid(1));
    if (request.status == ExternalInstallRequest::Status::Rejected) {
        std::fprintf(stderr, "%s\n", qPrintable(request.error));
        return 2;
    }
    QCoreApplication::setOrganizationName(QStringLiteral("MeoArch"));
    QCoreApplication::setApplicationName(QStringLiteral("OmniStore"));
    QCoreApplication::setApplicationVersion(QString::fromUtf8(OMNISTORE_RELEASE_VERSION));
    app.setDesktopFileName(QStringLiteral("org.meo.OmniStore"));

    // Translation availability follows the compiled catalogs, while locale
    // selection follows the running system. Missing catalogs fall back to the
    // English source strings instead of forcing a product language.
    QTranslator translator;
    if (translator.load(QLocale::system(), QStringLiteral("omnistore"),
                        QStringLiteral("_"), QStringLiteral(":/i18n"))) {
        app.installTranslator(&translator);
    }

    // MeoUI owns the visual language. Basic keeps Qt Controls used internally
    // by the design system from importing a competing Material theme.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    AccountAiBridge accountAi;
    BackendBridge backend;
    RepositoryBridge repositoryBridge;
    SystemBridge systemBridge;
    TransactionClient transactions;
    QQmlApplicationEngine engine;
#ifdef OMNISTORE_MEOUI_BUILD_IMPORT_PATH
    // addImportPath prepends: the explicitly built dependency must win over
    // an older system-installed MeoUI module.
    engine.addImportPath(QString::fromUtf8(OMNISTORE_MEOUI_BUILD_IMPORT_PATH));
#endif
    if (app.arguments().mid(1) == QStringList{QStringLiteral("--check-qml")}) {
        // Compile real embedded pages without instantiating them or starting
        // backend requests. Main's Meo.System integration is checked on Meo.
        const QStringList types = {QStringLiteral("SearchPage"), QStringLiteral("TasksPage"),
            QStringLiteral("HomePage"), QStringLiteral("ExplorePage"),
            QStringLiteral("UpdatesPage"), QStringLiteral("InstalledPage"),
            QStringLiteral("SettingsPage"), QStringLiteral("AppDetailsPane"), QStringLiteral("AccountAiPanel")};
        for (const auto &type : types) {
            QQmlComponent component(&engine);
            component.loadFromModule(QStringLiteral("OmniStore.Native"), type);
            if (!component.isReady()) {
                std::fprintf(stderr, "%s: %s\n", qPrintable(type), qPrintable(component.errorString()));
                return 1;
            }
        }
        return 0;
    }

    QVariantMap pendingInstallRequest;
    if (request.status == ExternalInstallRequest::Status::Accepted) {
        pendingInstallRequest.insert(QStringLiteral("id"), request.packageId);
        pendingInstallRequest.insert(QStringLiteral("name"), request.packageId);
        pendingInstallRequest.insert(QStringLiteral("primary_source"), request.source);
        pendingInstallRequest.insert(QStringLiteral("external_install_request"), true);
    }
    engine.rootContext()->setContextProperty(QStringLiteral("pendingInstallRequest"), pendingInstallRequest);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("accountAi"), &accountAi);
    engine.rootContext()->setContextProperty(QStringLiteral("repoBridge"), &repositoryBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("systemBridge"), &systemBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("transactions"), &transactions);
    engine.rootContext()->setContextProperty(QStringLiteral("appLicenseText"),
                                             installedLicenseFile(QStringLiteral("LICENSE")));
    engine.rootContext()->setContextProperty(QStringLiteral("appNoticesText"),
                                             installedLicenseFile(QStringLiteral("THIRD_PARTY_NOTICES.md")));

    if (app.arguments().mid(1) == QStringList{QStringLiteral("--smoke-pages")}) {
        // Instantiate every page (wide and narrow) against the real bridges and fail on
        // any QML runtime warning: undefined properties, bad bindings, type errors.
        static int warnings = 0;
        qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &, const QString &message) {
            if (type >= QtWarningMsg && message.contains(QStringLiteral(".qml"))) {
                ++warnings;
                std::fprintf(stderr, "QML warning: %s\n", qPrintable(message));
            }
        });
        const QStringList types = {QStringLiteral("HomePage"), QStringLiteral("ExplorePage"),
            QStringLiteral("InstalledPage"), QStringLiteral("UpdatesPage"), QStringLiteral("SearchPage"),
            QStringLiteral("TasksPage"), QStringLiteral("SettingsPage")};
        const QStringList categories = {QStringLiteral("appearance"), QStringLiteral("sources"),
            QStringLiteral("updates"), QStringLiteral("ai"), QStringLiteral("notifications"),
            QStringLiteral("privacy"), QStringLiteral("advanced")};
        for (const QSize &size : {QSize(1280, 800), QSize(480, 800)}) {
            for (const auto &type : types) {
                QQmlComponent component(&engine);
                component.loadFromModule(QStringLiteral("OmniStore.Native"), type);
                if (!component.isReady()) {
                    std::fprintf(stderr, "%s: %s\n", qPrintable(type), qPrintable(component.errorString()));
                    return 1;
                }
                QQuickWindow window;
                window.resize(size);
                auto *item = qobject_cast<QQuickItem *>(component.create());
                if (!item) {
                    std::fprintf(stderr, "%s: could not be created\n", qPrintable(type));
                    return 1;
                }
                item->setParentItem(window.contentItem());
                item->setSize(size);
                window.show();
                const bool settings = type == QLatin1String("SettingsPage");
                for (const QString &category : settings ? categories : QStringList{QString()}) {
                    if (settings)
                        item->setProperty("category", category);
                    QEventLoop loop;
                    QTimer::singleShot(250, &loop, &QEventLoop::quit);
                    loop.exec();
                    // Optional visual evidence: OMNISTORE_SMOKE_SHOTS=<dir> saves a PNG per page.
                    const QString shots = qEnvironmentVariable("OMNISTORE_SMOKE_SHOTS");
                    if (!shots.isEmpty()) {
                        const QString name = QStringLiteral("%1/%2-%3%4.png").arg(shots, type)
                            .arg(size.width()).arg(category.isEmpty() ? QString() : QLatin1Char('-') + category);
                        window.grabWindow().save(name);
                    }
                }
                delete item;
            }
        }
        std::fprintf(stderr, "smoke: %d QML warning(s)\n", warnings);
        return warnings == 0 ? 0 : 1;
    }

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("OmniStore.Native"), QStringLiteral("Main"));

    return app.exec();
}
