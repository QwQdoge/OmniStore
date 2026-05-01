import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'app_package.dart';
import 'backend_service.dart';
import 'l10n_service.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final SystemTray _systemTray = SystemTray();

  final ValueNotifier<List<dynamic>> availableUpdates = ValueNotifier([]);
  Timer? _updateTimer;
  Map<String, dynamic> _config = {};
  DateTime? _lastNotificationTime;
  String? _lastNotifiedUpdateHash;

  Future<void> init() async {
    // 初始化通知
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
    const InitializationSettings initializationSettings =
        InitializationSettings(linux: initializationSettingsLinux);
    await _notificationsPlugin.initialize(initializationSettings);

    // 初始化托盘
    await _initSystemTray();

    // 启动定时检查
    _startUpdateTimer();
  }

  Future<void> updateConfig() async {
    _config = await BackendService().loadConfig();
    _startUpdateTimer();
  }

  Future<void> _initSystemTray() async {
    // 根据当前项目结构，尝试找一个图标，如果没找到 system_tray 可能会报错，
    // 这里我们先初始化标题
    // system_tray 2.x 使用 init 配合图标路径
    // await _systemTray.initTray(title: "OmniStore");

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: L10nService.s('show_window'), onClicked: (menuItem) => windowManager.show()),
      MenuItemLabel(label: L10nService.s('check_updates'), onClicked: (menuItem) => checkNow()),
      MenuSeparator(),
      MenuItemLabel(label: L10nService.s('exit'), onClicked: (menuItem) => exit(0)),
    ]);

    await _systemTray.setContextMenu(menu);
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
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
    final updates = await BackendService().checkUpdates();
    availableUpdates.value = updates;

    final remindEnabled = _config['updates']?['remind_updates'] ?? true;
    final notificationsEnabled = _config['notifications']?['enabled'] ?? true;

    if (updates.isNotEmpty) {
      final currentHash = updates.map((e) => "${e['name']}-${e['new_version']}").join(",");
      if (remindEnabled && notificationsEnabled && currentHash != _lastNotifiedUpdateHash) {
        _showUpdateNotification(updates.length);
        _lastNotifiedUpdateHash = currentHash;
      }
      await _systemTray.setToolTip(L10nService.s('tray_tooltip_updates', args: [updates.length.toString()]));
    } else {
      _lastNotifiedUpdateHash = null;
      await _systemTray.setToolTip(L10nService.s('tray_tooltip_uptodate'));
    }
  }

  Future<void> checkUpdates() => checkNow();

  Future<void> startUpdate(String name, String source) async {
    if (BackendService.isDownloading.value) return;

    BackendService.isDownloading.value = true;
    BackendService.globalStatus.value = L10nService.s('preparing_update');
    BackendService.globalProgress.value = null;
    BackendService.clearLogs();

    showProgressNotification(L10nService.s('preparing_update'), 0);

    // Create a dummy AppPackage for tracking if we don't have one
    final app = AppPackage(
      name: name,
      description: "Updating...",
      installed: true,
      version: "Latest",
      sources: [source],
      primarySource: source,
    );
    BackendService.activeApp.value = app;

    try {
      final process = await Process.start(
        BackendService.venvPython,
        [BackendService.scriptPath, "-U", name, "--source", source, "--json"],
        workingDirectory: BackendService.workingDir,
      );

      BackendService.activeProcess = process;

      process.stdout
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen((line) {
        String cleanLine = line.trim();
        if (cleanLine.startsWith("[CALLBACK]")) {
          try {
            final data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
            String log = data['message'] ?? data['log'] ?? "";
            if (log.isNotEmpty) {
              if (log.startsWith("[PROGRESS]")) {
                final p = double.tryParse(log.split(" ")[1]);
                if (p != null) {
                  final progressValue = p / 100.0;
                  BackendService.globalProgress.value = progressValue;
                  showProgressNotification(name, progressValue);
                }
              } else {
                BackendService.addLog(log);
              }
            }
          } catch (_) {}
        }
      });

      final exitCode = await process.exitCode;
      BackendService.isDownloading.value = false;
      BackendService.activeApp.value = null;
      BackendService.activeProcess = null;

      showCompletionNotification(name, exitCode == 0);

      if (exitCode == 0) {
        checkNow(); // Refresh update list
      }
    } catch (e) {
      BackendService.isDownloading.value = false;
      BackendService.activeApp.value = null;
      showCompletionNotification(name, false);
    }
  }

  Future<void> _showUpdateNotification(int count) async {
    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(linux: linuxPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      0,
      L10nService.s('notification_title'),
      L10nService.s('notification_body', args: [count.toString()]),
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
      L10nService.s('task_completed'),
      "$title: ${success ? L10nService.s('success') : L10nService.s('failed')}",
      NotificationDetails(linux: linuxDetails),
    );
  }
}
