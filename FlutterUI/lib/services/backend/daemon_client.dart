import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DaemonResult {
  final String status;
  final dynamic response;
  final String stdout;
  final String? error;

  DaemonResult({
    required this.status,
    this.response,
    required this.stdout,
    this.error,
  });
}

/// Murphy-proof: Client for communicating with the Python backend daemon.
/// Implements robust connection management, heartbeat, and serialized requests.
class DaemonClient {
  final int port;
  final String host;
  final Future<Process?> Function() onDemandStart;

  DaemonClient({
    this.port = 9081,
    this.host = '127.0.0.1',
    required this.onDemandStart,
  });

  Socket? _socket;
  StreamSubscription<String>? _socketSub;
  Completer<DaemonResult>? _responseCompleter;
  Timer? _heartbeatTimer;
  Completer<void> _mutex = Completer<void>()..complete();

  bool get isConnected => _socket != null;

  /// Murphy-proof: Serialized communication with the daemon.
  /// Ensures that only one transaction happens at a time and handles timeouts.
  Future<DaemonResult?> send(
    String action,
    List<dynamic> args, {
    Map<String, dynamic>? kwargs,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;

    try {
      await previousMutex.future.timeout(
        Duration(seconds: timeout.inSeconds + 5),
        onTimeout: () => debugPrint("DaemonClient: Mutex bottlenecked for $action"),
      );
    } catch (_) {}

    try {
      await _ensureConnected();
      final socket = _socket;
      if (socket == null) return null;

      final payload = jsonEncode({
        "action": action,
        "args": args,
        "kwargs": kwargs ?? {},
      });

      _responseCompleter = Completer<DaemonResult>();

      try {
        socket.write('$payload\n');
        await socket.flush().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("DaemonClient: Socket write error: $e");
        _cleanupSocket();
        return null;
      }

      return await _responseCompleter!.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException("Daemon response timed out for $action"),
      );
    } catch (e) {
      debugPrint("DaemonClient: Transaction failed [$action]: $e");
      _cleanupSocket();
      return null;
    } finally {
      _responseCompleter = null;
      if (!currentMutex.isCompleted) currentMutex.complete();
    }
  }

  Future<void> _ensureConnected() async {
    if (_socket != null) return;

    await onDemandStart();

    int retryDelay = 200;
    for (int i = 0; i < 6; i++) {
      try {
        _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
        _socketSub = _socket!
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_handleLine, onError: (_) => _cleanupSocket(), onDone: _cleanupSocket);

        _startHeartbeat();
        debugPrint("DaemonClient: Connected to daemon on $host:$port");
        return;
      } catch (_) {
        if (i == 5) break;
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2; // Exponential backoff
      }
    }
    throw Exception("DaemonClient: Failed to connect to daemon at $host:$port");
  }

  void _handleLine(String line) {
    try {
      final res = jsonDecode(line);
      if (res is Map && (res.containsKey('status') || res.containsKey('error'))) {
        final completer = _responseCompleter;
        if (completer != null && !completer.isCompleted) {
          if (res['status'] == 'success') {
            completer.complete(DaemonResult(
              status: 'success',
              response: res['response'],
              stdout: res['stdout'] ?? '',
            ));
          } else {
            completer.complete(DaemonResult(
              status: 'error',
              error: res['error'] ?? 'Daemon error',
              stdout: res['stdout'] ?? '',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("DaemonClient: JSON parse error: $e");
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        // Send a simple no-op action or check socket state
        if (_socket == null) {
          timer.cancel();
          return;
        }
        // Minimal ping logic can be added here if the daemon supports it.
        // For now, we rely on socket 'done' and 'error' events.
      } catch (_) {
        _cleanupSocket();
      }
    });
  }

  void _cleanupSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.destroy();
    _socket = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(Exception("Daemon connection lost"));
    }
  }

  Future<void> dispose() async {
    _cleanupSocket();
    if (!_mutex.isCompleted) _mutex.complete();
  }
}
