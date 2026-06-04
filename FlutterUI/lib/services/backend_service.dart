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
    if (_isPackaged) return "";
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

  // Reactive State Notifiers
  static final ValueNotifier<double?> globalProgress = ValueNotifier(null);
  static final ValueNotifier<String> globalStatus = ValueNotifier("Ready");
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  static final ValueNotifier<bool> isAIEnabled = ValueNotifier(false);
  static final ValueNotifier<AppPackage?> activeApp = ValueNotifier(null);
  static final ValueNotifier<String?> activeFlag = ValueNotifier(null);
  static final ValueNotifier<List<String>> globalLogs = ValueNotifier([]);
  static final ValueNotifier<int> navigationIndex = ValueNotifier(0);
  static final ValueNotifier<String?> pendingSearchQuery = ValueNotifier(null);

  static Process? activeProcess;
  static Process? activeSearchProcess;

  /// Kill a process and its children using process groups on Linux.
  Future<void> _killProcess(Process? process) async {
    if (process == null) return;
    try {
      if (Platform.isLinux) {
        // Send SIGTERM to the entire process group
        await Process.run('kill', ['-TERM', '-${process.pid}']);
        // Wait a bit and force kill if still alive
        await Future.delayed(const Duration(milliseconds: 500));
        await Process.run('kill', ['-KILL', '-${process.pid}']);
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      debugPrint("Error killing process ${process.pid}: $e");
      process.kill(ProcessSignal.sigkill); // Fallback
    }
  }

  /// Safe wrapper for Process.run with mandatory timeout and exception handling.
  Future<ProcessResult?> _safeRun(List<String> args,
      {Duration timeout = const Duration(seconds: 30)}) async {
    // 防呆：检查执行环境
    if (!File(_venvPython).existsSync() && _venvPython != 'python') {
      debugPrint("Backend Error: Python executable not found at $_venvPython");
      return null;
    }

    try {
      return await Process.run(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
      ).timeout(timeout, onTimeout: () {
        debugPrint("BackendService._safeRun Timeout: $args");
        throw TimeoutException("Operation timed out after ${timeout.inSeconds}s");
      });
    } catch (e) {
      debugPrint("BackendService._safeRun Exception [args: $args]: $e");
      return null;
    }
  }

  /// Safe wrapper for Process.start returns a stream and handles process lifecycle.
  Stream<String> _safeStream(List<String> args) async* {
    Process? process;
    final controller = StreamController<String>();

    try {
      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
        runInShell: true, // Needed for proper signal propagation in some environments
      );

      // Bind to global lifecycle
      activeProcess = process;

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (data) {
          if (!controller.isClosed) controller.add(data);
        },
        onError: (e) {
          debugPrint("Process Stdout Error: $e");
          if (!controller.isClosed) {
            controller.add("[CALLBACK] {\"log\": \"[ERROR] 致命数据流异常: $e\"}");
          }
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
          if (activeProcess == process) activeProcess = null;
        },
      );

      process.stderr.transform(utf8.decoder).listen((data) => debugPrint("Backend Stderr: $data"));

      controller.onCancel = () async {
        debugPrint("Stream cancelled, performing deep cleanup for process ${process?.pid}");
        await _killProcess(process);
        if (activeProcess == process) activeProcess = null;
      };

      yield* controller.stream;
    } catch (e) {
      debugPrint("BackendService._safeStream Exception: $e");
      yield "[CALLBACK] {\"log\": \"[ERROR] 进程启动失败，请检查环境配置: $e\"}";
      if (!controller.isClosed) controller.close();
    }
  }

  static void addLog(String log) {
    final currentLogs = globalLogs.value;
    if (currentLogs.length > 1000) {
      globalLogs.value = [...currentLogs.sublist(currentLogs.length - 999), log];
    } else {
      globalLogs.value = [...currentLogs, log];
    }
  }

  static void clearLogs() => globalLogs.value = [];

  static Future<void> cancelCurrentTask() async {
    if (activeProcess != null) {
      await BackendService.instance._killProcess(activeProcess);
      activeProcess = null;
      isDownloading.value = false;
      globalStatus.value = "任务已强制终止";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  Future<List<dynamic>> searchPackages(String query, {bool cancelOngoing = true}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

    if (cancelOngoing && activeSearchProcess != null) {
      await _killProcess(activeSearchProcess);
      activeSearchProcess = null;
    }

    try {
      final process = await Process.start(_venvPython, _buildArgs(["-S", trimmedQuery, "--json"]), workingDirectory: _workingDir);
      activeSearchProcess = process;

      final results = <dynamic>[];
      final output = await process.stdout.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));

      final parsed = _tryParseJson(output);
      if (parsed is List) {
        results.addAll(parsed);
      } else if (parsed != null) {
        results.add(parsed);
      }

      return results;
    } catch (e) {
      debugPrint("searchPackages Error: $e");
      return [];
    } finally {
      activeSearchProcess = null;
    }
  }

  dynamic _tryParseJson(String input) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;
    try {
      return jsonDecode(cleanInput);
    } catch (_) {
      // Defensive: search for valid JSON blocks if output is noisy
      final jsonPattern = RegExp(r'(\[.*\]|\{.*\})', dotAll: true);
      final matches = jsonPattern.allMatches(cleanInput);
      if (matches.isNotEmpty) {
        final match = matches.last;
        try {
          return jsonDecode(match.group(0)!);
        } catch (e) {
          debugPrint("Defensive JSON parse failed: $e");
        }
      }
      return null;
    }
  }

  Future<List<dynamic>> listInstalled() async {
    final res = await _safeRun(["-L", "--json"], timeout: const Duration(seconds: 45));
    if (res == null || res.exitCode != 0) return [];
    final data = _tryParseJson(res.stdout.toString());
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> loadConfig() async {
    final res = await _safeRun(["--get-config", "--json"], timeout: const Duration(seconds: 15));
    if (res == null) return {};
    final data = _tryParseJson(res.stdout.toString());
    if (data is Map<String, dynamic>) {
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    return {};
  }

  Future<String> _aiCall(List<String> args, {Duration timeout = const Duration(seconds: 60)}) async {
    final res = await _safeRun([...args, "--json"], timeout: timeout);
    if (res == null) return "AI 连接超时，请稍后重试。";
    final data = _tryParseJson(res.stdout.toString());
    return (data is Map) ? (data['response'] ?? "AI 未能提供有效响应。") : "AI 响应解析失败。";
  }

  Future<String> aiExplain(String name, String desc) => _aiCall(["--ai-explain", name, "--ai-desc", desc]);
  Future<String> aiSummarizeUpdate(String n, String c, String next) => _aiCall(["--ai-changelog", "$n,$c,$next"]);
  Future<String> aiGenerateCLI(String n, String s) => _aiCall(["--ai-cli", "$n,$s"], timeout: const Duration(seconds: 20));
  Future<String> aiDetectConflicts(String n) => _aiCall(["--ai-conflicts", n]);
  Future<String> aiPickOfTheDay() => _aiCall(["--ai-pick"]);
  Future<String> aiSuggestCorrection(String q) => _aiCall(["--ai-correct", q], timeout: const Duration(seconds: 15));
  Future<String> aiCompareVariants(String n) => _aiCall(["--ai-compare", n]);
  Future<String> aiSystemHealth() => _aiCall(["--ai-health"]);
  Future<String> aiAnalyzeError(String log) => _aiCall(["--ai-analyze-error", log]);
  Future<String> aiRecommend(String p) => _aiCall(["--ai-recommend", p], timeout: const Duration(seconds: 90));

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final process = await Process.start(_venvPython, _buildArgs(["--set-config", "stdin", "--json"]), workingDirectory: _workingDir);
      process.stdin.write(jsonEncode(config));
      await process.stdin.close();
      final code = await process.exitCode.timeout(const Duration(seconds: 10));
      return code == 0;
    } catch (e) {
      debugPrint("saveConfig Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    final res = await _safeRun(["--check-env", "--json"], timeout: const Duration(seconds: 15));
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return (data is Map<String, dynamic>) ? data : {};
  }

  Stream<String> bootstrap() => _safeStream(["--bootstrap", "--json"]);

  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    final res = await _safeRun(["--recommend", "--json"], timeout: const Duration(seconds: 30));
    if (res == null) return {};
    final data = _tryParseJson(res.stdout.toString());
    final Map<String, List<AppPackage>> result = {};
    if (data is Map) {
      data.forEach((k, v) {
        if (v is List) {
          result[k] = v.map((i) => AppPackage.fromJson(i as Map<String, dynamic>)).toList();
        }
      });
    } else if (data is List) {
      result["featured"] = data.map((i) => AppPackage.fromJson(i as Map<String, dynamic>)).toList();
    }
    return result;
  }

  Future<bool> launchApp(String n, String s) async {
    final res = await _safeRun(["--launch", n, "--source", s, "--json"], timeout: const Duration(seconds: 10));
    return res?.exitCode == 0;
  }

  Future<bool> locateApp(String n, String s) async {
    final res = await _safeRun(["--locate", n, "--source", s, "--json"], timeout: const Duration(seconds: 10));
    return res?.exitCode == 0;
  }

  Future<Map<String, dynamic>> getAppDetails(String id) async {
    final res = await _safeRun(["--details", id, "--json"], timeout: const Duration(seconds: 25));
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return (data is Map<String, dynamic>) ? data : {};
  }

  Stream<String> executeAction(String f, String n, String s, {String? url}) {
    if (n.trim().isEmpty) return Stream.value("[CALLBACK] {\"log\": \"[ERROR] 应用名称不能为空\"}");
    List<String> args = [f, n, "--source", s, "--json"];
    if (url != null && url.isNotEmpty) args.addAll(["--url", url]);
    return _safeStream(args);
  }

  Future<List<dynamic>> checkUpdates() async {
    final res = await _safeRun(["-C", "--json"], timeout: const Duration(seconds: 60));
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return data is List ? data : [];
  }

  Stream<String> updateAll(String s) => _safeStream(["-U", "all", "--source", s, "--json"]);

  Future<List<dynamic>> getEssentials() async {
    final res = await _safeRun(["--essentials", "--json"]);
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return data is List ? data : [];
  }

  Future<List<dynamic>> importPackages(String path) async {
    final res = await _safeRun(["--import-packages", path, "--json"]);
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    final res = await _safeRun(["--export-packages", path, "--json"], timeout: const Duration(seconds: 30));
    final data = _tryParseJson(res?.stdout?.toString() ?? "");
    return (data is Map<String, dynamic>) ? data : {"status": "error"};
  }

  Stream<String> cleanSystem() => _safeStream(["--clean-system", "--json"]);
}
