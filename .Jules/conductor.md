## 2026-06-08 - [AnimatedSwitcher for MD3 interaction smoothing]
- Used `AnimatedSwitcher` in `FlutterUI/lib/features/explore/presentation/pages/details_page.dart` to ensure subtle implicit animations between the loading state (skeletons) and the final markdown text.
- Also utilized `AnimatedSwitcher` to smooth out transitions in the `_buildActionArea` (install, uninstall, busy/progress tasks) to prevent abrupt visual jumps.
- Keep animation durations reasonably short (e.g., 300ms) to preserve UI responsiveness while adding clarity.
