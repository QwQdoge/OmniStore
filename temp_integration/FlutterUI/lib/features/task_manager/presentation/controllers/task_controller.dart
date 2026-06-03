import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/backend/repositories/task_repository.dart';

class TaskController with ChangeNotifier {
  final TaskRepository _taskRepository;

  bool _isBusy = false;
  double? _progress;
  String _status = "Ready";
  String _speed = "";
  final List<String> _logs = [];

  TaskController(this._taskRepository);

  bool get isBusy => _isBusy;
  double? get progress => _progress;
  String get status => _status;
  String get speed => _speed;
  List<String> get logs => List.unmodifiable(_logs);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void cancelTask() {
    _taskRepository.cancelCurrentTask();
    _isBusy = false;
    _status = "Task Cancelled";
    _progress = null;
    notifyListeners();
  }

  Future<void> runTask(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) async {
    _isBusy = true;
    _progress = null;
    _status = "Starting...";
    notifyListeners();

    final stream = _taskRepository.executeAction(
      flag,
      packageName,
      source,
      url: url,
    );

    await for (final line in stream) {
      _parseLine(line);
      notifyListeners();
    }

    _isBusy = false;
    _progress = null;
    notifyListeners();
  }

  void _parseLine(String line) {
    if (line.startsWith("[PROGRESS]")) {
      final val = double.tryParse(line.replaceFirst("[PROGRESS]", "").trim());
      if (val != null) _progress = val / 100.0;
    } else if (line.startsWith("[SPEED]")) {
      _speed = line.replaceFirst("[SPEED]", "").trim();
    } else if (line.startsWith("[CALLBACK]")) {
      final jsonStr = line.replaceFirst("[CALLBACK]", "").trim();
      try {
        final data = jsonDecode(jsonStr);
        if (data['message'] != null) {
          _logs.add(data['message']);
          _status = data['message'];
        }
      } catch (_) {}
    } else {
      _logs.add(line);
    }

    if (_logs.length > 500) _logs.removeAt(0);
  }
}
