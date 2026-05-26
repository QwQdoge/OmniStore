import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/task_state.dart';
import 'backend_service.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  final _taskStateController = StreamController<TaskState?>.broadcast();
  TaskState? _currentTask;
  Process? _activeProcess;

  Stream<TaskState?> get taskStateStream => _taskStateController.stream;
  TaskState? get currentTask => _currentTask;
  bool get isBusy => _currentTask != null;

  // Throttling mechanism
  DateTime _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _throttleDuration = Duration(milliseconds: 16); // ~60Hz

  /// Updates the internal state and notifies listeners via the stream.
  /// Implements throttling (max 60Hz) to prevent UI jank from high-frequency backend logs.
  void _updateState(TaskState? state) {
    _currentTask = state;

    final now = DateTime.now();
    // Always emit terminal states or null immediately.
    // Otherwise, throttle based on _throttleDuration.
    if (state == null || state.status == TaskStatus.success || state.status == TaskStatus.failed ||
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
    if (isBusy) return false;

    _updateState(TaskState(
      id: id,
      status: TaskStatus.pending,
      progress: -1.0,
      message: "Initializing task...",
    ));

    BackendService.clearLogs();
    BackendService.isDownloading.value = true;
    BackendService.globalStatus.value = "Starting...";

    try {
      List<String> args = [
        BackendService.scriptPath,
        actionFlag,
        packageName,
        "--source",
        source,
        "--json",
      ];
      if (url != null && url.isNotEmpty) {
        args.addAll(["--url", url]);
      }

      _activeProcess = await Process.start(
        BackendService.venvPython,
        args,
        workingDirectory: BackendService.workingDir,
      );

      _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutput);

      _activeProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("TaskManager Stderr: $data");
        BackendService.addLog("stderr: $data");
      });

      final exitCode = await _activeProcess!.exitCode;

      if (exitCode == 0) {
        _updateState(_currentTask?.copyWith(
          status: TaskStatus.success,
          progress: 1.0,
          message: "Task completed successfully",
          speed: "",
        ));
        return true;
      } else {
        // If it was cancelled, it might have been set to failed already or still in progress
        if (_currentTask?.status != TaskStatus.failed) {
          _updateState(_currentTask?.copyWith(
            status: TaskStatus.failed,
            message: "Task failed with exit code $exitCode",
            speed: "",
          ));
        }
      }
    } catch (e) {
      _updateState(_currentTask?.copyWith(
        status: TaskStatus.failed,
        message: "Error: $e",
        speed: "",
      ));
    } finally {
      _activeProcess = null;
      BackendService.isDownloading.value = false;
      // Keep the final state for a moment or let UI handle it
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentTask?.status == TaskStatus.success || _currentTask?.status == TaskStatus.failed) {
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
        final p = double.tryParse(logMessage.split(" ")[1]);
        if (p != null) {
          _updateState(_currentTask?.copyWith(
            progress: p / 100.0,
            status: TaskStatus.downloading, // Default to downloading when progress moves
          ));
        }
      } else if (logMessage.startsWith("[SPEED]")) {
        final s = logMessage.replaceFirst("[SPEED] ", "");
        _updateState(_currentTask?.copyWith(speed: s));
      } else if (logMessage.startsWith("[INFO]")) {
        final msg = logMessage.replaceFirst("[INFO] ", "");
        BackendService.addLog(logMessage);

        TaskStatus status = _currentTask?.status ?? TaskStatus.pending;
        if (msg.toLowerCase().contains("installing")) {
          status = TaskStatus.installing;
        } else if (msg.toLowerCase().contains("downloading")) {
          status = TaskStatus.downloading;
        }

        _updateState(_currentTask?.copyWith(
          message: msg,
          status: status,
        ));
        BackendService.globalStatus.value = msg;
      } else if (logMessage.startsWith("[ERROR]")) {
        BackendService.addLog(logMessage);
        _updateState(_currentTask?.copyWith(
          status: TaskStatus.failed,
          message: logMessage.replaceFirst("[ERROR] ", ""),
        ));
      } else {
        BackendService.addLog(logMessage);
      }
    }
  }

  void cancelTask() {
    if (_activeProcess != null) {
      _activeProcess!.kill(ProcessSignal.sigterm);
      _updateState(_currentTask?.copyWith(
        status: TaskStatus.failed,
        message: "Task cancelled by user",
        speed: "",
      ));
    } else if (_currentTask != null) {
      // Clear if not running
      _updateState(null);
    }
  }

  void clearTask() {
    _updateState(null);
  }

  // Mock task for testing high-frequency updates
  void startMockTask() async {
    if (isBusy) return;

    _updateState(TaskState(
      id: "mock-task",
      status: TaskStatus.downloading,
      progress: 0.0,
      message: "Simulating high-frequency updates...",
    ));

    for (int i = 0; i <= 100; i++) {
      if (!isBusy) break;
      await Future.delayed(const Duration(milliseconds: 5)); // > 60Hz
      _updateState(_currentTask?.copyWith(
        progress: i / 100.0,
        speed: "${(10 + i % 5).toStringAsFixed(1)} MB/s",
        message: "Mock downloading part $i...",
      ));
    }

    if (isBusy) {
      _updateState(_currentTask?.copyWith(
        status: TaskStatus.installing,
        progress: -1.0,
        message: "Mock installing...",
      ));
      await Future.delayed(const Duration(seconds: 2));
      _updateState(_currentTask?.copyWith(
        status: TaskStatus.success,
        progress: 1.0,
        message: "Mock task finished",
      ));

      Future.delayed(const Duration(seconds: 2), () {
        _updateState(null);
      });
    }
  }
}
