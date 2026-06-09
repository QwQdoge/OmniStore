# Image Memory Optimization

Added `memCacheWidth` and `memCacheHeight` to `CachedNetworkImage` widgets to resize images before caching in memory.

This improves memory usage when dealing with large images or numerous icon images in lists.

It resizes:
- app icons to reasonable scales (80x80, 108x108, 200x200 depending on placement)
- hero banner image to 880 width.
- detail page hero to 720 width.
- detail page icon to 200 width.

# Rebuild Scope Reduction in Navigation Shell

Removed `context.watch<TaskController>()` from the root of `AdaptiveNavigationShell` in `adaptive_navigation_shell.dart`.
Because `TaskController` frequently calls `notifyListeners()` during file downloads to update progress numbers and speeds, observing it at the root caused the entire application shell and current page view to rebuild multiple times per second.

Instead, wrapped the specific sub-components (`_TaskProgressBar`, `_DownloadAction`, and `_ExpandedDownloadTile` icons) in isolated `Consumer<TaskController>` widgets. This measurably reduces the widget rebuild scope during active background tasks without altering any product behavior.
\n# Rebuild Scope Reduction in HomePage and SearchPage\n\nRemoved `context.watch<BrowseController>()` and `context.watch<SettingsController>()` from the root `build` methods of `HomePage` and `SearchPage`.\nInstead, wrapped specific sub-components with `Consumer<BrowseController>`, `Consumer<SettingsController>`, and `Consumer2` where state reactivity is actually required.\n\nThis prevents the entire page structure (including the `Scaffold` and `CustomScrollView`) from needlessly rebuilding every time search results update or recommendations are fetched.
