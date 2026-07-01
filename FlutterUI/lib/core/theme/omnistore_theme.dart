import 'package:flutter/material.dart';

/// MD3 palette with balanced cool and warm roles for desktop app surfaces.
abstract final class OmnistoreTheme {
  static const Color seedColor = Color(0xFF006A6A);
  static const Color tertiaryAccent = Color(0xFF8B5E00);

  static ThemeData light({String? fontFamily}) =>
      _build(Brightness.light, fontFamily);

  static ThemeData dark({String? fontFamily}) =>
      _build(Brightness.dark, fontFamily);

  static TextStyle standardHeader(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      color: theme.colorScheme.primary,
      letterSpacing: 0,
    );
  }

  static ThemeData _build(Brightness brightness, String? fontFamily) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      tertiary: tertiaryAccent,
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
      fontFamily: fontFamily == 'System' ? null : fontFamily,
      iconTheme: const IconThemeData(size: 24),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
