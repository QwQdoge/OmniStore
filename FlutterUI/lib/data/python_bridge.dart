import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves paths to `python/main.py` or the packaged `python_server` binary.
/// Lives in `lib/data/` (Flutter-side bridge), not the `python/` backend tree.
class PythonBridge {
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
