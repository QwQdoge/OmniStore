import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/package_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_package.dart';
import 'backend/process_registry.dart';
import 'backend/daemon_client.dart';
import 'backend/platform_environment.dart';
import 'backend/security_validator.dart';
import 'backend/daemon_ipc_service.dart';
import 'backend/process_execution_service.dart';
import '../features/ai/account_ai_prompts.dart';
import '../features/ai/account_ai_service.dart';
import '../features/ai/local_ai_service.dart';

export 'backend/daemon_client.dart' show DaemonResult;

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;

  late final ProcessRegistry _processRegistry;
  late final DaemonClient _daemonClient;

  // Specialized Services
  late final DaemonIpcService _ipc;
  late final ProcessExecutionService _executor;

  BackendService._internal() {
    _processRegistry = ProcessRegistry();
    _daemonClient = DaemonClient(onDemandStart: _startDaemonIfNeeded);
    _ipc = DaemonIpcService(_daemonClient);
    _executor = ProcessExecutionService(_processRegistry);
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
  Future<Process?>? _daemonStartFuture;
  bool _backgroundDaemonEnabled = false;
  bool _backgroundDaemonConfigured = false;
  int _daemonRestartCount = 0;
  DateTime? _lastDaemonStartTime;

  bool get backgroundDaemonEnabled => _backgroundDaemonEnabled;

  Future<void> setBackgroundDaemonEnabled(bool enabled) async {
    if (_backgroundDaemonConfigured && _backgroundDaemonEnabled == enabled) {
      return;
    }
    _backgroundDaemonConfigured = true;
    _backgroundDaemonEnabled = enabled;
    if (enabled) {
      _scheduleHealthCheck(const Duration(seconds: 20));
      return;
    }
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    await _daemonClient.shutdown(startIfNeeded: false);
    _daemonProcess = null;
    _daemonRestartCount = 0;
    _lastDaemonStartTime = null;
  }

  Future<Process?> _startDaemonIfNeeded() async {
    if (kIsWeb || !_backgroundDaemonEnabled) return null;
    final activeStart = _daemonStartFuture;
    if (activeStart != null) return activeStart;
    final start = _startDaemonOnce();
    _daemonStartFuture = start;
    try {
      return await start;
    } finally {
      if (identical(_daemonStartFuture, start)) _daemonStartFuture = null;
    }
  }

  Future<bool> _probeDaemon() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        '127.0.0.1',
        9081,
        timeout: const Duration(seconds: 1),
      );
      socket.write(
        '${jsonEncode({"action": "ping", "args": [], "kwargs": {}})}\n',
      );
      await socket.flush().timeout(const Duration(seconds: 1));
      final line = await socket
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 2));
      final response = jsonDecode(line);
      return response is Map &&
          response['status'] == 'success' &&
          response['response'] is Map &&
          response['response']['protocol'] == 1;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<Process?> _startDaemonOnce() async {
    if (await _probeDaemon()) {
      _daemonRestartCount = 0;
      return null;
    }

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

    // Guard: Prevent rapid restart-loop "storm" with exponential backoff logic
    final now = DateTime.now();
    if (_lastDaemonStartTime != null &&
        now.difference(_lastDaemonStartTime!) < const Duration(seconds: 15)) {
      _daemonRestartCount++;
      if (_daemonRestartCount > 3) {
        final backoff = Duration(seconds: 5 * _daemonRestartCount);
        debugPrint(
          "Murphy-proof: Daemon restart storm detected. Throttling for ${backoff.inSeconds}s.",
        );
        await Future.delayed(backoff);
      }
      if (_daemonRestartCount > 10) {
        debugPrint(
          "Murphy-proof Fatal: Daemon failed to stabilize after 10 retries.",
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
      // Murphy-proof: Strict environment check before process launch
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
            // Murphy-proof: Ensure new process group for the daemon
            runInShell: false,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                "Failed to start Python daemon within 15s",
              );
            },
          );

      // Murphy-proof: Immediate registration to ensure reaping on exit
      _processRegistry.add(_daemonProcess!);

      // The daemon protocol uses the socket only. Always drain stdout so a
      // mismatched/older backend can never block when its pipe fills up.
      _daemonProcess!.stdout.listen(
        (_) {},
        onError: (error) => debugPrint('Daemon stdout drain error: $error'),
      );

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

      final spawnedDaemon = _daemonProcess!;
      spawnedDaemon.exitCode.then((exitCode) {
        if (identical(_daemonProcess, spawnedDaemon)) {
          _daemonProcess = null;
        }
        if (_backgroundDaemonEnabled && exitCode != 0) {
          _daemonRestartCount++;
          _scheduleHealthCheck(_restartBackoff());
        }
      });
      _scheduleHealthCheck(const Duration(seconds: 20));
      return _daemonProcess;
    } catch (e) {
      debugPrint("Failed to start Python daemon: $e");
      return null;
    }
  }

  Duration _restartBackoff() {
    final exponent = _daemonRestartCount.clamp(0, 5);
    return Duration(seconds: (5 * (1 << exponent)).clamp(5, 300));
  }

  void _scheduleHealthCheck(Duration delay) {
    _healthCheckTimer?.cancel();
    if (!_backgroundDaemonEnabled || (!Platform.isLinux && !Platform.isMacOS)) {
      return;
    }
    _healthCheckTimer = Timer(delay, () async {
      final healthy = await _probeDaemon();
      if (healthy) {
        _daemonRestartCount = 0;
        _scheduleHealthCheck(const Duration(seconds: 20));
        return;
      }
      _daemonRestartCount++;
      await _startDaemonIfNeeded();
      if (await _probeDaemon()) {
        _daemonRestartCount = 0;
        _scheduleHealthCheck(const Duration(seconds: 20));
      } else {
        _scheduleHealthCheck(_restartBackoff());
      }
    });
  }

  Future<DaemonResult?> _sendToDaemon(
    String action,
    List<dynamic> args, [
    Map<String, dynamic>? kwargs,
  ]) async {
    if (_isTestEnv || !_backgroundDaemonEnabled) return null;
    return _ipc.send(action, args, kwargs: kwargs);
  }

  Future<ProcessResult?> runRaw(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _executor.run(args: args, timeout: timeout);
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
      yield* _executor.stream(
        args: args,
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
      try {
        return await PackageRepository().searchPackages(
          query,
          cancelOngoing: cancelOngoing,
        );
      } catch (e) {
        debugPrint("Web searchPackages Error: $e");
        return [];
      }
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

    // Murphy-proof: Use daemon with automatic fallbacks and strong typing
    try {
      final daemonRes = await _sendToDaemon("run_search", [trimmedQuery, true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        // Murphy-proof: Support both stdout-wrapped JSON and direct response body
        final rawData = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map((item) => AppPackage.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Daemon searchPackages error: $e. Falling back.");
    }

    // Legacy fallback: Raw process execution
    try {
      if (cancelOngoing && activeSearchProcess != null) {
        await _killProcess(activeSearchProcess).catchError((_) {});
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
        // Multi-stage Recovery:
        // 1. Precise balanced JSON extraction using non-greedy scan
        final jsonPattern = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])');
        final matches = jsonPattern.allMatches(cleaned).toList();

        if (matches.isNotEmpty) {
          for (final match in matches.reversed) {
            final candidate = match.group(0)!;
            // Murphy-proof: Basic brace balancing check before full decode
            int balance = 0;
            bool inQuote = false;
            for (int i = 0; i < candidate.length; i++) {
              if (candidate[i] == '"' && (i == 0 || candidate[i - 1] != '\\')) {
                inQuote = !inQuote;
              }
              if (!inQuote) {
                if (candidate[i] == '{' || candidate[i] == '[') balance++;
                if (candidate[i] == '}' || candidate[i] == ']') balance--;
              }
            }
            if (balance == 0) {
              try {
                return jsonDecode(candidate);
              } catch (_) {}
            }
          }
        }

        // 2. Fragment Stitching: Try to find a JSON object that was split across lines
        // This is a last-resort for heavily corrupted or streaming output
        if (cleaned.contains('{') && cleaned.contains('}')) {
          final firstBrace = cleaned.indexOf('{');
          final lastBrace = cleaned.lastIndexOf('}');
          if (lastBrace > firstBrace) {
            final candidate = cleaned.substring(firstBrace, lastBrace + 1);
            try {
              return jsonDecode(candidate);
            } catch (_) {}
          }
        }

        // 3. Line-by-line tail recovery
        final lines = cleaned.split('\n');
        final scanDepth = lines.length.clamp(0, 100);
        final startIdx = (lines.length - scanDepth).clamp(0, lines.length);

        for (int i = lines.length - 1; i >= startIdx; i--) {
          final lineCandidate = lines[i].trim();
          if (lineCandidate.isEmpty) continue;

          if (lineCandidate.startsWith('{') || lineCandidate.startsWith('[')) {
            try {
              return jsonDecode(lineCandidate);
            } catch (_) {}
          }

          final jsonStart = lineCandidate.indexOf(RegExp(r'[\{\[]'));
          if (jsonStart != -1) {
            final subCandidate = lineCandidate.substring(jsonStart);
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

  Future<List<AppPackage>> listInstalled({bool forceRefresh = false}) async {
    if (kIsWeb) {
      try {
        final results = await PackageRepository().listInstalled();
        return results
            .whereType<Map<String, dynamic>>()
            .map((e) => AppPackage.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint("Web listInstalled Error: $e");
        return [];
      }
    }
    try {
      final daemonRes = await _sendToDaemon("run_list_installed", [
        true,
        forceRefresh,
        true,
      ]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final packages = _installedPackagesFromPayload(
          daemonRes.response ?? _safeJsonDecode(daemonRes.stdout),
        );
        if (packages != null) return packages;
      }
    } catch (e) {
      debugPrint("Daemon listInstalled error: $e. Falling back.");
    }
    try {
      final res = await _safeRun([
        "-L",
        if (forceRefresh) "--force-refresh",
        "--json",
      ], timeout: const Duration(seconds: 45));
      if (res == null || res.exitCode != 0) return [];
      final packages = _installedPackagesFromPayload(
        _safeJsonDecode(res.stdout.toString()),
      );
      if (packages != null) return packages;
      return [];
    } catch (e) {
      debugPrint("listInstalled Error: $e");
      return [];
    }
  }

  /// Accept both daemon lists and the CLI's CommandResponse envelope.
  /// The CLI wraps JSON output in `{status, response}`, while the daemon
  /// returns `response` directly.  Keeping this in one place prevents a
  /// successful Windows registry/Winget scan from being discarded by the UI.
  List<AppPackage>? _installedPackagesFromPayload(dynamic payload) {
    final data = payload is Map && payload['response'] is List
        ? payload['response']
        : payload;
    if (data is! List) return null;
    return data
        .whereType<Map>()
        .map((item) => AppPackage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<dynamic>> listPlugins() async {
    if (kIsWeb) return [];
    try {
      final daemonRes = await _sendToDaemon("run_list_plugins", [true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
    if (kIsWeb || _isTestEnv) {
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

  // Fail-safe AI counter
  int _aiFailureCount = 0;

  Future<({Map<String, dynamic> ai, String language})?>
  _configuredAiContext() async {
    final config = await ConfigRepository.instance.loadConfig();
    final rawAi = config['ai'];
    if (rawAi is! Map) return null;
    final ai = Map<String, dynamic>.from(rawAi);
    final language = OmniStoreAiPrompts.language(
      config['ui'] is Map
          ? '${(config['ui'] as Map)['language'] ?? 'zh-CN'}'
          : 'zh-CN',
    );
    return (ai: ai, language: language);
  }

  Future<String> _callConfiguredAi(
    FutureOr<OmniStoreAiPrompt> Function(String language) buildPrompt,
  ) async {
    final context = await _configuredAiContext();
    if (context == null) {
      throw const LocalAiException('AI 配置不可用。');
    }
    if (context.ai['enabled'] != true) {
      throw const LocalAiException('AI 功能尚未启用。');
    }
    final prompt = await buildPrompt(context.language);
    final temperature = context.ai['temperature'] is num
        ? (context.ai['temperature'] as num).toDouble()
        : 0.3;
    final configuredMaxTokens = context.ai['max_tokens'] is num
        ? (context.ai['max_tokens'] as num).toInt()
        : prompt.maxOutputTokens;
    final provider = '${context.ai['provider'] ?? 'ollama'}'.trim();
    if (provider == 'account') {
      final credentialId = '${context.ai['account_credential_id'] ?? ''}'
          .trim();
      if (credentialId.isEmpty) {
        throw const AccountAiException('请先在 OmniStore 设置中选择账号 AI 连接。');
      }
      return AccountAiService.instance.invokeWithConsent(
        credentialId: credentialId,
        purpose: prompt.purpose,
        dataCategories: prompt.dataCategories,
        systemPrompt: prompt.systemPrompt,
        userPrompt: prompt.userPrompt,
        model: '${context.ai['model'] ?? ''}',
        temperature: temperature,
        maxOutputTokens: configuredMaxTokens.clamp(1, prompt.maxOutputTokens),
      );
    }
    return LocalAiService.instance.invokeWithConsent(
      provider: provider,
      endpoint: '${context.ai['endpoint'] ?? ''}',
      model: '${context.ai['model'] ?? ''}',
      purpose: prompt.purpose,
      dataCategories: prompt.dataCategories,
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      temperature: temperature,
      maxOutputTokens: configuredMaxTokens.clamp(1, prompt.maxOutputTokens),
    );
  }

  Future<String> aiExplain(String name, String desc) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.explain(name, desc, language),
    );
  }

  Future<String> aiSummarizeUpdate(String n, String c, String next) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.summarizeUpdate(n, c, next, language),
    );
  }

  Future<String> aiGenerateCLI(String n, String s) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.cli(n, s, language),
    );
  }

  Future<String> aiDetectConflicts(String n) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.conflicts(n, language),
    );
  }

  Future<String> aiPickOfTheDay() async {
    return _callConfiguredAi(OmniStoreAiPrompts.pick);
  }

  Future<String> aiSuggestCorrection(String q) async {
    try {
      _validateString(q, "AI Query");
      return await _callConfiguredAi(
        (language) => OmniStoreAiPrompts.correction(q, language),
      );
    } catch (e) {
      return q;
    }
  }

  Future<String> aiCompareVariants(String n) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.compare(n, language),
    );
  }

  Future<String> aiSystemHealth() async {
    return _callConfiguredAi(
      (language) async => OmniStoreAiPrompts.health(await checkEnv(), language),
    );
  }

  Future<String> aiAnalyzeError(String log) async {
    return _callConfiguredAi(
      (language) => OmniStoreAiPrompts.analyzeError(log, language),
    );
  }

  Future<String> aiRecommend(String p) async {
    try {
      _validateString(p, "AI Prompt");
      final response = await _callConfiguredAi(
        (language) => OmniStoreAiPrompts.recommend(p, language),
      );
      _aiFailureCount = 0;
      return response;
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

  bool get _isTestEnv =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<Map<String, dynamic>> checkEnv() async {
    if (kIsWeb || _isTestEnv) {
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

  /// The selected Meo update channel is read from pacman's resolved repository
  /// list. It is never persisted as a Flutter preference.
  Future<Map<String, dynamic>> getMeoChannel() async {
    if (kIsWeb || _isTestEnv) {
      return const {"status": "success", "channel": "unconfigured"};
    }
    try {
      final result = await _safeRun(
        ["--meo-channel", "status", "--json"],
        timeout: const Duration(seconds: 20),
        useLock: true,
      );
      final data = _safeJsonDecode(result?.stdout.toString() ?? "");
      return data is Map<String, dynamic> ? data : const {"status": "error"};
    } catch (error) {
      debugPrint("getMeoChannel Error: $error");
      return const {"status": "error"};
    }
  }

  Future<Map<String, dynamic>> setMeoChannel(
    String channel, {
    bool confirmStableDowngrades = false,
  }) async {
    if (channel != "stable" && channel != "beta") {
      throw ArgumentError("Unknown Meo channel");
    }
    if (kIsWeb || _isTestEnv) return const {"status": "error"};
    final arguments = <String>["--meo-channel", channel];
    if (confirmStableDowngrades) {
      arguments.add("--confirm-meo-stable-downgrades");
    }
    arguments.add("--json");
    final result = await _safeRun(
      arguments,
      timeout: const Duration(minutes: 30),
      useLock: true,
    );
    final data = _safeJsonDecode(result?.stdout.toString() ?? "");
    return data is Map<String, dynamic> ? data : const {"status": "error"};
  }

  Stream<String> bootstrap() {
    if (kIsWeb || _isTestEnv) {
      return Stream.value(
        "[CALLBACK] {\"log\": \"[INFO] Environment is ready!\"}",
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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

  Future<Map<String, dynamic>> getInstallationDecision(
    String appName,
    List<AppVariant> variants,
  ) async {
    final fallback = <String, dynamic>{
      'recommendedVariant': variants
          .map((variant) => variant.source)
          .cast<String?>()
          .firstWhere(
            (source) => [
              'Flatpak',
              'Native',
              'Pacman',
              'AUR',
              'AppImage',
            ].contains(source),
            orElse: () => null,
          ),
      'reasons': ['Uses OmniStore\'s deterministic source priority.'],
      'risks': [
        'Review the publisher and requested permissions before installing.',
      ],
      'alternatives': variants
          .map((variant) => variant.source)
          .toSet()
          .toList(),
      'preflightChecks': [
        'Confirm available disk space.',
        'Confirm the selected source is enabled.',
      ],
    };
    if (appName.trim().isEmpty || variants.isEmpty) return fallback;
    final payload = variants
        .map((variant) => Map<String, dynamic>.from(variant.toJson()))
        .toList(growable: false);

    final aiContext = await _configuredAiContext();
    if (aiContext != null && aiContext.ai['enabled'] == true) {
      try {
        final response = await _callConfiguredAi(
          (language) => OmniStoreAiPrompts.installationDecision(
            appName.trim(),
            payload,
            language,
          ),
        );
        final recommendation = _installationDecisionFromText(
          response,
          variants,
        );
        if (recommendation != null) return recommendation;
      } catch (error) {
        debugPrint('AI installation decision fallback: ${error.runtimeType}');
      }
      return fallback;
    }
    return fallback;
  }

  Map<String, dynamic>? _installationDecisionFromText(
    String text,
    List<AppVariant> variants,
  ) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) return null;
      final result = Map<String, dynamic>.from(decoded);
      const listKeys = ['reasons', 'risks', 'alternatives', 'preflightChecks'];
      if (listKeys.any((key) => result[key] is! List)) return null;
      final sources = variants.map((variant) => variant.source).toSet();
      final selected = result['recommendedVariant'];
      if (selected != null && !sources.contains(selected)) return null;
      return result;
    } catch (_) {
      return null;
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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
        final data = daemonRes.response ?? _safeJsonDecode(daemonRes.stdout);
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

  Future<Map<String, dynamic>> testAiConnection({
    Map<String, dynamic>? aiOverride,
    String? ephemeralApiKey,
  }) async {
    final aiContext = aiOverride == null ? await _configuredAiContext() : null;
    final ai = aiOverride ?? aiContext?.ai;
    if (ai == null || ai['enabled'] != true) {
      return {"status": "error", "response": "AI 功能尚未启用。"};
    }
    final provider = '${ai['provider'] ?? 'ollama'}'.trim();
    if (provider == 'account') {
      final credentialId = '${ai['account_credential_id'] ?? ''}'.trim();
      if (credentialId.isEmpty) {
        return {"status": "error", "response": "请先选择账号 AI 连接。"};
      }
      return AccountAiService.instance.testConnection(
        credentialId: credentialId,
        model: '${ai['model'] ?? ''}',
      );
    }
    final localService = ephemeralApiKey == null
        ? LocalAiService.instance
        : LocalAiService(keyReader: (_) async => ephemeralApiKey);
    return localService.testConnection(
      provider: provider,
      endpoint: '${ai['endpoint'] ?? ''}',
      model: '${ai['model'] ?? ''}',
    );
  }
}
