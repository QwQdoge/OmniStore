# ⚡ Bolt Learning Journal

Routine work is never logged. Surprising technical findings, failed optimizations, or architecture-specific bottlenecks must be recorded here using the format: `## YYYY-MM-DD - [Title], **Learning:** [Insight], **Action:** [Future application].`

## 2026-06-16 - HomePage Selector Optimization

**Learning:** Using `Consumer<BrowseController>` in a large page like HomePage causes all of its descendants (like multiple `AppShelf` instances) to rebuild their child tree every time the provided controller's `notifyListeners` is called. For a shelf that only cares about one specific list (e.g., 'trending' apps), this causes many unnecessary rebuilds. By switching to `Selector`, we narrow the rebuild trigger to only fire when the specific property changes.

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

## 2026-07-14 - Search Scoring & Merging Optimization

**Learning:** Redundant string transformations (truncation and lowercasing) and dictionary lookups inside high-frequency search loops (scoring and merging hundreds of items) create significant CPU and memory allocation overhead. Truncating descriptions before they reach the scoring function not only saves processing time but also drastically improves `lru_cache` hit rates by reducing the key space.

**Action:** Optimized `SearchManager` and `SmartScoring` by pre-calculating source metadata, implementing early description truncation, hoisting static priority maps, and deferring variant dictionary allocations until absolutely necessary.

## 2026-07-15 - CachedNetworkImage Optimization in Store Header

**Learning:** Using standard `Image.network` for static or frequently accessed network images (like the GitHub logo in the store header) causes redundant network requests on subsequent rebuilds, increasing latency and memory overhead. Replacing it with `CachedNetworkImage` prevents redundant downloads, utilizing disk caching for improved loading performance.

**Action:** Replaced `Image.network` with `CachedNetworkImage` in `github_store_header.dart`.

## 2026-07-28 - Image Memory Optimization and Scroll Virtualization
**Learning:** `memCacheWidth` and `memCacheHeight` must be set in `CachedNetworkImage` for fixed-size assets like logos to avoid engine decoding full-resolution source images into heap. Mismatched dimensions between `prototypeItem` and `itemBuilder` in `ListView.builder` cause scroll jitter and inaccurate scrollbar sizing during virtualization.
**Action:** Added missing `memCacheWidth: 64` and `memCacheHeight: 64` to `github_store_header.dart`. Also added missing `prototypeItem`s in `tasks_tab.dart` and `terminal_dialog.dart` to fix virtual scroll rendering issues. Finally, correctly memoized `CategoryService.getCategories` within `didChangeDependencies` in `CategoryPage` to optimize local rebuilds.

## 2026-07-29 - Horizontal Chips List prototypeItem Limitation

**Learning:** Using `prototypeItem` on horizontal lists containing variable-width elements (like `ActionChip` or `ChoiceChip` with dynamic labels) is a layout trap. In Flutter, `prototypeItem` forces every child element to have the exact same extent in the scroll direction. For variable-width items, this results in severe truncation for long texts and massive empty padding for short ones.

**Action:** Skipped `prototypeItem` in `category_quick_access.dart` and `ai_app_resolver.dart` to preserve variable-width chip layouts, reserving it for fixed-dimension children or vertical layouts with uniform item extents.

## 2026-07-29 - Recommendations Fetch Deduplication & Rate Limiting

**Learning:** Frequently navigating back and forth or switching tabs triggers repetitive background network/daemon recommendation updates, causing unnecessary IPC/HTTP overhead and potentially hitting API rate limits. Coalescing simultaneous fetches via a cached `Future` and throttling background updates using a 5-minute cooldown (`_lastFetchTime`) drastically improves startup/navigation responsiveness and network efficiency.

**Action:** Implement cached `Future` deduplication (`_activeFetchFuture`) and timestamp-based throttling (`_lastFetchTime`) for heavy background metadata and recommendation endpoints, while providing a `forceRefresh` option for manual user triggers.

## 2026-07-30 - Category Apps Cache & Fetch Deduplication

**Learning:** Accessing categories (like Development, Games, AudioVideo) repeatedly triggers heavy network calls to Flathub and results in high latency for the user. Adding a 24-hour cache TTL and in-flight request deduplication on the backend daemon prevents duplicate network roundtrips, resulting in instantaneous, O(1) page loads on repeat access.

**Action:** Implemented category app caching and task coalescing inside `RecommendationManager`, including proper JSON state loading and async snapshot preservation on disk.

## 2024-07-27 - Task Manager List Virtualization
- **Optimization**: Removed `SingleChildScrollView` + `ListView.builder(shrinkWrap: true)` anti-pattern in `tasks_tab.dart`.
- **Implementation**: Replaced with `CustomScrollView`, separating static elements into `SliverToBoxAdapter`s wrapped in `SmoothSizeSwitcher` and keeping the reactive list as `SliverList.builder`. Padding was applied via `Padding` inside adapters and `SliverPadding`.
- **Result**: Restored O(1) lazy-rendering virtualization for the completed tasks list, significantly improving performance when the task history grows large, without altering layout visually.

## 2026-07-30 - FlatpakStorePage Rebuild Reduction

**Learning:** Invoking `MediaQuery.sizeOf(context)` directly inside a stateful page's build method forces the entire page, including its heavy list views and details subtrees, to rebuild on every pixel of window resizing. Implementing a self-contained caching `ResponsiveLayoutBuilder` that clears its cache on `didUpdateWidget` but retains it during media query updates isolates the resize recalculation, skipping all subtree rebuilds unless the desktop/mobile threshold (900px) is crossed.

**Action:** Replaced direct `MediaQuery` lookup in `flatpak_store_page.dart` with a custom `ResponsiveLayoutBuilder` to completely isolate resize rebuilds from parent state updates.
## 2026-08-01 - SearchPage Selector & MediaQuery Optimization (Extracted ResponsiveLayoutBuilder)

**Learning:** Placing `MediaQuery.sizeOf(context)` inside the `selector` function of a `Selector` widget forces the entire `Selector` (and the `search_page` itself indirectly) to rebuild on every pixel of window resizing, bypassing the intended optimization.

**Action:** Extracted `ResponsiveLayoutBuilder` into `core/widgets/` for reusability. Wrapped the `Selector` in `SearchPage` with `ResponsiveLayoutBuilder`, effectively isolating the MediaQuery dependency from the Selector's state checks.
## 2026-08-01 - AppPackage Lazy Caching Optimization

**Learning:** Redundant `.toLowerCase()` string transformations inside hot-path UI filtering loops (such as search inputs parsing hundreds of items in AppsPage, DownloadPage, and SearchPage) create unnecessary CPU overhead. Pre-computing these fields lazily on the model drastically improves performance.

**Action:** Added lazy `nameLower`, `descriptionLower`, and `primarySourceLower` fields to `AppPackage` and updated all corresponding `toLowerCase()` UI usage to reference the cached fields.

- Added memCacheHeight to 1:1 app icons in various files to restrict decoder memory allocation inside the heap, following the memory optimization guideline.

## 2024-08-01 - UpdatesTab List Virtualization & Loading Optimization

**Learning:** Skeletons should use `ListView.builder` with `prototypeItem` for better scroll virtualization, and state should be managed carefully to ensure loaders properly display and hide. The `UpdateService` was previously checking updates without exposing its loading state properly to the UI, leading to glitches. Also, ensuring that `finally { isCheckingUpdates.value = false; }` prevents permanent loading state locks.

**Action:** Created `UpdatesTabSkeleton` with a `ListView.builder` and `prototypeItem`. Integrated `UpdateService.isCheckingUpdates` `ValueNotifier` to properly switch between loading skeleton, empty state, and list data. Fixed missing `finally` cleanup block in `UpdateService.checkNow()`.
## 2026-08-01 - FlatpakAppListSkeleton List Virtualization Optimization

**Learning:** `ListView.builder` widgets inside Skeleton loading states should always include a `prototypeItem` matching the dimensions of the skeleton items to ensure efficient scroll virtualization and avoid redundant layout calculations across the view port.

**Action:** Added `prototypeItem` to `FlatpakAppListSkeleton` in `FlutterUI/lib/features/explore/presentation/widgets/flatpak_app_list.dart` to optimize scroll layout overhead.

## 2026-08-02 - Store/Source Search Caching Optimization

**Learning:** Frequently navigating back and forth or switching tabs within store/source-specific views (like Flatpak or GitHub) triggers redundant, expensive daemon subprocess searches or external network API calls. Caching these queries under a short, 5-minute TTL inside `PackageRepository` eliminates this duplicate overhead, realizing instantaneous tab switching and page re-entry.

**Action:** Implemented a targeted `_sourceSearchCache` in `PackageRepository` for all `"source:"` prefixed queries with an LRU limit of 20. Leveraged a `forceRefresh` parameter to allow manual pull-to-refresh or retry actions to bypass the cache and successfully retrieve fresh data.

## 2026-08-05 - Extracted prototypeItem for Skeletons

**Learning:** Duplicating layout code between `prototypeItem` and `itemBuilder` in virtualized `ListView.builder` widgets is prone to layout drift (dimension mismatches causing virtualization jitter) and violates DRY principles.

**Action:** Extracted the skeleton widget structure into a local `skeletonItem` variable inside the `build()` method (or `_buildSkeletonResults()`) and assigned it to both properties across all skeleton lists (`AppsPageSkeleton`, `InstalledAppListSkeleton`, `UpdatesTabSkeleton`, `FlatpakAppListSkeleton`, `GitHubAppListSkeleton`, and `SearchResultsView`).

## 2026-08-03 - PackageRepository Singleton & App Details Cache

**Learning:** Direct instantiation of repositories (e.g. `PackageRepository()`) on every usage inside controllers, pages, or background services creates distinct instances, thereby entirely neutralizing any internal in-memory caching mechanisms. Refactoring the repository class into a factory singleton shares the internal cache state across all layers. Implementing a request deduplication (coalescing) map alongside in-memory details caching for `getAppDetails` with targeted invalidation on task completions drastically reduces network and IPC overhead during navigation.

**Action:** Refactored `PackageRepository` to a singleton pattern, added details in-memory cache and `_activeDetailsRequests` coalescing map, and hooked `clearDetailsCacheFor` to successful task completions in `TaskManager` and `TaskController`.

## 2026-08-06 - Category Lookup Memoization in Discovery and Empty Results

**Learning:** Invoking `CategoryService.getCategories(context)` directly inside `build()` re-instantiates list objects and re-evaluates localized strings on every frame or state rebuild. Caching the category list in `didChangeDependencies()` avoids these redundant allocations during search typing and animations.

**Action:** Refactored `DiscoveryContent` and `EmptyResults` to memoize category lookups in `didChangeDependencies()`.
