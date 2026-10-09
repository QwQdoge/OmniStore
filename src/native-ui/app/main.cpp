#include "backendbridge.h"
#include "externalinstallrequest.h"
#include "repositorybridge.h"
#include "systembridge.h"
#include "transactionclient.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQuickStyle>
#include <QTranslator>
#include <QVariantMap>
#include <cstdio>

#ifndef OMNISTORE_RELEASE_VERSION
#define OMNISTORE_RELEASE_VERSION "development"
#endif

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
            QStringLiteral("SettingsPage"), QStringLiteral("AppDetailsPane")};
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
    engine.rootContext()->setContextProperty(QStringLiteral("repoBridge"), &repositoryBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("systemBridge"), &systemBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("transactions"), &transactions);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("OmniStore.Native"), QStringLiteral("Main"));

    return app.exec();
}
