
## 2025-05-15 - Installed List Subprocess Consolidation

**Learning:** Retrieving package sizes in a loop for installed lists is a massive O(N) bottleneck due to subprocess spawning overhead. Most modern package managers (Flatpak, Pacman) provide ways to retrieve this metadata in bulk.

**Action:** Always prefer batch metadata retrieval (e.g., `flatpak list --columns=...,size` or bulk `pacman -Qi`) over individual per-package queries for list-based UI features.

## 2026-06-15 - MediaQuery Rebuild Optimization

**Learning:** Using `MediaQuery.of(context).size.width` triggers a rebuild of the entire widget whenever ANY property of `MediaQueryData` changes (e.g., keyboard visibility, system theme). Using `MediaQuery.sizeOf(context).width` (available in Flutter 3.10+) ensures the widget only rebuilds when the size specifically changes.

**Action:** Replaced `MediaQuery.of(context).size.width` with `MediaQuery.sizeOf(context).width` in `flatpak_store_page.dart` and `search_page.dart`.

## 2026-06-16 - Search Selection & AppCard Optimization

**Learning:** Managing selection state in a monolithic page using `setState` causes the entire list to rebuild, which is expensive for large datasets. Offloading selection to a `ChangeNotifier` and using `context.select` in list items isolates rebuilds. Additionally, `AppCard` animations can be skipped for non-interactive items by checking for the presence of `onTap`.

**Action:** Refactored `SearchPage` and `SearchResultTile` to use reactive selection via `BrowseController`. Optimized `AppCard` to conditionally enable `MouseRegion` and `ScaleTransition`. Ensure `Selector` in `SearchPage` also listens to local state (filters) and `MediaQuery.sizeOf` to avoid blocking valid UI updates.

## 2026-06-17 - Trending Shelf Rebuild Reduction

**Learning:** `Consumer` widgets rebuild their child tree every time the provided controller's `notifyListeners` is called. For a shelf that only cares about one specific list (e.g., 'trending' apps), this causes many unnecessary rebuilds. By switching to `Selector`, we narrow the rebuild trigger to only fire when the specific property changes.

**Action:** Replaced `Consumer<BrowseController>` with `Selector<BrowseController, List<AppPackage>>` in `home_page.dart` for the 'Trending' shelf, successfully isolating its build behavior without altering functionality.

## 2026-06-18 - HomePage Category Allocations

**Learning:** Allocating a new list and performing localization lookups in the `build()` method causes unnecessary allocations on every frame or state change. Caching lists that only change when dependencies (like localization) change reduces garbage collection overhead and makes `build()` faster.

**Action:** Added `_categories` state to `_HomePageState` and initialized it in `didChangeDependencies()` to memoize `CategoryService.getCategories(context)`, avoiding redundant evaluations in `_buildCategoryQuickAccess()`.
Target: Reduced high-frequency rebuilds triggered by TaskController.
Files Modified: tasks_tab.dart, download_page.dart, task_manager/presentation/widgets/terminal_dialog.dart, explore/presentation/widgets/terminal_dialog.dart
Action: Replaced broad Consumer<TaskController> widgets with targeted Selector widgets.
Details: In TerminalDialog and TasksTab, ListView components were rebuilding on every single progress tick due to the Consumer. Migrated to Selector using Dart 3 records to pass safely referenced lists, ensuring the UI lists only rebuild when the actual log/history counts change. Same for the terminal badge icon in DownloadPage.
Result: Significantly reduced 60fps widget rebuilds during active downloads. Tests passed.

## 2026-06-25 - SettingsController Rebuild Reduction

**Learning:** Using `Consumer<SettingsController>` in root widgets like `MaterialApp` or persistent page components causes the entire subtree to rebuild whenever ANY setting changes (even unrelated ones, like background update checks or daemon toggles). By switching to `Selector`, we narrow the rebuild triggers to specific UI-relevant properties.

**Action:** Replaced `Consumer<SettingsController>` with targeted `Selector` implementations in `omnistore_app.dart` (selecting only themeMode, locale, fontFamily, and fontScale), `search_page.dart` (selecting only the specific 'search sources' JSON), and `updates_tab.dart` (selecting only `isAIEnabled`). This isolates rebuilds and improves rendering performance across the app.

## 2026-06-27 - SearchPage Selector & MediaQuery Optimization

**Learning:** Using `jsonEncode` for map equality in a `Selector` is a hidden performance trap, causing expensive string allocations and JSON parsing on every notification. Additionally, placing `MediaQuery.sizeOf(context)` at the top of a page's `build` method causes the entire page to rebuild on every single pixel change of the window width, even if the layout only depends on a specific threshold.

**Action:** Optimized `SearchPage` by: 1) Replacing `jsonEncode` in the sources `Selector` with `MapEquality` from `package:collection`. 2) Moving the `MediaQuery` width check into the main `BrowseController` `Selector` and converting it to a boolean (`isDesktop`). This ensures the page only rebuilds when the desktop/mobile threshold (900px) is actually crossed.

## 2026-06-28 - SearchPage ListView & Selector Optimization

**Learning:** Adding `prototypeItem` to `ListView.builder` significantly improves scroll performance and scrollbar accuracy by allowing the framework to pre-calculate dimensions without laying out every child. In `Selector`, when returning a filtered list, the default identity equality will always trigger a rebuild because `.toList()` creates a new instance. Using `shouldRebuild` with `IterableEquality` ensures rebuilds only occur when the actual contents change.

**Action:** Optimized `SearchPage` by adding `prototypeItem` to results and skeleton lists, moving filtering logic into the `Selector`, and implementing `IterableEquality` in `shouldRebuild`.

## 2026-06-30 - Lazy Animation & Cache-First Badge Optimization

**Learning:** Initializing an `AnimationController` in every instance of a common list item (like `AppCard`) creates significant memory and Ticker overhead, especially for non-interactive skeletons and prototype items. Deferring initialization until `onTap` is confirmed as non-null reduces this waste. Additionally, for high-frequency metadata like star counts, relying solely on `FutureBuilder`-style async patterns causes visual "flicker" even when data is cached; a synchronous cache-check in `initState` provides a much smoother browsing experience.

**Action:** Refactored `AppCard` to lazy-initialize its controller and updated `GitHubStarBadge` to perform synchronous cache lookups in `GitHubClient`.

## 2026-07-02 - SettingsPage Granular Selector Optimization

**Learning:** Using broad `Consumer<SettingsController>` widgets in a complex settings page causes significant performance degradation as any single change (like toggling a switch or moving a slider) forces the entire page or large sections of it to rebuild. Using targeted `Selector` widgets with Dart 3 records for primitive grouping and `MapEquality` for configuration maps ensures that only the relevant widgets rebuild.

**Action:** Refactored `SettingsPage.dart` by replacing all `Consumer<SettingsController>` widgets with granular `Selector` implementations for General, Repositories, Updates, Typography, and AI sections.

## 2026-07-04 - Search Latency & List Virtualization Optimization

**Learning:** Artificial debounce timers (e.g., 300ms) in search controllers are redundant for explicit user actions (like 'onSubmitted' or category clicks) and introduce unnecessary lag. Using a request ID ('_activeSearchId') allows for immediate execution while safely handling asynchronous race conditions. Furthermore, horizontal shelves with fixed-size items benefit significantly from switching from 'ListView.separated' to 'ListView.builder' with a 'prototypeItem', as it optimizes scroll virtualization and scrollbar accuracy.

**Action:** Removed 300ms debounce from `BrowseController.search`, added race condition handling via `_activeSearchId`, and refactored `AppShelf` to use `ListView.builder` with `prototypeItem`.
- Refactored `AppShelf` (FlutterUI/lib/core/widgets/app_shelf.dart) to replace `ListView.separated` with `ListView.builder` utilizing `prototypeItem` for list virtualization. Adjusted padding to maintain exact pixel layout.

## 2026-07-05 - Hot-path String & Repaint Optimization

**Learning:** Redundant string transformations (like `.lower()`) and dictionary allocations inside hot search loops (e.g., scoring hundreds of items) create significant CPU overhead. Additionally, hover-triggered animations in common list items (like `AppCard`) can trigger expensive repaints of the entire list if not isolated.

**Action:** Hoisted priority dictionary and `.lower()` transformations out of search loops in `manager.py` and `scoring.py`. Wrapped `ScaleTransition` in `AppCard` with a `RepaintBoundary` to isolate hover animations.

## 2026-07-06 - Batch Subprocess Consolidation for Installed Apps

**Learning:** Spawning a subprocess for every installed package to fetch metadata (like size or description) creates extreme O(N) latency and CPU spikes. Most package managers (pacman, flatpak) support batch retrieval or streaming output that allows fetching metadata for all packages in a single O(1) operation.

**Action:** Optimized `FlatpakSource`, `PacmanSource`, and `AurSource` in the Python backend. Replaced per-package loops with batch commands (`flatpak list --columns=...,size`, `pacman -Qqne | pacman -Qi -`, and `pacman -Qi [foreign_pkgs]`). Implemented a metadata stream parser to extract details efficiently.
