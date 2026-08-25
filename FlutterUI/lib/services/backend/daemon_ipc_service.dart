import 'dart:async';
import 'package:flutter/foundation.dart';
import 'daemon_client.dart';

/// Murphy-proof: Specialized service for Daemon IPC communication.
class DaemonIpcService {
  final DaemonClient _client;

  int _failureStreak = 0;
  static const int _failureThreshold = 3;
  bool _isCircuitBreakerTripped = false;
  bool _halfOpenProbeInFlight = false;
  DateTime? _retryAfter;

  DaemonIpcService(this._client);

  Future<DaemonResult?> send(
    String action,
    List<dynamic> args, {
    Map<String, dynamic>? kwargs,
  }) async {
    // Circuit Breaker Logic
    if (_isCircuitBreakerTripped) {
      final now = DateTime.now();
      if (_retryAfter != null && now.isBefore(_retryAfter!)) {
        debugPrint("DaemonIpcService: Circuit Breaker ACTIVE. Bypassing.");
        return null;
      }
      if (_halfOpenProbeInFlight) return null;
      _halfOpenProbeInFlight = true;
    }

    try {
      final res = await _client
          .send(action, args, kwargs: kwargs)
          .timeout(const Duration(seconds: 15));
      if (res != null) {
        _failureStreak = 0;
        _isCircuitBreakerTripped = false;
        _retryAfter = null;
        return res;
      }
      throw Exception("Daemon returned null");
    } catch (e) {
      _failureStreak++;
      debugPrint("DaemonIpcService Error (Streak: $_failureStreak): $e");
      if (_failureStreak >= _failureThreshold) {
        _isCircuitBreakerTripped = true;
        final exponent = (_failureStreak - _failureThreshold).clamp(0, 4);
        final retrySeconds = (5 * (1 << exponent)).clamp(5, 60);
        _retryAfter = DateTime.now().add(Duration(seconds: retrySeconds));
      }
      return null;
    } finally {
      _halfOpenProbeInFlight = false;
    }
  }

  Future<void> shutdown() async {
    try {
      await _client.shutdown(startIfNeeded: false);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _client.dispose();
  }
}
