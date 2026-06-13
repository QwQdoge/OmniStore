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
    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;
    await previousMutex.future;

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
      late StreamSubscription sub;

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
      success = await completer.future;
      _subscriptions.remove(sub);

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

      if (!currentMutex.isCompleted) currentMutex.complete();
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
    // 1. Cancel all active subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

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

    // 2. Murphy-proof: Use unified cancellation through BackendService
    await BackendService.cancelCurrentTask();

    _updateState(
      _currentTask?.copyWith(
        status: TaskStatus.failed,
        messageKey: "taskCancelledByUser",
        speed: "",
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (_currentTask?.status == TaskStatus.failed) {
        _updateState(null);
      }
    });
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
