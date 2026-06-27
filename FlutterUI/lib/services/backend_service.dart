import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../data/repositories/config_repository.dart';
import '../data/repositories/package_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/python_bridge.dart';
import '../../models/app_package.dart';
import 'backend/process_registry.dart';
import 'backend/daemon_client.dart';
import 'backend/security_validator.dart';

export 'backend/daemon_client.dart' show DaemonResult;

class BackendService {
  static final BackendService instance = BackendService._internal();
  factory BackendService() => instance;

  late final ProcessRegistry _processRegistry;
  late final DaemonClient _daemonClient;

  BackendService._internal() {
    _processRegistry = ProcessRegistry();
    _daemonClient = DaemonClient(onDemandStart: _startDaemonIfNeeded);
  }

  // ignore: unused_field
  final Completer<void> _initCompleter = Completer<void>();

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
          final res =
              await Process.run('kill', ['-0', '${_daemonProcess!.pid}']);
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
            "Murphy-proof Warning: Daemon restart loop detected. Throttling.");
        return null;
      }
    } else {
      _daemonRestartCount = 0;
    }
    _lastDaemonStartTime = now;

    final home = Platform.environment['HOME'] ?? '/home/user';
    final logDir = Directory(p.join(home, '.config', 'omnistore'));
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    final logFile = File(p.join(logDir.path, 'daemon_stderr.log'));

    try {
      if (!File(_venvPython).existsSync() && _venvPython != 'python') {
        debugPrint("Backend Error: Python executable not found at $_venvPython");
        return null;
      }

      _daemonProcess = await Process.start(
        _venvPython,
        _buildArgs(['--daemon', '--json']),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Failed to start Python daemon within 10s");
      });

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
    int backoffSeconds = 20;

    _healthCheckTimer =
        Timer.periodic(Duration(seconds: backoffSeconds), (timer) async {
      bool needsRestart = false;
      if (_daemonProcess == null) {
        needsRestart = true;
      } else {
        try {
          if (Platform.isLinux || Platform.isMacOS) {
            final res =
                await Process.run('kill', ['-0', '${_daemonProcess!.pid}']);
            if (res.exitCode != 0) {
              debugPrint("Daemon dead detected by health check.");
              needsRestart = true;
            }
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

  // Murphy-proof: Circuit breaker for persistent daemon failures
  int _daemonFailureStreak = 0;
  static const int _daemonFailureThreshold = 5;

  Future<DaemonResult?> _sendToDaemon(
    String action,
    List<dynamic> args, [
    Map<String, dynamic>? kwargs,
  ]) async {
    if (_daemonFailureStreak >= _daemonFailureThreshold) {
      debugPrint("Circuit Breaker: Daemon persistent failure. Bypassing to CLI.");
      return null;
    }

    try {
      final res = await _daemonClient.send(action, args, kwargs: kwargs);
      _daemonFailureStreak = 0; // Reset on success
      return res;
    } catch (e) {
      _daemonFailureStreak++;
      debugPrint("Daemon IPC Error (Streak: $_daemonFailureStreak): $e");
      return null;
    }
  }

  Future<ProcessResult?> _safeRun(
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
    bool useLock = false,
  }) async {
    if (kIsWeb) return null;

    if (!File(_venvPython).existsSync() && _venvPython != 'python') {
      debugPrint("Backend Error: Python executable not found at $_venvPython");
      return null;
    }

    if (useLock) await _acquireLock();

    Process? process;
    try {
      final apiKey = await PythonBridge.getApiKey();
      final env = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        env['OMNISTORE_AI_API_KEY'] = apiKey;
      }

      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
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
      if (useLock) _releaseLock();
    }
  }

  Stream<String> _safeStream(List<String> args, {bool useLock = true}) async* {
    if (kIsWeb) {
      yield "[CALLBACK] {\"log\": \"Running in browser sandbox\"}";
      return;
    }
    if (useLock) await _acquireLock();

    Process? process;
    final controller = StreamController<String>();

    try {
      final apiKey = await PythonBridge.getApiKey();
      final env = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        env['OMNISTORE_AI_API_KEY'] = apiKey;
      }

      process = await Process.start(
        _venvPython,
        _buildArgs(args),
        workingDirectory: _workingDir,
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
        debugPrint(
          "Stream cancelled, performing deep cleanup for process ${process?.pid}",
        );
        stdoutSub.cancel();
        stderrSub.cancel();
        await _killProcess(process);
        if (activeProcess == process) activeProcess = null;
        if (!controller.isClosed) await controller.close();
      };

      yield* controller.stream;
    } catch (e) {
      debugPrint("BackendService._safeStream Exception: $e");
      yield "[CALLBACK] {\"key\": \"errorProcessStart\", \"error\": \"$e\"}";
      if (!controller.isClosed) await controller.close();
      if (process != null) await _killProcess(process);
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
    if (trimmedQuery.isEmpty) return [];
    if (trimmedQuery.length > 500) return [];

    try {
      SecurityValidator.validateString(trimmedQuery, "Search Query");
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
          results.addAll(
            parsed.map(
              (item) => AppPackage.fromJson(item as Map<String, dynamic>),
            ),
          );
        } else if (parsed is Map<String, dynamic>) {
          results.add(AppPackage.fromJson(parsed));
        }
        return results;
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

      final process = await Process.start(
        _venvPython,
        _buildArgs(["-S", trimmedQuery, "--json"]),
        workingDirectory: _workingDir,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Search process start timed out");
      });

      _processRegistry.add(process);
      activeSearchProcess = process;

      final results = <AppPackage>[];
      final output = await process.stdout
          .transform(utf8.decoder)
          .join()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException("Search timed out"),
          );

      final parsed = _safeJsonDecode(output);
      if (parsed is List) {
        results.addAll(
          parsed.map(
            (item) => AppPackage.fromJson(item as Map<String, dynamic>),
          ),
        );
      } else if (parsed != null) {
        results.add(AppPackage.fromJson(parsed as Map<String, dynamic>));
      }

      return results;
    } catch (e) {
      debugPrint("searchPackages [query: $query] Error: $e");
      return [];
    } finally {
      if (activeSearchProcess != null) {
        _processRegistry.remove(activeSearchProcess!);
        await _killProcess(activeSearchProcess);
      }
      activeSearchProcess = null;
    }
  }

  /// Murphy-proof: Strict JSON decoder with size limits, noise filtering,
  /// and fallback recovery for messy subprocess output.
  dynamic _safeJsonDecode(String input) {
    final rawInput = input.trim();
    if (rawInput.isEmpty) return null;

    // Boundary Defense: Reject payloads > 5MB to prevent OOM
    if (rawInput.length > 5 * 1024 * 1024) {
      debugPrint("Security Warning: Rejected JSON payload exceeding 5MB limit");
      return null;
    }

    try {
      return jsonDecode(rawInput);
    } catch (_) {
      // Noise Reduction: Strip ANSI escape codes and terminal artifacts
      final cleaned = rawInput.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');

      try {
        // Pattern-based extraction: look for the first balanced JSON structure
        final jsonPattern = RegExp(r'(\{[\s\S]*\}|\[[\s\S]*\])');
        final match = jsonPattern.firstMatch(cleaned);

        if (match != null) {
          final candidate = match.group(0)!;
          try {
            return jsonDecode(candidate);
          } catch (_) {
            // Last Resort: Line-by-line tail recovery for concatenated logs/JSON
            final lines = cleaned.split('\n');
            if (lines.length <= 200) {
              for (int i = lines.length - 1; i >= 0; i--) {
                try {
                  final tailCandidate = lines.sublist(i).join('\n').trim();
                  if (tailCandidate.startsWith('{') || tailCandidate.startsWith('[')) {
                    return jsonDecode(tailCandidate);
                  }
                } catch (_) {}
              }
            }
          }
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
    try {
      final daemonRes = await _sendToDaemon("run_list_installed", [true, false]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return data is List ? data : [];
      }
    } catch (e) {
      debugPrint("Daemon listInstalled error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["-L", "--json"], timeout: const Duration(seconds: 45));
      if (res == null || res.exitCode != 0) return [];
      final data = _safeJsonDecode(res.stdout.toString());
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
      final res = await _safeRun(["--get-config", "--json"], timeout: const Duration(seconds: 15));
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
        return "AI_TIMEOUT"; // Standardized internal code for l10n mapping
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

  // Fail-safe AI counter to prevent infinite retry loops in UI
  int _aiFailureCount = 0;

  Future<String> aiExplain(String name, String desc) async {
    try {
      SecurityValidator.validateString(name, "AI App Name");
      return await _aiCall(["--ai-explain", name.trim(), "--ai-desc", desc.trim()]);
    } catch (e) {
      return "AI Explanation unavailable: $e";
    }
  }

  Future<String> aiSummarizeUpdate(String n, String c, String next) async {
    try {
      SecurityValidator.validateString(n, "AI Package Name");
      return await _aiCall(["--ai-changelog", "${n.trim()},${c.trim()},${next.trim()}"]);
    } catch (e) {
      return "Update summary unavailable.";
    }
  }

  Future<String> aiGenerateCLI(String n, String s) async {
    try {
      SecurityValidator.validateString(n, "AI App Name");
      SecurityValidator.validateString(s, "AI Source");
      return await _aiCall(["--ai-cli", "${n.trim()},${s.trim()}"],
          timeout: const Duration(seconds: 20));
    } catch (e) {
      return "CLI generation failed.";
    }
  }

  Future<String> aiDetectConflicts(String n) async {
    try {
      SecurityValidator.validateString(n, "AI Package Name");
      return await _aiCall(["--ai-conflicts", n.trim()]);
    } catch (e) {
      return "Conflict detection failed.";
    }
  }

  Future<String> aiPickOfTheDay() async {
    try {
      return await _aiCall(["--ai-pick"]);
    } catch (e) {
       return "Pick of the day unavailable.";
    }
  }

  Future<String> aiSuggestCorrection(String q) async {
    try {
      SecurityValidator.validateString(q, "AI Query");
      return await _aiCall(["--ai-correct", q.trim()],
          timeout: const Duration(seconds: 15));
    } catch (e) {
      return q; // Graceful degradation: return original query
    }
  }

  Future<String> aiCompareVariants(String n) async {
    try {
      SecurityValidator.validateString(n, "AI App Name");
      return await _aiCall(["--ai-compare", n.trim()]);
    } catch (e) {
      return "Variant comparison unavailable.";
    }
  }

  Future<String> aiSystemHealth() async {
    try {
      return await _aiCall(["--ai-health"]);
    } catch (e) {
      return "System health report unavailable.";
    }
  }

  Future<String> aiAnalyzeError(String log) async {
    try {
      return await _aiCall(["--ai-analyze-error", log.trim()]);
    } catch (e) {
      return "Error analysis unavailable.";
    }
  }

  Future<String> aiRecommend(String p) async {
    try {
      SecurityValidator.validateString(p, "AI Prompt");
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
      // Murphy-proof: Immediate registration to ensure reaping on exit
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
      final res = await _safeRun(["--check-env", "--json"], timeout: const Duration(seconds: 15));
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
      }
    } catch (e) {
      debugPrint("Daemon getRecommendations error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["--recommend", "--json"], timeout: const Duration(seconds: 30));
      if (res == null) return {};
      final data = _safeJsonDecode(res.stdout.toString());
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
      SecurityValidator.validateString(n, "App Name");
      SecurityValidator.validateString(s, "Source");
      final daemonRes = await _sendToDaemon("run_launch", [n.trim(), s.trim(), true]);
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
      debugPrint("launchApp [name: $n] Error: $e");
      return false;
    }
  }

  Future<bool> locateApp(String n, String s) async {
    if (kIsWeb) {
      return PackageRepository().locateApp(n, s);
    }
    try {
      SecurityValidator.validateString(n, "App Name");
      SecurityValidator.validateString(s, "Source");
      final daemonRes = await _sendToDaemon("run_locate", [n.trim(), s.trim(), true]);
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
      debugPrint("locateApp [name: $n] Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> getAppDetails(String id) async {
    if (kIsWeb) {
      return PackageRepository().getAppDetails(id);
    }
    try {
      SecurityValidator.validateString(id, "App ID");
      final daemonRes = await _sendToDaemon("run_app_details", [id.trim(), true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return (data is Map<String, dynamic>) ? data : {};
      }
    } catch (e) {
      debugPrint("Daemon getAppDetails error: $e. Falling back.");
    }
    try {
      SecurityValidator.validateString(id, "App ID");
      final res = await _safeRun(["--details", id.trim(), "--json"], timeout: const Duration(seconds: 25));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
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
      final res = await _safeRun(["-C", "--json"], timeout: const Duration(seconds: 60));
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
      SecurityValidator.validatePath(path);
      final daemonRes = await _sendToDaemon("run_import_packages", [path.trim()]);
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
      debugPrint("importPackages [path: $path] Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> exportPackages(String path) async {
    if (kIsWeb) {
      return TaskRepository().exportPackages(path);
    }
    try {
      SecurityValidator.validatePath(path);
      final daemonRes = await _sendToDaemon("run_export_packages", [path.trim()]);
      if (daemonRes != null && daemonRes.status == 'success') {
        final data = _safeJsonDecode(daemonRes.stdout);
        return (data is Map<String, dynamic>) ? data : {"status": "error"};
      }
    } catch (e) {
      debugPrint("Daemon exportPackages error: $e. Falling back.");
    }
    try {
      SecurityValidator.validatePath(path);
      final res = await _safeRun(["--export-packages", path.trim(), "--json"], timeout: const Duration(seconds: 30));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
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
      SecurityValidator.validateString(type, "Repo Type");
      SecurityValidator.validateString(name, "Repo Name");
      SecurityValidator.validateUrl(url);

      final daemonRes = await _sendToDaemon(
          "run_add_custom_repo", [type.trim(), name.trim(), url.trim(), true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon addCustomRepo error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["--add-custom-repo", "$type,$name,$url", "--json"], timeout: const Duration(seconds: 20));
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

      final daemonRes = await _sendToDaemon("run_remove_custom_repo", [type.trim(), name.trim(), true]);
      if (daemonRes != null && daemonRes.status == 'success') {
        return daemonRes.response == true;
      }
    } catch (e) {
      debugPrint("Daemon removeCustomRepo error: $e. Falling back.");
    }
    try {
      final res = await _safeRun(["--remove-custom-repo", "$type,$name", "--json"], timeout: const Duration(seconds: 20));
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
      final res = await _safeRun(["--storage-info", "--json"], timeout: const Duration(seconds: 15));
      final data = _safeJsonDecode(res?.stdout?.toString() ?? "");
      return (data is Map<String, dynamic>) ? data : {};
    } catch (e) {
      debugPrint("getStorageInfo Error: $e");
      return {};
    }
  }

  Future<void> shutdownBackend() async {
    if (kIsWeb) return;
    try {
      await _sendToDaemon("shutdown", []);
    } catch (_) {}
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
      final res = await _safeRun(["--ai-test", "--json"], timeout: const Duration(seconds: 60));
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
