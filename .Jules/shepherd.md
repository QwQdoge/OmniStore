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
## 2026-06-13 - Terminology Consistency: Task In Progress
- Added unified UX feedback for `taskInProgress` scenario during app updates and uninstalls.
- In `FlutterUI/lib/features/explore/presentation/pages/details_page.dart`, added the `ScaffoldMessenger` displaying `AppLocalizations.of(context)!.taskInProgress` when the `taskController` is busy, similar to `settings_page.dart`.
- In `FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart`, explicitly prevented parallel background task execution via checking `isBusy` on "Update All" and single "Update" actions, throwing consistent `taskInProgress` localized errors via `ScaffoldMessenger`.

## 2026-06-15 - Standardized App Item Presentation

**Learning:** Using raw `Card` widgets for app items leads to visual inconsistency. Standardizing on `AppCard` ensures that all app lists and grid items share the same MD3 surface container styling and standardized hover/tap scale animations (0.98 scale).

**Action:** Replaced raw `Card` with `AppCard` in `download_page.dart` and updated skeleton loaders in `download_page.dart`, `search_page.dart`, `apps_page.dart`, and `flatpak_store_page.dart` to use `AppCard`.
## 2026-06-16 - AI Connection Feedback Consistency
- Replaced hardcoded connection success/failure and error strings in `ai_settings_section.dart` with localized keys (`aiTestSuccess`, `failed`, `aiTestFailed`) to ensure terminology and SnackBar/Dialog consistency across the app.
## 2026-06-17 - Terminology Consistency: Tray Initialization Error Feedback
- Replaced the hardcoded bilingual string `'托盘初始化失败，已自动关闭后台驻留。 / Tray initialization failed. Close to tray disabled.'` used in `SnackBar` within `FlutterUI/lib/app/main_navigation.dart` with a newly updated localized key `trayInitFailedDisabled`.
- Updated the key and translation text for `trayInitFailedDisabled` across all ARB files (`app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`, `app_ja.arb`, `app_es.arb`) to accurately describe the behavior (disabling "close to tray") instead of incorrectly claiming the app is exiting.
## 2026-06-18 - Dialog Consistency: Terminal Dialog Consolidation
- Identified duplicated `TerminalDialog` implementations in `explore` and `task_manager` features.
- Consolidated into a single `TerminalDialog` in `FlutterUI/lib/features/task_manager/presentation/widgets/terminal_dialog.dart`, incorporating the rich AI error analysis features from the `explore` version.
- Replaced hardcoded `12.0` border radius and `Colors.redAccent` with standardized MD3 `28.0` radius and `theme.colorScheme.error` for improved visual consistency.
