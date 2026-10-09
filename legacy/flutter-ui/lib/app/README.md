# `app/` — composition root

| File | Role |
|------|------|
| `app_bootstrap.dart` | `bootstrapOmniStore()` — window init, `SharedPreferences`, `MultiProvider` |
| `omnistore_app.dart` | `MaterialApp`, theme, onboarding gate |
| `main_navigation.dart` | `MainNavigationEntry` — tray close, `AdaptiveNavigationShell` |

`lib/main.dart` only calls `bootstrapOmniStore()`.
