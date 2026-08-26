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

  factory DaemonResult.fromWire(Map<String, dynamic> wire) {
    Map<String, dynamic> payload = wire;
    for (var depth = 0; depth < 3; depth++) {
      final nested = payload['response'];
      if (payload['status'] == 'success' &&
          nested is Map<String, dynamic> &&
          (nested['status'] == 'success' || nested['status'] == 'error')) {
        payload = nested;
        continue;
      }
      break;
    }
    return DaemonResult(
      status: payload['status']?.toString() ?? 'error',
      response: payload['response'],
      stdout: payload['stdout']?.toString() ?? '',
      error: payload['error']?.toString(),
    );
  }
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
  bool _heartbeatInFlight = false;
  Completer<void> _mutex = Completer<void>()..complete();

  bool get isConnected => _socket != null;

  /// Murphy-proof: Serialized communication with the daemon.
  /// Ensures that only one transaction happens at a time and handles timeouts.
  Future<DaemonResult?> send(
    String action,
    List<dynamic> args, {
    Map<String, dynamic>? kwargs,
    Duration timeout = const Duration(seconds: 60),
    bool startIfNeeded = true,
  }) async {
    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;

    var acquired = false;
    try {
      await previousMutex.future.timeout(
        Duration(seconds: timeout.inSeconds + 5),
        onTimeout: () => throw TimeoutException(
          "Daemon transaction queue timed out for $action",
        ),
      );
      acquired = true;
    } catch (error) {
      debugPrint("DaemonClient: Refusing overlapping transaction: $error");
      if (!currentMutex.isCompleted) currentMutex.complete();
      return null;
    }

    try {
      await _ensureConnected(startIfNeeded: startIfNeeded);
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
      if (acquired && !currentMutex.isCompleted) currentMutex.complete();
    }
  }

  Future<void> _ensureConnected({required bool startIfNeeded}) async {
    if (_socket != null) return;

    // Murphy-proof: Trigger daemon start/liveness check before connection
    try {
      if (startIfNeeded) await onDemandStart();
    } catch (e) {
      debugPrint("DaemonClient: Failed to trigger daemon start: $e");
    }

    int retryDelay = 300;
    final int maxRetries = startIfNeeded ? 12 : 1;
    for (int i = 0; i < maxRetries; i++) {
      try {
        // Murphy-proof: Strict connection timeout to prevent hanging the UI thread
        _socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );

        _socketSub = _socket!
            .cast<List<int>>()
            .transform(
              const Utf8Decoder(allowMalformed: true),
            ) // Be resilient to encoding issues
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
              cancelOnError: true,
            );

        _startHeartbeat();
        debugPrint("DaemonClient: Connected to daemon on $host:$port");
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          debugPrint("DaemonClient: Exhausted connection retries ($i): $e");
          break;
        }
        // Murphy-proof: Progressive exponential backoff
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay = (retryDelay * 1.6).toInt().clamp(300, 3000);
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
      if (res is Map<String, dynamic>) {
        final completer = _responseCompleter;
        if (completer != null && !completer.isCompleted) {
          final result = DaemonResult.fromWire(res);
          if (result.status == 'success' || result.status == 'error') {
            completer.complete(result);
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
      if (_heartbeatInFlight) return;
      _heartbeatInFlight = true;

      try {
        // Murphy-proof: Lightweight liveness ping to ensure daemon is still responsive.
        // We use a short timeout to prevent the heartbeat from hanging.
        final res = await send("ping", [], timeout: const Duration(seconds: 5));
        if (res == null || res.status != 'success') {
          debugPrint("DaemonClient: Heartbeat failed. Reconnecting...");
          _cleanupSocket();
        }
      } catch (e) {
        debugPrint("DaemonClient: Heartbeat Exception: $e");
        _cleanupSocket();
      } finally {
        _heartbeatInFlight = false;
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

  Future<void> shutdown({bool startIfNeeded = false}) async {
    try {
      await send(
        'shutdown',
        const [],
        timeout: const Duration(seconds: 3),
        startIfNeeded: startIfNeeded,
      );
    } finally {
      _cleanupSocket();
    }
  }
}
