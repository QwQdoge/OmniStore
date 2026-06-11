import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../python_bridge.dart';
import "../../services/local_apps_tracker.dart";
import "../../services/sync_service.dart";

class TaskRepository {
  Process? _activeProcess;

  Stream<String> executeAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) {
    if (packageName.isEmpty) {
      return Stream.value("[CALLBACK] {\"key\": \"errorPackageNameRequired\"}");
    }

    if (kIsWeb) {
      return _webExecuteAction(flag, packageName, source, url: url);
    }

    // NOTE: Convert stdout parsing to JSON-RPC over Local Sockets (UDS/TCP) to avoid parsing stdout text directly.
    // NOTE: Implement a heartbeat / watchdog system to detect if the Python subprocess hangs indefinitely.
    final controller = StreamController<String>();

    try {
      List<String> baseArgs = [flag, packageName, "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        baseArgs.addAll(["--url", url]);
      }

      // NOTE: Support multiplexing multiple concurrent tasks over a single persistent backend daemon process.
      Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(baseArgs),
        workingDirectory: PythonBridge.workingDir,
      ).then((process) {
        _activeProcess = process;

        // Listen to stdout
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!controller.isClosed) controller.add(line);
              },
              onError: (err) {
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}");
                }
              },
            );

        // Listen to stderr
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                debugPrint("Python Stderr: $line");
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"log\": \"stderr: $line\"}");
                }
              },
            );

        // Wait for exit code
        process.exitCode.then((exitCode) async {
          _activeProcess = null;
          if (exitCode != 0) {
            if (!controller.isClosed) {
              controller.add("[CALLBACK] {\"key\": \"errorStartFailed\", \"error\": \"Process exited with code $exitCode\"}");
            }
          } else {
            // Local tracking for OmniStore apps
            if (flag == "-I") {
              await LocalAppsTracker.trackApp(packageName);
              SyncService().syncInstalledApps();
            } else if (flag == "-R") {
              await LocalAppsTracker.untrackApp(packageName);
              SyncService().syncInstalledApps();
            }
          }
          if (!controller.isClosed) controller.close();
        });
      }).catchError((err) {
        _activeProcess = null;
        if (!controller.isClosed) {
          controller.add("[CALLBACK] {\"key\": \"errorStartFailed\", \"error\": \"$err\"}");
          controller.close();
        }
      });
    } catch (e) {
      _activeProcess = null;
      if (!controller.isClosed) {
        controller.add("[CALLBACK] {\"key\": \"errorStartFailed\", \"error\": \"$e\"}");
        controller.close();
      }
    }

    controller.onCancel = () {
      if (_activeProcess != null) {
        _activeProcess!.kill(ProcessSignal.sigterm);
        _activeProcess = null;
      }
    };

    return controller.stream;
  }

  Stream<String> _webExecuteAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) async* {
    final isInstall = flag == "-I";
    
    yield '[CALLBACK] {"type": "log", "message": "[INFO] Starting ${isInstall ? "install" : "uninstall"} for $packageName via $source...", "level": "INFO"}';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 10';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 40';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 80';
    await Future.delayed(const Duration(milliseconds: 300));
    
    yield '[PROGRESS] 100';
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final installedIds = prefs.getStringList('omnistore_installed_ids') ?? [];
    final installedCacheRaw = prefs.getString('omnistore_installed_packages_cache');
    List<dynamic> installedCache = [];
    if (installedCacheRaw != null) {
      try {
        installedCache = jsonDecode(installedCacheRaw) as List<dynamic>;
      } catch (_) {}
    }

    if (isInstall) {
      if (!installedIds.contains(packageName)) {
        installedIds.add(packageName);
      }
      installedCache.removeWhere((item) => item['id'] == packageName);
      installedCache.add({
        "name": packageName.split('/').last,
        "id": packageName,
        "primary_source": source,
        "installed": true,
        "description": "Installed via Omnistore Web client.",
        "version": "Latest",
        "url": url ?? "",
        "variants": [{"source": source, "id": packageName, "installed": true}]
      });
      await LocalAppsTracker.trackApp(packageName);
          SyncService().syncInstalledApps();
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Installed successfully!", "level": "SUCCESS"}';
    } else {
      installedIds.remove(packageName);
      installedCache.removeWhere((item) => item['id'] == packageName);
      await LocalAppsTracker.untrackApp(packageName);
          SyncService().syncInstalledApps();
      yield '[CALLBACK] {"type": "log", "message": "[INFO] Uninstalled successfully!", "level": "SUCCESS"}';
    }

    await prefs.setStringList('omnistore_installed_ids', installedIds);
    await prefs.setString('omnistore_installed_packages_cache', jsonEncode(installedCache));
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return [];
    }

    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["-C", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 30));

      if (result.exitCode != 0) return [];
      return _tryParseJson(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("CheckUpdates Exception: $e");
      return [];
    }
  }

  Stream<String> updateAll(String source) {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add('[CALLBACK] {"type": "log", "message": "[INFO] Starting system update on web...", "level": "INFO"}');
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.add('[PROGRESS] 50');
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        controller.add('[PROGRESS] 100');
        controller.add('[CALLBACK] {"type": "log", "message": "[INFO] Web updates completed!", "level": "SUCCESS"}');
        controller.close();
      });
      return controller.stream;
    }

    final controller = StreamController<String>();

    try {
      Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["-U", "all", "--source", source, "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).then((process) {
        _activeProcess = process;

        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!controller.isClosed) controller.add(line);
              },
              onError: (err) {
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}");
                }
              },
            );

        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                debugPrint("Python Stderr: $line");
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"log\": \"stderr: $line\"}");
                }
              },
            );

        process.exitCode.then((exitCode) {
          _activeProcess = null;
          if (exitCode != 0) {
            if (!controller.isClosed) {
              controller.add("[CALLBACK] {\"key\": \"errorUpdateFailed\", \"error\": \"Process exited with code $exitCode\"}");
            }
          }
          if (!controller.isClosed) controller.close();
        });
      }).catchError((err) {
        _activeProcess = null;
        if (!controller.isClosed) {
          controller.add("[CALLBACK] {\"key\": \"errorUpdateFailed\", \"error\": \"$err\"}");
          controller.close();
        }
      });
    } catch (e) {
      _activeProcess = null;
      if (!controller.isClosed) {
        controller.add("[CALLBACK] {\"key\": \"errorUpdateFailed\", \"error\": \"$e\"}");
        controller.close();
      }
    }

    controller.onCancel = () {
      if (_activeProcess != null) {
        _activeProcess!.kill(ProcessSignal.sigterm);
        _activeProcess = null;
      }
    };

    return controller.stream;
  }

  void cancelCurrentTask() {
    if (kIsWeb) return;
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
  }

  List<dynamic> _tryParseJson(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      final start = input.lastIndexOf('[');
      final end = input.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        try {
          return jsonDecode(input.substring(start, end + 1));
        } catch (_) {}
      }
      return [];
    }
  }

  Future<Map<String, dynamic>> exportPackages(String filepath) async {
    if (kIsWeb) {
      return {"status": "error", "message": "File export is not supported in the web browser."};
    }

    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--export-packages", filepath]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(const Duration(seconds: 15));

      if (result.exitCode != 0) return {"status": "error"};
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("exportPackages Exception: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add('[CALLBACK] {"type": "log", "message": "[INFO] Running system cleanup in browser...", "level": "INFO"}');
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.add('[PROGRESS] 50');
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        controller.add('[PROGRESS] 100');
        controller.add('[CALLBACK] {"type": "log", "message": "[INFO] Browser storage cleanup finished!", "level": "SUCCESS"}');
        controller.close();
      });
      return controller.stream;
    }

    final controller = StreamController<String>();

    try {
      Process.start(
        PythonBridge.venvPython,
        PythonBridge.buildArgs(["--clean-system", "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).then((process) {
        _activeProcess = process;

        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!controller.isClosed) controller.add(line);
              },
              onError: (err) {
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}");
                }
              },
            );

        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                debugPrint("Python Stderr: $line");
                if (!controller.isClosed) {
                  controller.add("[CALLBACK] {\"log\": \"stderr: $line\"}");
                }
              },
            );

        process.exitCode.then((exitCode) {
          _activeProcess = null;
          if (exitCode != 0) {
            if (!controller.isClosed) {
              controller.add("[CALLBACK] {\"key\": \"errorCleanFailed\", \"error\": \"Process exited with code $exitCode\"}");
            }
          }
          if (!controller.isClosed) controller.close();
        });
      }).catchError((err) {
        _activeProcess = null;
        if (!controller.isClosed) {
          controller.add("[CALLBACK] {\"key\": \"errorCleanFailed\", \"error\": \"$err\"}");
          controller.close();
        }
      });
    } catch (e) {
      _activeProcess = null;
      if (!controller.isClosed) {
        controller.add("[CALLBACK] {\"key\": \"errorCleanFailed\", \"error\": \"$e\"}");
        controller.close();
      }
    }

    controller.onCancel = () {
      if (_activeProcess != null) {
        _activeProcess!.kill(ProcessSignal.sigterm);
        _activeProcess = null;
      }
    };

    return controller.stream;
  }
}
