## 2026-06-08 - Global SnackBar Consistency
- Added global `SnackBarThemeData` to `omnistore_theme.dart` with `behavior: SnackBarBehavior.floating`.
- Removed hardcoded `SnackBarBehavior.floating` from individual `SnackBar` instantiations to ensure consistent floating behavior across the entire app.

## 2026-06-09 - Global SnackBar Consistency Update
- Re-verified implementation of global `SnackBarThemeData` in `omnistore_theme.dart` with `behavior: SnackBarBehavior.floating`.
- Removed newly introduced hardcoded `behavior: SnackBarBehavior.floating` from `FlutterUI/lib/features/explore/presentation/pages/details_page.dart` (copy item SnackBar).

## 2026-06-10 - Terminology Consistency: Settings Page Restart Warnings
- Replaced hardcoded dual-language restart warning strings in `FlutterUI/lib/features/settings/presentation/pages/settings_page.dart` (for the `useSystemTitleBar` switch) with the localized `l10n.configSaved` string. This standardizes the terminology and relies on standard localization files.

## 2026-06-11 - Global SnackBar and Terminology Consistency: Update Check Failures
- Replaced the hardcoded Chinese string `检查更新失败: $e` in `FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart` with a localized `checkUpdateFailed` key. Added translations for this new key to all ARB files (`app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`, `app_es.arb`, `app_ja.arb`).
- Removed two hardcoded `behavior: SnackBarBehavior.floating` assignments from `SnackBar` widgets in `download_page.dart` to enforce reliance on the globally consistent `SnackBarThemeData` established in `omnistore_theme.dart`.

## 2026-06-12 - Global SnackBar Consistency: Navigation
- Removed a hardcoded `behavior: SnackBarBehavior.floating` assignment from the `SnackBar` widget shown upon application exit to the system tray in `FlutterUI/lib/app/main_navigation.dart`. This ensures the application consistently uses the default `SnackBarBehavior.floating` defined in the global `SnackBarThemeData` of `omnistore_theme.dart`.
