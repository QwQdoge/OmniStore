import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart' as wm;
import '../l10n/app_localizations.dart';
import 'backend_service.dart';
import 'task_manager.dart';

// Background update scheduling for OmniStore (Linux desktop):
//
// Dynamic interval updates: When the user changes `updates.check_interval_hours`
// in Settings, SettingsController.updateConfig() automatically calls
// UpdateService().updateConfig(), which triggers _startUpdateTimer().
// _startUpdateTimer() compares the new interval with _currentInterval and only
// restarts the Dart Timer when the value has actually changed — so in-app
// interval changes take effect immediately without restarting the app.
//
// Background updates when app is closed: Handled via a systemd user-level timer
// (omnistore-update.timer) written to ~/.config/systemd/user/ on Linux.
// Android WorkManager and iOS BackgroundFetch are NOT applicable — OmniStore
// is a Linux desktop application.
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

  /// Returns true if the system tray was successfully initialized (or not required).
  /// Returns false if tray init failed and background residency is unavailable.
  Future<bool> init() async {
    if (kIsWeb) return true;

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open OmniStore');
    const InitializationSettings initializationSettings =
        InitializationSettings(linux: initializationSettingsLinux);
    await _notificationsPlugin.initialize(settings: initializationSettings);

    try {
      final trayOk = await _initSystemTray();
      return trayOk;
    } catch (e) {
      debugPrint('System tray init failed: $e');
      return false;
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
      // 更新托盘菜单文本（初始化已在 init() 中完成）
      await _refreshTrayMenu();
    } else {
      _startUpdateTimer();
    }
  }

  /// 仅更新托盘右键菜单文本，不重新初始化托盘
  Future<void> _refreshTrayMenu() async {
    if (kIsWeb) return;
    try {
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
      await _systemTray.setContextMenu(menu).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Failed to refresh tray menu: $e');
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

  /// Returns true on success, false on failure.
  Future<bool> _initSystemTray() async {
    if (kIsWeb) return true;
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return true;

    final config = await BackendService.instance.loadConfig();
    final bool trayEnabled = config['ui']?['enable_system_tray'] ?? true;
    if (!trayEnabled) {
      debugPrint("System tray disabled in config.");
      return true; // 用户主动禁用，不视为失败
    }

    final String home =
        Platform.environment['HOME'] ??
        '/home/${Platform.environment['USER'] ?? 'user'}';
    final configDir = Directory(p.join(home, '.config', 'omnistore'));
    final guardFile = File(p.join(configDir.path, '.tray_initializing'));

    if (Platform.isLinux) {
      if (guardFile.existsSync()) {
        debugPrint("System tray previously crashed. Skipping to prevent loop.");
        return false; // 之前崩溃过，视为失败
      }

      final hasDeps = await _checkLinuxTrayDependencies();
      if (!hasDeps) {
        debugPrint(
          "Skipping system tray initialization due to missing dependencies.",
        );
        return false; // 缺少依赖库，视为失败
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
      return true; // 初始化成功
    } catch (e) {
      debugPrint("System tray initialization failed gracefully: $e");
      return false; // 初始化失败
    }
  }

  int? _currentInterval;

  /// Starts or restarts the in-app periodic timer only when the configured
  /// interval has actually changed.  Also synchronises the systemd background
  /// timer so that background checks (when the app is closed) use the same
  /// cadence.  When the `updates` section is entirely absent from config the
  /// timer is left running with the previous interval to avoid accidental
  /// disabling.
  void _startUpdateTimer() {
    final interval = _config['updates']?['check_interval_hours'] ?? 1;
    final enabled = _config['updates']?['remind_updates'] ?? true;
    final systemdEnabled = _config['updates']?['enable_systemd_service'] ?? false;

    if (!enabled) {
      // User disabled background update checks — cancel any running timer
      // and remove the systemd timer so the app also stops checking in the
      // background when closed.
      if (_updateTimer != null) {
        _updateTimer!.cancel();
        _updateTimer = null;
        _currentInterval = null;
        debugPrint('Update timer disabled by config.');
        _disableSystemdBackgroundTimer();
      }
      return;
    }

    if (systemdEnabled) {
      _setupSystemdBackgroundTimer(interval);
    } else {
      _disableSystemdBackgroundTimer();
    }

    if (_updateTimer != null && _currentInterval == interval) {
      return; // Interval unchanged — nothing to do.
    }
    _currentInterval = interval;
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(Duration(hours: interval), (_) => checkNow());
    checkNow();
  }

  /// Writes a systemd user-level service + timer that runs OmniStore in
  /// headless mode to check for updates even when the GUI is closed.
  /// Called whenever the check interval changes.
  Future<void> _setupSystemdBackgroundTimer(int intervalHours) async {
    if (!Platform.isLinux) return;
    try {
      final home = Platform.environment['HOME'] ?? '/home/user';
      final systemdDir = Directory(p.join(home, '.config', 'systemd', 'user'));
      if (!systemdDir.existsSync()) {
        systemdDir.createSync(recursive: true);
      }

      final serviceFile = File(
        p.join(systemdDir.path, 'omnistore-update.service'),
      );
      final timerFile = File(p.join(systemdDir.path, 'omnistore-update.timer'));

      final exePath = Platform.resolvedExecutable;

      serviceFile.writeAsStringSync('''[Unit]
Description=OmniStore Background Update Checker
After=network.target

[Service]
Type=simple
ExecStart=$exePath --check-updates-background
Restart=no
ExecStopPost=/bin/sh -c 'if [ "\$\$SERVICE_RESULT" != "success" ]; then systemctl --user disable --now omnistore-update.timer; fi'
''');

      timerFile.writeAsStringSync('''[Unit]
Description=Run OmniStore Background Update Checker

[Timer]
OnCalendar=*:0/$intervalHours
Persistent=true

[Install]
WantedBy=timers.target
''');

      await Process.run('systemctl', ['--user', 'daemon-reload']);
      await Process.run(
        'systemctl',
        ['--user', 'enable', '--now', 'omnistore-update.timer'],
      );
      debugPrint('systemd background timer set to every $intervalHours hour(s).');
    } catch (e) {
      debugPrint('Failed to setup systemd background timer: $e');
    }
  }

  /// Stops and disables the systemd user-level timer so the app no longer
  /// checks for updates in the background when the GUI is closed.
  Future<void> _disableSystemdBackgroundTimer() async {
    if (!Platform.isLinux) return;
    try {
      await Process.run(
        'systemctl',
        ['--user', 'disable', '--now', 'omnistore-update.timer'],
      );
      debugPrint('systemd background timer disabled.');
    } catch (e) {
      debugPrint('Failed to disable systemd background timer: $e');
    }
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
