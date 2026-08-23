import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current.parent.path;

  test('systemd background unit is oneshot and cannot restart-loop', () {
    final updateService = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'update_service.dart',
      ),
    ).readAsStringSync();

    expect(updateService, contains('Type=oneshot'));
    expect(updateService, contains('Restart=no'));
    expect(updateService, contains('TimeoutStartSec=10min'));
    expect(updateService, contains('OnUnitInactiveSec='));
    expect(updateService, isNot(contains('Restart=always')));
    expect(updateService, isNot(contains('Restart=on-failure')));
  });

  test('backend daemon uses a one-shot health timer and lightweight ping', () {
    final backendService = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'backend_service.dart',
      ),
    ).readAsStringSync();
    final daemonClient = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'backend',
        'daemon_client.dart',
      ),
    ).readAsStringSync();

    expect(backendService, contains('_scheduleHealthCheck'));
    expect(
      backendService,
      isNot(contains('Timer.periodic(Duration(seconds: backoffSeconds)')),
    );
    expect(daemonClient, contains('"ping"'));
    expect(daemonClient, isNot(contains('"run_check_env"')));
    expect(daemonClient, contains('startIfNeeded: startIfNeeded'));
  });

  test('platform-vault AI keys are never injected into Python processes', () {
    final pythonBridge = File(
      p.join(projectRoot, 'FlutterUI', 'lib', 'data', 'python_bridge.dart'),
    ).readAsStringSync();
    final processExecutor = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'backend',
        'process_execution_service.dart',
      ),
    ).readAsStringSync();
    final backendService = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'backend_service.dart',
      ),
    ).readAsStringSync();

    expect(pythonBridge, isNot(contains("env['OMNISTORE_AI_API_KEY']")));
    expect(processExecutor, isNot(contains('OMNISTORE_AI_API_KEY')));
    expect(backendService, isNot(contains('apiKey: apiKey')));
  });

  test('systemd disable path removes installed user unit files', () {
    final updateService = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'services',
        'update_service.dart',
      ),
    ).readAsStringSync();

    expect(updateService, contains("'disable'"));
    expect(updateService, contains("'--now'"));
    expect(updateService, contains("'omnistore-update.timer'"));
    expect(updateService, contains("'omnistore-update.service'"));
    expect(updateService, contains('unitFile.deleteSync()'));
    expect(updateService, contains("'daemon-reload'"));
    expect(updateService, contains('removeSystemdBackgroundTimer()'));
  });

  test('settings systemd switch writes systemd config, not daemon config', () {
    final settingsPage = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'features',
        'settings',
        'presentation',
        'widgets',
        'update_settings_card.dart',
      ),
    ).readAsStringSync();

    final systemdSwitchStart = settingsPage.indexOf(
      'l10n.enableSystemdService',
    );
    expect(systemdSwitchStart, greaterThanOrEqualTo(0));
    final systemdSwitchBlock = settingsPage.substring(
      systemdSwitchStart,
      settingsPage.indexOf('ListTile(', systemdSwitchStart),
    );
    expect(systemdSwitchBlock, contains('setEnableSystemdService'));
    expect(systemdSwitchBlock, isNot(contains('setDaemonEnabled')));
  });

  test('linux package exposes user systemd cleanup command', () {
    final pkgbuild = File(p.join(projectRoot, 'PKGBUILD')).readAsStringSync();

    expect(pkgbuild, contains('omnistore-cleanup-systemd'));
    expect(
      pkgbuild,
      contains('systemctl --user disable --now omnistore-update.timer'),
    );
    expect(
      pkgbuild,
      contains('rm -f "\$HOME/.config/systemd/user/omnistore-update.timer"'),
    );
    expect(
      pkgbuild,
      contains('rm -f "\$HOME/.config/systemd/user/omnistore-update.service"'),
    );
  });

  test('completed updates trigger a silent authoritative recheck', () {
    final updatesTab = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'features',
        'task_manager',
        'presentation',
        'widgets',
        'updates_tab.dart',
      ),
    ).readAsStringSync();
    final downloadPage = File(
      p.join(
        projectRoot,
        'FlutterUI',
        'lib',
        'features',
        'task_manager',
        'presentation',
        'pages',
        'download_page.dart',
      ),
    ).readAsStringSync();

    expect(updatesTab, contains('await taskController.updateAll'));
    expect(updatesTab, contains('await onUpdateFinished(success)'));
    expect(downloadPage, contains('UpdateService().checkNow(notify: false)'));
    expect(downloadPage, contains('availableUpdates.value.length'));
  });
}
