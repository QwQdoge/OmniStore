import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized registry for tracking and reaping subprocesses.
class ProcessRegistry {
  final Set<Process> _activeProcesses = {};
  Timer? _reaperTimer;

  ProcessRegistry() {
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _reaperTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _reapStale(),
      );
    }
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

  void add(Process process) {
    _activeProcesses.add(process);
    process.exitCode.then((_) => _activeProcesses.remove(process));
  }

  void remove(Process process) {
    _activeProcesses.remove(process);
  }

  Future<int?> _processGroupId(int processId) async {
    try {
      final result = await Process.run('ps', [
        '-o',
        'pgid=',
        '-p',
        '$processId',
      ]).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return null;
      return int.tryParse(result.stdout.toString().trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _signalDirectChildren(int processId, String signal) async {
    try {
      // Best-effort cleanup for helpers spawned by package managers. This is
      // deliberately scoped to children of the backend process; it never
      // signals OmniStore's own process group.
      await Process.run('pkill', [
        '-$signal',
        '-P',
        '$processId',
      ]).timeout(const Duration(seconds: 2));
    } catch (_) {
      // `pkill` may be unavailable or return non-zero when there are no
      // children. Either case is safe to ignore before killing the parent.
    }
  }

  /// Terminates a tracked process without ever signalling OmniStore's own
  /// process group. Escalates from TERM to KILL if necessary.
  Future<void> kill(Process? process) async {
    if (process == null) return;
    _activeProcesses.remove(process);
    final processId = process.pid;

    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final pgid = await _processGroupId(processId);

        // A process group is safe to signal only when the child is its group
        // leader (PGID == PID). The previous PGID != PID condition could target
        // the shared group containing the Flutter application itself.
        final ownsProcessGroup = pgid != null && pgid > 1 && pgid == processId;

        if (ownsProcessGroup) {
          try {
            await Process.run('kill', [
              '-TERM',
              '--',
              '-$pgid',
            ]).timeout(const Duration(seconds: 2));
          } catch (_) {
            process.kill(ProcessSignal.sigterm);
          }
        } else {
          await _signalDirectChildren(processId, 'TERM');
          try {
            process.kill(ProcessSignal.sigterm);
          } catch (_) {}
        }

        await Future.delayed(const Duration(milliseconds: 800));

        if (await _isProcessAlive(processId)) {
          if (ownsProcessGroup) {
            try {
              await Process.run('kill', [
                '-KILL',
                '--',
                '-$pgid',
              ]).timeout(const Duration(seconds: 2));
            } catch (_) {
              process.kill(ProcessSignal.sigkill);
            }
          } else {
            await _signalDirectChildren(processId, 'KILL');
            try {
              process.kill(ProcessSignal.sigkill);
            } catch (_) {}
          }
        }
      } else if (Platform.isWindows) {
        try {
          await Process.run('taskkill', [
            '/F',
            '/T',
            '/PID',
            '$processId',
          ]).timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint(
            "ProcessRegistry: Windows taskkill failed for PID $processId: $e",
          );
          process.kill(ProcessSignal.sigkill);
        }
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      debugPrint("ProcessRegistry: Failed to reap PID $processId: $e");
    } finally {
      // Direct-handle fail-safe. This affects only the tracked process, never a
      // process group.
      try {
        if (await _isProcessAlive(processId)) {
          process.kill(ProcessSignal.sigkill);
        }
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _reaperTimer?.cancel();
    _reaperTimer = null;
    final processes = List<Process>.from(_activeProcesses);
    _activeProcesses.clear();
    await Future.wait(processes.map((p) => kill(p)));
  }

  Future<bool> _isProcessAlive(int processId) async {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('kill', ['-0', '$processId']);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', [
          '/FI',
          'PID eq $processId',
          '/NH',
        ]);
        final output = result.stdout.toString();
        return result.exitCode == 0 && output.contains('$processId');
      }
    } catch (_) {}
    return false;
  }
}
