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
        onTimeout: () =>
            debugPrint("DaemonClient: Mutex bottlenecked for $action"),
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

      final completer = _responseCompleter;
      if (completer == null) return null;

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.completeError(
              TimeoutException("Daemon response timed out for $action"),
            );
          }
          throw TimeoutException("Daemon response timed out for $action");
        },
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

    // Murphy-proof: Trigger daemon start/liveness check before connection
    await onDemandStart();

    int retryDelay = 200;
    final int maxRetries = 10; // Increased retries for slow startup
    for (int i = 0; i < maxRetries; i++) {
      try {
        // Murphy-proof: Strict connection timeout
        _socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );

        _socketSub = _socket!
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleLine,
              onError: (e) {
                debugPrint("DaemonClient: Socket Error: $e");
                _cleanupSocket();
              },
              onDone: () {
                debugPrint("DaemonClient: Socket Done (Closed)");
                _cleanupSocket();
              },
            );

        _startHeartbeat();
        debugPrint("DaemonClient: Connected to daemon on $host:$port");
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          debugPrint("DaemonClient: Exhausted connection retries ($i): $e");
          break;
        }
        // Exponential backoff to avoid hammering while daemon is starting
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay = (retryDelay * 1.5).toInt().clamp(200, 2000);
      }
    }
    throw Exception(
      "DaemonClient: Failed to connect to daemon at $host:$port after $maxRetries attempts",
    );
  }

  void _handleLine(String line) {
    try {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) return;

      final dynamic res = jsonDecode(trimmedLine);
      if (res is Map) {
        final completer = _responseCompleter;
        if (completer != null && !completer.isCompleted) {
          if (res['status'] == 'success') {
            completer.complete(
              DaemonResult(
                status: 'success',
                response: res['response'],
                stdout: res['stdout']?.toString() ?? '',
              ),
            );
          } else if (res['status'] == 'error' || res.containsKey('error')) {
            completer.complete(
              DaemonResult(
                status: 'error',
                error: res['error']?.toString() ?? 'Daemon error',
                stdout: res['stdout']?.toString() ?? '',
              ),
            );
          } else {
            // Unexpected map structure
            debugPrint("DaemonClient: Received unexpected JSON map: $res");
          }
        }
      } else {
        debugPrint("DaemonClient: Received non-map JSON: $res");
      }
    } catch (e) {
      debugPrint("DaemonClient: JSON parse error on line: $line\nError: $e");
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (
      timer,
    ) async {
      if (_socket == null) {
        timer.cancel();
        return;
      }

      try {
        // Murphy-proof: Lightweight liveness ping to ensure daemon is still responsive.
        // We use a short timeout to prevent the heartbeat from hanging.
        final res = await send("run_check_env", [], timeout: const Duration(seconds: 5));
        if (res == null || res.status != 'success') {
          debugPrint("DaemonClient: Heartbeat failed. Reconnecting...");
          _cleanupSocket();
        }
      } catch (e) {
        debugPrint("DaemonClient: Heartbeat Exception: $e");
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

    final completer = _responseCompleter;
    _responseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception("Daemon connection lost"));
    }
  }

  Future<void> dispose() async {
    _cleanupSocket();
    if (!_mutex.isCompleted) _mutex.complete();
  }
}
