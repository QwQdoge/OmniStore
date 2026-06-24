import 'dart:async';
import 'dart:convert';
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

  // Murphy-proof: Lock to prevent concurrent task starts
  Completer<void> _mutex = Completer<void>()..complete();

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

  // Murphy-proof: Use a dedicated set to track active subscriptions to prevent leaks
  final Set<StreamSubscription> _subscriptions = {};

  /// Murphy-proof: Starts a task with strict atomic locking and subscription tracking.
  /// Prevents race conditions from "double-clicks" or rapid task transitions.
  Future<bool> startTask({
    required String id,
    required String packageName,
    required String source,
    required String actionFlag, // "-I", "-R", "-U"
    String? url,
  }) async {
    // Murphy-proof: Input validation
    if (id.isEmpty || packageName.isEmpty || source.isEmpty) return false;
    if (!["-I", "-R", "-U"].contains(actionFlag)) return false;

    // Fail-safe check: Do not even attempt to acquire lock if already busy
    if (isBusy) return false;

    // Mutex chain: Ensures only one task initialization sequence runs at a time
    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;

    try {
      await previousMutex.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException("TaskManager: Could not acquire task lock."),
      );
    } catch (e) {
      debugPrint("TaskManager Mutex Error: $e");
      if (!currentMutex.isCompleted) currentMutex.complete();
      return false;
    }

    // Re-check busy status after lock acquisition
    if (isBusy) {
      if (!currentMutex.isCompleted) currentMutex.complete();
      return false;
    }

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

    String actionTitle = "正在处理";
    if (actionFlag == "-I") actionTitle = "开始安装";
    if (actionFlag == "-R") actionTitle = "开始卸载";
    if (actionFlag == "-U") actionTitle = "开始更新";
    UpdateService().showSimpleNotification(
      "$actionTitle: $packageName",
      "源: $source。任务已启动，请稍候...",
    );

    try {
      final success = await _runTaskInternal(
        packageName: packageName,
        source: source,
        actionFlag: actionFlag,
        url: url,
      );
      return success;
    } catch (e) {
      debugPrint("TaskManager.startTask Fatal: $e");
      _updateState(
        _currentTask?.copyWith(
          status: TaskStatus.failed,
          message: "Critical task failure: $e",
        ),
      );
      return false;
    } finally {
      // Murphy-proof: Critical lock release to ensure the next task can start
      if (!currentMutex.isCompleted) currentMutex.complete();
    }
  }

  /// Murphy-proof: Core task execution logic wrapped in try-finally to ensure state reset.
  Future<bool> _runTaskInternal({
    required String packageName,
    required String source,
    required String actionFlag,
    String? url,
  }) async {
    try {
      if (kIsWeb) {
        try {
          final stream = TaskRepository().executeAction(
            actionFlag,
            packageName,
            source,
            url: url,
          );
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
          _handleError(e);
          BackendService.isDownloading.value = false;
          UpdateService().showCompletionNotification(packageName, false);
          return false;
        }
      }

      try {
        // Murphy-proof: Use unified _safeStream for consistent process lifecycle and cleanup
        final stream = BackendService.instance.executeAction(
          actionFlag,
          packageName,
          source,
          url: url,
        );

        bool success = true;
        final completer = Completer<bool>();
        StreamSubscription? sub;

        try {
          sub = stream.listen(
            (line) {
              _handleOutput(line);
              if (line.toLowerCase().contains("error") ||
                  line.contains("[ERROR]")) {
                success = false;
              }
            },
            onError: (e) {
              debugPrint("TaskManager Stream Error: $e");
              success = false;
              if (!completer.isCompleted) completer.complete(false);
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete(success);
            },
            cancelOnError: false,
          );

          _subscriptions.add(sub);
          success = await completer.future.timeout(
            const Duration(minutes: 60),
            onTimeout: () => throw TimeoutException("Task execution exceeded 60m safety limit"),
          );
        } finally {
          if (sub != null) {
            _subscriptions.remove(sub);
            await sub.cancel();
          }
        }

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
                messageKey: "taskFailed",
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
        _handleError(e);
      }
    } finally {
      // Murphy-proof: Absolute state reset to prevent the UI from being "stuck" in busy mode.
      BackendService.isDownloading.value = false;

      if (_currentTask != null &&
          _currentTask!.status != TaskStatus.success &&
          _currentTask!.status != TaskStatus.failed) {
        _updateState(_currentTask!.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskTerminatedUnexpectedly",
        ));
      }

      // Murphy-proof: Capture task ID to ensure we only clear the specific task that finished
      final finishedTaskId = _currentTask?.id;
      // Auto-clear success/failed status after a delay to revert UI to neutral state
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentTask?.id == finishedTaskId &&
            (_currentTask?.status == TaskStatus.success ||
                _currentTask?.status == TaskStatus.failed)) {
          _updateState(null);
        }
      });
    }

    return false;
  }

  /// Murphy-proof: Strict state-machine output handler.
  /// Uses structured JSON callbacks where possible and provides safe fallbacks
  /// for unstructured log lines to prevent UI state corruption.
  void _handleOutput(String line) {
    if (line.isEmpty) return;
    final cleanLine = line.trim();

    String? logMessage;

    try {
      if (cleanLine.startsWith("[CALLBACK]")) {
        try {
          final data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
          _processStructuredCallback(data);
          return;
        } catch (_) {}
      } else if (cleanLine.startsWith("{")) {
        try {
          final data = jsonDecode(cleanLine);
          _processStructuredCallback(data);
          return;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Murphy-proof: Output parsing failed: $e");
    }

    if (logMessage != null && logMessage.isNotEmpty) {
      try {
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
          // Unstructured fallback
          BackendService.addLog(cleanLine);
        }
      } catch (e) {
        debugPrint(
          "Murphy-proof Warning: TaskManager failed to parse line: $e\nLine: $line",
        );
        BackendService.addLog("Raw: $cleanLine");
      }
    }
  }

  void _processStructuredCallback(Map<String, dynamic> data) {
    final String? log = data['log'] ?? data['message'];
    final String? type = data['type']?.toString().toUpperCase();

    if (log != null) {
      if (type == 'ERROR') {
        _processError(log);
      } else {
        _processInfo(log);
      }
    }
  }

  /// Murphy-proof: Hardened cancellation logic that ensures absolute resource
  /// cleanup even if individual steps fail.
  /// Murphy-proof: Resource cleanup.
  Future<void> dispose() async {
    final subs = List<StreamSubscription>.from(_subscriptions);
    _subscriptions.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
    await _taskStateController.close();
  }

  Future<void> cancelTask() async {
    try {
      // Murphy-proof: Capture current task ID for idempotent clearing
      final cancelledTaskId = _currentTask?.id;

      // 1. Cancel all active subscriptions to stop UI updates and stream processing
      final subs = List<StreamSubscription>.from(_subscriptions);
      _subscriptions.clear();
      for (final sub in subs) {
        try {
          await sub.cancel();
        } catch (e) {
          debugPrint("Murphy-proof Warning: Failed to cancel subscription: $e");
        }
      }

      if (kIsWeb) {
        _updateState(_currentTask?.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskCancelledByUser",
          speed: "",
        ));
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentTask?.id == cancelledTaskId) _updateState(null);
        });
        return;
      }

      // 2. Deep Reaping: Signal BackendService to kill the underlying process
      try {
        await BackendService.cancelCurrentTask().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              debugPrint("BackendService.cancelCurrentTask timed out"),
        );
      } catch (e) {
        debugPrint("Murphy-proof Error: Process cancellation failed: $e");
      }

      if (_currentTask?.id == cancelledTaskId) {
        _updateState(_currentTask?.copyWith(
          status: TaskStatus.failed,
          messageKey: "taskCancelledByUser",
          speed: "",
        ));
      }
    } catch (e) {
      debugPrint("TaskManager.cancelTask Fatal Exception: $e");
    } finally {
      final cancelledTaskId = _currentTask?.id;
      // Ensure the UI state eventually resets
      Future.delayed(const Duration(seconds: 3), () {
        if (_currentTask?.id == cancelledTaskId &&
            _currentTask?.status == TaskStatus.failed) {
          _updateState(null);
        }
      });
    }
  }

  void _handleError(dynamic e) {
    debugPrint("TaskManager execution exception: $e");
    _updateState(
      _currentTask?.copyWith(
        status: TaskStatus.failed,
        messageKey: "taskError",
        messageArgs: {"error": e.toString()},
        speed: "",
      ),
    );
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
