import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/app_package.dart';
import '../backend_constants.dart';

class PackageRepository {
  Process? _activeSearchProcess;

  Future<List<dynamic>> searchPackages(
    String query, {
    bool cancelOngoing = true,
  }) async {
    if (cancelOngoing) _activeSearchProcess?.kill();

    try {
      final process = await Process.start(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["-S", query, "--json"]),
        workingDirectory: BackendConstants.workingDir,
      );

      if (cancelOngoing) _activeSearchProcess = process;

      final results = <dynamic>[];
      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          results.addAll(_tryParseJson(trimmed));
        }
      }

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 45),
      );
      _activeSearchProcess = null;

      if (exitCode != 0) {
        debugPrint('searchPackages failed with code $exitCode');
        return [];
      }

      return results;
    } catch (e) {
      _activeSearchProcess = null;
      debugPrint('searchPackages Exception: $e');
      return [];
    }
  }

  List<dynamic> _tryParseJson(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      const separator = "###JSON_START###";
      String target = input;
      if (input.contains(separator)) {
        target = input.split(separator).last.trim();
      }

      final start = target.lastIndexOf('[');
      final end = target.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        try {
          return jsonDecode(target.substring(start, end + 1));
        } catch (e) {
          debugPrint("Failed to parse extracted JSON block: $e");
        }
      }
      return [];
    }
  }

  Future<List<dynamic>> listInstalled() async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["-L", "--json"]),
        workingDirectory: BackendConstants.workingDir,
      ).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("ListInstalled Exception: $e");
      return [];
    }
  }

  Future<Map<String, List<AppPackage>>> getRecommendations() async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["--recommend", "--json"]),
        workingDirectory: BackendConstants.workingDir,
      ).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) return {};
      final output = result.stdout.toString().trim();
      if (output.isEmpty) return {};

      final dynamic data = jsonDecode(output);

      if (data is Map<String, dynamic>) {
        final Map<String, List<AppPackage>> categories = {};
        data.forEach((key, value) {
          if (value is List) {
            categories[key] = value
                .map(
                  (item) => AppPackage.fromJson(item as Map<String, dynamic>),
                )
                .toList();
          }
        });
        return categories;
      } else if (data is List) {
        return {
          "featured": data
              .map((item) => AppPackage.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return {};
    } catch (e) {
      debugPrint("Recommendations Exception: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> getAppDetails(String appId) async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["--details", appId, "--json"]),
        workingDirectory: BackendConstants.workingDir,
      ).timeout(const Duration(seconds: 20));
      return jsonDecode(result.stdout);
    } catch (e) {
      debugPrint("getAppDetails Exception: $e");
      return {};
    }
  }

  Future<List<dynamic>> getEssentials() async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["--essentials", "--json"]),
        workingDirectory: BackendConstants.workingDir,
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("getEssentials Exception: $e");
      return [];
    }
  }

  Future<bool> launchApp(String name, String source) async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs([
          "--launch",
          name,
          "--source",
          source,
          "--json",
        ]),
        workingDirectory: BackendConstants.workingDir,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> locateApp(String name, String source) async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs([
          "--locate",
          name,
          "--source",
          source,
          "--json",
        ]),
        workingDirectory: BackendConstants.workingDir,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> importPackages(String filepath) async {
    try {
      final result = await Process.run(
        BackendConstants.venvPython,
        BackendConstants.buildArgs(["--import-packages", filepath, "--json"]),
        workingDirectory: BackendConstants.workingDir,
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("importPackages Exception: $e");
      return [];
    }
  }
}
