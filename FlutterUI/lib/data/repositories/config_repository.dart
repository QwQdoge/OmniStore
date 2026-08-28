import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../python_bridge.dart';

typedef ConfigPersistenceWriter =
    Future<bool> Function(Map<String, dynamic> config);

class _ConfigRepositoryState {
  Timer? saveTimer;
  Map<String, dynamic>? pendingConfig;
  Completer<bool>? pendingCompleter;
  Future<void> writeTail = Future<void>.value();
  Map<String, dynamic>? cachedConfig;
  Map<String, dynamic>? cachedEnv;
}

class ConfigRepository {
  static const String _webConfigKey = 'omnistore_config';
  static final _ConfigRepositoryState _sharedState = _ConfigRepositoryState();

  /// Shared production instance. Default-constructed repositories also use the
  /// same state so accidental duplicate instances cannot race each other.
  static final ConfigRepository instance = ConfigRepository._(_sharedState);

  final _ConfigRepositoryState _state;
  final ConfigPersistenceWriter? _desktopWriter;
  final Duration _saveDebounce;

  ConfigRepository() : this._(_sharedState);

  ConfigRepository._(this._state)
    : _desktopWriter = null,
      _saveDebounce = const Duration(milliseconds: 500);

  @visibleForTesting
  ConfigRepository.test({
    ConfigPersistenceWriter? desktopWriter,
    Duration saveDebounce = const Duration(milliseconds: 500),
  }) : _state = _ConfigRepositoryState(),
       // Public test constructor intentionally keeps non-private argument names.
       // ignore: prefer_initializing_formals
       _desktopWriter = desktopWriter,
       // ignore: prefer_initializing_formals
       _saveDebounce = saveDebounce;

  static final Map<String, dynamic> _defaultWebConfig = {
    "first_run": true,
    "search": {
      "sources": {
        "pacman": false,
        "aur": false,
        "flatpak": false,
        "appimage": false,
        "snap": false,
        "github": true,
        "bitu": true,
        "winget": false,
        "scoop": false,
        "brew": false,
        "ai": false,
      },
      "max_results": 50,
    },
    "ui": {
      "appearance": "system",
      "color_seed": "#4E7EEF",
      "language": "zh-CN",
      "enable_system_tray": false,
      "close_to_tray": false,
    },
    "ai": {
      "enabled": false,
      "provider": "ollama",
      "account_credential_id": "",
      "endpoint": "http://localhost:11434",
      "model": "qwen2.5:1.5b",
      "api_key": "",
    },
  };

  bool get _isTestEnv =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool get _preferencesArePrimary =>
      _desktopWriter == null && (kIsWeb || _isTestEnv);

  Map<String, dynamic> _copyMap(Map<String, dynamic> value) {
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  Map<String, dynamic> _decodeMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Configuration root must be an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _commitConfig(Map<String, dynamic> config) {
    _state.cachedConfig = _copyMap(config);
    _state.cachedEnv = null;
  }

  Future<Map<String, dynamic>> loadConfig({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _settlePendingWrites();
    }

    final cachedConfig = _state.cachedConfig;
    if (cachedConfig != null && !forceRefresh) {
      return _copyMap(cachedConfig);
    }

    if (kIsWeb || _isTestEnv) {
      return _loadPreferencesOrDefault();
    }

    try {
      final result = await PythonBridge.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--get-config", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 5));

      if (result.exitCode != 0) {
        debugPrint(
          'loadConfig failed with exit code ${result.exitCode}; '
          'using the last local backup.',
        );
        return await _loadPreferencesOrDefault();
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        debugPrint('loadConfig returned no data; using the last local backup.');
        return await _loadPreferencesOrDefault();
      }

      final config = _decodeMap(output);
      _state.cachedConfig = _copyMap(config);
      return _copyMap(config);
    } catch (error) {
      debugPrint(
        'loadConfig failed (${error.runtimeType}); '
        'using the last local backup.',
      );
      return _loadPreferencesOrDefault();
    }
  }

  Future<Map<String, dynamic>> _loadPreferencesOrDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webConfigKey);
      if (raw != null) {
        final config = _decodeMap(raw);
        _state.cachedConfig = _copyMap(config);
        return _copyMap(config);
      }

      final defaultConfig = _copyMap(_defaultWebConfig);
      final stored = await prefs.setString(
        _webConfigKey,
        jsonEncode(defaultConfig),
      );
      if (!stored) {
        debugPrint('Failed to persist the default OmniStore configuration.');
      }
      _state.cachedConfig = _copyMap(defaultConfig);
      return _copyMap(defaultConfig);
    } catch (error) {
      debugPrint(
        'Local configuration backup could not be loaded '
        '(${error.runtimeType}).',
      );
      final defaultConfig = _copyMap(_defaultWebConfig);
      _state.cachedConfig = _copyMap(defaultConfig);
      return _copyMap(defaultConfig);
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    late final Map<String, dynamic> snapshot;
    try {
      snapshot = _copyMap(config);
    } catch (error) {
      debugPrint(
        'Configuration is not JSON serializable (${error.runtimeType}).',
      );
      return false;
    }

    if (_preferencesArePrimary) {
      return _enqueueWrite(() => _persistPreferencesAsPrimary(snapshot));
    }

    _state.pendingConfig = snapshot;
    final completer = _state.pendingCompleter ??= Completer<bool>();

    _state.saveTimer?.cancel();
    _state.saveTimer = Timer(_saveDebounce, () {
      unawaited(_flushPendingConfig());
    });

    return completer.future;
  }

  Future<void> _flushPendingConfig() async {
    _state.saveTimer = null;
    final configToSave = _state.pendingConfig;
    final completer = _state.pendingCompleter;
    _state.pendingConfig = null;
    _state.pendingCompleter = null;

    if (configToSave == null) {
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      }
      return;
    }

    final success = await _enqueueWrite(
      () => _persistDesktopAndCommit(configToSave),
    );
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }

  Future<bool> _enqueueWrite(Future<bool> Function() operation) {
    final result = _state.writeTail.then((_) async {
      try {
        return await operation();
      } catch (error) {
        debugPrint('Configuration persistence failed (${error.runtimeType}).');
        return false;
      }
    });

    _state.writeTail = result.then<void>((_) {});
    return result;
  }

  Future<bool> _persistPreferencesAsPrimary(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = await prefs.setString(_webConfigKey, jsonEncode(config));
      if (!stored) return false;
      _commitConfig(config);
      return true;
    } catch (error) {
      debugPrint(
        'Configuration preferences write failed (${error.runtimeType}).',
      );
      return false;
    }
  }

  Future<bool> _persistDesktopAndCommit(Map<String, dynamic> config) async {
    final desktopWriter = _desktopWriter;
    final persisted = desktopWriter != null
        ? await desktopWriter(_copyMap(config))
        : await _writeDesktopConfig(config);
    if (!persisted) return false;

    _commitConfig(config);
    await _writeBackup(config);
    return true;
  }

  Future<bool> _writeDesktopConfig(Map<String, dynamic> config) async {
    Process? process;
    try {
      process = await PythonBridge.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--set-config", "stdin", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 5));

      final outputDrain = process.stdout.drain<void>();
      final errorDrain = process.stderr.drain<void>();

      process.stdin.write(jsonEncode(config));
      await process.stdin.close();

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 5),
      );
      await Future.wait([outputDrain, errorDrain]);
      return exitCode == 0;
    } catch (error) {
      process?.kill();
      debugPrint('saveConfig failed (${error.runtimeType}).');
      return false;
    }
  }

  Future<void> _writeBackup(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = await prefs.setString(_webConfigKey, jsonEncode(config));
      if (!stored) {
        debugPrint('The desktop configuration backup could not be updated.');
      }
    } catch (error) {
      debugPrint(
        'The desktop configuration backup could not be updated '
        '(${error.runtimeType}).',
      );
    }
  }

  Future<void> _settlePendingWrites() async {
    if (_state.pendingConfig != null) {
      _state.saveTimer?.cancel();
      _state.saveTimer = null;
      await _flushPendingConfig();
    }
    await _state.writeTail;
  }

  Future<Map<String, dynamic>> checkEnv({bool forceRefresh = false}) async {
    final cachedEnv = _state.cachedEnv;
    if (cachedEnv != null && !forceRefresh) {
      return _copyMap(cachedEnv);
    }

    if (kIsWeb || _isTestEnv) {
      final env = <String, dynamic>{
        "platform": "Web / Browser",
        "python_status": "Not supported (Browser Sandbox)",
        "available_sources": ["GitHub", "Bitu"],
        "os_details": "Chrome / Web browser environment",
      };
      _state.cachedEnv = _copyMap(env);
      return _copyMap(env);
    }

    try {
      final result = await PythonBridge.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--check-env", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 10));
      final env = _decodeMap(result.stdout.toString());
      _state.cachedEnv = _copyMap(env);
      return _copyMap(env);
    } catch (error) {
      debugPrint('checkEnv failed (${error.runtimeType}).');
      final env = <String, dynamic>{
        "platform": "Unknown/Desktop",
        "python_status": "Error",
        "available_sources": ["GitHub", "Bitu"],
      };
      _state.cachedEnv = _copyMap(env);
      return _copyMap(env);
    }
  }
}
