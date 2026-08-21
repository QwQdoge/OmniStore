import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/data/repositories/package_repository.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/task_state.dart';

enum TaskLogLevel { debug, info, warning, error, success }

class TaskLogEntry {
  const TaskLogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  final String message;
  final TaskLogLevel level;
  final DateTime timestamp;
}

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
  int _taskGeneration = 0;
  final List<TaskLogEntry> _logEntries = [];
  final List<TaskState> _completedTasks = [];

  late UnmodifiableListView<TaskLogEntry> _logEntriesView;
  late UnmodifiableListView<TaskState> _completedTasksView;

  TaskController(this._taskRepository) {
    _logEntriesView = UnmodifiableListView(_logEntries);
    _completedTasksView = UnmodifiableListView(_completedTasks);
  }

  bool get isBusy => _isBusy;
  double? get progress => _progress;
  String get status => _status;
  String get speed => _speed;
  String? get packageName => _packageName;
  String? get flag => _flag;

  /// Backwards-compatible plain-text view for callers that only need messages.
  List<String> get logs => List<String>.unmodifiable(
    _logEntries.map((entry) => entry.message),
  );

  /// Structured log entries for UI and diagnostics.
  List<TaskLogEntry> get logEntries => _logEntriesView;

  List<TaskState> get completedTasks => _completedTasksView;

  void clearLogs() {
    _logEntries.clear();
    notifyListeners();
  }

  void clearHistory() {
    _completedTasks.clear();
    notifyListeners();
  }

  void cancelTask(AppLocalizations l10n) {
    if (!_isBusy) return;
    // Invalidate the active stream before stopping its process. A process can
    // still emit buffered output after cancellation; those stale events must
    // never complete or overwrite a newer task.
    _taskGeneration++;
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

  /// Consolidated task execution logic with guaranteed state reset and robust
  /// error isolation. Failure is determined from structured event severity,
  /// never by searching arbitrary log text for the word "error".
  Future<bool> _executeTaskInternal(
    Stream<String> Function() streamFactory,
    String flag,
    String packageName,
    String source,
    AppLocalizations l10n, {
    String Function(String)? errorMapper,
  }) async {
    if (_isBusy) return false;
    final taskGeneration = ++_taskGeneration;
    _isBusy = true;
    _packageName = packageName;
    _flag = flag;
    _progress = null;
    _status = l10n.taskStarting;
    _logEntries.clear();
    bool hasError = false;
    notifyListeners();

    try {
      final stream = streamFactory();

      await for (final line in stream) {
        if (taskGeneration != _taskGeneration) break;
        final level = _parseLine(line, l10n);
        if (level == TaskLogLevel.error) hasError = true;
        notifyListeners();
      }
    } catch (e) {
      if (taskGeneration != _taskGeneration) return false;
      hasError = true;
      _status = l10n.errorFatalStream(e.toString());
      _appendLog(e.toString(), TaskLogLevel.error);
    } finally {
      if (taskGeneration == _taskGeneration) {
        _isBusy = false;
        _progress = null;
        notifyListeners();
      }
    }

    if (taskGeneration != _taskGeneration) return false;

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

    if (!hasError) {
      PackageRepository().clearDetailsCacheFor(packageName);
    }

    return !hasError;
  }

  Future<void> runCleanSystem(AppLocalizations l10n) async {
    if (_isBusy) return;
    final taskGeneration = ++_taskGeneration;
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
        if (taskGeneration != _taskGeneration) break;
        final level = _parseLine(line, l10n);
        if (level == TaskLogLevel.error) hasError = true;
        notifyListeners();
      }
    } catch (e) {
      if (taskGeneration != _taskGeneration) return;
      hasError = true;
      _status = l10n.errorCleanFailed(e.toString());
      _appendLog(e.toString(), TaskLogLevel.error);
    } finally {
      if (taskGeneration == _taskGeneration) {
        _isBusy = false;
        _progress = null;
        _packageName = null;
        _flag = null;
        notifyListeners();
      }
    }

    if (taskGeneration != _taskGeneration) return;

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

  TaskLogLevel? _parseLine(String line, AppLocalizations l10n) {
    final cleanLine = line.trim();
    if (cleanLine.isEmpty) return null;

    // Prefer structured callback JSON. Legacy tags remain supported only as a
    // compatibility boundary while older Python/plugin producers migrate.
    if (cleanLine.startsWith("[CALLBACK]")) {
      final jsonStr = cleanLine.replaceFirst("[CALLBACK]", "").trim();
      try {
        final data = jsonDecode(jsonStr);
        return _processStructuredData(data, l10n);
      } catch (e) {
        debugPrint("TaskController: JSON parse error: $e");
      }
    }

    if (cleanLine.startsWith("{")) {
      try {
        final data = jsonDecode(cleanLine);
        return _processStructuredData(data, l10n);
      } catch (e) {
        debugPrint("TaskController: JSON parse error: $e");
      }
    }

    if (cleanLine.startsWith("[PROGRESS]")) {
      final val = double.tryParse(
        cleanLine.replaceFirst("[PROGRESS]", "").trim(),
      );
      if (val != null && val.isFinite) {
        _progress = (val / 100.0).clamp(0.0, 1.0);
      }
      return null;
    }

    if (cleanLine.startsWith("[SPEED]")) {
      _speed = cleanLine.replaceFirst("[SPEED]", "").trim();
      return null;
    }

    final legacyLevel = _legacyLevel(cleanLine);
    final message = _stripLegacyPrefix(cleanLine);
    _appendLog(message, legacyLevel ?? TaskLogLevel.info);
    if (message.isNotEmpty) _status = message;
    return legacyLevel ?? TaskLogLevel.info;
  }

  TaskLogLevel? _processStructuredData(
    dynamic data,
    AppLocalizations l10n,
  ) {
    if (data is! Map<String, dynamic>) return null;

    String? message;
    final key = data['key']?.toString();
    if (key != null) {
      final error = data['error']?.toString();
      message = _translateKey(key, error, l10n);
    } else if (data['log'] != null) {
      message = data['log'].toString();
    } else if (data['message'] != null) {
      message = data['message'].toString();
    }

    if (data['progress'] != null) {
      final p = double.tryParse(data['progress'].toString());
      if (p != null && p.isFinite) {
        _progress = (p / 100.0).clamp(0.0, 1.0);
      }
    }

    if (data['speed'] != null) {
      _speed = data['speed'].toString();
    }

    if (message == null || message.trim().isEmpty) {
      return key?.toLowerCase().startsWith('error') == true
          ? TaskLogLevel.error
          : null;
    }

    var level = _parseLevel(
      data['level']?.toString() ?? data['severity']?.toString(),
    );

    final type = data['type']?.toString().toLowerCase();
    if (type == 'error' || type == 'fatal') {
      level = TaskLogLevel.error;
    } else if (type == 'warning' || type == 'warn') {
      level = TaskLogLevel.warning;
    }

    if (key?.toLowerCase().startsWith('error') == true) {
      level = TaskLogLevel.error;
    }

    final legacyLevel = _legacyLevel(message);
    if (legacyLevel != null && data['level'] == null) {
      level = legacyLevel;
    }

    final cleanMessage = _stripLegacyPrefix(message);
    _appendLog(cleanMessage, level);
    _status = cleanMessage;
    return level;
  }

  TaskLogLevel _parseLevel(String? level) {
    switch (level?.trim().toLowerCase()) {
      case 'debug':
      case 'trace':
        return TaskLogLevel.debug;
      case 'warning':
      case 'warn':
        return TaskLogLevel.warning;
      case 'error':
      case 'fatal':
      case 'critical':
        return TaskLogLevel.error;
      case 'success':
        return TaskLogLevel.success;
      default:
        return TaskLogLevel.info;
    }
  }

  TaskLogLevel? _legacyLevel(String message) {
    final trimmed = message.trimLeft();
    if (trimmed.startsWith('[ERROR]') ||
        trimmed.startsWith('[FATAL]') ||
        trimmed.startsWith('[CRITICAL]')) {
      return TaskLogLevel.error;
    }
    if (trimmed.startsWith('[WARNING]') || trimmed.startsWith('[WARN]')) {
      return TaskLogLevel.warning;
    }
    if (trimmed.startsWith('[SUCCESS]')) return TaskLogLevel.success;
    if (trimmed.startsWith('[DEBUG]') || trimmed.startsWith('[TRACE]')) {
      return TaskLogLevel.debug;
    }
    if (trimmed.startsWith('[INFO]')) return TaskLogLevel.info;
    return null;
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

  void _appendLog(String message, TaskLogLevel level) {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    _logEntries.add(
      TaskLogEntry(
        message: cleanMessage,
        level: level,
        timestamp: DateTime.now(),
      ),
    );

    if (_logEntries.length > 500) _logEntries.removeAt(0);
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
