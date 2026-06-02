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
    // Defensive check
    if (query.trim().isEmpty) return [];

    // Cancel any ongoing search to prevent race conditions
    if (cancelOngoing && activeSearchProcess != null) {
      try {
        activeSearchProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      activeSearchProcess = null;
    }

    Process? process;
    try {
      process = await Process.start(
        _venvPython,
        _buildArgs(["-S", query, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10));

      if (cancelOngoing) activeSearchProcess = process;

      final results = <dynamic>[];
      // Use a subscription to allow for explicit cancellation/timeout
      final stream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: (sink) {
              debugPrint("Search stream timed out");
              sink.close();
            },
          );

      await for (final line in stream) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          final parsed = _tryParseJson(trimmed);
          if (parsed is List) {
            results.addAll(parsed);
          }
        }
      }

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          try {
            process?.kill(ProcessSignal.sigkill);
          } catch (_) {}
          return -1;
        },
      );

      if (cancelOngoing) activeSearchProcess = null;

      if (exitCode != 0 && exitCode != -1) {
        debugPrint('searchPackages failed with code $exitCode');
      }

      return results;
    } catch (e) {
      if (cancelOngoing) activeSearchProcess = null;
      try {
        process?.kill(ProcessSignal.sigkill);
      } catch (_) {}
      debugPrint('searchPackages Exception: $e');
      return [];
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
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["-L", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) return [];
      final parsed = _tryParseJson(result.stdout.toString().trim());
      return parsed is List ? parsed : [];
    } catch (e) {
      debugPrint("ListInstalled Exception: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--get-config", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        debugPrint(
          "loadConfig failed with exit code ${result.exitCode}: ${result.stderr}",
        );
        return {};
      }
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};
      final data = jsonDecode(output);
      if (data is! Map<String, dynamic>) return {};

      final config = data;

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
      final result = await Process.run(
        _venvPython,
        _buildArgs([
          "--ai-explain",
          appName,
          "--ai-desc",
          description,
          "--json",
        ]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 60));
      final data = _tryParseJson(result.stdout.toString().trim());
      if (data is Map) return data['response'] ?? "AI Error: No response";
      return "AI Error: Invalid response format";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 更新内容总结
  Future<String> aiSummarizeUpdate(
    String name,
    String current,
    String next,
  ) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-changelog", "$name,$current,$next", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI CLI 命令生成
  Future<String> aiGenerateCLI(String name, String source) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-cli", "$name,$source", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "";
    } catch (e) {
      return "";
    }
  }

  /// AI 冲突检测
  Future<String> aiDetectConflicts(String name) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-conflicts", name, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 每日推荐
  Future<String> aiPickOfTheDay() async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-pick", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 搜索纠错
  Future<String> aiSuggestCorrection(String query) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-correct", query, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "";
    } catch (e) {
      return "";
    }
  }

  /// AI 版本比较
  Future<String> aiCompareVariants(String appName) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-compare", appName, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 系统健康报告
  Future<String> aiSystemHealth() async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-health", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 分析错误
  Future<String> aiAnalyzeError(String errorLog) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-analyze-error", errorLog, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  /// AI 推荐应用
  Future<String> aiRecommend(String prompt) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--ai-recommend", prompt, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 60));
      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final process = await Process.start(
        _venvPython,
        _buildArgs(["--set-config", "stdin", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 5));

      process.stdin.write(jsonEncode(config));
      await process.stdin.close();

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 5),
      );
      return exitCode == 0;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--check-env", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      return {};
    }
  }

  Stream<String> bootstrap() async* {
    try {
      final process = await Process.start(
        _venvPython,
        _buildArgs(["--bootstrap", "--json"]),
        workingDirectory: _workingDir,
      );

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
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--recommend", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) return {};
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};

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
        // 向后兼容旧的列表格式
        return {
          "featured": data
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return {};
    } catch (e) {
      debugPrint("Recommendations Exception: $e");
      return {};
    }
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
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--locate", name, "--source", source, "--json"]),
        workingDirectory: _workingDir,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取应用详情 (从 Flathub 等外部源)
  Future<Map<String, dynamic>> getAppDetails(String appId) async {
    try {
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--details", appId, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 20));
      final data = _tryParseJson(result.stdout.toString().trim());
      if (data is Map<String, dynamic>) return data;
      return {};
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
      List<String> baseArgs = [flag, packageName, "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        baseArgs.addAll(["--url", url]);
      }

      final process = await Process.start(
        _venvPython,
        _buildArgs(baseArgs),
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
      final result = await Process.run(
        _venvPython,
        _buildArgs(["-C", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 45));

      if (result.exitCode != 0) return [];
      final parsed = _tryParseJson(result.stdout.toString().trim());
      return parsed is List ? parsed : [];
    } catch (e) {
      debugPrint("CheckUpdates Exception: $e");
      return [];
    }
  }

  /// 更新所有
  Stream<String> updateAll(String source) async* {
    try {
      final process = await Process.start(
        _venvPython,
        _buildArgs(["-U", "all", "--source", source, "--json"]),
        workingDirectory: _workingDir,
      );

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
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--essentials", "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10));

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
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--import-packages", filepath, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10));

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
      final result = await Process.run(
        _venvPython,
        _buildArgs(["--export-packages", filepath]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 15));

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
      final process = await Process.start(
        _venvPython,
        _buildArgs(["--clean-system", "--json"]),
        workingDirectory: _workingDir,
      );

      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"清理失败: $e\"}";
    }
  }
}
