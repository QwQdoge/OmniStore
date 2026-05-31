import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'app_package.dart';

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;
  BackendService._internal();

  static String get _projectRoot {
    final searchRoots = <String>{Directory.current.path};

    try {
      final script = Platform.script.toFilePath();
      if (script.isNotEmpty) searchRoots.add(p.dirname(script));
    } catch (_) {}

    try {
      final exec = Platform.resolvedExecutable;
      if (exec.isNotEmpty) searchRoots.add(p.dirname(exec));
    } catch (_) {}

    for (final root in searchRoots) {
      var dir = Directory(root);
      while (true) {
        final candidate = p.join(dir.path, 'python', 'main.py');
        if (File(candidate).existsSync()) return dir.path;
        if (dir.parent.path == dir.path) break;
        dir = dir.parent;
      }
    }

    if (Directory.current.path.endsWith('FlutterUI')) {
      final fallback = Directory.current.parent;
      final candidate = p.join(fallback.path, 'python', 'main.py');
      if (File(candidate).existsSync()) return fallback.path;
    }

    return Directory.current.path;
  }

  static String get venvPython {
    final candidate = p.join(_projectRoot, 'python', '.venv', 'bin', 'python');
    return File(candidate).existsSync() ? candidate : 'python';
  }

  static String get scriptPath => p.join(_projectRoot, 'python', 'main.py');
  static String get workingDir => p.join(_projectRoot, 'python');

  String get _venvPython => venvPython;
  String get _scriptPath => scriptPath;
  String get _workingDir => workingDir;

  // 全局进度通知器
  static final ValueNotifier<double?> globalProgress = ValueNotifier(null);
  static final ValueNotifier<String> globalStatus = ValueNotifier("Ready");
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  static final ValueNotifier<bool> isAIEnabled = ValueNotifier(false);

  // 当前正在操作的 app（用于跨页面状态恢复）
  static final ValueNotifier<AppPackage?> activeApp = ValueNotifier(null);
  static final ValueNotifier<String?> activeFlag = ValueNotifier(
    null,
  ); // "-I" or "-R"
  static final ValueNotifier<List<String>> globalLogs = ValueNotifier([]);
  // Navigation and pending search query notifiers
  static final ValueNotifier<int> navigationIndex = ValueNotifier(0);
  static final ValueNotifier<String?> pendingSearchQuery = ValueNotifier(null);

  static Process? activeProcess;
  static Process? activeSearchProcess;

  static void addLog(String log) {
    final currentLogs = globalLogs.value;
    if (currentLogs.length > 500) {
      globalLogs.value = [
        ...currentLogs.sublist(currentLogs.length - 499),
        log,
      ];
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
  Future<List<dynamic>> searchPackages(String query, {bool cancelOngoing = true}) async {
    // Cancel any ongoing search to prevent race conditions (usually for search bar)
    if (cancelOngoing) activeSearchProcess?.kill();

    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        "-S",
        query,
        "--json",
      ], workingDirectory: _workingDir);

      if (cancelOngoing) activeSearchProcess = process;

      final outputFuture = process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(const Duration(seconds: 45));

      activeSearchProcess = null;

      if (exitCode != 0) {
        debugPrint('searchPackages failed with code $exitCode');
        return [];
      }

      final output = (await outputFuture).trim();
      if (output.isEmpty) return [];
      return _tryParseJson(output);
    } catch (e) {
      activeSearchProcess = null;
      debugPrint('searchPackages Exception: $e');
      return [];
    }
  }

  /// Robust JSON parsing that finds the first JSON block or array
  List<dynamic> _tryParseJson(String input) {
    try {
      // 1. Try direct decoding
      return jsonDecode(input);
    } catch (_) {
      // 2. Handle AI special separator
      const separator = "###JSON_START###";
      String target = input;
      if (input.contains(separator)) {
        target = input.split(separator).last.trim();
      }

      // 3. Fallback: Find the last [ ... ] block (usually where AI or backend puts the results)
      final start = target.lastIndexOf('[');
      final end = target.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        try {
          return jsonDecode(target.substring(start, end + 1));
        } catch (e) {
          debugPrint("Failed to parse extracted JSON block: $e");
        }
      }
      return [];
    }
  }

  /// 获取已安装列表
  Future<List<dynamic>> listInstalled() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "-L",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("ListInstalled Exception: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--get-config",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) {
        debugPrint("loadConfig failed with exit code ${result.exitCode}: ${result.stderr}");
        return {};
      }
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};
      final config = jsonDecode(output) as Map<String, dynamic>;

      // Update global AI status
      final ai = config['ai'] as Map<String, dynamic>?;
      isAIEnabled.value = ai?['enabled'] ?? false;

      return config;
    } catch (e) {
      debugPrint("loadConfig Exception: $e");
      return {};
    }
  }

  /// AI 解释应用
  Future<String> aiExplain(String appName, String description) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-explain",
        appName,
        "--ai-desc",
        description,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 60));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 更新内容总结
  Future<String> aiSummarizeUpdate(String name, String current, String next) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-changelog",
        "$name,$current,$next",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI CLI 命令生成
  Future<String> aiGenerateCLI(String name, String source) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-cli",
        "$name,$source",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 20));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "";
    } catch (e) {
      return "";
    }
  }

  /// AI 冲突检测
  Future<String> aiDetectConflicts(String name) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-conflicts",
        name,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 每日推荐
  Future<String> aiPickOfTheDay() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-pick",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 30));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 搜索纠错
  Future<String> aiSuggestCorrection(String query) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-correct",
        query,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 15));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "";
    } catch (e) {
      return "";
    }
  }

  /// AI 版本比较
  Future<String> aiCompareVariants(String appName) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-compare",
        appName,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 系统健康报告
  Future<String> aiSystemHealth() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-health",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 分析错误
  Future<String> aiAnalyzeError(String errorLog) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-analyze-error",
        errorLog,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 推荐应用
  Future<String> aiRecommend(String prompt) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--ai-recommend",
        prompt,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 60));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        "--set-config",
        "stdin",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 5));

      process.stdin.write(jsonEncode(config));
      await process.stdin.close();

      final exitCode = await process.exitCode.timeout(const Duration(seconds: 5));
      return exitCode == 0;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--check-env",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 10));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      return {};
    }
  }

  Stream<String> bootstrap() async* {
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        "--bootstrap",
        "--json",
      ], workingDirectory: _workingDir);

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"[ERROR] 启动引导失败: $e\"}";
    }
  }

  /// 获取动态推荐 (已分类)
  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--recommend",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) return {};
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};

      final dynamic data = jsonDecode(output);

      if (data is Map<String, dynamic>) {
        final Map<String, List<AppPackage>> categories = {};
        data.forEach((key, value) {
          if (value is List) {
            categories[key] = value
                .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        });
        return categories;
      } else if (data is List) {
        // 向后兼容旧的列表格式
        return {
          "featured": data
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList()
        };
      }
      return {};
    } catch (e) {
      debugPrint("Recommendations Exception: $e");
      return {};
    }
  }

  /// 获取应用详情 (从 Flathub 等外部源)
  Future<Map<String, dynamic>> getAppDetails(String appId) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--details",
        appId,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 20));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("getAppDetails Exception: $e");
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
        return name.isNotEmpty && url.isNotEmpty
            ? '$name|$url'
            : entry.toString();
      }
      return entry.toString();
    }).toList();
  }

  Future<bool> savePacmanMirrors(List<String> mirrors) async {
    final config = await loadConfig();
    final customRepos = Map<String, dynamic>.from(
      config['custom_repos'] as Map? ?? {},
    );
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
      List<String> args = [
        _scriptPath,
        flag,
        packageName,
        "--source",
        source,
        "--json",
      ];
      if (url != null && url.isNotEmpty) {
        args.addAll(["--url", url]);
      }

      final process = await Process.start(
        _venvPython,
        args,
        workingDirectory: _workingDir,
      );

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

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
        _scriptPath,
        "-C",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 30));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("CheckUpdates Exception: $e");
      return [];
    }
  }

  /// 更新所有
  Stream<String> updateAll(String source) async* {
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        "-U",
        "all",
        "--source",
        source,
        "--json",
      ], workingDirectory: _workingDir);

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"更新失败: $e\"}";
    }
  }

  /// 获取必备包
  Future<List<dynamic>> getEssentials() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--essentials",
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("getEssentials Exception: $e");
      return [];
    }
  }

  /// 导入包
  Future<List<dynamic>> importPackages(String filepath) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--import-packages",
        filepath,
        "--json",
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("importPackages Exception: $e");
      return [];
    }
  }

  /// 导出包列表
  Future<Map<String, dynamic>> exportPackages(String filepath) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--export-packages",
        filepath,
      ], workingDirectory: _workingDir).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) return {"status": "error"};
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("exportPackages Exception: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  /// 清理系统（孤立包和缓存）
  Stream<String> cleanSystem() async* {
    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        "--clean-system",
        "--json",
      ], workingDirectory: _workingDir);

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"清理失败: $e\"}";
    }
  }
}
