# Pull Request Description: Daily Localization and Polish

## What (Changes)
This PR updates the application localization resources across target locales (Simplified Chinese, Traditional Chinese, and Spanish) to eliminate rigid literal translations, ensure technical accuracy, and guarantee global consistency of terms.
Specifically, key adjustments were made:
- **Simplified Chinese (`zh`) & Traditional Chinese (`zh_Hant`)**:
  - `activity`: "活动" / "活動" -> "任务动态" / "任務動態" (Activity is in the context of task history, not promotional campaigns).
  - `source`: "来源" / "來源" -> "软件源" / "軟體源" (Source refers specifically to software repository sources).
  - `variant`: "可用版本" / "可用版本" -> "分发版本" / "分發版本" (Variants are different packaging formats like Flatpak vs Pacman, not versions).
  - `loggingLevel`: "日志详细程度" / "日誌詳細程度" -> "日志级别" / "日誌級別" (Standard developer term for Log Level).
  - `license`: "许可" / "授權" -> "许可证" / "授權條款" (Standard software license terminology).
  - `dependenciesCount`: "依赖软件包" / "依賴套件" -> "依赖项" / "依賴項" (Cleaner, standard developer translation for Dependencies).
  - `aiPromptExplain`: "解析" -> "AI 解析" (Terminology consistency with other AI features).
  - `aiExplainUpdate`: "解析此更新" -> "AI 解析此更新" (Consistent prefix).
- **Spanish (`es`)**:
  - `variant`: "Fuente de instalación" -> "Variantes" (Avoid redundancy with "Fuente" and accurately translates "Variants").

All refinements were integrated into `python/polish_l10n.py` and subsequently compiled into ARB and Dart files.

## Coverage & Verification
- Custom verification script `/home/jules/self_created_tools/verify_l10n.py` was created to validate JSON integrity, key synchronization, and placeholder parameter consistency. It verified all files perfectly with 0 issues.
- Frontend Flutter localization classes were successfully regenerated using `flutter gen-l10n`.
- Verified all changes against standard tests:
  - 69 backend python tests passed successfully.
  - Frontend widget tests passed successfully.

## Result
Highly polished, mother-tongue, publishing-grade native translations that blend flawlessly with the Material Design 3 and Arch Linux contexts.
