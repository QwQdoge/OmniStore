import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/task_state.dart';

class TaskController with ChangeNotifier {
  final TaskRepository _taskRepository;

  bool _isBusy = false;
  double? _progress;
  String _status = "Ready";
  String _speed = "";
  String? _packageName;
  String? _flag;
  final List<String> _logs = [];
  final List<TaskState> _completedTasks = [];

  late UnmodifiableListView<String> _logsView;
  late UnmodifiableListView<TaskState> _completedTasksView;

  TaskController(this._taskRepository) {
    _logsView = UnmodifiableListView(_logs);
    _completedTasksView = UnmodifiableListView(_completedTasks);
  }

  bool get isBusy => _isBusy;
  double? get progress => _progress;
  String get status => _status;
  String get speed => _speed;
  String? get packageName => _packageName;
  String? get flag => _flag;
  List<String> get logs => _logsView;
  List<TaskState> get completedTasks => _completedTasksView;

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void clearHistory() {
    _completedTasks.clear();
    notifyListeners();
  }

  void cancelTask(AppLocalizations l10n) {
    _taskRepository.cancelCurrentTask();
    _isBusy = false;
    _packageName = null;
    _flag = null;
    _status = l10n.taskCancelled;
    _progress = null;
    notifyListeners();
  }

  Future<bool> runTask(
    String flag,
    String packageName,
    String source,
    AppLocalizations l10n, {
    String? url,
  }) async {
    return _executeTaskInternal(
      () => _taskRepository.executeAction(flag, packageName, source, url: url),
      flag,
      packageName,
      source,
      l10n,
      errorMapper: (err) => flag == "-U"
          ? l10n.errorUpdateFailed(err)
          : flag == "-R"
              ? l10n.taskError("Uninstall failed: $err")
              : l10n.errorStartFailed(err),
    );
  }

  Future<bool> updateAll(String source, AppLocalizations l10n) async {
    return _executeTaskInternal(
      () => _taskRepository.updateAll(source),
      "-U",
      "All Packages",
      source,
      l10n,
      errorMapper: (err) => l10n.errorUpdateAll(err),
    );
  }

  /// Murphy-proof: Consolidated task execution logic with guaranteed state reset and robust error isolation.
  Future<bool> _executeTaskInternal(
    Stream<String> Function() streamFactory,
    String flag,
    String packageName,
    String source,
    AppLocalizations l10n, {
    String Function(String)? errorMapper,
  }) async {
    // Stage 1: State Locking & Initialization
    if (_isBusy) return false;
    _isBusy = true;
    _packageName = packageName;
    _flag = flag;
    _progress = null;
    _status = l10n.taskStarting;
    _logs.clear();
    bool hasError = false;
    notifyListeners();

    try {
      // Stage 2: Stream Consumption with Circuit Breaker Logic
      final stream = streamFactory();

      await for (final line in stream) {
        if (line.contains("errorFatalStream") ||
            line.contains("errorProcessStart") ||
            line.contains("errorStartFailed") ||
            line.contains("errorUpdateFailed") ||
            line.contains("errorCleanFailed") ||
            line.contains("errorUpdateAll") ||
            line.contains("[ERROR]")) {
          hasError = true;
        }
        _parseLine(line, l10n);
        notifyListeners();
      }
    } catch (e) {
      // Stage 3: Panic Recovery
      hasError = true;
      final errorStr = e.toString();
      _status = errorMapper != null ? errorMapper(errorStr) : l10n.errorFatalStream(errorStr);
      _logs.add("[ERROR] Fatal task stream exception: $e");
    } finally {
      // Stage 4: Absolute State Reset (Murphy-proof)
      _isBusy = false;
      _progress = null;

      _completedTasks.insert(
        0,
        TaskState(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          packageName: packageName,
          source: source,
          status: !hasError ? TaskStatus.success : TaskStatus.failed,
          progress: !hasError ? 1.0 : 0.0,
          stage: flag == "-I"
              ? "Install"
              : flag == "-R"
              ? "Uninstall"
              : "Update",
          message: !hasError ? "Success" : _status,
        ),
      );

      _packageName = null;
      _flag = null;
      // Ensure status reflects the final outcome if it hasn't been set by an error
      if (!hasError && _status == l10n.taskStarting) {
         _status = l10n.taskSuccess;
      }

      notifyListeners();
    }

    return !hasError;
  }

  Future<void> runCleanSystem(AppLocalizations l10n) async {
    await _executeTaskInternal(
      () => _taskRepository.cleanSystem(),
      "--clean",
      "System Cleanup",
      "System",
      l10n,
      errorMapper: (err) => l10n.errorCleanFailed(err),
    );
  }

  void _parseLine(String line, AppLocalizations l10n) {
    if (line.startsWith("[PROGRESS]")) {
      final val = double.tryParse(line.replaceFirst("[PROGRESS]", "").trim());
      if (val != null) _progress = val / 100.0;
    } else if (line.startsWith("[SPEED]")) {
      _speed = line.replaceFirst("[SPEED]", "").trim();
    } else if (line.startsWith("[CALLBACK]")) {
      final jsonStr = line.replaceFirst("[CALLBACK]", "").trim();
      try {
        final data = jsonDecode(jsonStr);
        String? message;
        if (data['key'] != null) {
          final key = data['key'] as String;
          final error = data['error'] as String?;
          if (key == "errorPackageNameRequired") {
            message = l10n.errorPackageNameRequired;
          } else if (key == "errorStartFailed") {
            message = l10n.errorStartFailed(error ?? "Unknown");
          } else if (key == "errorUpdateFailed") {
            message = l10n.errorUpdateFailed(error ?? "Unknown");
          } else if (key == "errorCleanFailed") {
            message = l10n.errorCleanFailed(error ?? "Unknown");
          } else if (key == "errorFatalStream") {
            message = l10n.errorFatalStream(error ?? "Unknown");
          } else if (key == "errorProcessStart") {
            message = l10n.errorProcessStart(error ?? "Unknown");
          } else if (key == "errorUpdateAll") {
            message = l10n.errorUpdateAll(error ?? "Unknown");
          }
        } else if (data['log'] != null) {
          message = data['log'];
        } else if (data['message'] != null) {
          message = data['message'];
        }

        if (message != null) {
          _logs.add(message);
          _status = message;
        }
      } catch (_) {}
    } else {
      _logs.add(line);
    }

    if (_logs.length > 500) _logs.removeAt(0);
  }
}
