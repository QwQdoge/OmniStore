#include "transactionclient.h"
#include <QLocalServer>
#include <QLocalSocket>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTemporaryDir>
#include <QtTest>

class TransactionAuthenticationTest : public QObject {
    Q_OBJECT
private slots:
    void promptAppearsWhileRunningAndClearsOnCompletion() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        QLocalServer server;
        const QString path = directory.filePath("daemon.sock");
        QVERIFY(server.listen(path));
        qputenv("OMNISTORE_DAEMON_SOCKET", path.toUtf8());
        qputenv("OMNISTORE_NO_SYSTEMD_START", "1");
        const QString prompt = "Place your finger on the fingerprint reader";
        bool finished = false;
        connect(&server, &QLocalServer::newConnection, this, [&] {
            auto *socket = server.nextPendingConnection();
            connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            connect(socket, &QLocalSocket::readyRead, this, [&, socket] {
                while (socket->canReadLine()) {
                    const auto request = QJsonDocument::fromJson(socket->readLine()).object();
                    const auto action = request.value("action").toString();
                    QVERIFY(action == "task.list" || action == "task.get");
                    QJsonObject task{{"taskId", "test"}, {"kind", "install"},
                                     {"status", finished ? "succeeded" : "running"},
                                     {"authenticationPrompt", prompt}};
                    QJsonValue value = action == "task.list"
                        ? QJsonValue(QJsonArray{task}) : QJsonValue(task);
                    socket->write(QJsonDocument(QJsonObject{{"status", "success"},
                                                            {"response", value}}).toJson(QJsonDocument::Compact) + '\n');
                    socket->flush();
                }
            });
        });
        TransactionClient client;
        QTRY_COMPARE_WITH_TIMEOUT(client.authenticationPrompt(), prompt, 2000);
        QVERIFY(client.busy());
        finished = true;
        QTRY_VERIFY_WITH_TIMEOUT(!client.busy(), 2000);
        QCOMPARE(client.authenticationPrompt(), QString{});
    }
};
QTEST_GUILESS_MAIN(TransactionAuthenticationTest)
#include "transaction_authentication_test.moc"
