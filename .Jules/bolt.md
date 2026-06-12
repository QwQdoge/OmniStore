# Image Memory Optimization

Added `memCacheWidth` and `memCacheHeight` to `CachedNetworkImage` widgets to resize images before caching in memory.

This improves memory usage when dealing with large images or numerous icon images in lists.

It resizes:
- app icons to reasonable scales (80x80, 108x108, 200x200 depending on placement)
- hero banner image to 880 width.
- detail page hero to 720 width.
- detail page icon to 200 width.
- screenshot viewer image to 1080 width.

# Rebuild Scope Reduction in Navigation Shell and AppDetailsPage

Removed `context.watch<TaskController>()` from the root of `AdaptiveNavigationShell` in `adaptive_navigation_shell.dart`.
Because `TaskController` frequently calls `notifyListeners()` during file downloads to update progress numbers and speeds, observing it at the root caused the entire application shell and current page view to rebuild multiple times per second.

Instead, wrapped the specific sub-components (`_TaskProgressBar`, `_DownloadAction`, and `_ExpandedDownloadTile` icons) in isolated `Consumer<TaskController>` widgets. This measurably reduces the widget rebuild scope during active background tasks without altering any product behavior.

Similarly, removed `context.watch<TaskController>()` from the `build` method of `AppDetailsPage` in `details_page.dart`.
Wrapped `_buildActionArea` (and its desktop variant) and the `_buildMainContent` call in `Consumer<TaskController>` to ensure that high-frequency progress updates during downloads only trigger rebuilds for the relevant UI components, preventing unnecessary re-rendering of the entire page content.
Wrapped the terminal output `Badge` in a `Selector<TaskController, bool>` to only react to `isBusy` state changes.

# Search UI Responsiveness

Replaced `setState` in the text input `onChanged` handler with `ValueListenableBuilder` tied to `_searchController` in `FlutterUI/lib/features/explore/presentation/pages/search_page.dart`.
Previously, every keystroke triggered a full-page rebuild just to determine whether to display the "Clear" trailing button in the `SearchBar`. By removing `onChanged` and moving the trailing `IconButton` into a `ValueListenableBuilder<TextEditingValue>`, state updates are now correctly isolated to the clear button itself. This measurably improves responsiveness during active typing by eliminating unnecessary widget tree traversal and rendering.
## 2024-06-12 - Search UI Responsiveness

Learning:
Replacing `setState` in text input `onChanged` with `ValueNotifier` prevents full-page rebuilds per keystroke by isolating state updates to specific sub-components like 'Clear' buttons.

Action:
Replaced TextEditingValue listenable with _hasSearchText ValueNotifier and implemented onChanged in SearchPage.dart.
