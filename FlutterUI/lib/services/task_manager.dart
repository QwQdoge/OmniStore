import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/task_state.dart';
import 'backend_service.dart';
import 'update_service.dart';
import '../data/repositories/task_repository.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  final _taskStateController = StreamController<TaskState?>.broadcast();
  TaskState? _currentTask;
  Process? _activeProcess;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  // Murphy-proof: Lock to prevent concurrent task starts
  final _mutex = Completer<void>()..complete();

  Stream<TaskState?> get taskStateStream => _taskStateController.stream;
  TaskState? get currentTask => _currentTask;
  bool get isBusy => _currentTask != null;

  // Throttling mechanism
  DateTime _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _throttleDuration = Duration(milliseconds: 16); // ~60Hz

  void _updateState(TaskState? state) {
    _currentTask = state;

    final now = DateTime.now();
    if (state == null ||
        state.status == TaskStatus.success ||
        state.status == TaskStatus.failed ||
        now.difference(_lastUpdateTime) >= _throttleDuration) {
      _taskStateController.add(state);
      _lastUpdateTime = now;
    }
  }

  Future<bool> startTask({
    required String id,
    required String packageName,
    required String source,
    required String actionFlag, // "-I", "-R", "-U"
    String? url,
  }) async {
    // 状态互斥与防呆：防止连击导致并发冲突
    if (isBusy) return false;

    // Mutex lock to ensure atomic start sequence
    if (!_mutex.isCompleted) return false;

    _updateState(
      TaskState(
        id: id,
        status: TaskStatus.pending,
        progress: -1.0,
        messageKey: "taskInitializing",
        packageName: packageName,
        source: source,
      ),
    );

    BackendService.clearLogs();
    BackendService.isDownloading.value = true;
    BackendService.globalStatus.value = ""; 

    if (kIsWeb) {
      try {
        final stream = TaskRepository().executeAction(actionFlag, packageName, source, url: url);
        await for (final line in stream) {
          _handleOutput(line);
        }
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.success,
            progress: 1.0,
            messageKey: "taskSuccess",
            speed: "",
          ),
        );
        BackendService.isDownloading.value = false;
        
        UpdateService().showCompletionNotification(packageName, true);
        
        Future.delayed(const Duration(seconds: 5), () {
          if (_currentTask?.status == TaskStatus.success ||
              _currentTask?.status == TaskStatus.failed) {
            _updateState(null);
          }
        });
        return true;
      } catch (e) {
        debugPrint("Web TaskManager execution exception: $e");
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.failed,
            messageKey: "taskError",
            messageArgs: {"error": e.toString()},
            speed: "",
          ),
        );
        BackendService.isDownloading.value = false;
        return false;
      }
    }

    try {
      final List<String> args = [
        BackendService.scriptPath,
        actionFlag,
        packageName,
        "--source",
        source,
        "--json",
        if (url != null && url.isNotEmpty) ...["--url", url],
      ];

      _activeProcess = await Process.start(
        BackendService.venvPython,
        args,
        workingDirectory: BackendService.workingDir,
        runInShell: Platform.isWindows,
      );

      // Murphy-proof: Ensure subscriptions are managed and disposed
      _stdoutSubscription = _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleOutput,
        onError: (e) => debugPrint("TaskManager Stdout Error: $e"),
        cancelOnError: false,
      );

      _stderrSubscription = _activeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (data) {
          debugPrint("TaskManager Stderr: $data");
          BackendService.addLog("stderr: $data");
        },
        onError: (e) => debugPrint("TaskManager Stderr Error: $e"),
        cancelOnError: false,
      );

      final exitCode = await _activeProcess!.exitCode.timeout(
        const Duration(hours: 2),
        onTimeout: () {
          debugPrint("TaskManager: Process timed out after 2 hours.");
          // Attempt graceful kill first then force
          if (_activeProcess != null) {
            _activeProcess!.kill(ProcessSignal.sigterm);
            Future.delayed(const Duration(seconds: 2), () => _activeProcess?.kill(ProcessSignal.sigkill));
          }
          return -1;
        },
      );
      final success = exitCode == 0;

      if (success) {
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.success,
            progress: 1.0,
            messageKey: "taskSuccess",
            speed: "",
          ),
        );
      } else {
        if (_currentTask?.status != TaskStatus.failed) {
          _updateState(
            _currentTask?.copyWith(
              status: TaskStatus.failed,
              messageKey: "taskFailedWithCode",
              messageArgs: {"code": exitCode},
              speed: "",
            ),
          );
        }
      }

      if (_currentTask != null) {
        UpdateService().showCompletionNotification(
          _currentTask!.packageName ?? "OmniStore",
          success,
        );
      }

      return success;
    } catch (e) {
      debugPrint("TaskManager execution exception: $e");
      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskError",
          messageArgs: {"error": e.toString()},
          speed: "",
        ),
      );
    } finally {
      _stdoutSubscription?.cancel();
      _stderrSubscription?.cancel();
      _stdoutSubscription = null;
      _stderrSubscription = null;
      _activeProcess = null;
      BackendService.isDownloading.value = false;

      if (_currentTask != null &&
          _currentTask!.status != TaskStatus.success &&
          _currentTask!.status != TaskStatus.failed) {
        _updateState(_currentTask!.copyWith(status: TaskStatus.failed));
      }

      Future.delayed(const Duration(seconds: 5), () {
        if (_currentTask?.status == TaskStatus.success ||
            _currentTask?.status == TaskStatus.failed) {
          _updateState(null);
        }
      });
    }

    return false;
  }

  void _handleOutput(String line) {
    if (line.isEmpty) return;

    String cleanLine = line.trim();
    String? logMessage;

    if (cleanLine.startsWith("[CALLBACK]")) {
      try {
        final data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
        logMessage = data['message'] ?? data['log'] ?? "";
      } catch (_) {}
    } else if (cleanLine.startsWith("{")) {
      try {
        final data = jsonDecode(cleanLine);
        logMessage = data['message'] ?? data['log'] ?? "";
      } catch (_) {}
    } else {
      logMessage = cleanLine;
    }

    if (logMessage != null && logMessage.isNotEmpty) {
      if (logMessage.startsWith("[PROGRESS]")) {
        final parts = logMessage.split(" ");
        if (parts.length > 1) {
          final p = double.tryParse(parts[1]);
          if (p != null) {
            final progress = p / 100.0;
            _updateState(
              _currentTask?.copyWith(
                progress: progress,
                status: TaskStatus.downloading,
              ),
            );

            UpdateService().showProgressNotification(
              _currentTask?.packageName ?? "OmniStore",
              progress,
            );
          }
        }
      } else if (logMessage.startsWith("[SPEED]")) {
        final s = logMessage.replaceFirst("[SPEED] ", "");
        _updateState(_currentTask?.copyWith(speed: s));
      } else if (logMessage.startsWith("[STAGE]")) {
        final stage = logMessage.replaceFirst("[STAGE] ", "");
        _updateState(_currentTask?.copyWith(stage: stage));
      } else if (logMessage.startsWith("[INFO]")) {
        final msg = logMessage.replaceFirst("[INFO] ", "");
        BackendService.addLog(logMessage);

        TaskStatus status = _currentTask?.status ?? TaskStatus.pending;
        double? progress = _currentTask?.progress;

        if (msg.toLowerCase().contains("installing") ||
            msg.toLowerCase().contains("verifying") ||
            msg.toLowerCase().contains("building") ||
            msg.toLowerCase().contains("cleaning")) {
          status = TaskStatus.installing;
          progress = -1.0;
        } else if (msg.toLowerCase().contains("downloading")) {
          status = TaskStatus.downloading;
        }

        _updateState(
          _currentTask?.copyWith(
            message: msg,
            status: status,
            progress: progress,
          ),
        );
        BackendService.globalStatus.value = msg;
      } else if (logMessage.startsWith("[ERROR]")) {
        BackendService.addLog(logMessage);
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.failed,
            message: logMessage.replaceFirst("[ERROR] ", ""),
          ),
        );
      } else {
        BackendService.addLog(logMessage);
      }
    }
  }

  Future<void> cancelTask() async {
    if (kIsWeb) {
      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskCancelledByUser",
          speed: "",
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        _updateState(null);
      });
      return;
    }

    if (_activeProcess != null) {
      final pid = _activeProcess!.pid;
      debugPrint("TaskManager: User requested cancellation for PID $pid");

      try {
        if (Platform.isLinux || Platform.isMacOS) {
          await Process.run('kill', ['-TERM', '-$pid']);
          await Process.run('pkill', ['-P', pid.toString()]);
        }
        _activeProcess?.kill(ProcessSignal.sigterm);
      } catch (e) {
        debugPrint("TaskManager cancellation error: $e");
        _activeProcess?.kill(ProcessSignal.sigterm);
      }

      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskCancelledByUser",
          speed: "",
        ),
      );

    Future.delayed(const Duration(seconds: 3), () async {
      if (_activeProcess != null && _activeProcess!.pid == pid) {
          debugPrint("TaskManager: Force killing stalled process $pid");
          try {
            if (Platform.isLinux || Platform.isMacOS) {
            await Process.run('kill', ['-KILL', '--', '-$pid']);
            }
            _activeProcess?.kill(ProcessSignal.sigkill);
          } catch (_) {}
          _activeProcess = null;
        }
      });
    } else if (_currentTask != null) {
      _updateState(null);
    }
  }

  void clearTask() {
    _updateState(null);
  }

  void startMockTask() async {
    if (isBusy) return;

    _updateState(
      TaskState(
        id: "mock-task",
        status: TaskStatus.downloading,
        progress: 0.0,
        message: "Simulating high-frequency updates...",
      ),
    );

    for (int i = 0; i <= 100; i++) {
      if (!isBusy) break;
      await Future.delayed(const Duration(milliseconds: 5));
      _updateState(
        _currentTask?.copyWith(
          progress: i / 100.0,
          speed: "${(10 + i % 5).toStringAsFixed(1)} MB/s",
          message: "Mock downloading part $i...",
        ),
      );
    }

    if (isBusy) {
      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.installing,
          progress: -1.0,
          message: "Mock installing...",
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.success,
          progress: 1.0,
          message: "Mock task finished",
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        _updateState(null);
      });
    }
  }
}
