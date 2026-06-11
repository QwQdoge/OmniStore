plan = """
1. **Fix missing `mounted` check in `main_navigation.dart`**:
   Insert `if (!mounted) return;` before the final window manager async calls in `_handleFullExit()`.
2. **Fix missing `mounted` check in `home_page.dart`**:
   Insert `if (!mounted) return;` before `context.read<SettingsController>()` in `_fetchAIPick()`, or just put it before `_fetchAIPick` in `_refresh()`.
   Actually, `_fetchAIPick()` already checks `mounted` later inside the method. However, right at the start of `_fetchAIPick()` it does `final settings = context.read<SettingsController>();`. Wait, `_fetchAIPick()` is called directly without `await` from `initState()`, and it's also called with `await` from `_refresh()`. The `context.read` is safe synchronously, but since `_refresh()` awaits before calling it, it's safer to have `if (!mounted) return;` at the beginning of `_fetchAIPick()`.
3. **Fix missing `mounted` check in `settings_page.dart`**:
   Add `if (!mounted) return;` between the `await taskController.runCleanSystem(l10n);` and `await _fetchStorageInfo();` in `_handleClean()`.
4. **Log the action in `.Jules/sentinel.md`**:
   Document the missing mounted check scenarios handled.
"""
print(plan)
