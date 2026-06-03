import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../python_bridge.dart';

class ConfigRepository {
  Future<Map<String, dynamic>> loadConfig() async {
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
      return {};
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
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
      return exitCode == 0;
    } catch (e) {
      debugPrint("saveConfig Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkEnv() async {
    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--check-env", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      return {};
    }
  }
}
