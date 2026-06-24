import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Murphy-proof: Centralized platform and environment resolution.
/// Ensures consistent pathing and capability detection across the app.
class PlatformEnvironment {
  static final PlatformEnvironment instance = PlatformEnvironment._internal();
  factory PlatformEnvironment() => instance;
  PlatformEnvironment._internal();

  String get projectRoot {
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

  bool get isPackaged {
    if (kIsWeb) return false;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final pythonServer = p.join(
      exeDir,
      'backends',
      Platform.isWindows ? 'python_server.exe' : 'python_server',
    );
    return File(pythonServer).existsSync();
  }

  String get venvPython {
    if (kIsWeb) return '';
    if (isPackaged) {
      return p.join(
        p.dirname(Platform.resolvedExecutable),
        'backends',
        Platform.isWindows ? 'python_server.exe' : 'python_server',
      );
    }
    final candidate = p.join(projectRoot, 'python', '.venv', 'bin', 'python');
    return File(candidate).existsSync() ? candidate : 'python';
  }

  String get scriptPath {
    if (kIsWeb) return '';
    if (isPackaged) return "";
    return p.join(projectRoot, 'python', 'main.py');
  }

  String get workingDir {
    if (kIsWeb) return '';
    if (isPackaged) return p.dirname(Platform.resolvedExecutable);
    return p.join(projectRoot, 'python');
  }

  List<String> buildArgs(List<String> baseArgs) {
    if (kIsWeb) return [];
    if (isPackaged) {
      return baseArgs;
    } else {
      return [scriptPath, ...baseArgs];
    }
  }

  void validateString(String? val, String name) {
    if (val == null || val.trim().isEmpty) {
      throw ArgumentError("$name cannot be null or empty");
    }
    final trimmed = val.trim();
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError("Invalid characters in $name: Only alphanumeric, '.', '_', '/', '-', and spaces are allowed.");
    }
  }

  void validatePath(String? path) {
    if (path == null || path.trim().isEmpty) {
      throw ArgumentError("Path cannot be null or empty");
    }
    final trimmed = path.trim();
    if (!RegExp(r'^[a-zA-Z0-9._/ -]+$').hasMatch(trimmed)) {
      throw ArgumentError("Invalid characters in path: Security policy forbids shell metacharacters.");
    }
    if (trimmed.contains('..')) {
      throw ArgumentError("Security: Relative path traversal ('..') is strictly forbidden.");
    }
  }
}
