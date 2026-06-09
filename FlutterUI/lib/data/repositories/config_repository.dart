import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../python_bridge.dart';

class ConfigRepository {
  static const String _webConfigKey = 'omnistore_config';

  final Map<String, dynamic> _defaultWebConfig = {
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
        "ai": false
      },
      "max_results": 50
    },
    "ui": {
      "appearance": "system",
      "color_seed": "#4E7EEF",
      "language": "zh-CN",
      "enable_system_tray": false,
      "close_to_tray": false
    },
    "ai": {
      "enabled": false,
      "provider": "openai",
      "endpoint": "",
      "model": "",
      "api_key": ""
    }
  };

  Map<String, dynamic>? _cachedConfig;
  Map<String, dynamic>? _cachedEnv;

  // TODO: Consider reducing timeout to prevent UI freezes if Python startup is extremely slow.
  Future<Map<String, dynamic>> loadConfig({bool forceRefresh = false}) async {
    if (_cachedConfig != null && !forceRefresh) {
      return _cachedConfig!;
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw == null) {
          await prefs.setString(_webConfigKey, jsonEncode(_defaultWebConfig));
          _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
          return _cachedConfig!;
        }
        _cachedConfig = jsonDecode(raw) as Map<String, dynamic>;
        return _cachedConfig!;
      } catch (e) {
        debugPrint("Web loadConfig Exception: $e");
        _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
        return _cachedConfig!;
      }
    }

    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--get-config", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) {
        debugPrint(
          "loadConfig failed with exit code ${result.exitCode}: ${result.stderr}",
        );
        return {};
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};
      _cachedConfig = jsonDecode(output) as Map<String, dynamic>;
      return _cachedConfig!;
    } catch (e) {
      debugPrint("loadConfig Exception: $e");
      // Fallback to SharedPreferences on desktop if python is broken
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw != null) {
          _cachedConfig = jsonDecode(raw) as Map<String, dynamic>;
          return _cachedConfig!;
        }
      } catch (_) {}
      _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
      return _cachedConfig!;
    }
  }

  // TODO: Batch configuration updates to avoid spawning a process on every single change.
  // TODO: Move away from spawning a short-lived python process for config saving. Use persistent UDS/Socket connection.
  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.setString(_webConfigKey, jsonEncode(config));
        if (success) {
          _cachedConfig = config;
        }
        return success;
      } catch (e) {
        debugPrint("Web saveConfig Exception: $e");
        return false;
      }
    }

    try {
      // TODO: Define a shared JSON schema or Protobuf spec so Dart and Python config files are strongly typed.
      final process = await Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--set-config", "stdin", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 5));

      process.stdin.write(jsonEncode(config));
      await process.stdin.close();

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 5),
      );
      
      // Also save to preferences as a backup/sync mechanism
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_webConfigKey, jsonEncode(config));
      } catch (_) {}

      final success = exitCode == 0;
      if (success) {
        _cachedConfig = config;
        _cachedEnv = null; // Invalidate env check cache in case source configs changed
      }
      return success;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.setString(_webConfigKey, jsonEncode(config));
        if (success) {
          _cachedConfig = config;
        }
        return success;
      } catch (_) {}
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv({bool forceRefresh = false}) async {
    if (_cachedEnv != null && !forceRefresh) {
      return _cachedEnv!;
    }

    if (kIsWeb) {
      _cachedEnv = {
        "platform": "Web / Browser",
        "python_status": "Not supported (Browser Sandbox)",
        "available_sources": ["GitHub", "Bitu"],
        "os_details": "Chrome / Web browser environment"
      };
      return _cachedEnv!;
    }

    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--check-env", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 10));
      _cachedEnv = jsonDecode(result.stdout) as Map<String, dynamic>;
      return _cachedEnv!;
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      _cachedEnv = {
        "platform": "Unknown/Desktop",
        "python_status": "Error: $e",
        "available_sources": ["GitHub", "Bitu"]
      };
      return _cachedEnv!;
    }
  }
}
