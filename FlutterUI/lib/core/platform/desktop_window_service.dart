import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Desktop-only window setup (not used in widget build trees).
abstract final class DesktopWindowService {
  static const Size minWindowSize = Size(900, 640);
  static const Size defaultWindowSize = Size(1150, 800);

  static bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  static Future<void> initialize({bool useSystemTitleBar = false}) async {
    if (!isSupported) return;

    await wm.windowManager.ensureInitialized();

    final options = wm.WindowOptions(
      size: defaultWindowSize,
      minimumSize: minWindowSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: useSystemTitleBar
          ? wm.TitleBarStyle.normal
          : wm.TitleBarStyle.hidden,
      title: 'OmniStore',
    );

    await wm.windowManager.waitUntilReadyToShow(options, () async {
      await wm.windowManager.setTitle('OmniStore');
      await wm.windowManager.setMinimumSize(minWindowSize);
      await wm.windowManager.setSkipTaskbar(false);
      await wm.windowManager.show();
      await wm.windowManager.focus();
      await wm.windowManager.setPreventClose(true);
    });
  }
}
