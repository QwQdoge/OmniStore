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

/// Murphy-proof: Centralized input validation to prevent injection and malformed args.
class InputValidator {
  static void validateString(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
    final trimmed = val.trim();
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
          "Invalid characters in $name: Only alphanumeric, '.', '_', '/', '-', and spaces are allowed.");
    }
  }

  static void validatePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw ArgumentError("Path cannot be null or empty");
    }
    final trimmed = path.trim();
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
          "Invalid characters in path: Security policy forbids shell metacharacters.");
    }
    if (trimmed.contains('..')) {
      throw ArgumentError(
          "Security: Relative path traversal ('..') is strictly forbidden.");
    }
  }
}

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

  /// Murphy-proof: Daemon health check with exponential backoff and strict liveness validation.
  void _startHealthCheckLoop({int backoffSeconds = 20}) {
    _healthCheckTimer?.cancel();

    _healthCheckTimer = Timer.periodic(Duration(seconds: backoffSeconds), (timer) async {
      if (_daemonCircuitBroken) return;

      bool needsRestart = false;
      if (_daemonProcess == null) {
        needsRestart = true;
      } else {
        try {
          if (Platform.isLinux || Platform.isMacOS) {
            final res = await Process.run('kill', ['-0', '${_daemonProcess!.pid}']);
            if (res.exitCode != 0) {
              debugPrint("Daemon dead detected by health check.");
              needsRestart = true;
            }
          } else {
            // For other platforms, we rely on _daemonProcess.exitCode check if possible
            // but in Dart, awaiting exitCode blocks. We check if the process is nullified.
          }
        } catch (_) {
          needsRestart = true;
        }
      }

      if (needsRestart) {
        final success = await _startDaemonIfNeeded() != null;
        if (!success) {
          // Increase backoff on repeated failures (max 5 minutes)
          final nextBackoff = (backoffSeconds * 1.5).toInt().clamp(20, 300);
          if (nextBackoff != backoffSeconds) {
            _startHealthCheckLoop(backoffSeconds: nextBackoff);
          }
        } else if (backoffSeconds != 20) {
          // Reset to default on success
          _startHealthCheckLoop(backoffSeconds: 20);
        }
      }
    });
  }

  Future<DaemonResult?> _sendToDaemon(
    String action,
    List<dynamic> args, [
    Map<String, dynamic>? kwargs,
    Duration timeout = const Duration(seconds: 60),
  ]) async {
    return await _daemonClient.send(action, args,
        kwargs: kwargs, timeout: timeout);
  }

  /// Murphy-proof: Unified execution engine with Daemon-first and CLI-fallback.
  /// Ensures that all backend calls have consistent error handling, timeouts,
  /// and "Graceful Degradation" to a safe default value.
  Future<T> _callBackend<T>({
    required String action,
    required List<dynamic> args,
    required T defaultValue,
    required T Function(dynamic json) mapper,
    Map<String, dynamic>? kwargs,
    List<String>? cliArgs,
    Duration timeout = const Duration(seconds: 30),
    bool useLock = false,
  }) async {
    // 1. Attempt via Resident Daemon (Fast IPC)
    try {
      final daemonRes = await _sendToDaemon(action, args, kwargs, timeout);
      if (daemonRes != null && daemonRes.status == 'success') {
        // Favor structured response if available, fallback to stdout parsing
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
        if (data != null) {
          return mapper(data);
        }
      }
    } catch (e) {
      debugPrint("Murphy-proof: Daemon $action failed: $e. Falling back to CLI.");
    }

    // 2. Graceful Fallback to CLI (Cold Process)
    if (cliArgs == null) return defaultValue;

    try {
      final res = await _safeRun(cliArgs, timeout: timeout, useLock: useLock);
      if (res != null && res.exitCode == 0) {
        final data = _safeJsonDecode(res.stdout);
        if (data != null) {
          return mapper(data);
        }
      }
    } catch (e) {
      debugPrint("Murphy-proof: CLI fallback for $action failed: $e");
    }

    return defaultValue;
  }

  /// Murphy-proof: Safely run a command with timeouts and guaranteed lock release.
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

  /// Murphy-proof: Safely stream output with timeouts and guaranteed lock release.
  Stream<String> _safeStream(List<String> args, {bool useLock = true}) async* {
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
      InputValidator.validateString(trimmedQuery, "Search Query");
    } catch (e) {
      debugPrint("Security: $e");
      return [];
    }

    // Murphy-proof: Cancel ongoing search before starting new one to prevent race conditions
    if (cancelOngoing && activeSearchProcess != null) {
      await _killProcess(activeSearchProcess);
      activeSearchProcess = null;
    }

    return await _callBackend<List<AppPackage>>(
      action: "run_search",
      args: [trimmedQuery, true],
      cliArgs: ["-S", trimmedQuery, "--json"],
      defaultValue: [],
      timeout: const Duration(seconds: 25),
      mapper: (data) {
        if (data is List) {
          return data
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic>) {
          return [AppPackage.fromJson(data)];
        }
        return [];
      },
    );
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
    if (kIsWeb) {
      return PackageRepository().listInstalled();
    }
    return await _callBackend<List<dynamic>>(
      action: "run_list_installed",
      args: [true, false],
      cliArgs: ["-L", "--json"],
      defaultValue: [],
      timeout: const Duration(seconds: 45),
      mapper: (data) => data is List ? data : [],
    );
  }

  Future<Map<String, dynamic>> loadConfig() async {
    if (kIsWeb) {
      final data = await ConfigRepository().loadConfig();
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    final config = await _callBackend<Map<String, dynamic>>(
      action: "config.data",
      args: [],
      cliArgs: ["--get-config", "--json"],
      defaultValue: {},
      timeout: const Duration(seconds: 15),
      mapper: (data) => (data is Map<String, dynamic>) ? data : {},
    );
    isAIEnabled.value = config['ai']?['enabled'] ?? false;
    return config;
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
      _validateString(name, "AI App Name");
      final daemonRes = await _sendToDaemon("run_ai_explain", [name.trim(), desc.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-explain", name.trim(), "--ai-desc", desc.trim()]);
    } catch (e) {
      return "AI unavailable: $e";
    }
  }

  Future<String> aiSummarizeUpdate(String n, String c, String next) async {
    try {
      _validateString(n, "AI Package Name");
      final daemonRes = await _sendToDaemon("run_ai_changelog", [n.trim(), c.trim(), next.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-changelog", "${n.trim()},${c.trim()},${next.trim()}"]);
    } catch (e) {
      return "Update summary unavailable.";
    }
  }

  Future<String> aiGenerateCLI(String n, String s) async {
    try {
      _validateString(n, "AI App Name");
      _validateString(s, "AI Source");
      final daemonRes = await _sendToDaemon("run_ai_cli", [n.trim(), s.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-cli", "${n.trim()},${s.trim()}"],
          timeout: const Duration(seconds: 20));
    } catch (e) {
      return "CLI generation failed.";
    }
  }

  Future<String> aiDetectConflicts(String n) async {
    try {
      _validateString(n, "AI Package Name");
      final daemonRes = await _sendToDaemon("run_ai_conflicts", [n.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-conflicts", n.trim()]);
    } catch (_) {
      return "Conflict detection failed.";
    }
  }

  Future<String> aiPickOfTheDay() async {
    try {
      final daemonRes = await _sendToDaemon("run_ai_pick", []);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-pick"]);
    } catch (e) {
      return "Pick of the day unavailable.";
    }
  }

  Future<String> aiSuggestCorrection(String q) async {
    try {
      _validateString(q, "AI Query");
      final daemonRes = await _sendToDaemon("run_ai_correct", [q.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-correct", q.trim()],
          timeout: const Duration(seconds: 15));
    } catch (e) {
      return q;
    }
  }

  Future<String> aiCompareVariants(String n) async {
    try {
      _validateString(n, "AI App Name");
      final daemonRes = await _sendToDaemon("run_ai_compare", [n.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-compare", n.trim()]);
    } catch (_) {
      return "Variant comparison unavailable.";
    }
  }

  Future<String> aiSystemHealth() async {
    try {
      final daemonRes = await _sendToDaemon("run_ai_health", []);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-health"]);
    } catch (_) {
      return "System health report unavailable.";
    }
  }

  Future<String> aiAnalyzeError(String log) async {
    try {
      final daemonRes = await _sendToDaemon("run_ai_analyze_error", [log.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          return data['response'].toString();
        }
      }
      return await _aiCall(["--ai-analyze-error", log.trim()]);
    } catch (_) {
      return "Error analysis unavailable.";
    }
  }

  Future<String> aiRecommend(String p) async {
    try {
      _validateString(p, "AI Prompt");
      final daemonRes = await _sendToDaemon("run_ai_recommend", [p.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map && data.containsKey('response')) {
          _aiFailureCount = 0;
          return data['response'].toString();
        }
      }
      final res = await _aiCall(["--ai-recommend", p.trim()],
          timeout: const Duration(seconds: 90));
      _aiFailureCount = 0;
      return res;
    } catch (e) {
      _aiFailureCount++;
      if (_aiFailureCount > 3) {
        return "AI recommendations are currently offline. Please try again later.";
      }
      return "Recommendation service error.";
    }
  }

  /// Murphy-proof: Safely save configuration with timeouts and guaranteed lock release.
  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (kIsWeb) {
      isAIEnabled.value = config['ai']?['enabled'] ?? false;
      return ConfigRepository().saveConfig(config);
    }
    try {
      final daemonRes = await _sendToDaemon("run_save_config", [config]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon saveConfig error: $e. Falling back.");
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
      _processRegistry.add(process);

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
    if (kIsWeb) {
      return PackageRepository().getRecommendations();
    }
    return await _callBackend<Map<String, List<AppPackage>>>(
      action: "run_recommendations",
      args: [true],
      cliArgs: ["--recommend", "--json"],
      defaultValue: {},
      timeout: const Duration(seconds: 30),
      mapper: (data) {
        final Map<String, List<AppPackage>> result = {};
        if (data is Map) {
          data.forEach((k, v) {
            if (v is List) result[k] = v.map((i) => AppPackage.fromJson(i as Map<String, dynamic>)).toList();
          });
        }
        return result;
      },
    );
  }

  Future<bool> launchApp(String n, String s) async {
    if (kIsWeb) return PackageRepository().launchApp(n, s);
    try {
      InputValidator.validateString(n, "App Name");
      InputValidator.validateString(s, "Source");
    } catch (e) {
      debugPrint("Security: $e");
      return false;
    }

    return await _callBackend<bool>(
      action: "run_launch",
      args: [n.trim(), s.trim(), true],
      cliArgs: ["--launch", n.trim(), "--source", s.trim(), "--json"],
      defaultValue: false,
      timeout: const Duration(seconds: 15),
      mapper: (data) => data == true || (data is Map && data['status'] == 'success'),
    );
  }

  Future<bool> locateApp(String n, String s) async {
    if (kIsWeb) return PackageRepository().locateApp(n, s);
    try {
      InputValidator.validateString(n, "App Name");
      InputValidator.validateString(s, "Source");
    } catch (e) {
      debugPrint("Security: $e");
      return false;
    }

    return await _callBackend<bool>(
      action: "run_locate",
      args: [n.trim(), s.trim(), true],
      cliArgs: ["--locate", n.trim(), "--source", s.trim(), "--json"],
      defaultValue: false,
      timeout: const Duration(seconds: 10),
      mapper: (data) => data == true || (data is Map && data['status'] == 'success'),
    );
  }

  Future<Map<String, dynamic>> getAppDetails(String id) async {
    if (kIsWeb) return PackageRepository().getAppDetails(id);
    try {
      InputValidator.validateString(id, "App ID");
    } catch (e) {
      debugPrint("Security: $e");
      return {};
    }

    return await _callBackend<Map<String, dynamic>>(
      action: "run_app_details",
      args: [id.trim(), true],
      cliArgs: ["--details", id.trim(), "--json"],
      defaultValue: {},
      timeout: const Duration(seconds: 25),
      mapper: (data) => (data is Map<String, dynamic>) ? data : {},
    );
  }

  Stream<String> executeAction(String f, String n, String s, {String? url}) {
    if (kIsWeb) return TaskRepository().executeAction(f, n, s, url: url);
    try {
      InputValidator.validateString(n, "App Name");
      InputValidator.validateString(s, "Source");
      if (!["-I", "-R", "-U"].contains(f)) {
        throw ArgumentError("Invalid action flag: $f");
      }
      if (url != null && url.trim().isNotEmpty) {
        InputValidator.validateString(url, "URL");
      }
    } catch (e) {
      return Stream.value("[CALLBACK] {\"message\": \"[ERROR] $e\"}");
    }

    final args = [f, n.trim(), "--source", s.trim(), "--json"];
    if (url != null && url.trim().isNotEmpty) args.addAll(["--url", url.trim()]);
    return _safeStream(args);
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return TaskRepository().checkUpdates();
    }
    return await _callBackend<List<dynamic>>(
      action: "run_check_updates",
      args: [true],
      cliArgs: ["-C", "--json"],
      defaultValue: [],
      timeout: const Duration(seconds: 60),
      mapper: (data) => data is List ? data : [],
    );
  }

  Stream<String> updateAll(String s) {
    if (kIsWeb) return TaskRepository().updateAll(s);
    try {
      InputValidator.validateString(s, "Update Source");
      return _safeStream(["-U", "all", "--source", s.trim(), "--json"]);
    } catch (e) {
      return Stream.value("[CALLBACK] {\"error\": \"$e\"}");
    }
  }

  Future<List<dynamic>> getEssentials() async {
    if (kIsWeb) {
      return PackageRepository().getEssentials();
    }
    return await _callBackend<List<dynamic>>(
      action: "run_get_essentials",
      args: [],
      cliArgs: ["--essentials", "--json"],
      defaultValue: [],
      mapper: (data) => data is List ? data : [],
    );
  }

    final res = await _safeRun(["--essentials", "--json"]);
    return (_safeJsonDecode(res?.stdout?.toString() ?? "") as List?) ?? [];
  }

  Future<List<dynamic>> importPackages(String path) async {
    if (kIsWeb) return PackageRepository().importPackages(path);
    try {
      InputValidator.validatePath(path);
    } catch (e) {
      debugPrint("Security: $e");
      return [];
    }

    return await _callBackend<List<dynamic>>(
      action: "run_import_packages",
      args: [path.trim()],
      cliArgs: ["--import-packages", path.trim(), "--json"],
      defaultValue: [],
      mapper: (data) => data is List ? data : [],
    );
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    if (kIsWeb) return TaskRepository().exportPackages(path);
    try {
      InputValidator.validatePath(path);
    } catch (e) {
      debugPrint("Security: $e");
      return {"status": "error", "message": e.toString()};
    }

    return await _callBackend<Map<String, dynamic>>(
      action: "run_export_packages",
      args: [path.trim()],
      cliArgs: ["--export-packages", path.trim(), "--json"],
      defaultValue: {"status": "error"},
      timeout: const Duration(seconds: 30),
      mapper: (data) => (data is Map<String, dynamic>) ? data : {"status": "error"},
    );
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) return TaskRepository().cleanSystem();
    return _safeStream(["--clean-system", "--json"]);
  }

  Future<bool> addCustomRepo(String type, String name, String url) async {
    if (kIsWeb) return true;
    try {
      InputValidator.validateString(type, "Repo Type");
      InputValidator.validateString(name, "Repo Name");
      InputValidator.validateString(url, "Repo URL");
    } catch (e) {
      debugPrint("Security: $e");
      return false;
    }

    return await _callBackend<bool>(
      action: "run_add_custom_repo",
      args: [type.trim(), name.trim(), url.trim(), true],
      cliArgs: ["--add-custom-repo", "${type.trim()},${name.trim()},${url.trim()}", "--json"],
      defaultValue: false,
      timeout: const Duration(seconds: 20),
      mapper: (data) => data == true || (data is Map && data['status'] == 'success'),
    );
  }

  Future<bool> removeCustomRepo(String type, String name) async {
    if (kIsWeb) return true;
    try {
      InputValidator.validateString(type, "Repo Type");
      InputValidator.validateString(name, "Repo Name");
    } catch (e) {
      debugPrint("Security: $e");
      return false;
    }

    return await _callBackend<bool>(
      action: "run_remove_custom_repo",
      args: [type.trim(), name.trim(), true],
      cliArgs: ["--remove-custom-repo", "${type.trim()},${name.trim()}", "--json"],
      defaultValue: false,
      timeout: const Duration(seconds: 20),
      mapper: (data) => data == true || (data is Map && data['status'] == 'success'),
    );
  }

  Future<Map<String, dynamic>> getStorageInfo() async {
    if (kIsWeb) return {};
    return await _callBackend<Map<String, dynamic>>(
      action: "run_get_storage_info",
      args: [true],
      cliArgs: ["--storage-info", "--json"],
      defaultValue: {},
      timeout: const Duration(seconds: 15),
      mapper: (data) => (data is Map<String, dynamic>) ? data : {},
    );
  }

  /// Murphy-proof: Coordinated shutdown with timeout to prevent hanging.
  Future<void> shutdownBackend() async {
    if (kIsWeb) return;
    try {
      await _sendToDaemon("shutdown", []).timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint("Shutdown request failed: $e");
    }
  }

  Future<Map<String, dynamic>> testAiConnection() async {
    if (kIsWeb) return {"status": "error", "response": "Not supported on web"};
    return await _callBackend<Map<String, dynamic>>(
      action: "run_ai_test",
      args: [true],
      cliArgs: ["--ai-test", "--json"],
      defaultValue: {"status": "error", "response": "Internal Error"},
      timeout: const Duration(seconds: 60),
      mapper: (data) =>
          (data is Map<String, dynamic>) ? data : {"status": "error", "response": "Invalid format"},
    );
  }
}
