import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/app_package.dart';

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

  static bool get _isPackaged {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final pythonServer = p.join(
      exeDir,
      'backends',
      Platform.isWindows ? 'python_server.exe' : 'python_server',
    );
    return File(pythonServer).existsSync();
  }

  static String get venvPython {
    if (_isPackaged) {
      return p.join(
        p.dirname(Platform.resolvedExecutable),
        'backends',
        Platform.isWindows ? 'python_server.exe' : 'python_server',
      );
    }
    final candidate = p.join(_projectRoot, 'python', '.venv', 'bin', 'python');
    return File(candidate).existsSync() ? candidate : 'python';
  }

  static String get scriptPath {
    if (_isPackaged) return ""; // In packaged mode, venvPython IS the script
    return p.join(_projectRoot, 'python', 'main.py');
  }

  static String get workingDir {
    if (_isPackaged) return p.dirname(Platform.resolvedExecutable);
    return p.join(_projectRoot, 'python');
  }

  String get _venvPython => venvPython;
  String get _scriptPath => scriptPath;
  String get _workingDir => workingDir;

  List<String> _buildArgs(List<String> baseArgs) {
    if (_isPackaged) {
      return baseArgs;
    } else {
      return [_scriptPath, ...baseArgs];
    }
  }

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

  // Dynamic Sidebar items
  static final ValueNotifier<List<Map<String, dynamic>>> sidebarItems =
      ValueNotifier([
        {'title': 'Explore', 'icon': 'apps_rounded', 'index': 0},
        {'title': 'Categories', 'icon': 'grid_view_rounded', 'index': 1},
        {'title': 'Installed', 'icon': 'inventory_2_rounded', 'index': 5},
        {'title': 'GitHub Store', 'icon': 'code_rounded', 'index': 6},
        {'title': 'Flatpak Store', 'icon': 'shopping_bag_rounded', 'index': 7},
      ]);

  static Process? activeProcess;
  static Process? activeSearchProcess;

  /// Safe wrapper for Process.run with mandatory timeout and exception handling.
  Future<ProcessResult?> _safeRun(List<String> args,
      {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
      ).timeout(timeout);

      if (result.exitCode != 0) {
        debugPrint(
          "BackendService._safeRun failed (code ${result.exitCode}) [args: $args]: ${result.stderr}",
        );
      }
      return result;
    } catch (e) {
      debugPrint("BackendService._safeRun Exception [args: $args]: $e");
      return null;
    }
  }

  /// Safe wrapper for Process.start with exception handling.
  Future<Process?> _safeStart(List<String> args) async {
    try {
      return await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
      );
    } catch (e) {
      debugPrint("BackendService._safeStart Exception [args: $args]: $e");
      return null;
    }
  }

  /// Safe wrapper for Process.start that returns a stream and handles process lifecycle.
  Stream<String> _safeStream(List<String> args) async* {
    Process? process;
    final controller = StreamController<String>();

    try {
      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
      );

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (data) {
          if (!controller.isClosed) controller.add(data);
        },
        onError: (e) {
          debugPrint("Process [${args.firstOrNull}] Stdout Error: $e");
          if (!controller.isClosed) {
            controller.add("[CALLBACK] {\"log\": \"[ERROR] 数据流异常: $e\"}");
          }
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );

      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Process [${args.firstOrNull}] Stderr: $data");
      });

      controller.onCancel = () {
        debugPrint("Stream cancelled, killing process [${args.firstOrNull}]");
        process?.kill();
        process = null;
      };

      yield* controller.stream;
    } catch (e) {
      debugPrint("BackendService._safeStream Exception [args: $args]: $e");
      yield "[CALLBACK] {\"log\": \"[ERROR] 启动进程失败: $e\"}";
      if (!controller.isClosed) controller.close();
    }
  }

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

  /// 搜索逻辑 (Harden with timeouts and robust process management)
  Future<List<dynamic>> searchPackages(
    String query, {
    bool cancelOngoing = true,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    // Cancel any ongoing search to prevent race conditions
    if (cancelOngoing && activeSearchProcess != null) {
      try {
        activeSearchProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      activeSearchProcess = null;
    }

    Process? process = await _safeStart(["-S", trimmedQuery, "--json"]);
    if (process == null) return [];

    try {
      if (cancelOngoing) activeSearchProcess = process;

      final results = <dynamic>[];
      final stream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: (sink) {
              debugPrint("searchPackages: stream timeout");
              process.kill(ProcessSignal.sigkill);
              sink.close();
            },
          );

      await for (final line in stream) {
        final parsed = _tryParseJson(line);
        if (parsed is List) {
          results.addAll(parsed);
        } else if (parsed is Map) {
          results.add(parsed);
        }
      }

      return results;
    } catch (e) {
      debugPrint("searchPackages Exception: $e");
      return [];
    } finally {
      if (activeSearchProcess == process) activeSearchProcess = null;
    }
  }

  /// Robust JSON parsing that finds the first JSON block or array
  dynamic _tryParseJson(String input) {
    if (input.trim().isEmpty) return null;
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

      // 4. Fallback: Find the last { ... } block
      final startBrace = target.lastIndexOf('{');
      final endBrace = target.lastIndexOf('}');
      if (startBrace != -1 && endBrace != -1 && endBrace > startBrace) {
        try {
          return jsonDecode(target.substring(startBrace, endBrace + 1));
        } catch (e) {
          debugPrint("Failed to parse extracted JSON object: $e");
        }
      }

      return null;
    }
  }

  /// 获取已安装列表
  Future<List<dynamic>> listInstalled() async {
    final result = await _safeRun(["-L", "--json"],
        timeout: const Duration(seconds: 30));
    if (result == null || result.exitCode != 0) return [];

    final parsed = _tryParseJson(result.stdout.toString());
    return parsed is List ? parsed : [];
  }

  Future<Map<String, dynamic>> loadConfig() async {
    final result = await _safeRun(
      ["--get-config", "--json"],
      timeout: const Duration(seconds: 15),
    );
    if (result == null || result.exitCode != 0) return {};

    final data = _tryParseJson(result.stdout.toString());
    if (data is! Map<String, dynamic>) return {};

    // Update global AI status
    final ai = data['ai'] as Map<String, dynamic>?;
    isAIEnabled.value = ai?['enabled'] ?? false;

    return data;
  }

  /// AI 解释应用
  Future<String> aiExplain(String appName, String description) async {
    if (appName.trim().isEmpty) return "Error: appName is empty";
    final result = await _safeRun(
      ["--ai-explain", appName, "--ai-desc", description, "--json"],
      timeout: const Duration(seconds: 60),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 更新内容总结
  Future<String> aiSummarizeUpdate(
    String name,
    String current,
    String next,
  ) async {
    if (name.trim().isEmpty) return "Error: name is empty";
    final result = await _safeRun(
      ["--ai-changelog", "$name,$current,$next", "--json"],
      timeout: const Duration(seconds: 45),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI CLI 命令生成
  Future<String> aiGenerateCLI(String name, String source) async {
    if (name.trim().isEmpty) return "";
    final result = await _safeRun(
      ["--ai-cli", "$name,$source", "--json"],
      timeout: const Duration(seconds: 20),
    );
    if (result == null) return "";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "";
    return "";
  }

  /// AI 冲突检测
  Future<String> aiDetectConflicts(String name) async {
    if (name.trim().isEmpty) return "Error: name is empty";
    final result = await _safeRun(
      ["--ai-conflicts", name, "--json"],
      timeout: const Duration(seconds: 45),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 每日推荐
  Future<String> aiPickOfTheDay() async {
    final result = await _safeRun(
      ["--ai-pick", "--json"],
      timeout: const Duration(seconds: 30),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 搜索纠错
  Future<String> aiSuggestCorrection(String query) async {
    if (query.trim().isEmpty) return "";
    final result = await _safeRun(
      ["--ai-correct", query, "--json"],
      timeout: const Duration(seconds: 15),
    );
    if (result == null) return "";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "";
    return "";
  }

  /// AI 版本比较
  Future<String> aiCompareVariants(String appName) async {
    if (appName.trim().isEmpty) return "Error: appName is empty";
    final result = await _safeRun(
      ["--ai-compare", appName, "--json"],
      timeout: const Duration(seconds: 45),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 系统健康报告
  Future<String> aiSystemHealth() async {
    final result = await _safeRun(
      ["--ai-health", "--json"],
      timeout: const Duration(seconds: 45),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 分析错误
  Future<String> aiAnalyzeError(String errorLog) async {
    if (errorLog.trim().isEmpty) return "Error: errorLog is empty";
    final result = await _safeRun(
      ["--ai-analyze-error", errorLog, "--json"],
      timeout: const Duration(seconds: 45),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  /// AI 推荐应用
  Future<String> aiRecommend(String prompt) async {
    if (prompt.trim().isEmpty) return "Error: prompt is empty";
    final result = await _safeRun(
      ["--ai-recommend", prompt, "--json"],
      timeout: const Duration(seconds: 60),
    );
    if (result == null) return "AI Error: execution failed";

    final data = _tryParseJson(result.stdout.toString());
    if (data is Map) return data['response'] ?? "AI Error: No response";
    return "AI Error: Invalid response format";
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final process = await _safeStart(["--set-config", "stdin", "--json"]);
      if (process == null) return false;

      process.stdin.write(jsonEncode(config));
      await process.stdin.close();

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 10),
      );
      return exitCode == 0;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    final result = await _safeRun(
      ["--check-env", "--json"],
      timeout: const Duration(seconds: 15),
    );
    if (result == null) return {};

    final data = _tryParseJson(result.stdout.toString());
    return data is Map<String, dynamic> ? data : {};
  }

  Stream<String> bootstrap() => _safeStream(["--bootstrap", "--json"]);

  /// 获取动态推荐 (已分类)
  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    final result = await _safeRun(["--recommend", "--json"],
        timeout: const Duration(seconds: 20));
    if (result == null || result.exitCode != 0) return {};

    final output = result.stdout.toString().trim();
    if (output.isEmpty) return {};

    try {
      final dynamic data = jsonDecode(output);
      if (data is Map<String, dynamic>) {
        final Map<String, List<AppPackage>> categories = {};
        data.forEach((key, value) {
          if (value is List) {
            categories[key] = value
                .map(
                  (item) => AppPackage.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          }
        });
        return categories;
      } else if (data is List) {
        return {
          "featured": data
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
    } catch (e) {
      debugPrint("getRecommendations JSON parse error: $e");
    }
    return {};
  }

  /// 启动应用
  Future<bool> launchApp(String name, String source) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--launch", name, "--source", source, "--json"]),
        workingDirectory: _workingDir,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 定位应用
  Future<bool> locateApp(String name, String source) async {
    if (name.trim().isEmpty) return false;
    final result = await _safeRun(
      ["--launch", name, "--source", source, "--json"],
      timeout: const Duration(seconds: 15),
    );
    return result?.exitCode == 0;
  }

  /// 获取应用详情 (从 Flathub 等外部源)
  Future<Map<String, dynamic>> getAppDetails(String appId) async {
    final trimmedId = appId.trim();
    if (trimmedId.isEmpty) return {};

    final result = await _safeRun(["--details", trimmedId, "--json"],
        timeout: const Duration(seconds: 20));
    if (result == null || result.exitCode != 0) return {};

    final data = _tryParseJson(result.stdout.toString());
    return data is Map<String, dynamic> ? data : {};
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
    final trimmedPkg = packageName.trim();
    if (trimmedPkg.isEmpty) {
      yield "[CALLBACK] {\"log\": \"错误：包名不能为空\"}";
      return;
    }

    List<String> args = [flag, trimmedPkg, "--source", source, "--json"];
    if (url != null && url.trim().isNotEmpty) {
      args.addAll(["--url", url.trim()]);
    }

    yield* _safeStream(args);
  }

  /// 检查更新
  Future<List<dynamic>> checkUpdates() async {
    final result = await _safeRun(["-C", "--json"],
        timeout: const Duration(seconds: 45));
    if (result == null || result.exitCode != 0) return [];

    final parsed = _tryParseJson(result.stdout.toString());
    return parsed is List ? parsed : [];
  }

  /// 更新所有
  Stream<String> updateAll(String source) =>
      _safeStream(["-U", "all", "--source", source, "--json"]);

  /// 获取必备包
  Future<List<dynamic>> getEssentials() async {
    final result = await _safeRun(
      ["--essentials", "--json"],
      timeout: const Duration(seconds: 15),
    );
    if (result == null || result.exitCode != 0) return [];
    final data = _tryParseJson(result.stdout.toString());
    return data is List ? data : [];
  }

  /// 导入包
  Future<List<dynamic>> importPackages(String filepath) async {
    if (filepath.trim().isEmpty) return [];
    final result = await _safeRun(
      ["--import-packages", filepath, "--json"],
      timeout: const Duration(seconds: 15),
    );
    if (result == null || result.exitCode != 0) return [];
    final data = _tryParseJson(result.stdout.toString());
    return data is List ? data : [];
  }

  /// 导出包列表
  Future<Map<String, dynamic>> exportPackages(String filepath) async {
    if (filepath.trim().isEmpty) return {"status": "error", "message": "empty path"};
    final result = await _safeRun(
      ["--export-packages", filepath],
      timeout: const Duration(seconds: 20),
    );
    if (result == null || result.exitCode != 0) {
      return {"status": "error", "message": "execution failed"};
    }
    final data = _tryParseJson(result.stdout.toString());
    return data is Map<String, dynamic> ? data : {"status": "error"};
  }

  /// 清理系统（孤立包和缓存）
  Stream<String> cleanSystem() => _safeStream(["--clean-system", "--json"]);
}
