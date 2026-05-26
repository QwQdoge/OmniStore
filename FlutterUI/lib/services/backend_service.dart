import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_package.dart';

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;
  BackendService._internal();

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
      if (result.exitCode != 0) return {};
      return jsonDecode(result.stdout);
    } catch (e) {
      return {};
    }
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

  Future<List<String>> getPacmanMirrors() async {
    final config = await loadConfig();
    final customRepos = config['custom_repos'] as Map<String, dynamic>?;
    final pacman = customRepos?['pacman'] as List<dynamic>? ?? [];
    return pacman.map((entry) {
      if (entry is Map<String, dynamic>) {
        final name = entry['name']?.toString() ?? '';
        final url = entry['url']?.toString() ?? '';
        return name.isNotEmpty && url.isNotEmpty ? '$name|$url' : entry.toString();
      }
      return entry.toString();
    }).toList();
  }

  Future<bool> savePacmanMirrors(List<String> mirrors) async {
    final config = await loadConfig();
    final customRepos = Map<String, dynamic>.from(config['custom_repos'] as Map? ?? {});
    customRepos['pacman'] = mirrors.map((entry) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        return {'name': parts[0].trim(), 'url': parts[1].trim()};
      }
      return {'name': entry.trim(), 'url': entry.trim()};
    }).toList();
    config['custom_repos'] = customRepos;
    return saveConfig(config);
  }

  Stream<String> executeAction(String flag, String packageName, String source, {String? url}) async* {
    if (packageName.isEmpty) {
      yield "[CALLBACK] {\"log\": \"错误：包名不能为空\"}";
      return;
    }

    try {
      List<String> args = [_scriptPath, flag, packageName, "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        args.addAll(["--url", url]);
      }

      final process = await Process.start(_venvPython, args, workingDirectory: _workingDir);

      yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());

      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Python Stderr: $data");
      });
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"启动失败: $e\"}";
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
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath, "-U", "all", "--source", source, "--json",
      ], workingDirectory: _workingDir);

      yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"更新失败: $e\"}";
    }
  }

  /// 获取必备包
  Future<List<dynamic>> getEssentials() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--essentials",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      return [];
    }
  }

  /// 导入包
  Future<List<dynamic>> importPackages(String filepath) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--import-packages", filepath,
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      return [];
    }
  }
}
