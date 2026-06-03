import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../python_bridge.dart';

class TaskRepository {
  Process? _activeProcess;

  Stream<String> executeAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) async* {
    if (packageName.isEmpty) {
      yield "[CALLBACK] {\"log\": \"错误：包名不能为空\"}";
      return;
    }

    try {
      List<String> baseArgs = [flag, packageName, "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        baseArgs.addAll(["--url", url]);
      }

      final process = await Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(baseArgs),
        workingDirectory: PythonBridge.workingDir,
      );

      _activeProcess = process;

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Python Stderr: $data");
      });

      await process.exitCode;
      _activeProcess = null;
    } catch (e) {
      _activeProcess = null;
      yield "[CALLBACK] {\"log\": \"启动失败: $e\"}";
    }
  }

  Future<List<dynamic>> checkUpdates() async {
    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["-C", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 30));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("CheckUpdates Exception: $e");
      return [];
    }
  }

  Stream<String> updateAll(String source) async* {
    try {
      final process = await Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["-U", "all", "--source", source, "--json"]),
        workingDirectory: PythonBridge.workingDir,
      );

      _activeProcess = process;

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await process.exitCode;
      _activeProcess = null;
    } catch (e) {
      _activeProcess = null;
      yield "[CALLBACK] {\"log\": \"更新失败: $e\"}";
    }
  }

  void cancelCurrentTask() {
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
  }

  List<dynamic> _tryParseJson(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      final start = input.lastIndexOf('[');
      final end = input.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        try {
          return jsonDecode(input.substring(start, end + 1));
        } catch (_) {}
      }
      return [];
    }
  }

  Future<Map<String, dynamic>> exportPackages(String filepath) async {
    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--export-packages", filepath]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) return {"status": "error"};
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("exportPackages Exception: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  Stream<String> cleanSystem() async* {
    try {
      final process = await Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--clean-system", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      );

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await process.exitCode;
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"清理失败: $e\"}";
    }
  }
}
