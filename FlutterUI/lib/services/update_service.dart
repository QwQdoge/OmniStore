import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
// import 'app_package.dart';
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
  // String _preparingUpdateLabel = "Preparing update...";
  String _taskCompletedLabel = "Task Completed";
  String _successLabel = "Success";
  String _failedLabel = "Failed";

  String Function(int) _trayTooltipUpdates = (count) =>
      "OmniStore: $count updates";
  String Function(int) _notificationBody = (count) =>
      "$count applications are available";

  Future<void> init() async {
    // 初始化通知
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
    const InitializationSettings initializationSettings =
        InitializationSettings(linux: initializationSettingsLinux);
    await _notificationsPlugin.initialize(initializationSettings);

    // Initialize tray with error handling
    try {
      await _initSystemTray();
    } catch (e) {
      // Log error but continue execution to avoid app crash
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
      // _preparingUpdateLabel = l10n.preparingUpdate;
      _taskCompletedLabel = l10n.taskCompleted;
      _successLabel = l10n.success;
      _failedLabel = l10n.failed;
      _trayTooltipUpdates = (count) => l10n.trayTooltipUpdates(count);
      _notificationBody = (count) => l10n.notificationBody(count);
    }

    _startUpdateTimer();
    // 重新初始化托盘，确保语言和菜单最新
    await _initSystemTray();
  }

  Future<bool> _checkLinuxTrayDependencies() async {
    if (!Platform.isLinux) return true;
    try {
      // 检查常见的托盘依赖库是否存在
      final result = await Process.run('ldconfig', ['-p']);
      if (result.exitCode != 0) return true; // 如果 ldconfig 失败，保守假设存在

      final output = result.stdout.toString();
      bool hasDbusMenu = output.contains('libdbusmenu-gtk3.so');
      bool hasAppIndicator =
          output.contains('libappindicator3.so') ||
          output.contains('libayatana-appindicator3.so') ||
          output.contains('libappindicator-gtk3.so');

      return hasDbusMenu && hasAppIndicator;
    } catch (e) {
      debugPrint("Dependency check failed: $e");
      return true; // 报错则跳过检查
    }
  }

  Future<void> _initSystemTray() async {
    final config = await BackendService.instance.loadConfig();
    // 默认在 Linux 上禁用，除非明确启用且依赖检查通过
    final bool trayEnabled = config['ui']?['enable_system_tray'] ?? false;
    if (!trayEnabled) {
      debugPrint("System tray disabled (default on Linux or user set).");
      return;
    }

    final String home =
        Platform.environment['HOME'] ??
        '/home/${Platform.environment['USER'] ?? 'user'}';
    final configDir = Directory(p.join(home, '.config', 'omnistore'));
    final guardFile = File(p.join(configDir.path, '.tray_initializing'));

    if (Platform.isLinux) {
      // 检查崩溃守卫
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

      // system_tray 2.x 初始化图标 - 增加超时以防止 DBus 阻塞
      await _systemTray
          .initSystemTray(title: "OmniStore", iconPath: 'assets/app_icon.png')
          .timeout(const Duration(seconds: 3));

      final Menu menu = Menu();
      await menu
          .buildFrom([
            MenuItemLabel(
              label: _showWindowLabel,
              onClicked: (menuItem) => windowManager.show(),
            ),
            MenuItemLabel(
              label: _checkUpdatesLabel,
              onClicked: (menuItem) => checkNow(),
            ),
            MenuSeparator(),
            MenuItemLabel(label: _exitLabel, onClicked: (menuItem) => exit(0)),
          ])
          .timeout(const Duration(seconds: 2));

      await _systemTray
          .setContextMenu(menu)
          .timeout(const Duration(seconds: 2));
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      // 初始化成功，清除崩溃守卫
      if (guardFile.existsSync()) guardFile.deleteSync();
    } catch (e) {
      debugPrint("System tray initialization failed or timed out: $e");
      // 注意：这里不删除 guardFile，以便下次启动知道这次失败了
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    final interval = _config['updates']?['check_interval_hours'] ?? 1;
    _updateTimer = Timer.periodic(Duration(hours: interval), (timer) {
      checkNow();
    });
    // 启动后立即检查一次
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
        await _systemTray.setToolTip(_trayTooltipUpdates(updates.length));
      } else {
        _lastNotifiedUpdateHash = null;
        try {
          await _systemTray.setToolTip(_trayTooltipUpToDate);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> checkUpdates() => checkNow();

  Future<void> startUpdate(String name, String source) async {
    if (TaskManager().isBusy) return;

    // Use TaskManager to ensure the update appears in the "Activity" tab
    final success = await TaskManager().startTask(
      id: "update-$name",
      packageName: name,
      source: source,
      actionFlag: "-U",
    );

    showCompletionNotification(name, success);

    if (success) {
      checkNow(); // Refresh update list
    }
  }

  Future<void> _showUpdateNotification(int count) async {
    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      linux: linuxPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(
      0,
      _notificationTitle,
      _notificationBody(count),
      platformChannelSpecifics,
    );
  }

  Future<void> showProgressNotification(String title, double progress) async {
    final enabled = _config['notifications']?['enabled'] ?? true;
    final progressEnabled = _config['notifications']?['progress'] ?? true;
    if (!enabled || !progressEnabled) return;

    // Throttle: once every 2 seconds
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < const Duration(seconds: 2)) {
      if (progress < 1.0) return;
    }
    _lastNotificationTime = now;

    final linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.low,
      customHints: [
        // For standard Linux notification daemons to show progress if supported
        // though not all support it via standard API
      ],
    );

    await _notificationsPlugin.show(
      1,
      title,
      "${(progress * 100).toInt()}%",
      NotificationDetails(linux: linuxDetails),
    );
  }

  Future<void> showCompletionNotification(String title, bool success) async {
    final enabled = _config['notifications']?['enabled'] ?? true;
    final completionEnabled = _config['notifications']?['completion'] ?? true;
    if (!enabled || !completionEnabled) return;

    final linuxDetails = const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _notificationsPlugin.show(
      2,
      _taskCompletedLabel,
      "$title: ${success ? _successLabel : _failedLabel}",
      NotificationDetails(linux: linuxDetails),
    );
  }
}
