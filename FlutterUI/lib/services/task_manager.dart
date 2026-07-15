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
  DateTime _lastLogTime = DateTime.now();
  Timer? _staleTaskTimer;

  void _updateState(TaskState? state) {
    _currentTask = state;
    _lastLogTime = DateTime.now();

    final now = DateTime.now();
    if (state == null ||
        state.status == TaskStatus.success ||
        state.status == TaskStatus.failed ||
        now.difference(_lastUpdateTime) >= _throttleDuration) {
      _taskStateController.add(state);
      _lastUpdateTime = now;
    }

    if (state != null &&
        (state.status == TaskStatus.downloading ||
            state.status == TaskStatus.installing ||
            state.status == TaskStatus.pending)) {
      _startStaleCheck();
    } else {
      _staleTaskTimer?.cancel();
    }
  }

  void _startStaleCheck() {
    _staleTaskTimer?.cancel();
    // Murphy-proof: Aggressive stale check (10 mins idle).
    _staleTaskTimer = Timer(const Duration(minutes: 10), () async {
      if (isBusy) {
        final now = DateTime.now();
        final idleTime = now.difference(_lastLogTime);
        if (idleTime >= const Duration(minutes: 10)) {
          debugPrint(
            "Murphy-proof: Stale task detected (Idle for ${idleTime.inMinutes}m). Forcing cleanup.",
          );
          await cancelTask();
        } else {
          _startStaleCheck();
        }
      }
    });
  }

  // Murphy-proof: Track active subscriptions to prevent leaks
  final Set<StreamSubscription> _subscriptions = {};

  Future<bool> startTask({
    required String id,
    required String packageName,
    required String source,
    required String actionFlag,
    String? url,
  }) async {
    if (isBusy) return false;

    final previousMutex = _mutex;
    final currentMutex = Completer<void>();
    _mutex = currentMutex;

    try {
      await previousMutex.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException("TaskManager: Could not acquire task lock."),
      );
    } catch (e) {
      debugPrint("TaskManager Mutex Error: $e");
      if (!currentMutex.isCompleted) currentMutex.complete();
      return false;
    }

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
      if (!currentMutex.isCompleted) currentMutex.complete();
    }
  }

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
        final stream = BackendService.instance.executeAction(
          actionFlag,
          packageName,
          source,
          url: url,
        );

        bool success = true;
        StreamSubscription? sub;

        try {
          final completer = Completer<bool>();
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
            onTimeout: () {
              debugPrint("Murphy-proof: Task timed out. Forcing cleanup.");
              return false;
            },
          );
        } finally {
          if (sub != null) {
            await sub.cancel();
            _subscriptions.remove(sub);
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
    } finally {
      BackendService.isDownloading.value = false;

      if (_currentTask != null &&
          _currentTask!.status != TaskStatus.success &&
          _currentTask!.status != TaskStatus.failed) {
        _updateState(
          _currentTask!.copyWith(
            status: TaskStatus.failed,
            messageKey: "taskTerminatedUnexpectedly",
          ),
        );
      }

      final finishedTaskId = _currentTask?.id;
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

  void _handleOutput(String line) {
    if (line.isEmpty) return;
    final cleanLine = line.trim();

    try {
      if (cleanLine.startsWith("[CALLBACK]")) {
        final data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
        _processStructuredCallback(data);
      } else if (cleanLine.startsWith("{")) {
        final data = jsonDecode(cleanLine);
        _processStructuredCallback(data);
      } else {
        _processLegacyLine(cleanLine);
      }
    } catch (e) {
      debugPrint("Murphy-proof Warning: Output parsing error: $e");
      BackendService.addLog("Raw: $cleanLine");
    }
  }

  void _processStructuredCallback(Map<String, dynamic> data) {
    final String? msg = data['message'] ?? data['log'];
    final String? type = data['type']?.toString().toUpperCase();

    if (msg != null) {
      if (type == 'ERROR' || msg.startsWith("[ERROR]")) {
        _processError(msg.replaceFirst("[ERROR] ", ""));
      } else if (msg.startsWith("[PROGRESS]")) {
        _processProgress(msg.replaceFirst("[PROGRESS] ", ""));
      } else if (msg.startsWith("[SPEED]")) {
        _updateState(
          _currentTask?.copyWith(speed: msg.replaceFirst("[SPEED] ", "")),
        );
      } else if (msg.startsWith("[STAGE]")) {
        _updateState(
          _currentTask?.copyWith(stage: msg.replaceFirst("[STAGE] ", "")),
        );
      } else {
        _processInfo(msg.replaceFirst("[INFO] ", ""));
      }
    }

    if (data.containsKey('progress')) {
      _processProgress(data['progress'].toString());
    }
  }

  void _processLegacyLine(String line) {
    if (line.startsWith("[PROGRESS]")) {
      _processProgress(line.replaceFirst("[PROGRESS] ", ""));
    } else if (line.startsWith("[SPEED]")) {
      _updateState(
        _currentTask?.copyWith(speed: line.replaceFirst("[SPEED] ", "")),
      );
    } else if (line.startsWith("[INFO]")) {
      _processInfo(line.replaceFirst("[INFO] ", ""));
    } else if (line.startsWith("[ERROR]")) {
      _processError(line.replaceFirst("[ERROR] ", ""));
    } else {
      BackendService.addLog(line);
    }
  }

  void _processProgress(String value) {
    final parts = value.split(" ");
    final p = double.tryParse(parts[0]);
    if (p == null) return;

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

  void _processInfo(String msg) {
    BackendService.addLog("[INFO] $msg");
    TaskStatus status = _currentTask?.status ?? TaskStatus.pending;
    double? progress = _currentTask?.progress;

    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains("installing") ||
        lowerMsg.contains("verifying") ||
        lowerMsg.contains("building") ||
        lowerMsg.contains("cleaning") ||
        lowerMsg.contains("extracting")) {
      status = TaskStatus.installing;
      progress = -1.0;
    } else if (lowerMsg.contains("downloading")) {
      status = TaskStatus.downloading;
    }

    _updateState(
      _currentTask?.copyWith(message: msg, status: status, progress: progress),
    );
    BackendService.globalStatus.value = msg;
  }

  void _processError(String err) {
    BackendService.addLog("[ERROR] $err");
    _updateState(
      _currentTask?.copyWith(status: TaskStatus.failed, message: err),
    );
  }

  Future<void> cancelTask() async {
    try {
      final cancelledTaskId = _currentTask?.id;

      if (_currentTask != null && _currentTask!.status != TaskStatus.failed) {
        _updateState(
          _currentTask!.copyWith(
            status: TaskStatus.failed,
            messageKey: "taskCancelling",
          ),
        );
      }

      final subs = List<StreamSubscription>.from(_subscriptions);
      _subscriptions.clear();
      for (final sub in subs) {
        try {
          await sub.cancel();
        } catch (_) {}
      }

      if (kIsWeb) {
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.failed,
            messageKey: "taskCancelledByUser",
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentTask?.id == cancelledTaskId) _updateState(null);
        });
        return;
      }

      try {
        await BackendService.cancelCurrentTask().timeout(
          const Duration(seconds: 10),
        );
      } catch (_) {}

      final currentMutex = _mutex;
      if (!currentMutex.isCompleted) currentMutex.complete();

      if (_currentTask?.id == cancelledTaskId) {
        _updateState(
          _currentTask?.copyWith(
            status: TaskStatus.failed,
            messageKey: "taskCancelledByUser",
            speed: "",
          ),
        );
      }
    } catch (e) {
      debugPrint("TaskManager.cancelTask Fatal: $e");
    } finally {
      final cancelledTaskId = _currentTask?.id;
      Future.delayed(const Duration(seconds: 3), () {
        if (_currentTask?.id == cancelledTaskId &&
            _currentTask?.status == TaskStatus.failed) {
          _updateState(null);
        }
      });
      BackendService.isDownloading.value = false;
    }
  }

  void clearTask() {
    _updateState(null);
  }
}
