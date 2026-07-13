import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backend_service.dart';
import "../../services/local_apps_tracker.dart";
import "../../services/sync_service.dart";

class TaskRepository {
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

    // Murphy-proof: Delegate process execution to BackendService to benefit from
    // centralized ProcessRegistry tracking, daemon multiplexing, and safety guards.
    final controller = StreamController<String>();
    var sawBackendError = false;

    final stream = BackendService.instance.executeAction(
      flag,
      packageName,
      source,
      url: url,
    );

    stream.listen(
      (line) {
        if (line.contains('[ERROR]')) sawBackendError = true;
        if (!controller.isClosed) controller.add(line);
      },
      onError: (err) {
        if (!controller.isClosed) {
          controller.add(
            "[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}",
          );
          controller.close();
        }
      },
      onDone: () async {
        if (!controller.isClosed) {
          if (sawBackendError) {
            controller.add(
              "[CALLBACK] {\"key\": \"errorStartFailed\", \"error\": \"Backend reported an error\"}",
            );
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
          controller.close();
        }
      },
    );

    controller.onCancel = () {
      BackendService.cancelCurrentTask();
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
    final installedCacheRaw = prefs.getString(
      'omnistore_installed_packages_cache',
    );
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
        "variants": [
          {"source": source, "id": packageName, "installed": true},
        ],
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
    await prefs.setString(
      'omnistore_installed_packages_cache',
      jsonEncode(installedCache),
    );
  }

  Future<List<dynamic>> checkUpdates() async {
    if (kIsWeb) {
      return [];
    }

    // Murphy-proof: Delegate to BackendService for centralized execution and caching.
    return BackendService.instance.checkUpdates();
  }

  Stream<String> updateAll(String source) {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add(
        '[CALLBACK] {"type": "log", "message": "[INFO] Starting system update on web...", "level": "INFO"}',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.add('[PROGRESS] 50');
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        controller.add('[PROGRESS] 100');
        controller.add(
          '[CALLBACK] {"type": "log", "message": "[INFO] Web updates completed!", "level": "SUCCESS"}',
        );
        controller.close();
      });
      return controller.stream;
    }

    final controller = StreamController<String>();
    final stream = BackendService.instance.updateAll(source);

    stream.listen(
      (line) {
        if (!controller.isClosed) controller.add(line);
      },
      onError: (err) {
        if (!controller.isClosed) {
          controller.add(
            "[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}",
          );
          controller.close();
        }
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    controller.onCancel = () {
      BackendService.cancelCurrentTask();
    };

    return controller.stream;
  }

  void cancelCurrentTask() {
    if (kIsWeb) return;
    BackendService.cancelCurrentTask();
  }

  Future<Map<String, dynamic>> exportPackages(String filepath) async {
    if (kIsWeb) {
      return {
        "status": "error",
        "message": "File export is not supported in the web browser.",
      };
    }

    // Murphy-proof: Delegate to BackendService for centralized execution and validation.
    return BackendService.instance.exportPackages(filepath);
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add(
        '[CALLBACK] {"type": "log", "message": "[INFO] Running system cleanup in browser...", "level": "INFO"}',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.add('[PROGRESS] 50');
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        controller.add('[PROGRESS] 100');
        controller.add(
          '[CALLBACK] {"type": "log", "message": "[INFO] Browser storage cleanup finished!", "level": "SUCCESS"}',
        );
        controller.close();
      });
      return controller.stream;
    }

    final controller = StreamController<String>();
    final stream = BackendService.instance.cleanSystem();

    stream.listen(
      (line) {
        if (!controller.isClosed) controller.add(line);
      },
      onError: (err) {
        if (!controller.isClosed) {
          controller.add(
            "[CALLBACK] {\"key\": \"errorFatalStream\", \"error\": \"$err\"}",
          );
          controller.close();
        }
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    controller.onCancel = () {
      BackendService.cancelCurrentTask();
    };

    return controller.stream;
  }
}
