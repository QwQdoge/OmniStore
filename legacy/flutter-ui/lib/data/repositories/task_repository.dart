import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backend_service.dart';
import "../../services/local_apps_tracker.dart";
import "../../services/sync_service.dart";

class TaskRepository {
  String _callback(Map<String, dynamic> payload) =>
      '[CALLBACK] ${jsonEncode(payload)}';

  String _logEvent(String message, {String level = 'info'}) => _callback({
    'type': 'log',
    'level': level,
    'message': message,
  });

  String _errorEvent(String key, {Object? error}) => _callback({
    'type': 'error',
    'level': 'error',
    'key': key,
    if (error != null) 'error': error.toString(),
  });

  String _progressEvent(num progress) => _callback({
    'type': 'progress',
    'progress': progress,
  });

  bool _isErrorEvent(String line) {
    final trimmed = line.trim();

    // Backwards compatibility for older Python/plugin output.
    if (trimmed.startsWith('[ERROR]')) return true;

    String? payloadText;
    if (trimmed.startsWith('[CALLBACK]')) {
      payloadText = trimmed.substring('[CALLBACK]'.length).trim();
    } else if (trimmed.startsWith('{')) {
      payloadText = trimmed;
    }

    if (payloadText == null || payloadText.isEmpty) return false;

    try {
      final payload = jsonDecode(payloadText);
      if (payload is! Map) return false;

      final level = payload['level']?.toString().toLowerCase();
      final type = payload['type']?.toString().toLowerCase();
      final key = payload['key']?.toString().toLowerCase();

      return level == 'error' ||
          level == 'fatal' ||
          type == 'error' ||
          type == 'fatal' ||
          (key?.startsWith('error') ?? false);
    } catch (_) {
      return false;
    }
  }

  Stream<String> executeAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) {
    if (packageName.isEmpty) {
      return Stream.value(_errorEvent('errorPackageNameRequired'));
    }

    if (kIsWeb) {
      return _webExecuteAction(flag, packageName, source, url: url);
    }

    // Delegate process execution to BackendService for centralized
    // ProcessRegistry tracking, daemon multiplexing, and safety guards.
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
        if (_isErrorEvent(line)) sawBackendError = true;
        if (!controller.isClosed) controller.add(line);
      },
      onError: (err) {
        if (!controller.isClosed) {
          controller.add(_errorEvent('errorFatalStream', error: err));
          controller.close();
        }
      },
      onDone: () async {
        if (!controller.isClosed) {
          if (sawBackendError) {
            controller.add(
              _errorEvent(
                'errorStartFailed',
                error: 'Backend reported an error',
              ),
            );
          } else {
            // Local tracking for OmniStore apps.
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

    yield _logEvent(
      'Starting ${isInstall ? "install" : "uninstall"} for $packageName via $source...',
    );
    await Future.delayed(const Duration(milliseconds: 300));

    yield _progressEvent(10);
    await Future.delayed(const Duration(milliseconds: 300));

    yield _progressEvent(40);
    await Future.delayed(const Duration(milliseconds: 300));

    yield _progressEvent(80);
    await Future.delayed(const Duration(milliseconds: 300));

    yield _progressEvent(100);
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
      yield _logEvent('Installed successfully!', level: 'success');
    } else {
      installedIds.remove(packageName);
      installedCache.removeWhere((item) => item['id'] == packageName);
      await LocalAppsTracker.untrackApp(packageName);
      SyncService().syncInstalledApps();
      yield _logEvent('Uninstalled successfully!', level: 'success');
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

    return BackendService.instance.checkUpdates();
  }

  Stream<String> updateAll(String source) {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add(_logEvent('Starting system update on web...'));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!controller.isClosed) controller.add(_progressEvent(50));
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (controller.isClosed) return;
        controller.add(_progressEvent(100));
        controller.add(_logEvent('Web updates completed!', level: 'success'));
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
          controller.add(_errorEvent('errorFatalStream', error: err));
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

    return BackendService.instance.exportPackages(filepath);
  }

  Stream<String> cleanSystem() {
    if (kIsWeb) {
      final controller = StreamController<String>();
      controller.add(_logEvent('Running system cleanup in browser...'));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!controller.isClosed) controller.add(_progressEvent(50));
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (controller.isClosed) return;
        controller.add(_progressEvent(100));
        controller.add(
          _logEvent('Browser storage cleanup finished!', level: 'success'),
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
          controller.add(_errorEvent('errorFatalStream', error: err));
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
