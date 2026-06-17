import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Murphy-proof: Centralized registry for tracking and reaping subprocesses.
/// Ensures that no zombie processes are left behind by utilizing process groups
/// and escalating termination signals.
class ProcessRegistry {
  final Set<Process> _activeProcesses = {};

  /// Registers a process for tracking.
  void add(Process process) {
    _activeProcesses.add(process);
    process.exitCode.then((_) => _activeProcesses.remove(process));
  }

  /// Removes a process from tracking.
  void remove(Process process) {
    _activeProcesses.remove(process);
  }

  /// Murphy-proof: Guaranteed process reaping using group-kill on Linux/macOS.
  /// Escalates from SIGTERM to SIGKILL to ensure termination.
  Future<void> kill(Process? process) async {
    if (process == null) return;
    _activeProcesses.remove(process);
    final pid = process.pid;

    try {
      if (Platform.isLinux || Platform.isMacOS) {
        // 1. Attempt SIGTERM on the entire process group (negative PID).
        try {
          await Process.run('kill', ['-TERM', '--', '-$pid']).timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 500));

        // 2. Escalation: Check if process is still alive and use SIGKILL if necessary.
        if (await _isProcessAlive(pid)) {
          try {
            await Process.run('kill', ['-KILL', '--', '-$pid']).timeout(
              const Duration(seconds: 2),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("ProcessRegistry: Group reap failed for PID $pid: $e");
    } finally {
      // 3. Final Fail-safe: Direct SIGKILL to the parent process handle.
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  /// Murphy-proof: Atomic reaping of all registered processes.
  Future<void> dispose() async {
    final processes = List<Process>.from(_activeProcesses);
    _activeProcesses.clear();
    for (final p in processes) {
      await kill(p);
    }
  }

  Future<bool> _isProcessAlive(int pid) async {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('kill', ['-0', '$pid']);
        return result.exitCode == 0;
      }
    } catch (_) {}
    return false;
  }
}
