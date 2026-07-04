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
## 2026-06-19 - Global Dialog Consistency
- Added global `DialogTheme` to `omnistore_theme.dart` with `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))` to standardize the MD3 dialog appearance across the app.
- Removed hardcoded `shape` assignments (with `28.0` radius) from `ActionConfirmDialog` and `AurSecurityDialog` in `action_dialogs.dart` to enforce reliance on the globally consistent `DialogTheme`.
- Removed hardcoded `shape` assignment (with `12.0` radius) from `TerminalDialog` in `terminal_dialog.dart` and updated its internal header container's top-left and top-right border radii from `12.0` to `28.0` to perfectly align with the new globally consistent dialog shape.
## 2026-06-20 - Terminology Consistency: AI Error Handling in Update Summary Dialog
- In `FlutterUI/lib/features/task_manager/presentation/widgets/ai_update_summary_dialog.dart`, replaced the hardcoded UI fallback string (`"AI failed to summarize."`) in `FutureBuilder` with a call to the localized `_buildAIMarkdown` method.
- This ensures AI error codes (like `AI_TIMEOUT`) are consistently mapped to standardized MD3 dialog terminology across the app, aligning with the `ai_dialogs.dart` implementation.
## 2026-06-21 - Dialog Terminology Consistency: Dismissal Actions
- Standardized the single-action dismissal buttons in informational, alert, and error dialogs to use `l10n.ok`.
- Updated `FlutterUI/lib/features/explore/presentation/pages/details_page.dart` failure dialog to use `l10n.ok` instead of `l10n.cancel`.
- Updated `FlutterUI/lib/features/explore/presentation/widgets/ai_dialogs.dart` (`AIMarkdownDialog` and `AICliDialog`) to use `l10n.ok` instead of `l10n.confirm`.
- Updated `FlutterUI/lib/features/task_manager/presentation/widgets/ai_update_summary_dialog.dart` to use `l10n.ok` instead of `l10n.confirm`.
- Updated `FlutterUI/lib/features/settings/presentation/widgets/storage_cleanup_card.dart` cleanup dialog to use `l10n.ok` instead of `l10n.confirm`.
## 2026-06-22 - Dialog Consistency & Install Flow Unification
- Removed hardcoded `shape` property (`RoundedRectangleBorder` with 28.0 radius) from `TerminalDialog` in `FlutterUI/lib/features/task_manager/presentation/widgets/terminal_dialog.dart`. This ensures the dialog falls back to the globally consistent `DialogTheme` defined in `omnistore_theme.dart`.
- Refactored `_importPackages` in `FlutterUI/lib/features/home/home_page.dart` to use the standardized `TaskController` flow instead of hitting `TaskRepository` directly.
- Added `taskController.isBusy` guard in `_importPackages` to prevent overlapping installations, showing a standard `l10n.taskInProgress` SnackBar if busy.
- Refactored the `packages` iteration in `_importPackages`'s `onConfirm` callback to safely capture `BuildContext` variables (`ScaffoldMessenger` and `AppLocalizations`) and `await taskController.runTask` sequentially. This prevents parallel installation race conditions and unifies the UI experience (e.g. terminal dialog progress) with the rest of the application.
## 2026-06-23 - Dialog Consistency: Storage Cleanup
- Replaced the custom inline `AlertDialog` in `StorageCleanupCard` (`FlutterUI/lib/features/settings/presentation/widgets/storage_cleanup_card.dart`) with the global `TerminalDialog`.
- Refactored `TerminalDialog` (`FlutterUI/lib/features/task_manager/presentation/widgets/terminal_dialog.dart`) to support progress indicators and status messages using Dart 3 records in a `Selector`, thus preserving the UX of `StorageCleanupCard` while standardizing the codebase and removing duplicated UI logic.
## 2026-06-24 - Dialog Consistency: Task Failure Terminal Output
- Replaced the custom inline `AlertDialog` in `details_page.dart` (which showed a generic task failure message) with the centralized `TerminalDialog`. This standardizes the task progress and terminal output experience, ensuring that task failures immediately present the user with the relevant terminal logs for inspection.
