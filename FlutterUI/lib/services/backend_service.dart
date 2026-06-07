import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/package_repository.dart';
import '../data/repositories/task_repository.dart';
import '../../models/app_package.dart';

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;
  BackendService._internal();

  // Registry for tracking all active subprocesses to prevent leaks
  final Set<Process> _allProcesses = {};

  // Murphy-proof: Global lock to prevent race conditions in I/O operations
  Completer<void>? _globalLock;

  static String get _projectRoot {
    if (kIsWeb) return '';
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
    if (kIsWeb) return false;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final pythonServer = p.join(
      exeDir,
      'backends',
      Platform.isWindows ? 'python_server.exe' : 'python_server',
    );
    return File(pythonServer).existsSync();
  }

  static String get venvPython {
    if (kIsWeb) return '';
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
    if (kIsWeb) return '';
    if (_isPackaged) return "";
    return p.join(_projectRoot, 'python', 'main.py');
  }

  static String get workingDir {
    if (kIsWeb) return '';
    if (_isPackaged) return p.dirname(Platform.resolvedExecutable);
    return p.join(_projectRoot, 'python');
  }

  String get _venvPython => venvPython;
  String get _scriptPath => scriptPath;
  String get _workingDir => workingDir;

  List<String> _buildArgs(List<String> baseArgs) {
    if (kIsWeb) return [];
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
  static final ValueNotifier<List<Map<String, dynamic>>> availableSources =
      ValueNotifier([]);

  static Process? activeProcess;
  static Process? activeSearchProcess;

  // Foolproof validation helpers
  void _validateString(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
  }

  void _validatePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw ArgumentError("Path cannot be null or empty");
    }
    // Basic protection against obvious malicious shell injections in paths if they ever reach a shell
    if (path.contains(';') || path.contains('&') || path.contains('|')) {
      throw ArgumentError("Invalid characters in path");
    }
  }

  /// Murphy-proof: Acquire global lock with timeout to prevent deadlocks
  Future<bool> _acquireLock({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    while (_globalLock != null) {
      await _globalLock!.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException("Could not acquire operation lock"),
      );
    }
    _globalLock = Completer<void>();
    return true;
  }

  void _releaseLock() {
    final lock = _globalLock;
    _globalLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();
  }

  /// Kill a process and its children using process groups on Linux.
  Future<void> _killProcess(Process? process) async {
    if (kIsWeb || process == null) return;
    _allProcesses.remove(process);
    try {
      if (Platform.isLinux) {
        // Send SIGTERM to the entire process group (negative PID)
        // Note: Using negative PID kills the process group if it was started in a new group.
        // Process.start with runInShell: true usually handles this well on Linux.
        await Process.run('kill', ['-TERM', '-${process.pid}']);
        // Wait a bit and force kill if still alive
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isProcessAlive(process)) {
          await Process.run('kill', ['-KILL', '-${process.pid}']);
        }
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      debugPrint("Error killing process ${process.pid}: $e");
      process.kill(ProcessSignal.sigkill); // Fallback
    }
  }

  bool _isProcessAlive(Process p) {
    if (kIsWeb) return false;
    try {
      // On Linux/Unix, signal 0 checks if process exists
      if (Platform.isLinux || Platform.isMacOS) {
        return Process.runSync('kill', ['-0', '${p.pid}']).exitCode == 0;
      }
    } catch (_) {}
    return true; // Assume alive if check fails
  }

  /// Emergency cleanup of all tracked processes
  Future<void> dispose() async {
    if (kIsWeb) return;
    final processes = List<Process>.from(_allProcesses);
    for (final p in processes) {
      await _killProcess(p);
    }
    _allProcesses.clear();
  }

  /// Safe wrapper for Process.run with mandatory timeout and exception handling.
  /// Refactored to use Process.start for absolute lifecycle tracking.
  Future<ProcessResult?> _safeRun(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
    bool useLock = false,
  }) async {
    if (kIsWeb) return null;
    // 防呆：检查执行环境
    if (!File(_venvPython).existsSync() && _venvPython != 'python') {
      debugPrint("Backend Error: Python executable not found at $_venvPython");
      return null;
    }

    if (useLock) await _acquireLock();

    Process? process;
    try {
      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
      );
      _allProcesses.add(process);

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      final exitCode = await process.exitCode.timeout(timeout);
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      return ProcessResult(process.pid, exitCode, stdout, stderr);
    } catch (e) {
      debugPrint("BackendService._safeRun Exception [args: $args]: $e");
      if (process != null) await _killProcess(process);
      return null;
    } finally {
      if (process != null) _allProcesses.remove(process);
      if (useLock) _releaseLock();
    }
  }

  /// Safe wrapper for Process.start returns a stream and handles process lifecycle.
  Stream<String> _safeStream(List<String> args, {bool useLock = true}) async* {
    if (kIsWeb) {
      yield "[CALLBACK] {\"log\": \"Running in browser sandbox\"}";
      return;
    }
    if (useLock) await _acquireLock();

    Process? process;
    final controller = StreamController<String>();

    try {
      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
        runInShell: true,
      );
      _allProcesses.add(process);

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
                controller.add(
                  "[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$e\"}",
                );
              }
            },
            onDone: () {
              if (process != null) _allProcesses.remove(process);
              if (!controller.isClosed) controller.close();
              if (activeProcess == process) activeProcess = null;
            },
          );

      process.stderr
          .transform(utf8.decoder)
          .listen((data) => debugPrint("Backend Stderr: $data"));

      controller.onCancel = () async {
        debugPrint(
          "Stream cancelled, performing deep cleanup for process ${process?.pid}",
        );
        await _killProcess(process);
        if (activeProcess == process) activeProcess = null;
      };

      yield* controller.stream;
    } catch (e) {
      debugPrint("BackendService._safeStream Exception: $e");
      yield "[CALLBACK] {\"key\": \"errorProcessStart\", \"error\": \"$e\"}";
      if (!controller.isClosed) controller.close();
    } finally {
      if (useLock) _releaseLock();
    }
  }

  static void addLog(String log) {
    final currentLogs = globalLogs.value;
    if (currentLogs.length > 1000) {
      globalLogs.value = [
        ...currentLogs.sublist(currentLogs.length - 999),
        log,
      ];
    } else {
      globalLogs.value = [...currentLogs, log];
    }
  }

  static void clearLogs() => globalLogs.value = [];

  static Future<void> cancelCurrentTask() async {
    if (kIsWeb) {
      isDownloading.value = false;
      globalStatus.value = "任务已取消";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
      return;
    }
    if (activeProcess != null) {
      await BackendService.instance._killProcess(activeProcess);
      activeProcess = null;
      isDownloading.value = false;
      globalStatus.value =
          ""; // Localized via TaskController/TaskManager // Key-like marker
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  Future<List<dynamic>> searchPackages(
    String query, {
    bool cancelOngoing = true,
  }) async {
    if (kIsWeb) {
      return PackageRepository().searchPackages(
        query,
        cancelOngoing: cancelOngoing,
      );
    }
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.length < 2) return [];

      if (cancelOngoing && activeSearchProcess != null) {
        await _killProcess(activeSearchProcess);
        activeSearchProcess = null;
      }

      final process = await Process.start(
        _venvPython,
        _buildArgs(["-S", trimmedQuery, "--json"]),
        workingDirectory: _workingDir,
      );
      _allProcesses.add(process);
      activeSearchProcess = process;

      final results = <dynamic>[];
      final output = await process.stdout
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));

      final parsed = _tryParseJson(output);
      if (parsed is List) {
        results.addAll(parsed);
      } else if (parsed != null) {
        results.add(parsed);
      }

      return results;
    } catch (e) {
      debugPrint("searchPackages [query: $query] Error: $e");
      return [];
    } finally {
      if (activeSearchProcess != null)
        _allProcesses.remove(activeSearchProcess);
      activeSearchProcess = null;
    }
  }

  dynamic _tryParseJson(String input) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    try {
      return jsonDecode(cleanInput);
    } catch (_) {}

    try {
      final jsonPattern = RegExp(r'(\[.*\]|\{.*\})', dotAll: true);
      final matches = jsonPattern.allMatches(cleanInput);

      for (final match in matches.toList().reversed) {
        final candidate = match.group(0)!;
        try {
          return jsonDecode(candidate);
        } catch (_) {
          final lines = candidate.split('\n');
          for (var i = 0; i < lines.length; i++) {
            try {
              final lineCandidate = lines.sublist(i).join('\n');
              return jsonDecode(lineCandidate);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("Murphy-proof JSON recovery failed: $e");
    }

    return null;
  }

  Future<List<dynamic>> listInstalled() async {
    if (kIsWeb) {
      return PackageRepository().listInstalled();
    }
    try {
      final res = await _safeRun([
        "-L",
        "--json",
      ], timeout: const Duration(seconds: 45));
      if (res == null || res.exitCode != 0) return [];
      final data = _tryParseJson(res.stdout.toString());
      return data is List ? data : [];
    } catch (e) {
      debugPrint("listInstalled Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    if (kIsWeb) {
      final data = await ConfigRepository().loadConfig();
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    try {
      final res = await _safeRun([
        "--get-config",
        "--json",
      ], timeout: const Duration(seconds: 15));
      if (res == null) return {};
      final data = _tryParseJson(res.stdout.toString());
      if (data is Map<String, dynamic>) {
        isAIEnabled.value = data['ai']?['enabled'] ?? false;
        return data;
      }
      return {};
    } catch (e) {
      debugPrint("loadConfig Error: $e");
      return {};
    }
  }

  Future<String> _aiCall(
    List<String> args, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      return "This is a simulated AI response on web.";
    }
    try {
      final res = await _safeRun([...args, "--json"], timeout: timeout);
      if (res == null) {
        return "⏱ AI request timed out. Please check your AI provider configuration in Settings → Advanced.";
      }
      final data = _tryParseJson(res.stdout.toString());
      if (data is Map) {
        return data['response']?.toString() ??
            "⚠ No response received from AI provider. Verify your endpoint and API key.";
      }
      return "⚠ Failed to parse AI response. The provider may have returned an unexpected format.";
    } catch (e) {
      debugPrint("_aiCall Error: $e");
      return "⚠ AI service error: ${e.toString().replaceAll(RegExp(r'Exception: '), '')}";
    }
  }

  Future<String> aiExplain(String name, String desc) =>
      _aiCall(["--ai-explain", name, "--ai-desc", desc]);
  Future<String> aiSummarizeUpdate(String n, String c, String next) =>
      _aiCall(["--ai-changelog", "$n,$c,$next"]);
  Future<String> aiGenerateCLI(String n, String s) =>
      _aiCall(["--ai-cli", "$n,$s"], timeout: const Duration(seconds: 20));
  Future<String> aiDetectConflicts(String n) => _aiCall(["--ai-conflicts", n]);
  Future<String> aiPickOfTheDay() => _aiCall(["--ai-pick"]);
  Future<String> aiSuggestCorrection(String q) =>
      _aiCall(["--ai-correct", q], timeout: const Duration(seconds: 15));
  Future<String> aiCompareVariants(String n) => _aiCall(["--ai-compare", n]);
  Future<String> aiSystemHealth() => _aiCall(["--ai-health"]);
  Future<String> aiAnalyzeError(String log) =>
      _aiCall(["--ai-analyze-error", log]);
  Future<String> aiRecommend(String p) =>
      _aiCall(["--ai-recommend", p], timeout: const Duration(seconds: 90));

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (kIsWeb) {
      isAIEnabled.value = config['ai']?['enabled'] ?? false;
      return ConfigRepository().saveConfig(config);
    }
    Process? process;
    await _acquireLock();
    try {
      if (config.isEmpty) return false;
      process = await Process.start(
        _venvPython,
        _buildArgs(["--set-config", "stdin", "--json"]),
        workingDirectory: _workingDir,
      );
      _allProcesses.add(process);
      process.stdin.write(jsonEncode(config));
      await process.stdin.close();
      final code = await process.exitCode.timeout(const Duration(seconds: 10));
      return code == 0;
    } catch (e) {
      debugPrint("saveConfig Error: $e");
      return false;
    } finally {
      if (process != null) _allProcesses.remove(process);
      _releaseLock();
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    if (kIsWeb) {
      return ConfigRepository().checkEnv();
    }
    try {
      final res = await _safeRun([
        "--check-env",
        "--json",
      ], timeout: const Duration(seconds: 15));
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {};
    } catch (e) {
      debugPrint("checkEnv Error: $e");
      return {};
    }
  }

  Stream<String> bootstrap() {
    if (kIsWeb) {
      return Stream.value(
        "[CALLBACK] {\"log\": \"[INFO] Web environment is already ready!\"}",
      );
    }
    return _safeStream(["--bootstrap", "--json"]);
  }

  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    if (kIsWeb) {
      return PackageRepository().getRecommendations();
    }
    try {
      final res = await _safeRun([
        "--recommend",
        "--json",
      ], timeout: const Duration(seconds: 30));
      if (res == null) return {};
      final data = _tryParseJson(res.stdout.toString());
      final Map<String, List<AppPackage>> result = {};
      if (data is Map) {
        data.forEach((k, v) {
          if (v is List) {
            result[k] = v
                .map((i) => AppPackage.fromJson(i as Map<String, dynamic>))
                .toList();
          }
        });
      } else if (data is List) {
        result["featured"] = data
            .map((i) => AppPackage.fromJson(i as Map<String, dynamic>))
            .toList();
      }
      return result;
    } catch (e) {
      debugPrint("getRecommendations Error: $e");
      return {};
    }
  }

  Future<bool> launchApp(String n, String s) async {
    if (kIsWeb) {
      return PackageRepository().launchApp(n, s);
    }
    try {
      _validateString(n, "App Name");
      _validateString(s, "Source");
      final res = await _safeRun([
        "--launch",
        n.trim(),
        "--source",
        s.trim(),
        "--json",
      ], timeout: const Duration(seconds: 10));
      return res?.exitCode == 0;
    } catch (e) {
      debugPrint("launchApp [name: $n] Error: $e");
      return false;
    }
  }

  Future<bool> locateApp(String n, String s) async {
    if (kIsWeb) {
      return PackageRepository().locateApp(n, s);
    }
    try {
      _validateString(n, "App Name");
      _validateString(s, "Source");
      final res = await _safeRun([
        "--locate",
        n.trim(),
        "--source",
        s.trim(),
        "--json",
      ], timeout: const Duration(seconds: 10));
      return res?.exitCode == 0;
    } catch (e) {
      debugPrint("locateApp [name: $n] Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> getAppDetails(String id) async {
    if (kIsWeb) {
      return PackageRepository().getAppDetails(id);
    }
    try {
      _validateString(id, "App ID");
      final res = await _safeRun([
        "--details",
        id.trim(),
        "--json",
      ], timeout: const Duration(seconds: 25));
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {};
    } catch (e) {
      debugPrint("getAppDetails [id: $id] Error: $e");
      return {};
    }
  }

  Stream<String> executeAction(String f, String n, String s, {String? url}) {
    if (kIsWeb) {
      return TaskRepository().executeAction(f, n, s, url: url);
    }
    if (n.trim().isEmpty)
      return Stream.value("[CALLBACK] {\"log\": \"[ERROR] 应用名称不能为空\"}");
    List<String> args = [f, n, "--source", s, "--json"];
    if (url != null && url.isNotEmpty) args.addAll(["--url", url]);
    return _safeStream(args);
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return TaskRepository().checkUpdates();
    }
    try {
      final res = await _safeRun([
        "-C",
        "--json",
      ], timeout: const Duration(seconds: 60));
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return data is List ? data : [];
    } catch (e) {
      debugPrint("checkUpdates Error: $e");
      return [];
    }
  }

  Stream<String> updateAll(String s) {
    if (kIsWeb) {
      return TaskRepository().updateAll(s);
    }
    try {
      _validateString(s, "Source");
      return _safeStream(["-U", "all", "--source", s.trim(), "--json"]);
    } catch (e) {
      return Stream.value(
        "[CALLBACK] {\"key\": \"errorUpdateAll\", \"error\": \"$e\"}",
      );
    }
  }

  Future<List<dynamic>> getEssentials() async {
    if (kIsWeb) {
      return PackageRepository().getEssentials();
    }
    try {
      final res = await _safeRun(["--essentials", "--json"]);
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return data is List ? data : [];
    } catch (e) {
      debugPrint("getEssentials Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> importPackages(String path) async {
    if (kIsWeb) {
      return PackageRepository().importPackages(path);
    }
    try {
      _validatePath(path);
      final res = await _safeRun(["--import-packages", path.trim(), "--json"]);
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return data is List ? data : [];
    } catch (e) {
      debugPrint("importPackages [path: $path] Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    if (kIsWeb) {
      return TaskRepository().exportPackages(path);
    }
    try {
      _validatePath(path);
      final res = await _safeRun([
        "--export-packages",
        path.trim(),
        "--json",
      ], timeout: const Duration(seconds: 30));
      final data = _tryParseJson(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {"status": "error"};
    } catch (e) {
      debugPrint("exportPackages [path: $path] Error: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) {
      return TaskRepository().cleanSystem();
    }
    return _safeStream(["--clean-system", "--json"]);
  }

  Future<bool> addCustomRepo(String type, String name, String url) async {
    if (kIsWeb) return true;
    try {
      final res = await _safeRun([
        "--add-custom-repo",
        "$type,$name,$url",
        "--json",
      ], timeout: const Duration(seconds: 20));
      return res?.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeCustomRepo(String type, String name) async {
    if (kIsWeb) return true;
    try {
      final res = await _safeRun([
        "--remove-custom-repo",
        "$type,$name",
        "--json",
      ], timeout: const Duration(seconds: 20));
      return res?.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
