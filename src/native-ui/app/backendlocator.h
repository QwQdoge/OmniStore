#pragma once

#include <QString>
#include <QStringList>

// Finds the Python backend on Linux, macOS and Windows. Shared by BackendBridge
// (one-shot commands) and TransactionClient (the long-running service).
struct BackendCommand {
    QString program;
    QStringList prefixArguments;  // e.g. the path of main.py when run from source
    QString workingDirectory;
    QString description;

    bool valid() const { return !program.isEmpty(); }
};

namespace BackendLocator {

BackendCommand locate();

// Where release bundles keep the frozen backend, relative to the app folder.
QStringList bundledCandidates(const QString &applicationDir);

}
