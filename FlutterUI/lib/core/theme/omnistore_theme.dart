import 'package:flutter/material.dart';

/// MD3 palette: deep purple seed with pink-blue tertiary accent.
abstract final class OmnistoreTheme {
  static const Color seedDeepPurple = Color(0xFF6750A4);
  static const Color accentPinkBlue = Color(0xFF7BA3D4);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static TextStyle standardHeader(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      color: theme.colorScheme.primary,
      letterSpacing: -1.0,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: seedDeepPurple,
      brightness: brightness,
      tertiary: accentPinkBlue,
    );
    final scheme = base.copyWith(
      surfaceContainerLowest: base.surface,
      surfaceContainerLow: base.surfaceContainerLow,
      surfaceContainer: base.surfaceContainer,
      surfaceContainerHigh: base.surfaceContainerHigh,
      surfaceContainerHighest: base.surfaceContainerHighest,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      iconTheme: const IconThemeData(size: 24),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        color: scheme.surfaceContainerLow,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
      hoverColor: scheme.onSurface.withValues(alpha: 0.08),
      focusColor: scheme.onSurface.withValues(alpha: 0.12),
      splashColor: scheme.onSurface.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
    );
  }
}
