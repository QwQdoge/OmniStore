import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    if (kIsWeb) {
      yield* _webExecuteAction(flag, packageName, source, url: url);
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

  Stream<String> _webExecuteAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) async* {
    final isInstall = flag == "-I";
    
    yield '[CALLBACK] {"type": "log", "message": "[INFO] Starting ${isInstall ? "install" : "uninstall"} for $packageName via $source...", "level": "INFO"}';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 10';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 40';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 80';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 100';
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final installedIds = prefs.getStringList('omnistore_installed_ids') ?? [];
    final installedCacheRaw = prefs.getString('omnistore_installed_packages_cache');
    List<dynamic> installedCache = [];
    if (installedCacheRaw != null) {
      try {
        installedCache = jsonDecode(installedCacheRaw) as List<dynamic>;
      } catch (_) {}
    }

    if (isInstall) {
      if (!installedIds.contains(packageName)) {
        installedIds.add(packageName);
      }
      // Remove any existing entry from cache first
      installedCache.removeWhere((item) => item['id'] == packageName);
      installedCache.add({
        "name": packageName.split('/').last,
        "id": packageName,
        "primary_source": source,
        "installed": true,
        "description": "Installed via Omnistore Web client.",
        "version": "Latest",
        "url": url ?? "",
        "variants": [{"source": source, "id": packageName, "installed": true}]
      });
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Installed successfully!", "level": "SUCCESS"}';
    } else {
      installedIds.remove(packageName);
      installedCache.removeWhere((item) => item['id'] == packageName);
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Uninstalled successfully!", "level": "SUCCESS"}';
    }

    await prefs.setStringList('omnistore_installed_ids', installedIds);
    await prefs.setString('omnistore_installed_packages_cache', jsonEncode(installedCache));
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return [];
    }

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
    if (kIsWeb) {
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Starting system update on web...", "level": "INFO"}';
      await Future.delayed(const Duration(milliseconds: 500));
      yield '[PROGRESS] 50';
      await Future.delayed(const Duration(milliseconds: 500));
      yield '[PROGRESS] 100';
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Web updates completed!", "level": "SUCCESS"}';
      return;
    }

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
    if (kIsWeb) return;
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
    if (kIsWeb) {
      return {"status": "error", "message": "File export is not supported in the web browser."};
    }

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
    if (kIsWeb) {
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Running system cleanup in browser...", "level": "INFO"}';
      await Future.delayed(const Duration(milliseconds: 500));
      yield '[PROGRESS] 50';
      await Future.delayed(const Duration(milliseconds: 500));
      yield '[PROGRESS] 100';
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Browser storage cleanup finished!", "level": "SUCCESS"}';
      return;
    }

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
