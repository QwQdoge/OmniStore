import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  Future<Map<String, dynamic>> loadConfig() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw == null) {
          await prefs.setString(_webConfigKey, jsonEncode(_defaultWebConfig));
          return Map<String, dynamic>.from(_defaultWebConfig);
        }
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Web loadConfig Exception: $e");
        return Map<String, dynamic>.from(_defaultWebConfig);
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
      return jsonDecode(output) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("loadConfig Exception: $e");
      // Fallback to SharedPreferences on desktop if python is broken
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw != null) {
          return jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
      return Map<String, dynamic>.from(_defaultWebConfig);
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(_webConfigKey, jsonEncode(config));
      } catch (e) {
        debugPrint("Web saveConfig Exception: $e");
        return false;
      }
    }

    try {
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

      return exitCode == 0;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(_webConfigKey, jsonEncode(config));
      } catch (_) {}
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    if (kIsWeb) {
      return {
        "platform": "Web / Browser",
        "python_status": "Not supported (Browser Sandbox)",
        "available_sources": ["GitHub", "Bitu"],
        "os_details": "Chrome / Web browser environment"
      };
    }

    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--check-env", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      return {
        "platform": "Unknown/Desktop",
        "python_status": "Error: $e",
        "available_sources": ["GitHub", "Bitu"]
      };
    }
  }
}
