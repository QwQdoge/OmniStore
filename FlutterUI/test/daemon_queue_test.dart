import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/backend/daemon_client.dart';

void main() {
  test('a timed-out queue slot cannot release a later transaction', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    final received = <String>[];
    final subscription = server.listen((socket) {
      sockets.add(socket);
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final action = (jsonDecode(line) as Map<String, dynamic>)['action'];
            received.add(action as String);
            socket.writeln(
              jsonEncode({'status': 'success', 'response': action}),
            );
          });
    });
    final startupGate = Completer<void>();
    var starts = 0;
    final client = DaemonClient(
      port: server.port,
      onDemandStart: () async {
        starts++;
        await startupGate.future;
        return null;
      },
    );
    addTearDown(() async {
      if (!startupGate.isCompleted) startupGate.complete();
      await client.dispose();
      for (final socket in sockets) {
        socket.destroy();
      }
      await subscription.cancel();
      await server.close();
    });

    final first = client.send(
      'first',
      [],
      timeout: const Duration(seconds: 10),
    );
    final abandoned = client.send('abandoned', [], timeout: Duration.zero);
    final last = client.send('last', [], timeout: const Duration(seconds: 10));
    expect(await abandoned, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1, reason: 'the first transaction still owns the queue');
    expect(received, isEmpty);

    startupGate.complete();
    expect((await first)?.response, 'first');
    expect((await last)?.response, 'last');
    expect(received, ['first', 'last']);
  });
}
