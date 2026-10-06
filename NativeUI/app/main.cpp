#include "backendbridge.h"
#include "repositorybridge.h"
#include "systembridge.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("MeoArch"));
    QCoreApplication::setApplicationName(QStringLiteral("OmniStore"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0-native"));

    // MeoUI owns the visual language. Basic keeps Qt Controls used internally
    // by the design system from importing a competing Material theme.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    BackendBridge backend;
    RepositoryBridge repositoryBridge;
    SystemBridge systemBridge;
    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("/usr/lib/qt6/qml"));
#ifdef OMNISTORE_MEOUI_BUILD_IMPORT_PATH
    engine.addImportPath(QString::fromUtf8(OMNISTORE_MEOUI_BUILD_IMPORT_PATH));
#endif
    const QString systemImportRoot = qEnvironmentVariable("MEO_SYSTEM_QML_IMPORT_PATH");
    if (!systemImportRoot.isEmpty())
        engine.addImportPath(systemImportRoot);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("repoBridge"), &repositoryBridge);
    engine.rootContext()->setContextProperty(QStringLiteral("systemBridge"), &systemBridge);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("OmniStore.Native"), QStringLiteral("Main"));

    return app.exec();
}
