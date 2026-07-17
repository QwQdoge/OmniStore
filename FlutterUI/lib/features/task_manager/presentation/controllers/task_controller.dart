import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/task_state.dart';

class TaskController with ChangeNotifier {
  final TaskRepository _taskRepository;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

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
      hasError = true;
      _status = l10n.errorFatalStream(e.toString());
      _logs.add("[FATAL] $e");
    } finally {
      // Murphy-proof: Guaranteed busy state reset
      _isBusy = false;
      _progress = null;
      notifyListeners();
    }

    // Murphy-proof: Record task result before clearing identifiers
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
    notifyListeners();
    return !hasError;
  }

  Future<void> runCleanSystem(AppLocalizations l10n) async {
    if (_isBusy) return;
    _isBusy = true;
    _packageName = 'System Cleanup';
    _flag = '-C';
    _progress = null;
    _status = l10n.systemCleaningStarted;
    bool hasError = false;
    notifyListeners();

    try {
      final stream = _taskRepository.cleanSystem();

      await for (final line in stream) {
        if (line.contains("errorCleanFailed") ||
            line.contains("errorFatalStream") ||
            line.contains("[ERROR]")) {
          hasError = true;
        }
        _parseLine(line, l10n);
        notifyListeners();
      }
    } catch (e) {
      hasError = true;
      _status = l10n.errorCleanFailed(e.toString());
      _logs.add("[FATAL] $e");
    } finally {
      // Murphy-proof: Guaranteed state reset
      _isBusy = false;
      _progress = null;
      _packageName = null;
      _flag = null;
      notifyListeners();
    }

    _completedTasks.insert(
      0,
      TaskState(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        packageName: "System Cleanup",
        source: "System",
        status: !hasError ? TaskStatus.success : TaskStatus.failed,
        progress: !hasError ? 1.0 : 0.0,
        stage: "Clean",
        message: !hasError ? "Success" : _status,
      ),
    );
  }

  void _parseLine(String line, AppLocalizations l10n) {
    final cleanLine = line.trim();
    if (cleanLine.isEmpty) return;

    // Murphy-proof: Prioritize structured [CALLBACK] JSON data for reliable parsing.
    if (cleanLine.startsWith("[CALLBACK]")) {
      final jsonStr = cleanLine.replaceFirst("[CALLBACK]", "").trim();
      try {
        final data = jsonDecode(jsonStr);
        _processStructuredData(data, l10n);
        return;
      } catch (e) {
        debugPrint("TaskController: JSON parse error: $e");
      }
    }

    // Fallback: Legacy tag-based parsing or raw log lines.
    if (cleanLine.startsWith("[PROGRESS]")) {
      final val = double.tryParse(
        cleanLine.replaceFirst("[PROGRESS]", "").trim(),
      );
      if (val != null && val.isFinite) {
        _progress = (val / 100.0).clamp(0.0, 1.0);
      }
    } else if (cleanLine.startsWith("[SPEED]")) {
      _speed = cleanLine.replaceFirst("[SPEED]", "").trim();
    } else if (cleanLine.startsWith("[ERROR]")) {
      final msg = cleanLine.replaceFirst("[ERROR]", "").trim();
      _logs.add(msg);
      _status = msg;
    } else if (cleanLine.startsWith("[INFO]")) {
      final msg = cleanLine.replaceFirst("[INFO]", "").trim();
      _logs.add(msg);
      _status = msg;
    } else {
      _logs.add(cleanLine);
    }

    if (_logs.length > 500) _logs.removeAt(0);
  }

  void _processStructuredData(dynamic data, AppLocalizations l10n) {
    if (data is! Map<String, dynamic>) return;

    String? message;
    if (data['key'] != null) {
      final key = data['key'] as String;
      final error = data['error'] as String?;
      message = _translateKey(key, error, l10n);
    } else if (data['log'] != null) {
      message = data['log'];
    } else if (data['message'] != null) {
      message = data['message'];
    }

    if (data['progress'] != null) {
      final p = double.tryParse(data['progress'].toString());
      if (p != null && p.isFinite) _progress = (p / 100.0).clamp(0.0, 1.0);
    }

    if (message != null) {
      _logs.add(message);
      _status = message;
    }

    if (_logs.length > 500) _logs.removeAt(0);
  }

  String? _translateKey(String key, String? error, AppLocalizations l10n) {
    switch (key) {
      case "errorPackageNameRequired":
        return l10n.errorPackageNameRequired;
      case "errorStartFailed":
        return l10n.errorStartFailed(error ?? "Unknown");
      case "errorUpdateFailed":
        return l10n.errorUpdateFailed(error ?? "Unknown");
      case "errorCleanFailed":
        return l10n.errorCleanFailed(error ?? "Unknown");
      case "errorFatalStream":
        return l10n.errorFatalStream(error ?? "Unknown");
      case "errorProcessStart":
        return l10n.errorProcessStart(error ?? "Unknown");
      case "errorUpdateAll":
        return l10n.errorUpdateAll(error ?? "Unknown");
      default:
        return error ?? key;
    }
  }
}
