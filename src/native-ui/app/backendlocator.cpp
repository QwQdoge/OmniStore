#include "backendlocator.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

namespace BackendLocator {

namespace {
QString executableName()
{
#ifdef Q_OS_WIN
    return QStringLiteral("python_server.exe");
#else
    return QStringLiteral("python_server");
#endif
}

QString findPython()
{
    const QString fromEnv = qEnvironmentVariable("OMNISTORE_PYTHON").trimmed();
    if (!fromEnv.isEmpty())
        return fromEnv;
#ifdef Q_OS_WIN
    for (const char *name : {"python", "py"}) {
        const QString found = QStandardPaths::findExecutable(QString::fromLatin1(name));
        if (!found.isEmpty())
            return found;
    }
    return QStringLiteral("python");
#else
    const QString found = QStandardPaths::findExecutable(QStringLiteral("python3"));
    return found.isEmpty() ? QStringLiteral("/usr/bin/python3") : found;
#endif
}
}

QStringList bundledCandidates(const QString &applicationDir)
{
    const QDir dir(applicationDir);
    const QString name = executableName();
    return {
        dir.absoluteFilePath(QStringLiteral("backends/") + name),                 // Windows / portable
        dir.absoluteFilePath(QStringLiteral("../Resources/backends/") + name),    // macOS .app bundle
        dir.absoluteFilePath(QStringLiteral("../backends/") + name),              // Linux bundle layout
        QStringLiteral("/opt/omnistore/backends/") + name,                         // MeoArch package
    };
}

BackendCommand locate()
{
    BackendCommand command;
    const QString explicitBackend = qEnvironmentVariable("OMNISTORE_BACKEND").trimmed();
    if (!explicitBackend.isEmpty()) {
        command.program = explicitBackend;
        command.workingDirectory = QFileInfo(explicitBackend).absolutePath();
        command.description = QStringLiteral("OMNISTORE_BACKEND · %1").arg(explicitBackend);
        return command;
    }

    for (const QString &candidate : bundledCandidates(QCoreApplication::applicationDirPath())) {
        const QFileInfo info(candidate);
        if (info.isFile() && info.isExecutable()) {
            command.program = info.absoluteFilePath();
            command.workingDirectory = info.absolutePath() + QStringLiteral("/..");
            command.description = QStringLiteral("Bundled Python backend");
            return command;
        }
    }

#ifdef OMNISTORE_SOURCE_ROOT
    const QString sourceRoot = QString::fromUtf8(OMNISTORE_SOURCE_ROOT);
    const QString sourceBackend = QDir(sourceRoot).absoluteFilePath(QStringLiteral("python/main.py"));
    if (QFileInfo(sourceBackend).isFile()) {
        command.program = findPython();
        command.prefixArguments = {sourceBackend};
        command.workingDirectory = sourceRoot;
        command.description = QStringLiteral("Source Python backend · %1").arg(sourceBackend);
        return command;
    }
#endif
    command.description = QStringLiteral("Backend unavailable");
    return command;
}

}
