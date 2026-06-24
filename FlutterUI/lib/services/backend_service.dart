import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/package_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/python_bridge.dart';
import '../../models/app_package.dart';
import 'backend/process_registry.dart';
import 'backend/daemon_client.dart';
import 'backend/platform_environment.dart';
import 'backend/execution_queue.dart';

export 'backend/daemon_client.dart' show DaemonResult;

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;

  late final ProcessRegistry _processRegistry;
  late final DaemonClient _daemonClient;
  late final PlatformEnvironment _env;
  late final ExecutionQueue _executionQueue;

  BackendService._internal() {
    _processRegistry = ProcessRegistry();
    _env = PlatformEnvironment.instance;
    _executionQueue = ExecutionQueue();
    _daemonClient = DaemonClient(onDemandStart: _startDaemonIfNeeded);
  }

  // Registry for tracking active subprocesses (migrated to _processRegistry)
  // Murphy-proof: Global lock for local IO operations
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

  // Murphy-proof: Circuit Breaker states for failing components
  bool _daemonCircuitBroken = false;
  int _daemonFailureCount = 0;
  DateTime? _lastDaemonFailureTime;

  static Process? activeProcess;
  static Process? activeSearchProcess;

  Future<void> _killProcess(Process? process) async {
    await _processRegistry.kill(process);
  }

  Future<void> dispose() async {
    if (kIsWeb) return;

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    await _daemonClient.dispose();
    await _processRegistry.dispose();

    activeProcess = null;
    activeSearchProcess = null;
    _daemonProcess = null;
    _executionQueue.reset();
  }

  Process? _daemonProcess;
  Timer? _healthCheckTimer;
  int _daemonRestartCount = 0;
  DateTime? _lastDaemonStartTime;

  Future<Process?> _startDaemonIfNeeded() async {
    if (kIsWeb) return null;
    if (_daemonCircuitBroken) {
      if (DateTime.now().difference(_lastDaemonFailureTime!) > const Duration(minutes: 2)) {
        debugPrint("Circuit Breaker: Attempting to reset daemon after cooldown.");
        _daemonCircuitBroken = false;
        _daemonFailureCount = 0;
      } else {
        return null;
      }
    }

    if (_daemonProcess != null) {
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          final res = await Process.run('kill', ['-0', '${_daemonProcess!.pid}']);
          if (res.exitCode == 0) return _daemonProcess;
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    if (_lastDaemonStartTime != null &&
        now.difference(_lastDaemonStartTime!) < const Duration(seconds: 5)) {
      _daemonRestartCount++;
      if (_daemonRestartCount > 3) {
        debugPrint("Murphy-proof Warning: Daemon restart loop detected. Tripping Circuit Breaker.");
        _daemonCircuitBroken = true;
        _lastDaemonFailureTime = now;
        return null;
      }
    } else {
      _daemonRestartCount = 0;
    }
    _lastDaemonStartTime = now;

    final home = Platform.environment['HOME'] ?? '/home/user';
    final logDir = Directory('${_env.projectRoot}/.logs');
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final logFile = File('${logDir.path}/daemon_stderr.log');

    try {
      if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
        debugPrint("Backend Error: Python executable not found at ${_env.venvPython}");
        return null;
      }

      _daemonProcess = await Process.start(
        _env.venvPython,
        _env.buildArgs(['--daemon', '--json']),
        workingDirectory: _env.workingDir,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Failed to start Python daemon within 10s");
      });

      _processRegistry.add(_daemonProcess!);

      final logSink = logFile.openWrite(mode: FileMode.append);
      _daemonProcess!.stderr
          .transform(utf8.decoder)
          .listen(
            (data) {
              try {
                logSink.write(data);
              } catch (e) {
                debugPrint("LogSink write error: $e");
              }
            },
            onError: (e) => debugPrint("Daemon stderr write error: $e"),
            onDone: () => logSink.close(),
          );

      _startHealthCheckLoop();
      return _daemonProcess;
    } catch (e) {
      debugPrint("Failed to start Python daemon: $e");
      _daemonFailureCount++;
      if (_daemonFailureCount > 5) {
        _daemonCircuitBroken = true;
        _lastDaemonFailureTime = DateTime.now();
      }
      return null;
    }
  }

  void _startHealthCheckLoop() {
    _healthCheckTimer?.cancel();
    int backoffSeconds = 20;

    _healthCheckTimer = Timer.periodic(Duration(seconds: backoffSeconds), (timer) async {
      if (_daemonCircuitBroken) return;

      bool needsRestart = false;
      if (_daemonProcess == null) {
        needsRestart = true;
      } else {
         try {
           final res = await Process.run('kill', ['-0', '${_daemonProcess!.pid}']);
           if (res.exitCode != 0) {
             debugPrint("Daemon dead detected by health check.");
             needsRestart = true;
           }
         } catch (_) {
           needsRestart = true;
         }
      }

      if (needsRestart) {
        final success = await _startDaemonIfNeeded() != null;
        if (!success) {
          backoffSeconds = (backoffSeconds * 1.5).toInt().clamp(20, 300);
          _startHealthCheckLoop();
        } else {
          if (backoffSeconds != 20) {
            backoffSeconds = 20;
            _startHealthCheckLoop();
          }
        }
      }
    });
  }

  Future<DaemonResult?> _sendToDaemon(
    String action,
    List<dynamic> args, [
    Map<String, dynamic>? kwargs,
  ]) async {
    if (_daemonCircuitBroken) return null;
    return await _daemonClient.send(action, args, kwargs: kwargs);
  }

  Future<ProcessResult?> _safeRun(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
    bool useQueue = false,
  }) async {
    if (kIsWeb) return null;

    final task = () async {
      if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
        debugPrint("Backend Error: Python executable not found at ${_env.venvPython}");
        return null;
      }

      Process? process;
      try {
        final apiKey = await PythonBridge.getApiKey();
        final env = <String, String>{};
        if (apiKey != null && apiKey.isNotEmpty) {
          env['OMNISTORE_AI_API_KEY'] = apiKey;
        }

        process = await Process.start(
          _env.venvPython,
          _env.buildArgs(args),
          workingDirectory: _env.workingDir,
          environment: env.isEmpty ? null : env,
        ).timeout(const Duration(seconds: 10), onTimeout: () {
          throw TimeoutException("Process start timed out for $args");
        });

        _processRegistry.add(process);

        final exitCode = await process.exitCode.timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException("Process execution timed out after ${timeout.inSeconds}s");
          },
        );

        final stdout = await process.stdout
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5), onTimeout: () => "");
        final stderr = await process.stderr
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5), onTimeout: () => "");

        return ProcessResult(process.pid, exitCode, stdout, stderr);
      } catch (e) {
        debugPrint("BackendService._safeRun Exception [args: $args]: $e");
        if (process != null) await _killProcess(process);
        return null;
      } finally {
        if (process != null) _processRegistry.remove(process);
      }
    };

    if (useQueue) {
      return await _executionQueue.run(task, label: "_safeRun ${args.first}");
    } else {
      return await task();
    }
  }

  Stream<String> _safeStream(List<String> args, {bool useQueue = true}) async* {
    if (kIsWeb) {
      yield "[CALLBACK] {\"log\": \"Running in browser sandbox\"}";
      return;
    }

    final controller = StreamController<String>();

    final task = () async {
      Process? process;
      try {
        final apiKey = await PythonBridge.getApiKey();
        final env = <String, String>{};
        if (apiKey != null && apiKey.isNotEmpty) {
          env['OMNISTORE_AI_API_KEY'] = apiKey;
        }

        process = await Process.start(
          _env.venvPython,
          _env.buildArgs(args),
          workingDirectory: _env.workingDir,
          environment: env.isEmpty ? null : env,
          runInShell: true,
        ).timeout(const Duration(seconds: 10), onTimeout: () {
          throw TimeoutException("Streaming process start timed out for $args");
        });

        _processRegistry.add(process);
        activeProcess = process;

        final stdoutSub = process.stdout
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
                if (process != null) _processRegistry.remove(process);
                if (!controller.isClosed) controller.close();
                if (activeProcess == process) activeProcess = null;
              },
              cancelOnError: false,
            );

        final stderrSub = process.stderr
            .transform(utf8.decoder)
            .listen(
              (data) => debugPrint("Backend Stderr: $data"),
              onError: (e) => debugPrint("Stderr Error: $e"),
            );

        controller.onCancel = () async {
          debugPrint("Stream cancelled, performing deep cleanup for process ${process?.pid}");
          stdoutSub.cancel();
          stderrSub.cancel();
          await _killProcess(process);
          if (activeProcess == process) activeProcess = null;
          if (!controller.isClosed) await controller.close();
        };
      } catch (e) {
        debugPrint("BackendService._safeStream Exception: $e");
        if (!controller.isClosed) {
          controller.add("[CALLBACK] {\"key\": \"errorProcessStart\", \"error\": \"$e\"}");
          await controller.close();
        }
        if (process != null) await _killProcess(process);
      }
    };

    if (useQueue) {
      _executionQueue.run(task, label: "_safeStream ${args.first}");
    } else {
      task();
    }

    yield* controller.stream;
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
      globalStatus.value = "";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  Future<List<AppPackage>> searchPackages(
    String query, {
    bool cancelOngoing = true,
  }) async {
    if (kIsWeb) {
      return PackageRepository().searchPackages(
        query,
        cancelOngoing: cancelOngoing,
      );
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || trimmedQuery.length > 500) return [];

    try {
      _env.validateString(trimmedQuery, "Search Query");
    } catch (e) {
      debugPrint("Security: $e");
      return [];
    }

    try {
      final daemonRes = await _sendToDaemon("run_search", [trimmedQuery, true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final results = <AppPackage>[];
        final parsed = _safeJsonDecode(daemonRes.stdout);
        if (parsed is List) {
          results.addAll(parsed.map((item) => AppPackage.fromJson(item as Map<String, dynamic>)));
        } else if (parsed is Map<String, dynamic>) {
          results.add(AppPackage.fromJson(parsed));
        }
        return results;
      }
    } catch (e) {
      debugPrint("Daemon searchPackages error: $e. Falling back.");
    }

    try {
      if (cancelOngoing && activeSearchProcess != null) {
        await _killProcess(activeSearchProcess);
        activeSearchProcess = null;
      }

      final res = await _safeRun(["-S", trimmedQuery, "--json"], timeout: const Duration(seconds: 20));
      if (res == null) return [];

      final results = <AppPackage>[];
      final parsed = _safeJsonDecode(res.stdout.toString());
      if (parsed is List) {
        results.addAll(parsed.map((item) => AppPackage.fromJson(item as Map<String, dynamic>)));
      } else if (parsed != null) {
        results.add(AppPackage.fromJson(parsed as Map<String, dynamic>));
      }
      return results;
    } catch (e) {
      debugPrint("searchPackages [query: $query] Error: $e");
      return [];
    }
  }

  dynamic _safeJsonDecode(String input) {
    final rawInput = input.trim();
    if (rawInput.isEmpty) return null;

    if (rawInput.length > 5 * 1024 * 1024) {
      debugPrint("Security Warning: Rejected JSON payload exceeding 5MB limit");
      return null;
    }

    try {
      return jsonDecode(rawInput);
    } catch (_) {
      final cleaned = rawInput.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
      try {
        final jsonPattern = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])');
        final match = jsonPattern.firstMatch(cleaned);
        if (match != null) {
          return jsonDecode(match.group(0)!);
        }
      } catch (e) {
        debugPrint("Murphy-proof Error: JSON recovery failed: $e");
      }
    }
    return null;
  }

  Future<List<dynamic>> listInstalled() async {
    if (kIsWeb) return PackageRepository().listInstalled();
    try {
      final daemonRes = await _sendToDaemon("run_list_installed", [true, false]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return data is List ? data : [];
      }
    } catch (_) {}

    final res = await _safeRun(["-L", "--json"], timeout: const Duration(seconds: 45));
    final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> loadConfig() async {
    if (kIsWeb) {
      final data = await ConfigRepository().loadConfig();
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    try {
      final daemonRes = await _sendToDaemon("config.data", []);
      if (daemonRes != null && daemonRes.status == 'success' && daemonRes.response is Map<String, dynamic>) {
        final configMap = daemonRes.response as Map<String, dynamic>;
        isAIEnabled.value = configMap['ai']?['enabled'] ?? false;
        return configMap;
      }
    } catch (_) {}

    final res = await _safeRun(["--get-config", "--json"], timeout: const Duration(seconds: 15));
    final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
    if (data is Map<String, dynamic>) {
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    return {};
  }

  Future<String> _aiCall(List<String> args, {Duration timeout = const Duration(seconds: 60)}) async {
    if (kIsWeb) return "AI not supported on web.";
    final res = await _safeRun([...args, "--json"], timeout: timeout);
    if (res == null) return "⏱ AI request timed out.";
    final data = _safeJsonDecode(res.stdout.toString());
    return (data is Map) ? (data['response']?.toString() ?? "⚠ No response") : "⚠ Parse error";
  }

  Future<String> aiExplain(String name, String desc) async {
    try {
      _env.validateString(name, "AI App Name");
      return await _aiCall(["--ai-explain", name.trim(), "--ai-desc", desc.trim()]);
    } catch (e) {
      return "AI unavailable: $e";
    }
  }

  Future<String> aiSummarizeUpdate(String n, String c, String next) async {
    try {
      _env.validateString(n, "AI Package Name");
      return await _aiCall(["--ai-changelog", "${n.trim()},${c.trim()},${next.trim()}"]);
    } catch (_) {
      return "Update summary unavailable.";
    }
  }

  Future<String> aiGenerateCLI(String n, String s) async {
    try {
      _env.validateString(n, "AI App Name");
      _env.validateString(s, "AI Source");
      return await _aiCall(["--ai-cli", "${n.trim()},${s.trim()}"], timeout: const Duration(seconds: 20));
    } catch (_) {
      return "CLI generation failed.";
    }
  }

  Future<String> aiDetectConflicts(String n) async {
    try {
      _env.validateString(n, "AI Package Name");
      return await _aiCall(["--ai-conflicts", n.trim()]);
    } catch (_) {
      return "Conflict detection failed.";
    }
  }

  Future<String> aiPickOfTheDay() async {
    try {
      return await _aiCall(["--ai-pick"]);
    } catch (_) {
       return "Pick of the day unavailable.";
    }
  }

  Future<String> aiSuggestCorrection(String q) async {
    try {
      _env.validateString(q, "AI Query");
      return await _aiCall(["--ai-correct", q.trim()], timeout: const Duration(seconds: 15));
    } catch (e) {
      return q;
    }
  }

  Future<String> aiCompareVariants(String n) async {
    try {
      _env.validateString(n, "AI App Name");
      return await _aiCall(["--ai-compare", n.trim()]);
    } catch (_) {
      return "Variant comparison unavailable.";
    }
  }

  Future<String> aiSystemHealth() async {
    try {
      return await _aiCall(["--ai-health"]);
    } catch (_) {
      return "System health report unavailable.";
    }
  }

  Future<String> aiAnalyzeError(String log) async {
    try {
      return await _aiCall(["--ai-analyze-error", log.trim()]);
    } catch (_) {
      return "Error analysis unavailable.";
    }
  }

  Future<String> aiRecommend(String p) async {
    try {
      _env.validateString(p, "AI Prompt");
      return await _aiCall(["--ai-recommend", p.trim()], timeout: const Duration(seconds: 90));
    } catch (_) {
      return "Recommendation service error.";
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (kIsWeb) {
      isAIEnabled.value = config['ai']?['enabled'] ?? false;
      return ConfigRepository().saveConfig(config);
    }
    return await _executionQueue.run(() async {
      Process? process;
      try {
        if (config.isEmpty) return false;
        process = await Process.start(_env.venvPython, _env.buildArgs(["--set-config", "stdin", "--json"]), workingDirectory: _env.workingDir);
        _processRegistry.add(process);
        process.stdin.write(jsonEncode(config));
        await process.stdin.close();
        final code = await process.exitCode.timeout(const Duration(seconds: 10));
        return code == 0;
      } catch (e) {
        debugPrint("saveConfig Error: $e");
        if (process != null) await _killProcess(process);
        return false;
      } finally {
        if (process != null) _processRegistry.remove(process);
      }
    }, label: "saveConfig");
  }

  Future<Map<String, dynamic>> checkEnv() async {
    if (kIsWeb) return ConfigRepository().checkEnv();
    try {
      final daemonRes = await _sendToDaemon("env.check_env", []);
      if (daemonRes != null && daemonRes.status == 'success' && daemonRes.response is Map<String, dynamic>) {
        return daemonRes.response as Map<String, dynamic>;
      }
    } catch (_) {}

    final res = await _safeRun(["--check-env", "--json"], timeout: const Duration(seconds: 15));
    final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
    return (data is Map<String, dynamic>) ? data : {};
  }

  Stream<String> bootstrap() {
    if (kIsWeb) return Stream.value("[CALLBACK] {\"log\": \"Web ready\"}");
    return _safeStream(["--bootstrap", "--json"]);
  }

  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    if (kIsWeb) return PackageRepository().getRecommendations();
    try {
      final daemonRes = await _sendToDaemon("run_recommendations", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        final Map<String, List<AppPackage>> result = {};
        if (data is Map) {
          data.forEach((k, v) {
            if (v is List) result[k] = v.map((i) => AppPackage.fromJson(i as Map<String, dynamic>)).toList();
          });
        }
        return result;
      }
    } catch (_) {}

    final res = await _safeRun(["--recommend", "--json"], timeout: const Duration(seconds: 30));
    final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
    final Map<String, List<AppPackage>> result = {};
    if (data is Map) {
      data.forEach((k, v) {
        if (v is List) result[k] = v.map((i) => AppPackage.fromJson(i as Map<String, dynamic>)).toList();
      });
    }
    return result;
  }

  Future<bool> launchApp(String n, String s) async {
    if (kIsWeb) return PackageRepository().launchApp(n, s);
    try {
      _env.validateString(n, "App Name");
      _env.validateString(s, "Source");
      final daemonRes = await _sendToDaemon("run_launch", [n.trim(), s.trim(), true]);
      if (daemonRes != null) return daemonRes.response == true;
    } catch (_) {}

    final res = await _safeRun(["--launch", n.trim(), "--source", s.trim(), "--json"], timeout: const Duration(seconds: 15));
    return res?.exitCode == 0;
  }

  Future<bool> locateApp(String n, String s) async {
    if (kIsWeb) return PackageRepository().locateApp(n, s);
    try {
      _env.validateString(n, "App Name");
      _env.validateString(s, "Source");
      final daemonRes = await _sendToDaemon("run_locate", [n.trim(), s.trim(), true]);
      if (daemonRes != null) return daemonRes.response == true;
    } catch (_) {}

    final res = await _safeRun(["--locate", n.trim(), "--source", s.trim(), "--json"], timeout: const Duration(seconds: 10));
    return res?.exitCode == 0;
  }

  Future<Map<String, dynamic>> getAppDetails(String id) async {
    if (kIsWeb) return PackageRepository().getAppDetails(id);
    try {
      _env.validateString(id, "App ID");
      final daemonRes = await _sendToDaemon("run_app_details", [id.trim(), true]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as Map<String, dynamic>;
    } catch (_) {}

    final res = await _safeRun(["--details", id.trim(), "--json"], timeout: const Duration(seconds: 25));
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as Map<String, dynamic>?) ?? {};
  }

  Stream<String> executeAction(String f, String n, String s, {String? url}) {
    if (kIsWeb) return TaskRepository().executeAction(f, n, s, url: url);
    try {
      _env.validateString(n, "App Name");
      _env.validateString(s, "Source");
      if (!["-I", "-R", "-U"].contains(f)) throw ArgumentError("Invalid action flag");
    } catch (e) {
      return Stream.value("[CALLBACK] {\"message\": \"[ERROR] $e\"}");
    }

    final args = [f, n.trim(), "--source", s.trim(), "--json"];
    if (url != null && url.trim().isNotEmpty) args.addAll(["--url", url.trim()]);
    return _safeStream(args);
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) return TaskRepository().checkUpdates();
    try {
      final daemonRes = await _sendToDaemon("run_check_updates", [true]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as List;
    } catch (_) {}

    final res = await _safeRun(["-C", "--json"], timeout: const Duration(seconds: 60));
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as List?) ?? [];
  }

  Stream<String> updateAll(String s) {
    if (kIsWeb) return TaskRepository().updateAll(s);
    try {
      _env.validateString(s, "Source");
      return _safeStream(["-U", "all", "--source", s.trim(), "--json"]);
    } catch (e) {
      return Stream.value("[CALLBACK] {\"error\": \"$e\"}");
    }
  }

  Future<List<dynamic>> getEssentials() async {
    if (kIsWeb) return PackageRepository().getEssentials();
    try {
      final daemonRes = await _sendToDaemon("run_get_essentials", []);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as List;
    } catch (_) {}

    final res = await _safeRun(["--essentials", "--json"]);
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as List?) ?? [];
  }

  Future<List<dynamic>> importPackages(String path) async {
    if (kIsWeb) return PackageRepository().importPackages(path);
    try {
      _env.validatePath(path);
      final daemonRes = await _sendToDaemon("run_import_packages", [path.trim()]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as List;
    } catch (_) {}

    final res = await _safeRun(["--import-packages", path.trim(), "--json"]);
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as List?) ?? [];
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    if (kIsWeb) return TaskRepository().exportPackages(path);
    try {
      _env.validatePath(path);
      final daemonRes = await _sendToDaemon("run_export_packages", [path.trim()]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as Map<String, dynamic>;
    } catch (_) {}

    final res = await _safeRun(["--export-packages", path.trim(), "--json"], timeout: const Duration(seconds: 30));
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as Map<String, dynamic>?) ?? {"status": "error"};
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) return TaskRepository().cleanSystem();
    return _safeStream(["--clean-system", "--json"]);
  }

  Future<bool> addCustomRepo(String type, String name, String url) async {
    if (kIsWeb) return true;
    try {
      _env.validateString(type, "Type");
      _env.validateString(name, "Name");
      _env.validateString(url, "URL");
      final daemonRes = await _sendToDaemon("run_add_custom_repo", [type.trim(), name.trim(), url.trim(), true]);
      if (daemonRes != null) return daemonRes.response == true;
    } catch (_) {}

    final res = await _safeRun(["--add-custom-repo", "$type,$name,$url", "--json"], timeout: const Duration(seconds: 20));
    return res?.exitCode == 0;
  }

  Future<bool> removeCustomRepo(String type, String name) async {
    if (kIsWeb) return true;
    try {
      _env.validateString(type, "Type");
      _env.validateString(name, "Name");
      final daemonRes = await _sendToDaemon("run_remove_custom_repo", [type.trim(), name.trim(), true]);
      if (daemonRes != null) return daemonRes.response == true;
    } catch (_) {}

    final res = await _safeRun(["--remove-custom-repo", "$type,$name", "--json"], timeout: const Duration(seconds: 20));
    return res?.exitCode == 0;
  }

  Future<Map<String, dynamic>> getStorageInfo() async {
    if (kIsWeb) return {};
    try {
      final daemonRes = await _sendToDaemon("run_get_storage_info", [true]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as Map<String, dynamic>;
    } catch (_) {}

    final res = await _safeRun(["--storage-info", "--json"], timeout: const Duration(seconds: 15));
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> testAiConnection() async {
    if (kIsWeb) return {"status": "error"};
    try {
      final daemonRes = await _sendToDaemon("run_ai_test", [true]);
      if (daemonRes != null) return _safeJsonDecode(daemonRes.stdout) as Map<String, dynamic>;
    } catch (_) {}

    final res = await _safeRun(["--ai-test", "--json"], timeout: const Duration(seconds: 60));
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as Map<String, dynamic>?) ?? {"status": "error"};
  }
}
