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

    // Initialize tray with error handling
    try {
      await _initSystemTray();
    } catch (e) {
      // Log error but continue execution to avoid app crash
      debugPrint('System tray init failed: $e');
    }

  }

  Future<void> updateConfig() async {
    _config = await BackendService.instance.loadConfig();
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
      bool hasDbusMenu = output.contains('libdbusmenu-gtk3.so.4');
      bool hasAppIndicator = output.contains('libappindicator3.so.1') ||
                             output.contains('libayatana-appindicator3.so.1');

      return hasDbusMenu && hasAppIndicator;
    } catch (e) {
      debugPrint("Dependency check failed: $e");
      return true; // 报错则跳过检查
    }
  }

  Future<void> _initSystemTray() async {
    if (Platform.isLinux) {
      final hasDeps = await _checkLinuxTrayDependencies();
      if (!hasDeps) {
        debugPrint("Skipping system tray initialization due to missing dependencies.");
        return;
      }
    }

    try {
      // system_tray 2.x 初始化图标 - 增加超时以防止 DBus 阻塞
      await _systemTray
          .initSystemTray(title: "OmniStore", iconPath: 'assets/app_icon.png')
          .timeout(const Duration(seconds: 3));

      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: L10nService.s('show_window'),
          onClicked: (menuItem) => windowManager.show(),
        ),
        MenuItemLabel(
          label: L10nService.s('check_updates'),
          onClicked: (menuItem) => checkNow(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: L10nService.s('exit'),
          onClicked: (menuItem) => exit(0),
        ),
      ]).timeout(const Duration(seconds: 2));

      await _systemTray.setContextMenu(menu).timeout(const Duration(seconds: 2));
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint("System tray initialization failed or timed out: $e");
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
    final updates = await BackendService.instance.checkUpdates();
    availableUpdates.value = updates;

    final remindEnabled = _config['updates']?['remind_updates'] ?? true;
    final notificationsEnabled = _config['notifications']?['enabled'] ?? true;

    if (updates.isNotEmpty) {
      final currentHash = updates.map((e) => "${e['name']}-${e['new_version']}").join(",");
      if (remindEnabled && notificationsEnabled && currentHash != _lastNotifiedUpdateHash) {
        _showUpdateNotification(updates.length);
        _lastNotifiedUpdateHash = currentHash;
      }
      await _systemTray.setToolTip(L10nService.s('trayTooltipUpdates', args: [updates.length.toString()]));
    } else {
      _lastNotifiedUpdateHash = null;
      await _systemTray.setToolTip(L10nService.s('trayTooltipUpToDate'));
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
      variants: [
        AppVariant(
          source: source,
          version: "Latest",
          installed: true,
          description: "Updating...",
        )
      ],
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
