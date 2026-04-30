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

  Future<void> init() async {
    // 初始化通知
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
    const InitializationSettings initializationSettings =
        InitializationSettings(linux: initializationSettingsLinux);
    await _notificationsPlugin.initialize(initializationSettings);

    // 初始化托盘
    await _initSystemTray();

    // 启动定时检查 (默认每小时检查一次)
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
    _updateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      checkNow();
    });
    // 启动后立即检查一次
    checkNow();
  }

  Future<void> checkNow() async {
    debugPrint("Checking for updates...");
    final updates = await BackendService().checkUpdates();
    availableUpdates.value = updates;

    if (updates.isNotEmpty) {
      _showUpdateNotification(updates.length);
      await _systemTray.setToolTip(L10nService.s('tray_tooltip_updates', args: [updates.length.toString()]));
    } else {
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

      process.stdout.transform(const Utf8Decoder()).transform(const LineSplitter()).listen((line) {
        String cleanLine = line.trim();
        if (cleanLine.startsWith("[CALLBACK]")) {
           try {
             final data = jsonDecode(cleanLine.replaceFirst("[CALLBACK] ", ""));
             String log = data['message'] ?? data['log'] ?? "";
             if (log.isNotEmpty) {
               if (log.startsWith("[PROGRESS]")) {
                  final p = double.tryParse(log.split(" ")[1]);
                  if (p != null) BackendService.globalProgress.value = p / 100.0;
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

      if (exitCode == 0) {
        checkNow(); // Refresh update list
      }
    } catch (e) {
      BackendService.isDownloading.value = false;
      BackendService.activeApp.value = null;
    }
  }

  Future<void> _showUpdateNotification(int count) async {
    const LinuxNotificationDetails linuxPlatformChannelSpecifics = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(linux: linuxPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      0,
      L10nService.s('notification_title'),
      L10nService.s('notification_body', args: [count.toString()]),
      platformChannelSpecifics,
    );
  }
}
