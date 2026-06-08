import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'backend_service.dart';
import 'task_manager.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SystemTray _systemTray = SystemTray();

  final ValueNotifier<List<dynamic>> availableUpdates = ValueNotifier([]);
  Timer? _updateTimer;
  Map<String, dynamic> _config = {};
  DateTime? _lastNotificationTime;
  String? _lastNotifiedUpdateHash;

  // Background strings cache for tray and notifications
  String _showWindowLabel = "Show Window";
  String _checkUpdatesLabel = "Check for Updates";
  String _exitLabel = "Exit";
  String _trayTooltipUpToDate = "OmniStore: Up to date";
  String _notificationTitle = "Updates Available";
  String _taskCompletedLabel = "Task Completed";
  String _successLabel = "Success";
  String _failedLabel = "Failed";

  String Function(int) _trayTooltipUpdates = (count) =>
      "OmniStore: $count updates";
  String Function(int) _notificationBody = (count) =>
      "$count applications are available";

  Future<void> init() async {
    if (kIsWeb) return;
    
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
    const InitializationSettings initializationSettings =
        InitializationSettings(linux: initializationSettingsLinux);
    await _notificationsPlugin.initialize(settings: initializationSettings);

    try {
      await _initSystemTray();
    } catch (e) {
      debugPrint('System tray init failed: $e');
    }
  }

  Future<void> updateConfig([AppLocalizations? l10n]) async {
    _config = await BackendService.instance.loadConfig();

    if (l10n != null) {
      _showWindowLabel = l10n.showWindow;
      _checkUpdatesLabel = l10n.checkUpdates;
      _exitLabel = l10n.exit;
      _trayTooltipUpToDate = l10n.trayTooltipUpToDate;
      _notificationTitle = l10n.notificationTitle;
      _taskCompletedLabel = l10n.taskCompleted;
      _successLabel = l10n.success;
      _failedLabel = l10n.failed;
      _trayTooltipUpdates = (count) => l10n.trayTooltipUpdates(count);
      _notificationBody = (count) => l10n.notificationBody(count);
    }

    if (!kIsWeb) {
      final notificationsEnabled = _config['notifications']?['enabled'] ?? true;
      if (notificationsEnabled) {
        const LinuxInitializationSettings initializationSettingsLinux =
            LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
        const InitializationSettings initializationSettings =
            InitializationSettings(linux: initializationSettingsLinux);
        await _notificationsPlugin.initialize(settings: initializationSettings);
      }
      _startUpdateTimer();
      await _initSystemTray();
    } else {
      _startUpdateTimer();
    }
  }

  Future<bool> _checkLinuxTrayDependencies() async {
    if (kIsWeb) return false;
    if (!Platform.isLinux) return true;
    try {
      final result = await Process.run('ldconfig', ['-p']);
      if (result.exitCode != 0) return true;

      final output = result.stdout.toString();
      bool hasDbusMenu = output.contains('libdbusmenu-gtk3.so');
      bool hasAppIndicator =
          output.contains('libappindicator3.so') ||
          output.contains('libayatana-appindicator3.so') ||
          output.contains('libappindicator-gtk3.so');

      return hasDbusMenu && hasAppIndicator;
    } catch (e) {
      debugPrint("Dependency check failed: $e");
      return true;
    }
  }

  Future<void> _initSystemTray() async {
    if (kIsWeb) return;
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return;

    final config = await BackendService.instance.loadConfig();
    final bool trayEnabled = config['ui']?['enable_system_tray'] ?? true;
    if (!trayEnabled) {
      debugPrint("System tray disabled in config.");
      return;
    }

    final String home =
        Platform.environment['HOME'] ??
        '/home/${Platform.environment['USER'] ?? 'user'}';
    final configDir = Directory(p.join(home, '.config', 'omnistore'));
    final guardFile = File(p.join(configDir.path, '.tray_initializing'));

    if (Platform.isLinux) {
      if (guardFile.existsSync()) {
        debugPrint("System tray previously crashed. Skipping to prevent loop.");
        return;
      }

      final hasDeps = await _checkLinuxTrayDependencies();
      if (!hasDeps) {
        debugPrint(
          "Skipping system tray initialization due to missing dependencies.",
        );
        return;
      }
    }

    try {
      if (Platform.isLinux) {
        if (!configDir.existsSync()) configDir.createSync(recursive: true);
        guardFile.createSync();
      }

      String iconPath = 'assets/app_icon.png';
      if (Platform.isLinux) {
        final String executablePath = Platform.resolvedExecutable;
        final String executableDir = p.dirname(executablePath);

        final List<String> candidatePaths = [
          p.join(
            executableDir,
            'data',
            'flutter_assets',
            'assets',
            'app_icon.png',
          ),
          p.join(executableDir, 'assets', 'app_icon.png'),
          p.join(Directory.current.path, 'FlutterUI', 'assets', 'app_icon.png'),
          p.join(Directory.current.path, 'assets', 'app_icon.png'),
        ];

        for (final path in candidatePaths) {
          if (File(path).existsSync()) {
            iconPath = path;
            debugPrint("Found tray icon at: $path");
            break;
          }
        }
      }

      await _systemTray
          .initSystemTray(title: "OmniStore", iconPath: iconPath)
          .timeout(const Duration(seconds: 3));

      final Menu menu = Menu();
      await menu
          .buildFrom([
            MenuItemLabel(
              label: _showWindowLabel,
              onClicked: (menuItem) => wm.windowManager.show(),
            ),
            MenuItemLabel(
              label: _checkUpdatesLabel,
              onClicked: (menuItem) => checkNow(),
            ),
            MenuSeparator(),
            MenuItemLabel(
              label: _exitLabel,
              onClicked: (menuItem) => _handleFullExit(),
            ),
          ])
          .timeout(const Duration(seconds: 2));

      await _systemTray
          .setContextMenu(menu)
          .timeout(const Duration(seconds: 2));

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          wm.windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      if (Platform.isLinux && guardFile.existsSync()) {
        guardFile.deleteSync();
      }
    } catch (e) {
      debugPrint("System tray initialization failed gracefully: $e");
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    final interval = _config['updates']?['check_interval_hours'] ?? 1;
    _updateTimer = Timer.periodic(Duration(hours: interval), (timer) {
      checkNow();
    });
    checkNow();
  }

  Future<void> checkNow() async {
    debugPrint("Checking for updates...");
    try {
      final updates = await BackendService.instance.checkUpdates().timeout(
        const Duration(seconds: 45),
      );
      availableUpdates.value = updates;

      final remindEnabled = _config['updates']?['remind_updates'] ?? true;
      final notificationsEnabled = _config['notifications']?['enabled'] ?? true;

      if (updates.isNotEmpty) {
        final currentHash = updates
            .map((e) => "${e['name']}-${e['new_version']}")
            .join(",");
        if (remindEnabled &&
            notificationsEnabled &&
            currentHash != _lastNotifiedUpdateHash) {
          _showUpdateNotification(updates.length);
          _lastNotifiedUpdateHash = currentHash;
        }
        if (!kIsWeb) {
          await _systemTray.setToolTip(_trayTooltipUpdates(updates.length));
        }
      } else {
        _lastNotifiedUpdateHash = null;
        if (!kIsWeb) {
          try {
            await _systemTray.setToolTip(_trayTooltipUpToDate);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> checkUpdates() => checkNow();

  Future<void> startUpdate(String name, String source) async {
    if (TaskManager().isBusy) return;

    final success = await TaskManager().startTask(
      id: "update-$name",
      packageName: name,
      source: source,
      actionFlag: "-U",
    );

    showCompletionNotification(name, success);

    if (success) {
      checkNow();
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
  }) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint("Failed to show notification: $e");
    }
  }

  Future<void> _showUpdateNotification(int count) async {
    if (kIsWeb) return;
    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      linux: linuxPlatformChannelSpecifics,
    );
    await _showNotification(
      id: 0,
      title: _notificationTitle,
      body: _notificationBody(count),
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> showProgressNotification(String title, double progress) async {
    if (kIsWeb) return;
    final enabled = _config['notifications']?['enabled'] ?? true;
    final progressEnabled = _config['notifications']?['progress'] ?? true;
    if (!enabled || !progressEnabled) return;

    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < const Duration(seconds: 2)) {
      if (progress < 1.0) return;
    }
    _lastNotificationTime = now;

    final linuxDetails = const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.low,
    );

    await _showNotification(
      id: 1,
      title: title,
      body: "${(progress * 100).toInt()}%",
      notificationDetails: NotificationDetails(linux: linuxDetails),
    );
  }

  Future<void> showCompletionNotification(String title, bool success) async {
    if (kIsWeb) return;
    final enabled = _config['notifications']?['enabled'] ?? true;
    final completionEnabled = _config['notifications']?['completion'] ?? true;
    if (!enabled || !completionEnabled) return;

    final linuxDetails = const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _showNotification(
      id: 2,
      title: _taskCompletedLabel,
      body: "$title: ${success ? _successLabel : _failedLabel}",
      notificationDetails: NotificationDetails(linux: linuxDetails),
    );
  }

  Future<void> showSimpleNotification(String title, String body) async {
    if (kIsWeb) return;
    final enabled = _config['notifications']?['enabled'] ?? true;
    if (!enabled) return;

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _showNotification(
      id: 3,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(linux: linuxDetails),
    );
  }

  Future<void> _handleFullExit() async {
    if (kIsWeb) return;
    try {
      await Process.run('pkill', ['omnistore-daemon']);
      await Process.run('pkill', ['-f', 'python/main.py']);
      await Process.run('pkill', ['python_server']);
    } catch (_) {}
    exit(0);
  }
}
