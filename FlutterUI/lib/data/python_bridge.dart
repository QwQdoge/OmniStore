import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Resolves paths to `python/main.py` or the packaged `python_server` binary.
/// Lives in `lib/data/` (Flutter-side bridge), not the `python/` backend tree.
class PythonBridge {
  static const _secureStorage = FlutterSecureStorage();
  static const String apiKeyStorageKey = 'omnistore_ai_api_key';

  static Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: apiKeyStorageKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveApiKey(String key) async {
    try {
      await _secureStorage.write(key: apiKeyStorageKey, value: key);
    } catch (_) {}
  }

  static Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: apiKeyStorageKey);
    } catch (_) {}
  }

  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    final apiKey = await getApiKey();
    final env = environment != null ? Map<String, String>.from(environment) : <String, String>{};
    if (apiKey != null && apiKey.isNotEmpty) {
      env['OMNISTORE_AI_API_KEY'] = apiKey;
    }
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
    final apiKey = await getApiKey();
    final env = environment != null ? Map<String, String>.from(environment) : <String, String>{};
    if (apiKey != null && apiKey.isNotEmpty) {
      env['OMNISTORE_AI_API_KEY'] = apiKey;
    }
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
    final String binPath = Platform.isWindows ? p.join('Scripts', 'python.exe') : p.join('bin', 'python');
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
