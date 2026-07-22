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
## 2026-06-25 - Dialog Button and Card Consistency
- Replaced the primary action `TextButton` with `FilledButton` in the 'Add Custom Source' inline dialog in `FlutterUI/lib/features/settings/presentation/widgets/sources_config_card.dart` to match the consistent dialog confirmation button pattern used throughout the app.
- Replaced raw `Card` with `AppCard` in `TasksTab` (`FlutterUI/lib/features/task_manager/presentation/widgets/tasks_tab.dart`) to ensure visual consistency with the rest of the application's Material Design 3 surface containers. Updated the `shape` parameter to `borderRadius` as required by `AppCard`.
## 2026-06-26 - Terminology Consistency: Clipboard Feedback
- Replaced fragmented clipboard copy feedback strings (`nameCopied`, `aiCommandCopied`) with a globally consistent `copiedToClipboard` string.
- Updated `FlutterUI/lib/features/explore/presentation/widgets/app_details_header.dart` and `FlutterUI/lib/features/explore/presentation/widgets/ai_dialogs.dart` to use the unified `copiedToClipboard` localization key.
- Removed redundant `nameCopied` and `aiCommandCopied` keys from all `.arb` files and regenerated localization files via `flutter gen-l10n`.
## 2026-06-27 - Global SnackBar Consistency: Clipboard Feedback Duration
- Identified inconsistency in the display duration of `SnackBar` widgets used for clipboard copy feedback. `FlutterUI/lib/features/explore/presentation/widgets/app_details_shared.dart` explicitly set `duration: const Duration(seconds: 2)`, while `FlutterUI/lib/features/explore/presentation/widgets/ai_dialogs.dart` and `FlutterUI/lib/features/explore/presentation/widgets/app_details_header.dart` relied on the default framework duration (typically 4 seconds).
- Standardized the duration across the application by adding `duration: const Duration(seconds: 2)` to the `SnackBar` instantiations in both `ai_dialogs.dart` and `app_details_header.dart`. This ensures a unified interaction flow and prevents overlapping or lingering feedback messages.
## 2026-06-28 - Button Consistency: Standardizing Primary Actions
- Replaced all instances of `ElevatedButton` and `ElevatedButton.icon` in `TasksTab` and `UpdatesTab` with `FilledButton` and `FilledButton.icon`. This unifies the primary action button style across the app since `FilledButton` is explicitly themed in `omnistore_theme.dart` and `ElevatedButton` is not.

## 2026-07-31 - Chinese Localization Polish & MD3 Terminology Synchronization

**Learning:** Static onboarding localization keys should never carry unnecessary conversational fillers, subjective remarks, or conditional 'If...then' clauses. Refining literal translation paths into direct, professional, active statements unifies the app interface consistency. Moreover, when polishing localization strings, updating the primary onboarding script generator `python/update_arb.py` prior to regenerating ARB files is mandatory to avoid config overwriting.

**Action:** Polished translations in `python/update_arb.py` (for `NEW_KEYS_ZH` and `NEW_KEYS_ZH_HANT`) to eliminate fillers ("提示：", "我们", "如果您...") and conditional clauses ("如果您使用...", "填入..."). Regenerated and sorted `.arb` files via `update_arb.py` and compiled via `flutter gen-l10n`.

| 类型 | 原始文本 | 旧翻译 | 优化后翻译 | 修改原因 |
| --- | --- | --- | --- | --- |
| zh | feedbackDesc | 如果您遇到问题，请通过 GitHub 反馈给我们。 | 遇到问题请通过 GitHub 提交反馈。 | 移除“如果您”条件从句与冗余字词 |
| zh | aiOllamaNote | 提示：如果您使用 Ollama，请确保它已在后台运行并开启了 OLLAMA_ORIGINS="*" 环境变量。 | Ollama 需在后台运行并启用 OLLAMA_ORIGINS="*" 环境变量。 | 移除“提示：”和“如果您使用”等冗余 filler/条件语气 |
| zh | envCheckSubtitle | 我们需要确保您的系统已准备就绪 | 确保系统已准备就绪 | 移除人称代词和多余语气 |
| zh | envWarningDesc | 缺少一些必要的组件，我们可以为您自动配置。 | 缺少必要组件，将进行自动配置。 | 移除冗余字眼，使其更具确定性 |
| zh | envOkDesc | 一切就绪！您的系统非常完美。 | 一切就绪！系统环境完整。 | 移除偏口语化和主观的描述，使其更专业 |
| zh | aiProviderDesc | 选择您的 AI 模型来源 (本地或云端) | 选择 AI 模型来源（本地或云端） | 移除人称代词及规范括号 |
| zh | aiEndpointHelper | Ollama 默认为 http://localhost:11434 | Ollama 默认地址为 http://localhost:11434 | 精确描述配置项 |
| zh | aiApiKeyHelper | Ollama 无需密钥，OpenAI 填入 sk-xxx | Ollama 无需密钥，OpenAI 密钥格式如 sk-xxx | 移除“填入”命令式口吻及 conditional 暗示 |
| zh | howToGetApiKeyDesc | 1. Ollama (本地)：运行 Ollama，无需密钥。2. 云端 (OpenAI)：前往官网创建并填入密钥。 | 1. Ollama（本地）：运行服务即可，无需密钥。2. 云端服务（OpenAI）：需前往官网创建并输入密钥。 | 精简用词并统一中文括号与术语 |
| zh_Hant | feedbackDesc | 如果您遇到問題，請透過 GitHub 反饋給我們。 | 遇到問題請透過 GitHub 提交反饋。 | 移除“如果您”條件從句與冗餘字詞 |
| zh_Hant | aiOllamaNote | 提示：如果您使用 Ollama，請確保它已在背景執行並開啟了 OLLAMA_ORIGINS="*" 環境變數。 | Ollama 需在背景執行並啟用 OLLAMA_ORIGINS="*" 環境變數。 | 移除“提示：”和“如果您使用”等冗餘 filler/條件語氣 |
| zh_Hant | envCheckSubtitle | 我們需要確保您的系統已準備就緒 | 確保系統已準備就緒 | 移除人稱代詞和多餘語氣 |
| zh_Hant | envWarningDesc | 缺少一些必要的組件，我們可以為您自動配置。 | 缺少必要組件，將進行自動配置。 | 移除冗餘字眼，使其更具確定性 |
| zh_Hant | envOkDesc | 一切就緒！您的系統非常完美。 | 一切就緒！系統環境完整。 | 移除偏口語化和主觀的描述，使其更專業 |
| zh_Hant | sourceConfigSubtitle | 選擇您想要啟用的軟體存放庫 | 選擇欲啟用的軟體存放庫 | 精簡傳統語境下的語意 |
| zh_Hant | aiProviderDesc | 選擇您的 AI 模型來源 (本地或雲端) | 選擇 AI 模型來源（本地或雲端） | 移除人稱代詞及規範括號 |
| zh_Hant | aiEndpointHelper | Ollama 預設為 http://localhost:11434 | Ollama 預設地址為 http://localhost:11434 | 精確描述配置项 |
| zh_Hant | aiApiKeyHelper | Ollama 無需金鑰，OpenAI 填入 sk-xxx | Ollama 無需金鑰，OpenAI 金鑰格式如 sk-xxx | 移除“填入”命令式口吻及 conditional 暗示 |
| zh_Hant | howToGetApiKeyDesc | 1. Ollama (本地)：執行 Ollama，無需金鑰。2. 雲端 (OpenAI)：前往官網建立並填入金鑰。 | 1. Ollama（本地）：執行服務即可，無需金鑰。2. 雲端服務（OpenAI）：需前往官網建立並輸入金鑰。 | 精簡用詞並統一中文括號與術語 |
