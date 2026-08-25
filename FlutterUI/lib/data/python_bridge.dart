import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Resolves paths to `python/main.py` or the packaged `python_server` binary.
/// Lives in `lib/data/` (Flutter-side bridge), not the `python/` backend tree.
class PythonBridge {
  static const _secureStorage = FlutterSecureStorage();
  // Legacy releases used this unbound key. It is migrated once to the
  // currently configured provider and then removed.
  static const String apiKeyStorageKey = 'omnistore_ai_api_key';
  static const Set<String> _credentialProviders = {
    'openai',
    'gemini',
    'deepseek',
    'openrouter',
    'openai_compatible',
  };

  static final Map<String, String> _testApiKeys = {};

  static String _normalizedCredentialProvider(String provider) {
    final normalized = provider.trim().toLowerCase() == 'custom'
        ? 'openai_compatible'
        : provider.trim().toLowerCase();
    if (!_credentialProviders.contains(normalized)) {
      throw ArgumentError.value(
        provider,
        'provider',
        'Unsupported AI credential provider',
      );
    }
    return normalized;
  }

  static String apiKeyStorageKeyForProvider(String provider) =>
      '${apiKeyStorageKey}_${_normalizedCredentialProvider(provider)}';

  static Future<String?> getApiKey({
    required String provider,
    bool throwOnError = false,
  }) async {
    final normalized = _normalizedCredentialProvider(provider);
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return _testApiKeys[normalized];
    }
    try {
      return await _secureStorage.read(
        key: apiKeyStorageKeyForProvider(normalized),
      );
    } catch (_) {
      if (throwOnError) rethrow;
      return null;
    }
  }

  static Future<void> saveApiKey(String key, {required String provider}) async {
    final normalized = _normalizedCredentialProvider(provider);
    if (key.isEmpty) {
      await deleteApiKey(provider: normalized);
      return;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testApiKeys[normalized] = key;
      return;
    }
    await _secureStorage.write(
      key: apiKeyStorageKeyForProvider(normalized),
      value: key,
    );
  }

  static Future<void> deleteApiKey({required String provider}) async {
    final normalized = _normalizedCredentialProvider(provider);
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testApiKeys.remove(normalized);
      return;
    }
    await _secureStorage.delete(key: apiKeyStorageKeyForProvider(normalized));
  }

  /// Moves the old provider-agnostic vault entry without ever exposing it to
  /// config, logs, subprocesses, or the network.
  static Future<bool> migrateLegacyApiKey({required String provider}) async {
    final normalized = _normalizedCredentialProvider(provider);
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    final current = await _secureStorage.read(
      key: apiKeyStorageKeyForProvider(normalized),
    );
    if (current != null && current.isNotEmpty) return false;
    final legacy = await _secureStorage.read(key: apiKeyStorageKey);
    if (legacy == null || legacy.isEmpty) return false;
    await _secureStorage.write(
      key: apiKeyStorageKeyForProvider(normalized),
      value: legacy,
    );
    await _secureStorage.delete(key: apiKeyStorageKey);
    return true;
  }

  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    final env = environment != null
        ? Map<String, String>.from(environment)
        : <String, String>{};
    // Generic Python helpers must never receive the AI credential. AI requests
    // are issued directly by the consent-gated Flutter services after approval.
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: env.isEmpty ? null : env,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );
  }

  static Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    final env = environment != null
        ? Map<String, String>.from(environment)
        : <String, String>{};
    // Keep secure-store credentials out of config and daemon subprocesses.
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: env.isEmpty ? null : env,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }

  static String get projectRoot {
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

  static bool get isPackaged {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final pythonServer = p.join(
      exeDir,
      'backends',
      Platform.isWindows ? 'python_server.exe' : 'python_server',
    );
    return File(pythonServer).existsSync();
  }

  static String get venvPython {
    if (isPackaged) {
      return p.join(
        p.dirname(Platform.resolvedExecutable),
        'backends',
        Platform.isWindows ? 'python_server.exe' : 'python_server',
      );
    }
    final String binPath = Platform.isWindows
        ? p.join('Scripts', 'python.exe')
        : p.join('bin', 'python');
    final candidate = p.join(projectRoot, 'python', '.venv', binPath);
    return File(candidate).existsSync() ? candidate : 'python';
  }

  static String get scriptPath {
    if (isPackaged) return "";
    return p.join(projectRoot, 'python', 'main.py');
  }

  static String get workingDir {
    if (isPackaged) return p.dirname(Platform.resolvedExecutable);
    return p.join(projectRoot, 'python');
  }

  static List<String> buildArgs(List<String> baseArgs) {
    if (isPackaged) {
      return baseArgs;
    } else {
      return [scriptPath, ...baseArgs];
    }
  }
}
