import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/package_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/python_bridge.dart';
import '../models/app_package.dart';
import 'backend/process_registry.dart';
import 'backend/daemon_client.dart';
import 'backend/platform_environment.dart';
import 'backend/security_validator.dart';
import 'backend/daemon_ipc_service.dart';
import 'backend/process_execution_service.dart';
import 'backend/ai_bridge_service.dart';

export 'backend/daemon_client.dart' show DaemonResult;

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;

  late final ProcessRegistry _processRegistry;
  late final DaemonClient _daemonClient;

  // Specialized Services
  late final DaemonIpcService _ipc;
  late final ProcessExecutionService _executor;
  late final AiBridgeService _aiBridge;

  BackendService._internal() {
    _processRegistry = ProcessRegistry();
    _daemonClient = DaemonClient(onDemandStart: _startDaemonIfNeeded);
    _ipc = DaemonIpcService(_daemonClient);
    _executor = ProcessExecutionService(_processRegistry);
    _aiBridge = AiBridgeService(this);
  }

  // ignore: unused_field
  final Completer<void> _initCompleter = Completer<void>();

  // Registry for tracking active subprocesses (migrated to _processRegistry)
  // Murphy-proof: Global lock for local IO operations
  Completer<void>? _globalLock;

  static PlatformEnvironment get _env => PlatformEnvironment.instance;
  static String get venvPython => _env.venvPython;
  static String get scriptPath => _env.scriptPath;
  static String get workingDir => _env.workingDir;

  String get _venvPython => venvPython;
  String get _workingDir => workingDir;

  List<String> _buildArgs(List<String> baseArgs) {
    return _env.buildArgs(baseArgs);
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

  /// Murphy-proof: Strict string validation to prevent shell injection and malformed inputs.
  void _validateString(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
    final trimmed = val.trim();
    if (trimmed.length > 1024) {
      throw ArgumentError("$name is too long (max 1024 characters)");
    }
    // Allow alphanumeric, dots, underscores, dashes, slashes, and spaces.
    // Strictly forbid characters like ; & | ` $ ( ) < > \ ' "
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
        "Invalid characters in $name: Security policy forbids shell metacharacters.",
      );
    }
  }

  /// Murphy-proof: Strict path validation to prevent traversal attacks.
  void _validatePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw ArgumentError("Path cannot be null or empty");
    }
    final trimmed = path.trim();
    if (trimmed.length > 1024) {
      throw ArgumentError("Path is too long");
    }
    if (trimmed.contains('..')) {
      throw ArgumentError(
        "Security: Relative path traversal ('..') is strictly forbidden.",
      );
    }
    // Cross-platform support: Allow Windows-style paths (C:\...)
    if (!RegExp(r'^[a-zA-Z0-9._/\\: -]+$').hasMatch(trimmed)) {
      throw ArgumentError(
        "Invalid characters in path: Security policy forbids shell metacharacters.",
      );
    }
  }

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

  // ignore: unused_element
  bool _isProcessAlive(Process p) {
    if (kIsWeb) return false;
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        return Process.runSync('kill', ['-0', '${p.pid}']).exitCode == 0;
      }
    } catch (_) {}
    return true;
  }

  Future<void> dispose() async {
    if (kIsWeb) return;

    // Murphy-proof: Aggressive and ordered cleanup
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // 1. Terminate IPC clients
    await _daemonClient.dispose();

    // 2. Kill all registered subprocesses (Daemon, Search, Actions)
    await _processRegistry.dispose();

    // 3. Nullify references to prevent memory leaks or reuse of dead handles
    activeProcess = null;
    activeSearchProcess = null;
    _daemonProcess = null;

    // 4. Force release any hanging global locks
    if (_globalLock != null && !_globalLock!.isCompleted) {
      _globalLock!.complete();
    }
    _globalLock = null;

    // 5. Clean up reactive state to baseline
    isDownloading.value = false;
    globalProgress.value = null;
  }

  Process? _daemonProcess;
  Timer? _healthCheckTimer;
  int _daemonRestartCount = 0;
  DateTime? _lastDaemonStartTime;

  Future<Process?> _startDaemonIfNeeded() async {
    if (kIsWeb) return null;

    if (_daemonProcess != null) {
      // Murphy-proof: Strict liveness check using kill -0
      try {
        if (Platform.isLinux || Platform.isMacOS) {
          final res = await Process.run('kill', [
            '-0',
            '${_daemonProcess!.pid}',
          ]);
          if (res.exitCode == 0) return _daemonProcess;
        }
      } catch (_) {}
    }

    // Guard: Prevent rapid restart-loop "storm"
    final now = DateTime.now();
    if (_lastDaemonStartTime != null &&
        now.difference(_lastDaemonStartTime!) < const Duration(seconds: 10)) {
      _daemonRestartCount++;
      if (_daemonRestartCount > 3) {
        debugPrint(
          "Murphy-proof Warning: Daemon restart loop detected. Throttling.",
        );
        return null;
      }
    } else {
      _daemonRestartCount = 0;
    }
    _lastDaemonStartTime = now;

    final logDir = Directory(_env.appConfigDir);
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final logFile = File(
      '${logDir.path}${Platform.pathSeparator}daemon_stderr.log',
    );

    try {
      if (!File(_venvPython).existsSync() && _venvPython != 'python') {
        debugPrint(
          "Backend Error: Python executable not found at $_venvPython",
        );
        return null;
      }

      _daemonProcess =
          await Process.start(
            _venvPython,
            _buildArgs(['--daemon', '--json']),
            workingDirectory: _workingDir,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                "Failed to start Python daemon within 10s",
              );
            },
          );

      // Murphy-proof: Immediate registration to ensure reaping on exit
      _processRegistry.add(_daemonProcess!);

      // Divert python stderr outputs to a structured local debug log file
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
      return null;
    }
  }

  void _startHealthCheckLoop() {
    _healthCheckTimer?.cancel();
    if (!Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    int backoffSeconds = 20;

    _healthCheckTimer = Timer.periodic(Duration(seconds: backoffSeconds), (
      timer,
    ) async {
      bool needsRestart = false;
      if (_daemonProcess == null) {
        needsRestart = true;
      } else {
        try {
          final res = await Process.run('kill', [
            '-0',
            '${_daemonProcess!.pid}',
          ]);
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
          // Increase backoff on repeated failures (max 5 minutes)
          final newBackoff = (backoffSeconds * 1.5).toInt().clamp(20, 300);
          if (newBackoff != backoffSeconds) {
            backoffSeconds = newBackoff;
            _startHealthCheckLoop(); // Restart loop with new interval
          }
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
    return _ipc.send(action, args, kwargs: kwargs);
  }

  Future<ProcessResult?> runRaw(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final apiKey = await PythonBridge.getApiKey();
    return _executor.run(args: args, timeout: timeout, apiKey: apiKey);
  }

  Future<ProcessResult?> _safeRun(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
    bool useLock = false,
  }) async {
    if (useLock) await _acquireLock();
    try {
      return await runRaw(args, timeout: timeout);
    } finally {
      if (useLock) _releaseLock();
    }
  }

  Stream<String> _safeStream(List<String> args, {bool useLock = true}) async* {
    if (useLock) await _acquireLock();
    try {
      final apiKey = await PythonBridge.getApiKey();
      yield* _executor.stream(
        args: args,
        apiKey: apiKey,
        onProcessStarted: (p) => activeProcess = p,
      );
    } finally {
      if (useLock) {
        _releaseLock();
        activeProcess = null;
      }
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
      globalStatus.value = "";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  Future<List<AppPackage>> searchPackages(
    String query, {
    bool cancelOngoing = true,
    bool throwOnError = false,
  }) async {
    if (kIsWeb) {
      return PackageRepository().searchPackages(
        query,
        cancelOngoing: cancelOngoing,
      );
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];
    if (trimmedQuery.length > 500) return []; // Fail fast check

    try {
      SecurityValidator.validateSearchQuery(trimmedQuery, "Search Query");
    } catch (e) {
      debugPrint("Security: $e");
      if (throwOnError) rethrow;
      return [];
    }

    try {
      final daemonRes = await _sendToDaemon("run_search", [trimmedQuery, true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final parsed = _safeJsonDecode(daemonRes.stdout);
        if (parsed is List) {
          return parsed
              .whereType<Map<String, dynamic>>()
              .map((item) => AppPackage.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Daemon searchPackages error: $e. Falling back.");
    }

    // Legacy fallback
    try {
      if (cancelOngoing && activeSearchProcess != null) {
        await _killProcess(activeSearchProcess);
        activeSearchProcess = null;
      }

      final res = await _safeRun([
        "-S",
        trimmedQuery,
        "--json",
      ], timeout: const Duration(seconds: 30));

      if (res != null && res.exitCode == 0) {
        final parsed = _safeJsonDecode(res.stdout.toString());
        if (parsed is List) {
          return parsed
              .whereType<Map<String, dynamic>>()
              .map((item) => AppPackage.fromJson(item))
              .toList();
        }
      }
      if (throwOnError) {
        throw StateError("Search failed for query: $trimmedQuery");
      }
      return [];
    } catch (e) {
      debugPrint("searchPackages [query: $query] Error: $e");
      if (throwOnError) rethrow;
      return [];
    } finally {
      activeSearchProcess = null;
    }
  }

  /// Murphy-proof: Strict JSON decoder with size limits, noise filtering,
  /// and fallback recovery for messy subprocess output.
  dynamic safeJsonDecode(String input) => _safeJsonDecode(input);

  dynamic _safeJsonDecode(String input) {
    final rawInput = input.trim();
    if (rawInput.isEmpty) return null;

    // Boundary Defense: Reject payloads > 10MB to prevent OOM
    if (rawInput.length > 10 * 1024 * 1024) {
      debugPrint(
        "Security Warning: Rejected JSON payload exceeding 10MB limit",
      );
      return null;
    }

    try {
      return jsonDecode(rawInput);
    } catch (_) {
      // Noise Reduction: Aggressive ANSI stripping including OSC and ESC sequences
      final cleaned = rawInput.replaceAll(
        RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07]*\x07'),
        '',
      );

      try {
        // Precise balanced JSON extraction using a non-greedy reverse scan
        // for more accurate recovery of nested structures.
        final jsonPattern = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])');
        final matches = jsonPattern.allMatches(cleaned).toList();

        if (matches.isNotEmpty) {
          // Priority 1: Full-match reverse scan
          for (final match in matches.reversed) {
            final candidate = match.group(0)!;
            try {
              return jsonDecode(candidate);
            } catch (_) {}
          }
        }

        // Priority 2: Precise Tail Recovery for multiplexed output
        // Splitting by lines and attempting to find the most recent valid JSON block
        // Murphy-proof: Scanning only the last 100 lines for performance.
        final lines = cleaned.split('\n');
        final scanDepth = lines.length.clamp(0, 100);
        final startIdx = (lines.length - scanDepth).clamp(0, lines.length);

        for (int i = lines.length - 1; i >= startIdx; i--) {
          final lineCandidate = lines[i].trim();
          if (lineCandidate.isEmpty) continue;

          // Optimization: Only attempt decode if line looks like JSON
          if (lineCandidate.startsWith('{') || lineCandidate.startsWith('[')) {
            try {
              return jsonDecode(lineCandidate);
            } catch (_) {}
          }

          // Sub-line recovery for lines that contain both text and JSON
          final startIdx = lineCandidate.indexOf(RegExp(r'[\{\[]'));
          if (startIdx != -1) {
            final subCandidate = lineCandidate.substring(startIdx);
            try {
              return jsonDecode(subCandidate);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint("Murphy-proof Error: JSON recovery failed: $e");
      }
    }
    return null;
  }

  Future<List<AppPackage>> listInstalled() async {
    if (kIsWeb) {
      final results = await PackageRepository().listInstalled();
      return results
          .whereType<Map<String, dynamic>>()
          .map((e) => AppPackage.fromJson(e))
          .toList();
    }
    try {
      final daemonRes = await _sendToDaemon("run_list_installed", [
        true,
        false,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => AppPackage.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Daemon listInstalled error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "-L",
        "--json",
      ], timeout: const Duration(seconds: 45));
      if (res == null || res.exitCode != 0) return [];
      final data = _safeJsonDecode(res.stdout.toString());
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => AppPackage.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("listInstalled Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> listPlugins() async {
    if (kIsWeb) return [];
    try {
      final daemonRes = await _sendToDaemon("run_list_plugins", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is List) {
          availableSources.value = data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          return data;
        }
      }
    } catch (e) {
      debugPrint("Daemon listPlugins error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["--list-plugins", "--json"]);
      if (res != null && res.exitCode == 0) {
        final data = _safeJsonDecode(res.stdout.toString());
        if (data is List) {
          availableSources.value = data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          return data;
        }
      }
    } catch (e) {
      debugPrint("listPlugins Error: $e");
    }
    return [];
  }

  Future<bool> setPluginEnabled(String pluginId, bool enabled) async {
    if (kIsWeb) return false;
    _validateString(pluginId, "Plugin ID");
    try {
      final daemonRes = await _sendToDaemon("run_set_plugin_enabled", [
        pluginId.trim(),
        enabled,
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        await listPlugins();
        return true;
      }
    } catch (e) {
      debugPrint("Daemon setPluginEnabled error: $e. Falling back.");
    }
    try {
      final value = enabled ? "true" : "false";
      final res = await _safeRun([
        "--set-plugin-enabled",
        "${pluginId.trim()}=$value",
        "--json",
      ]);
      final success = res != null && res.exitCode == 0;
      if (success) await listPlugins();
      return success;
    } catch (e) {
      debugPrint("setPluginEnabled Error: $e");
      return false;
    }
  }

  Future<bool> removePlugin(String pluginId) async {
    if (kIsWeb) return false;
    _validateString(pluginId, "Plugin ID");
    try {
      final daemonRes = await _sendToDaemon("run_remove_plugin", [
        pluginId.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        await listPlugins();
        return true;
      }
    } catch (e) {
      debugPrint("Daemon removePlugin error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--remove-plugin",
        pluginId.trim(),
        "--json",
      ]);
      final success = res != null && res.exitCode == 0;
      if (success) await listPlugins();
      return success;
    } catch (e) {
      debugPrint("removePlugin Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    if (kIsWeb) {
      final data = await ConfigRepository().loadConfig();
      isAIEnabled.value = data['ai']?['enabled'] ?? false;
      return data;
    }
    try {
      final daemonRes = await _sendToDaemon("config.data", []);
      if (daemonRes != null &&
          daemonRes.status == 'success' &&
          daemonRes.response is Map<String, dynamic>) {
        final configMap = daemonRes.response as Map<String, dynamic>;
        isAIEnabled.value = configMap['ai']?['enabled'] ?? false;
        return configMap;
      }
    } catch (e) {
      debugPrint("Daemon loadConfig error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--get-config",
        "--json",
      ], timeout: const Duration(seconds: 15));
      if (res == null) return {};
      final data = _safeJsonDecode(res.stdout.toString());
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
        return "AI_TIMEOUT";
      }
      final data = _safeJsonDecode(res.stdout.toString());
      if (data is Map) {
        return data['response']?.toString() ?? "AI_NO_RESPONSE";
      }
      return "AI_PARSE_FAILED";
    } catch (e) {
      debugPrint("_aiCall Error: $e");
      return "AI_ERROR: ${e.toString()}";
    }
  }

  // Fail-safe AI counter
  int _aiFailureCount = 0;

  Future<String> aiExplain(String name, String desc) =>
      _aiBridge.explain(name, desc);

  Future<String> aiSummarizeUpdate(String n, String c, String next) async {
    return _aiBridge.call(["--ai-changelog", "$n,$c,$next"]);
  }

  Future<String> aiGenerateCLI(String n, String s) async {
    return _aiBridge.call([
      "--ai-cli",
      "$n,$s",
    ], timeout: const Duration(seconds: 20));
  }

  Future<String> aiDetectConflicts(String n) async {
    return _aiBridge.call(["--ai-conflicts", n.trim()]);
  }

  Future<String> aiPickOfTheDay() async {
    return _aiBridge.call(["--ai-pick"]);
  }

  Future<String> aiSuggestCorrection(String q) async {
    try {
      _validateString(q, "AI Query");
      return await _aiCall([
        "--ai-correct",
        q.trim(),
      ], timeout: const Duration(seconds: 15));
    } catch (e) {
      return q;
    }
  }

  Future<String> aiCompareVariants(String n) async {
    return _aiBridge.call(["--ai-compare", n.trim()]);
  }

  Future<String> aiSystemHealth() async {
    return _aiBridge.call(["--ai-health"]);
  }

  Future<String> aiAnalyzeError(String log) => _aiBridge.analyzeError(log);

  Future<String> aiRecommend(String p) async {
    try {
      _validateString(p, "AI Prompt");
      final res = await _aiCall([
        "--ai-recommend",
        p.trim(),
      ], timeout: const Duration(seconds: 90));
      _aiFailureCount = 0;
      return res;
    } catch (e) {
      _aiFailureCount++;
      if (_aiFailureCount > 3) {
        return "AI recommendations are currently offline.";
      }
      return "Recommendation service error.";
    }
  }

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
      _processRegistry.add(process);

      try {
        process.stdin.write(jsonEncode(config));
        await process.stdin.close();
      } catch (e) {
        debugPrint("saveConfig Stdin Error: $e");
      }

      final code = await process.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Save config timed out");
        },
      );
      return code == 0;
    } catch (e) {
      debugPrint("saveConfig Error: $e");
      if (process != null) await _killProcess(process);
      return false;
    } finally {
      if (process != null) _processRegistry.remove(process);
      _releaseLock();
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    if (kIsWeb) {
      return ConfigRepository().checkEnv();
    }
    try {
      final daemonRes = await _sendToDaemon("env.check_env", []);
      if (daemonRes != null &&
          daemonRes.status == 'success' &&
          daemonRes.response is Map<String, dynamic>) {
        return daemonRes.response as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Daemon checkEnv error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--check-env",
        "--json",
      ], timeout: const Duration(seconds: 15));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
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
      final daemonRes = await _sendToDaemon("run_recommendations", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return _parseRecommendations(data);
      }
    } catch (e) {
      debugPrint("Daemon getRecommendations error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--recommend",
        "--json",
      ], timeout: const Duration(seconds: 30));
      if (res == null) return {};
      final data = _safeJsonDecode(res.stdout.toString());
      return _parseRecommendations(data);
    } catch (e) {
      debugPrint("getRecommendations Error: $e");
      return {};
    }
  }

  Map<String, List<AppPackage>> _parseRecommendations(dynamic data) {
    final Map<String, List<AppPackage>> result = {};
    if (data is Map) {
      data.forEach((k, v) {
        if (v is List) {
          result[k.toString()] = v
              .whereType<Map<String, dynamic>>()
              .map((i) => AppPackage.fromJson(i))
              .toList();
        }
      });
    } else if (data is List) {
      result["featured"] = data
          .whereType<Map<String, dynamic>>()
          .map((i) => AppPackage.fromJson(i))
          .toList();
    }
    return result;
  }

  Future<bool> launchApp(String n, String s) async {
    if (kIsWeb) {
      return PackageRepository().launchApp(n, s);
    }
    try {
      _validateString(n, "App Name");
      _validateString(s, "Source");
      final daemonRes = await _sendToDaemon("run_launch", [
        n.trim(),
        s.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon launchApp error: $e. Falling back.");
    }
    try {
      SecurityValidator.validateString(n, "App Name");
      SecurityValidator.validateString(s, "Source");
      final res = await _safeRun([
        "--launch",
        n.trim(),
        "--source",
        s.trim(),
        "--json",
      ], timeout: const Duration(seconds: 15));
      return res?.exitCode == 0;
    } catch (e) {
      debugPrint("launchApp Error: $e");
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
      final daemonRes = await _sendToDaemon("run_locate", [
        n.trim(),
        s.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon locateApp error: $e. Falling back.");
    }
    try {
      SecurityValidator.validateString(n, "App Name");
      SecurityValidator.validateString(s, "Source");
      final res = await _safeRun([
        "--locate",
        n.trim(),
        "--source",
        s.trim(),
        "--json",
      ], timeout: const Duration(seconds: 10));
      return res?.exitCode == 0;
    } catch (e) {
      debugPrint("locateApp Error: $e");
      return false;
    }
  }

  Future<AppPackage?> getAppDetails(String id) async {
    if (kIsWeb) {
      return PackageRepository().getAppDetails(id);
    }
    try {
      _validateString(id, "App ID");
      final daemonRes = await _sendToDaemon("run_app_details", [
        id.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        if (data is Map<String, dynamic>) return AppPackage.fromJson(data);
      }
    } catch (e) {
      debugPrint("Daemon getAppDetails error: $e. Falling back.");
    }
    try {
      _validateString(id, "App ID");
      final res = await _safeRun([
        "--details",
        id.trim(),
        "--json",
      ], timeout: const Duration(seconds: 25));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      if (data is Map<String, dynamic>) return AppPackage.fromJson(data);
      return null;
    } catch (e) {
      debugPrint("getAppDetails Error: $e");
      return null;
    }
  }

  Stream<String> executeAction(String f, String n, String s, {String? url}) {
    if (kIsWeb) {
      return TaskRepository().executeAction(f, n, s, url: url);
    }

    try {
      SecurityValidator.validateString(n, "App Name");
      SecurityValidator.validateString(s, "Source");
      if (!["-I", "-R", "-U"].contains(f)) {
        throw ArgumentError("Invalid action flag: $f");
      }
      if (url != null && url.trim().isNotEmpty) {
        SecurityValidator.validateUrl(url);
      }
    } catch (e) {
      return Stream.value(
        "[CALLBACK] {\"type\": \"log\", \"message\": \"[ERROR] $e\", \"level\": \"ERROR\"}",
      );
    }

    final trimmedName = n.trim();
    List<String> args = [f, trimmedName, "--source", s.trim(), "--json"];
    if (url != null && url.trim().isNotEmpty) {
      args.addAll(["--url", url.trim()]);
    }
    return _safeStream(args);
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return TaskRepository().checkUpdates();
    }
    try {
      final daemonRes = await _sendToDaemon("run_check_updates", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return data is List ? data : [];
      }
    } catch (e) {
      debugPrint("Daemon checkUpdates error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "-C",
        "--json",
      ], timeout: const Duration(seconds: 60));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
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
      SecurityValidator.validateString(s, "Update Source");
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
      final daemonRes = await _sendToDaemon("run_get_essentials", []);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return data is List ? data : [];
      }
    } catch (e) {
      debugPrint("Daemon getEssentials error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["--essentials", "--json"]);
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return data is List ? data : [];
    } catch (e) {
      debugPrint("getEssentials Error: $e");
      return [];
    }
  }

  Future<bool> updateDaemonEnv(Map<String, String> env) async {
    if (kIsWeb) return false;
    try {
      final daemonRes = await _sendToDaemon("run_update_env", [env, true]);
      return daemonRes != null && daemonRes.status == 'success';
    } catch (e) {
      debugPrint("Daemon updateDaemonEnv error: $e");
      return false;
    }
  }

  Future<List<dynamic>> importPackages(String path) async {
    if (kIsWeb) {
      return PackageRepository().importPackages(path);
    }
    try {
      _validatePath(path);
      final daemonRes = await _sendToDaemon("run_import_packages", [
        path.trim(),
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return data is List ? data : [];
      }
    } catch (e) {
      debugPrint("Daemon importPackages error: $e. Falling back.");
    }
    try {
      SecurityValidator.validatePath(path);
      final res = await _safeRun(["--import-packages", path.trim(), "--json"]);
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return data is List ? data : [];
    } catch (e) {
      debugPrint("importPackages Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    if (kIsWeb) {
      return TaskRepository().exportPackages(path);
    }
    try {
      _validatePath(path);
      final daemonRes = await _sendToDaemon("run_export_packages", [
        path.trim(),
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return (data is Map<String, dynamic>) ? data : {"status": "error"};
      }
    } catch (e) {
      debugPrint("Daemon exportPackages error: $e. Falling back.");
    }
    try {
      _validatePath(path);
      final res = await _safeRun([
        "--export-packages",
        path.trim(),
        "--json",
      ], timeout: const Duration(seconds: 30));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {"status": "error"};
    } catch (e) {
      debugPrint("exportPackages Error: $e");
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
      SecurityValidator.validateString(type, "Repo Type");
      SecurityValidator.validateString(name, "Repo Name");
      SecurityValidator.validateUrl(url);

      final daemonRes = await _sendToDaemon("run_add_custom_repo", [
        type.trim(),
        name.trim(),
        url.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon addCustomRepo error: $e. Falling back.");
    }
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
      SecurityValidator.validateString(type, "Repo Type");
      SecurityValidator.validateString(name, "Repo Name");

      final daemonRes = await _sendToDaemon("run_remove_custom_repo", [
        type.trim(),
        name.trim(),
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon removeCustomRepo error: $e. Falling back.");
    }
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

  Future<Map<String, dynamic>> getStorageInfo() async {
    if (kIsWeb) return {};
    try {
      final daemonRes = await _sendToDaemon("run_get_storage_info", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return (data is Map<String, dynamic>) ? data : {};
      }
    } catch (e) {
      debugPrint("Daemon getStorageInfo error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--storage-info",
        "--json",
      ], timeout: const Duration(seconds: 15));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {};
    } catch (e) {
      debugPrint("getStorageInfo Error: $e");
      return {};
    }
  }

  Future<void> shutdownBackend() async {
    if (kIsWeb) return;
    await _ipc.shutdown();
  }

  Future<Map<String, dynamic>> testAiConnection() async {
    if (kIsWeb) return {"status": "error", "response": "Not supported on web"};
    try {
      final daemonRes = await _sendToDaemon("run_ai_test", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return (data is Map<String, dynamic>)
            ? data
            : {"status": "error", "response": "Invalid format"};
      }
    } catch (e) {
      debugPrint("Daemon testAiConnection error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "--ai-test",
        "--json",
      ], timeout: const Duration(seconds: 60));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>)
          ? data
          : {"status": "error", "response": "Invalid response"};
    } catch (e) {
      debugPrint("testAiConnection Error: $e");
      return {"status": "error", "response": e.toString()};
    }
  }
}
