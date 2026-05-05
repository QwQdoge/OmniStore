import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_package.dart';

class BackendService {
  static String get _projectRoot => Directory.current.path.endsWith('FlutterUI')
      ? Directory.current.parent.path
      : Directory.current.path;

  static String get venvPython => "$_projectRoot/python/.venv/bin/python";
  static String get scriptPath => "$_projectRoot/python/main.py";
  static String get workingDir => "$_projectRoot/python";

  String get _venvPython => venvPython;
  String get _scriptPath => scriptPath;
  String get _workingDir => workingDir;

  // 全局进度通知器
  static final ValueNotifier<double?> globalProgress = ValueNotifier(null);
  static final ValueNotifier<String> globalStatus = ValueNotifier("Ready");
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  
  // 当前正在操作的 app（用于跨页面状态恢复）
  static final ValueNotifier<AppPackage?> activeApp = ValueNotifier(null);
  static final ValueNotifier<String?> activeFlag = ValueNotifier(null); // "-I" or "-R"
  static final ValueNotifier<List<String>> globalLogs = ValueNotifier([]);
  static Process? activeProcess;

  static void addLog(String log) {
    final currentLogs = globalLogs.value;
    if (currentLogs.length > 500) {
      globalLogs.value = [...currentLogs.sublist(currentLogs.length - 499), log];
    } else {
      globalLogs.value = [...currentLogs, log];
    }
  }

  static void clearLogs() {
    globalLogs.value = [];
  }

  static void cancelCurrentTask() {
    if (activeProcess != null) {
      activeProcess!.kill(ProcessSignal.sigterm);
      activeProcess = null;
      isDownloading.value = false;
      globalStatus.value = "任务已取消";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  /// 搜索逻辑
  Future<List<dynamic>> searchPackages(String query) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "-S", query, "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      return [];
    }
  }

  /// 获取已安装列表
  Future<List<dynamic>> listInstalled() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "-L", "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("ListInstalled Exception: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final result = await Process.run(_venvPython, [_scriptPath, "--get-config", "--json"]);
      return jsonDecode(result.stdout);
    } catch (e) { return {}; }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--set-config", jsonEncode(config), "--json",
      ]);
      return result.exitCode == 0;
    } catch (e) { return false; }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--check-env", "--json",
      ], workingDirectory: _workingDir);
      return jsonDecode(result.stdout);
    } catch (e) { return {}; }
  }

  Stream<String> bootstrap() async* {
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath, "--bootstrap", "--json",
      ], workingDirectory: _workingDir);

      yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"[ERROR] 启动引导失败: $e\"}";
    }
  }

  /// 获取动态推荐
  Future<List<AppPackage>> getRecommendations() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--recommend", "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      List<dynamic> data = jsonDecode(result.stdout.toString().trim());
      return data.map((item) => AppPackage.fromJson(item)).toList();
    } catch (e) {
      debugPrint("Recommendations Exception: $e");
      return [];
    }
  }

  /// 获取应用详情 (从 Flathub 等外部源)
  Future<Map<String, dynamic>> getAppDetails(String appId) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--details", appId, "--json",
      ], workingDirectory: _workingDir);
      return jsonDecode(result.stdout);
    } catch (e) {
      return {};
    }
  }

  Stream<String> executeAction(String flag, AppPackage app, String source, {String? url}) async* {
    if (app.name.isEmpty) {
      yield "[CALLBACK] {\"log\": \"[ERROR] 错误：包名不能为空\"}";
      return;
    }

    if (isDownloading.value) {
      yield "[CALLBACK] {\"log\": \"[ERROR] 另一个任务正在进行中\"}";
      return;
    }

    final isUninstall = flag == "-R";
    final isUpdate = flag == "-U";

    isDownloading.value = true;
    activeApp.value = app;
    activeFlag.value = flag;
    globalStatus.value = isUninstall ? 'preparing_uninstall' : (isUpdate ? 'preparing_update' : 'preparing_install');
    globalProgress.value = null;
    clearLogs();

    try {
      List<String> args = [_scriptPath, flag, app.name.trim(), "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        args.addAll(["--url", url]);
      }

      final process = await Process.start(_venvPython, args, workingDirectory: _workingDir);
      activeProcess = process;

      final stdoutStream = process.stdout.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stdoutStream) {
        String cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;

        yield cleanLine;

        Map<String, dynamic>? data;
        if (cleanLine.startsWith("[CALLBACK]")) {
          try {
            data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
          } catch (_) {}
        } else if (cleanLine.startsWith("{")) {
          try {
            data = jsonDecode(cleanLine);
          } catch (_) {}
        }

        if (data != null) {
          String log = data['message'] ?? data['log'] ?? "";
          if (log.isNotEmpty) {
            if (log.startsWith("[PROGRESS]")) {
              final parts = log.split(" ");
              if (parts.length > 1) {
                final p = double.tryParse(parts[1]);
                if (p != null) {
                  globalProgress.value = p / 100.0;
                }
              }
            } else {
              addLog(log);
              if (log.contains("[INFO]") || log.contains("[ERROR]")) {
                globalStatus.value = log;
              }
            }
          }
        }
      }

      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Python Stderr: $data");
        addLog("stderr: $data");
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0 && isDownloading.value) {
        globalStatus.value = "[ERROR] Task failed with exit code $exitCode";
      }
    } catch (e) {
      String errMsg = "[ERROR] 启动失败: $e";
      addLog(errMsg);
      globalStatus.value = errMsg;
      yield "[CALLBACK] {\"log\": \"$errMsg\"}";
    } finally {
      isDownloading.value = false;
      activeProcess = null;
    }
  }

  /// 检查更新
  Future<List<dynamic>> checkUpdates() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "-C", "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("CheckUpdates Exception: $e");
      return [];
    }
  }

  /// 更新所有
  Stream<String> updateAll(String source) async* {
    final dummyApp = AppPackage(
      name: "all",
      description: "Updating all packages from $source",
      installed: true,
      version: "Latest",
      variants: [AppVariant(source: source, version: "Latest", installed: true, description: "")],
      primarySource: source,
    );
    yield* executeAction("-U", dummyApp, source);
  }
}
