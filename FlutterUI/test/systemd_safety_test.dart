import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current.parent.path;

  test('systemd background unit is oneshot and cannot restart-loop', () {
    final updateService = File(
      p.join(projectRoot, 'FlutterUI', 'lib', 'services', 'update_service.dart'),
    ).readAsStringSync();

    expect(updateService, contains('Type=oneshot'));
    expect(updateService, contains('Restart=no'));
    expect(updateService, contains('TimeoutStartSec=10min'));
    expect(updateService, contains('OnUnitInactiveSec='));
    expect(updateService, isNot(contains('Restart=always')));
    expect(updateService, isNot(contains('Restart=on-failure')));
  });

  test('systemd disable path removes installed user unit files', () {
    final updateService = File(
      p.join(projectRoot, 'FlutterUI', 'lib', 'services', 'update_service.dart'),
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
        'pages',
        'settings_page.dart',
      ),
    ).readAsStringSync();

    final systemdSwitchStart = settingsPage.indexOf('l10n.enableSystemdService');
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
    expect(pkgbuild, contains('systemctl --user disable --now omnistore-update.timer'));
    expect(pkgbuild, contains('rm -f "\$HOME/.config/systemd/user/omnistore-update.timer"'));
    expect(pkgbuild, contains('rm -f "\$HOME/.config/systemd/user/omnistore-update.service"'));
  });
}
