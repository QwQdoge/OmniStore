# `core/` — application infrastructure

| Subfolder / file | Purpose |
|------------------|---------|
| `theme/omnistore_theme.dart` | MD3 light/dark `ThemeData` |
| `layout/adaptive_navigation_shell.dart` | Width-based `NavigationBar` / `NavigationRail` |
| `layout/breakpoints.dart` | 600 / 900 px breakpoints |
| `network/github_client.dart` | GitHub REST + prefs/memory cache |
| `platform/desktop_window_service.dart` | `window_manager` init (tray, min size) |
| `navigation_controller.dart` | Selected tab index |

No feature-specific business logic belongs here.
