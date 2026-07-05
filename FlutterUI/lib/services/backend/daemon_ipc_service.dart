import 'dart:async';
import 'package:flutter/foundation.dart';
import 'daemon_client.dart';

/// Murphy-proof: Specialized service for Daemon IPC communication.
class DaemonIpcService {
  final DaemonClient _client;

  int _failureStreak = 0;
  static const int _failureThreshold = 3;
  DateTime? _lastFailureTime;
  bool _isCircuitBreakerTripped = false;

  DaemonIpcService(this._client);

  Future<DaemonResult?> send(String action, List<dynamic> args, {Map<String, dynamic>? kwargs}) async {
    // Circuit Breaker Logic
    if (_isCircuitBreakerTripped) {
      final now = DateTime.now();
      if (_lastFailureTime != null && now.difference(_lastFailureTime!) < const Duration(minutes: 2)) {
        debugPrint("DaemonIpcService: Circuit Breaker ACTIVE. Bypassing.");
        return null;
      }
      _isCircuitBreakerTripped = false;
      _failureStreak = 0;
    }

    try {
      final res = await _client.send(action, args, kwargs: kwargs).timeout(const Duration(seconds: 15));
      if (res != null) {
        _failureStreak = 0;
        return res;
      }
      throw Exception("Daemon returned null");
    } catch (e) {
      _failureStreak++;
      _lastFailureTime = DateTime.now();
      debugPrint("DaemonIpcService Error (Streak: $_failureStreak): $e");
      if (_failureStreak >= _failureThreshold) {
        _isCircuitBreakerTripped = true;
      }
      return null;
    }
  }

  Future<void> shutdown() async {
    try {
      await _client.send("shutdown", []);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _client.dispose();
  }
}
