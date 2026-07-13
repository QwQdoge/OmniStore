import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Murphy-proof: Centralized registry for tracking and reaping subprocesses.
/// Ensures that no zombie processes are left behind by utilizing process groups
/// and escalating termination signals.
class ProcessRegistry {
  final Set<Process> _activeProcesses = {};
  Timer? _reaperTimer;

  ProcessRegistry() {
    // Murphy-proof: Periodic reaper to clean up stale process handles
    _reaperTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _reapStale(),
    );
  }

  void _reapStale() async {
    final toRemove = <Process>[];
    for (final proc in _activeProcesses) {
      if (await _isProcessAlive(proc.pid) == false) {
        toRemove.add(proc);
      }
    }
    for (final proc in toRemove) {
      _activeProcesses.remove(proc);
    }
  }

  /// Registers a process for tracking.
  void add(Process process) {
    _activeProcesses.add(process);
    process.exitCode.then((_) => _activeProcesses.remove(process));
  }

  /// Removes a process from tracking.
  void remove(Process process) {
    _activeProcesses.remove(process);
  }

  /// Murphy-proof: Guaranteed process reaping with tree-killing capability.
  /// Escalates from SIGTERM to SIGKILL to ensure termination.
  Future<void> kill(Process? process) async {
    if (process == null) return;
    _activeProcesses.remove(process);
    final pid = process.pid;

    try {
      if (Platform.isLinux || Platform.isMacOS) {
        // Murphy-proof: Verify process group ID before group-killing to avoid hitting self.
        bool groupKillSuccess = false;
        try {
          final pgidRes = await Process.run('ps', [
            '-o',
            'pgid=',
            '-p',
            '$pid',
          ]);
          final pgid = int.tryParse(pgidRes.stdout.toString().trim());

          if (pgid != null && pgid > 1 && pgid != pid) {
             // 1. Attempt SIGTERM on the entire process group
            await Process.run('kill', [
              '-TERM',
              '--',
              '-$pgid',
            ]).timeout(const Duration(seconds: 2));
            groupKillSuccess = true;
          }
        } catch (_) {}

        if (!groupKillSuccess) {
          try {
            process.kill(ProcessSignal.sigterm);
          } catch (_) {}
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // 2. Escalation: SIGKILL
        if (await _isProcessAlive(pid)) {
          try {
            final pgidRes = await Process.run('ps', [
              '-o',
              'pgid=',
              '-p',
              '$pid',
            ]);
            final pgid = int.tryParse(pgidRes.stdout.toString().trim());
            if (pgid != null && pgid > 1 && pgid != pid) {
              await Process.run('kill', [
                '-KILL',
                '--',
                '-$pgid',
              ]).timeout(const Duration(seconds: 2));
            } else {
              process.kill(ProcessSignal.sigkill);
            }
          } catch (_) {
            process.kill(ProcessSignal.sigkill);
          }
        }
      } else if (Platform.isWindows) {
        // Murphy-proof: Use taskkill /F /T /PID to kill the process tree on Windows.
        // /T ensures children are also terminated, /F forces termination.
        try {
          final res = await Process.run('taskkill', ['/F', '/T', '/PID', '$pid'])
              .timeout(const Duration(seconds: 5));
          if (res.exitCode != 0) {
             debugPrint("ProcessRegistry: taskkill exit code ${res.exitCode} for PID $pid");
          }
        } catch (e) {
          debugPrint("ProcessRegistry: Windows taskkill failed for PID $pid: $e");
        }
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      debugPrint("ProcessRegistry: Group reap failed for PID $pid: $e");
    } finally {
      // 3. Final Fail-safe: Direct SIGKILL to the parent process handle if still tracked.
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  /// Murphy-proof: Atomic reaping of all registered processes.
  Future<void> dispose() async {
    _reaperTimer?.cancel();
    _reaperTimer = null;
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
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', [
          '/FI',
          'PID eq $pid',
          '/NH',
        ]);
        final output = result.stdout.toString();
        return result.exitCode == 0 && output.contains('$pid');
      }
    } catch (_) {}
    return false;
  }
}
