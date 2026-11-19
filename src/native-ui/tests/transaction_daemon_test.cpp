// Starts the real Python daemon through TransactionClient and checks that the client
// connects over each transport: Unix socket (Linux, macOS) and token-authenticated
// loopback TCP (Windows). Needs OMNISTORE_PYTHON with the backend's requirements installed.
#include "transactionclient.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QtTest>

class TransactionDaemonTest : public QObject {
    Q_OBJECT
private:
    static bool waitAvailable(TransactionClient &client, int ms) {
        QElapsedTimer timer;
        timer.start();
        while (timer.elapsed() < ms) {
            if (client.available())
                return true;
            QTest::qWait(100);
        }
        return client.available();
    }
    static void shutdownLocal(const QString &path) {
        QLocalSocket socket;
        socket.connectToServer(path);
        if (socket.waitForConnected(2000)) {
            socket.write("{\"action\":\"shutdown\",\"args\":[],\"kwargs\":{}}\n");
            socket.waitForBytesWritten(1000);
            socket.waitForReadyRead(2000);
        }
    }
    static void shutdownTcp(const QString &file) {
        QFile f(file);
        if (!f.open(QIODevice::ReadOnly))
            return;
        const QJsonObject endpoint = QJsonDocument::fromJson(f.readAll()).object();
        QTcpSocket socket;
        socket.connectToHost(QHostAddress::LocalHost, endpoint.value("port").toInt());
        if (socket.waitForConnected(2000)) {
            socket.write(QJsonDocument(QJsonObject{{"auth", endpoint.value("token")}}).toJson(QJsonDocument::Compact) + "\n");
            socket.write("{\"action\":\"shutdown\",\"args\":[],\"kwargs\":{}}\n");
            socket.waitForBytesWritten(1000);
            socket.waitForReadyRead(2000);
        }
    }
private slots:
    void initTestCase() {
        if (qEnvironmentVariable("OMNISTORE_PYTHON").isEmpty())
            QSKIP("Set OMNISTORE_PYTHON to a Python with the backend requirements.");
        qputenv("OMNISTORE_NO_SYSTEMD_START", "1");
    }
    void connectsOverUnixSocket() {
#ifdef Q_OS_WIN
        QSKIP("Windows uses the TCP transport.");
#endif
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString socketPath = dir.filePath("d.sock");
        qputenv("OMNISTORE_DAEMON_SOCKET", socketPath.toUtf8());
        qunsetenv("OMNISTORE_DAEMON_TCP");
        qputenv("XDG_CONFIG_HOME", dir.filePath("cfg").toUtf8());
        {
            TransactionClient client;
            QVERIFY2(waitAvailable(client, 25000), qPrintable(client.errorMessage()));
        }
        shutdownLocal(socketPath);
    }
    void connectsOverAuthenticatedTcp() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString file = dir.filePath("daemon.json");
        qputenv("OMNISTORE_DAEMON_TCP", "1");
        qputenv("OMNISTORE_DAEMON_TCP_FILE", file.toUtf8());
        qputenv("OMNISTORE_DAEMON_SOCKET", dir.filePath("unused.sock").toUtf8());
        qputenv("XDG_CONFIG_HOME", dir.filePath("cfg").toUtf8());
        {
            TransactionClient client;
            QVERIFY2(waitAvailable(client, 25000), qPrintable(client.errorMessage()));
        }
        shutdownTcp(file);
    }
};
QTEST_MAIN(TransactionDaemonTest)
#include "transaction_daemon_test.moc"
