import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class WindowService {
  final SystemTray? _systemTray = kIsWeb ? null : SystemTray();

  Future<void> initTray() async {
    if (kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    String path = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    
    // Check if icon exists, fallback to simple string if not
    await _systemTray?.initSystemTray(
      title: "OmniStore",
      iconPath: path,
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (menuItem) => windowManager.show()),
      MenuItemLabel(label: 'Hide', onClicked: (menuItem) => windowManager.hide()),
      MenuSeparator(),
      MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
    ]);

    await _systemTray?.setContextMenu(menu);

    _systemTray?.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows ? windowManager.show() : _systemTray?.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows ? _systemTray?.popUpContextMenu() : windowManager.show();
      }
    });
  }
}
