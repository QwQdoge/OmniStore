import 'dart:async';
import 'package:flutter/foundation.dart';

/// Murphy-proof: A FIFO execution queue for asynchronous tasks.
/// Ensures that tasks are executed in order and prevents concurrent
/// access to sensitive backend resources.
class ExecutionQueue {
  Completer<void> _mutex = Completer<void>()..complete();

  /// Executes a task within the queue.
  /// Murphy-proof: Ensures the queue remains functional even if a task fails or times out.
  Future<T> run<T>(
    Future<T> Function() task, {
    Duration? timeout,
    String? label,
  }) async {
    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;

    try {
      // Wait for the previous task to complete, with a safety timeout
      // to prevent a single hung task from blocking the entire app forever.
      await previousMutex.future.timeout(
        timeout ?? const Duration(minutes: 5),
        onTimeout: () {
          debugPrint("ExecutionQueue: Safety timeout reached for ${label ?? 'unlabeled task'}. Forcing next task.");
        },
      );
    } catch (e) {
      debugPrint("ExecutionQueue: Previous task failed or timed out: $e");
    }

    try {
      if (timeout != null) {
        return await task().timeout(timeout);
      } else {
        return await task();
      }
    } finally {
      if (!currentMutex.isCompleted) currentMutex.complete();
    }
  }

  /// Murphy-proof: Resets the queue state.
  void reset() {
    if (!_mutex.isCompleted) _mutex.complete();
    _mutex = Completer<void>()..complete();
  }
}
