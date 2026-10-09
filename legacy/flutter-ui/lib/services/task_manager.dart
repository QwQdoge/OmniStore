import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/task_state.dart';
import 'backend_service.dart';
import 'update_service.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/package_repository.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  final _taskStateController = StreamController<TaskState?>.broadcast();
  TaskState? _currentTask;

  // Lock to prevent concurrent task starts.
  Completer<void> _mutex = Completer<void>()..complete();

  Stream<TaskState?> get taskStateStream => _taskStateController.stream;
  TaskState? get currentTask => _currentTask;
  bool get isBusy => _currentTask != null;

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
    _staleTaskTimer = Timer(const Duration(minutes: 10), () async {
      if (isBusy) {
        final now = DateTime.now();
        final idleTime = now.difference(_lastLogTime);
        if (idleTime >= const Duration(minutes: 10)) {
          debugPrint(
            "Stale task detected (idle for ${idleTime.inMinutes}m). Forcing cleanup.",
          );
          await cancelTask();
        } else {
          _startStaleCheck();
        }
      }
    });
  }

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
      debugPrint("TaskManager mutex error: $e");
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
      debugPrint("TaskManager.startTask fatal: $e");
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
          var success = true;
          await for (final line in stream) {
            _handleOutput(line);
            if (_isErrorEvent(line)) success = false;
          }

          _updateState(
            _currentTask?.copyWith(
              status: success ? TaskStatus.success : TaskStatus.failed,
              progress: success ? 1.0 : _currentTask?.progress,
              messageKey: success ? "taskSuccess" : "taskFailed",
              speed: "",
            ),
          );
          BackendService.isDownloading.value = false;

          if (success) {
            PackageRepository().clearDetailsCacheFor(packageName);
          }

          UpdateService().showCompletionNotification(packageName, success);

          Future.delayed(const Duration(seconds: 5), () {
            if (_currentTask?.status == TaskStatus.success ||
                _currentTask?.status == TaskStatus.failed) {
              _updateState(null);
            }
          });
          return success;
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
              if (_isErrorEvent(line)) success = false;
            },
            onError: (e) {
              debugPrint("TaskManager stream error: $e");
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
            onTimeout: () async {
              debugPrint("Task timed out. Forcing cleanup.");
              await BackendService.cancelCurrentTask();
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
          PackageRepository().clearDetailsCacheFor(packageName);
        } else if (_currentTask?.status != TaskStatus.failed) {
          _updateState(
            _currentTask?.copyWith(
              status: TaskStatus.failed,
              messageKey: "taskFailed",
              speed: "",
            ),
          );
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

  bool _isErrorEvent(String line) {
    final cleanLine = line.trim();
    if (cleanLine.startsWith("[ERROR]") ||
        cleanLine.startsWith("[FATAL]") ||
        cleanLine.startsWith("[CRITICAL]")) {
      return true;
    }

    String? jsonText;
    if (cleanLine.startsWith("[CALLBACK]")) {
      jsonText = cleanLine.substring("[CALLBACK]".length).trim();
    } else if (cleanLine.startsWith("{")) {
      jsonText = cleanLine;
    }

    if (jsonText == null || jsonText.isEmpty) return false;

    try {
      final data = jsonDecode(jsonText);
      if (data is! Map) return false;
      final level = data['level']?.toString().toLowerCase();
      final type = data['type']?.toString().toLowerCase();
      final key = data['key']?.toString().toLowerCase();
      return level == 'error' ||
          level == 'fatal' ||
          level == 'critical' ||
          type == 'error' ||
          type == 'fatal' ||
          (key?.startsWith('error') ?? false);
    } catch (_) {
      return false;
    }
  }

  void _handleOutput(String line) {
    if (line.isEmpty) return;
    final cleanLine = line.trim();

    try {
      if (cleanLine.startsWith("[CALLBACK]")) {
        final jsonText = cleanLine.substring("[CALLBACK]".length).trim();
        final data = jsonDecode(jsonText);
        if (data is Map<String, dynamic>) {
          _processStructuredCallback(data);
        }
      } else if (cleanLine.startsWith("{")) {
        final data = jsonDecode(cleanLine);
        if (data is Map<String, dynamic>) {
          _processStructuredCallback(data);
        }
      } else {
        _processLegacyLine(cleanLine);
      }
    } catch (e) {
      debugPrint("Task output parsing warning: $e");
      BackendService.addLog("Raw: $cleanLine");
    }
  }

  void _processStructuredCallback(Map<String, dynamic> data) {
    final key = data['key']?.toString();
    final level = data['level']?.toString().toLowerCase();
    final type = data['type']?.toString().toLowerCase();
    final rawMessage = data['message'] ?? data['log'] ?? data['error'] ?? key;
    final msg = rawMessage?.toString();

    final isError = level == 'error' ||
        level == 'fatal' ||
        level == 'critical' ||
        type == 'error' ||
        type == 'fatal' ||
        (key?.toLowerCase().startsWith('error') ?? false);

    if (msg != null && msg.isNotEmpty) {
      if (isError ||
          msg.startsWith("[ERROR]") ||
          msg.startsWith("[FATAL]") ||
          msg.startsWith("[CRITICAL]")) {
        _processError(_stripLegacyPrefix(msg));
      } else if (msg.startsWith("[PROGRESS]")) {
        _processProgress(msg.replaceFirst("[PROGRESS]", "").trim());
      } else if (msg.startsWith("[SPEED]")) {
        _updateState(
          _currentTask?.copyWith(
            speed: msg.replaceFirst("[SPEED]", "").trim(),
          ),
        );
      } else if (msg.startsWith("[STAGE]")) {
        _updateState(
          _currentTask?.copyWith(
            stage: msg.replaceFirst("[STAGE]", "").trim(),
          ),
        );
      } else {
        _processInfo(_stripLegacyPrefix(msg));
      }
    }

    if (data.containsKey('progress')) {
      _processProgress(data['progress'].toString());
    }
    if (data.containsKey('speed')) {
      _updateState(_currentTask?.copyWith(speed: data['speed'].toString()));
    }
    if (data.containsKey('stage')) {
      _updateState(_currentTask?.copyWith(stage: data['stage'].toString()));
    }
  }

  void _processLegacyLine(String line) {
    if (line.startsWith("[PROGRESS]")) {
      _processProgress(line.replaceFirst("[PROGRESS]", "").trim());
    } else if (line.startsWith("[SPEED]")) {
      _updateState(
        _currentTask?.copyWith(
          speed: line.replaceFirst("[SPEED]", "").trim(),
        ),
      );
    } else if (line.startsWith("[INFO]")) {
      _processInfo(_stripLegacyPrefix(line));
    } else if (line.startsWith("[ERROR]") ||
        line.startsWith("[FATAL]") ||
        line.startsWith("[CRITICAL]")) {
      _processError(_stripLegacyPrefix(line));
    } else {
      BackendService.addLog(line);
    }
  }

  String _stripLegacyPrefix(String message) {
    const prefixes = [
      '[CRITICAL]',
      '[WARNING]',
      '[SUCCESS]',
      '[ERROR]',
      '[FATAL]',
      '[DEBUG]',
      '[TRACE]',
      '[INFO]',
      '[WARN]',
    ];
    final trimmed = message.trim();
    for (final prefix in prefixes) {
      if (trimmed.startsWith(prefix)) {
        return trimmed.substring(prefix.length).trimLeft();
      }
    }
    return trimmed;
  }

  void _processProgress(String value) {
    final parts = value.split(" ");
    final p = double.tryParse(parts[0]);
    if (p == null || !p.isFinite) return;

    final progress = (p / 100.0).clamp(0.0, 1.0);
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
    final cleanMessage = msg.trim();
    if (cleanMessage.isEmpty) return;
    BackendService.addLog(cleanMessage);
    TaskStatus status = _currentTask?.status ?? TaskStatus.pending;
    double? progress = _currentTask?.progress;

    final lowerMsg = cleanMessage.toLowerCase();
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
      _currentTask?.copyWith(
        message: cleanMessage,
        status: status,
        progress: progress,
      ),
    );
    BackendService.globalStatus.value = cleanMessage;
  }

  void _processError(String err) {
    final cleanError = err.trim();
    if (cleanError.isEmpty) return;
    BackendService.addLog(cleanError);
    _updateState(
      _currentTask?.copyWith(status: TaskStatus.failed, message: cleanError),
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
      await Future.wait(
        subs.map((sub) async {
          try {
            await sub.cancel();
          } catch (_) {}
        }),
      );

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
      debugPrint("TaskManager.cancelTask fatal: $e");
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
