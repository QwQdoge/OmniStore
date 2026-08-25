import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:screen_retriever/screen_retriever.dart';

/// Desktop-only window setup (not used in widget build trees).
abstract final class DesktopWindowService {
  static const Size minWindowSize = Size(820, 600);
  static const Size defaultWindowSize = Size(1280, 840);

  static Size initialSizeFor(Size availableSize) {
    final width = (availableSize.width * 0.72).clamp(
      minWindowSize.width,
      1440.0,
    );
    final height = (availableSize.height * 0.78).clamp(
      minWindowSize.height,
      960.0,
    );
    return Size(width, height);
  }

  static Size minimumSizeFor(Size availableSize) => Size(
    minWindowSize.width.clamp(560.0, availableSize.width * 0.88),
    minWindowSize.height.clamp(480.0, availableSize.height * 0.88),
  );

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
    final display = await screenRetriever.getPrimaryDisplay();
    final availableSize = display.visibleSize ?? display.size;
    final initialSize = initialSizeFor(availableSize);
    final adaptiveMinimumSize = minimumSizeFor(availableSize);
    debugPrint(
      'OmniStore display=${display.name ?? display.id} '
      'logical=${availableSize.width}x${availableSize.height} '
      'scale=${display.scaleFactor ?? 1} '
      'window=${initialSize.width}x${initialSize.height}',
    );

    final options = wm.WindowOptions(
      size: initialSize,
      minimumSize: adaptiveMinimumSize,
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
      await wm.windowManager.setMinimumSize(adaptiveMinimumSize);
      await wm.windowManager.setSkipTaskbar(false);
      await wm.windowManager.show();
      await wm.windowManager.focus();
      await wm.windowManager.setPreventClose(true);
    });
  }
}
