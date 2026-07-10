## 2024-03-20 - Documentation and Localization Refinement

**Learning:** Hardcoded strings in navigation and sidebar components are easily overlooked but significantly impact internationalization. Unifying these early under `AppLocalizations` ensures a professional feel across all supported locales.

**Action:** Always check `main.dart` and top-level navigation components for hardcoded labels during UI audits.

**Learning:** `project_architecture.md` can drift quickly from the actual file structure. Maintaining this file is critical for agent onboarding and consistent development.

**Action:** Update `project_architecture.md` and `FlutterUI/ARCHITECTURE.md` whenever features move (e.g. under `lib/features/<name>/presentation/`). Keep `lib/data/` vs `python/` naming distinct in docs.

**Learning:** Empty search states are high-value real estate. Providing category quick-access and trending apps instead of a blank screen improves user engagement and discovery.

**Action:** Implement discovery shelves in `SearchPage` that leverage existing `BrowseController` data (like `recommendations['trending']`).

## 2024-03-22 - Extracting Oversized Dialog Widgets

**Learning:** Large monolithic files, especially in presentation layers (like `details_page.dart`), quickly become difficult to navigate and maintain when they contain numerous inline dialog builders.

**Action:** Extract inline dialog definitions (e.g., `showDialog(builder: (ctx) => AlertDialog(...))`) into their own `StatelessWidget` files within a `widgets/` subdirectory. This significantly cleans up the main UI class, makes the dialogs reusable across the app (like `TerminalDialog`), and makes unit testing the dialog components easier.

## 2024-03-22 - Extracting Action Dialog Widgets

**Learning:** Extracted action confirmation and AUR security warning dialogs from `details_page.dart` into a new `action_dialogs.dart` widget to reduce file size and simplify `details_page.dart` UI logic.

**Action:** Continue identifying oversized widgets and inline widget building logic, extracting them into dedicated component files where logical.

## 2024-03-22 - Extracted Dialog Implementation in Action Area

**Learning:** When extracting dialogs using `StatefulBuilder` out of a parent component (like `details_page.dart` into `ActionConfirmDialog`), the state returned by `Navigator.pop(context, result)` must be properly captured by the awaiting function (`_handleAction`). `showDialog` definition inline in the parent component can simply be replaced with the widget, removing large unreadable sections of code and leaving clean declarative logic.

**Action:** Replaced inline `AlertDialog` logic for confirm install/uninstall in `details_page.dart` with the already existing `ActionConfirmDialog` widget from `action_dialogs.dart`.
## 2024-05-24 - [Extract Widgets in AppDetailsPage]

Learning:
Extracting large UI building blocks into separate `StatelessWidget` classes significantly improves maintainability and readability of long files like `details_page.dart`. By passing down minimal state and callbacks, we can decouple the UI layout from the complex business logic residing in the `StatefulWidget`.

Action:
Extracted `AppDetailsHeader`, `AppDetailsActions`, `AppDependencySection`, `AppScreenshots`, and shared row components from `details_page.dart` into the `widgets` directory.

## 2026-06-13 - [Extract Widgets in DownloadPage]

Learning:
Extracting inline dialog definitions (`TerminalDialog`, `AIUpdateSummaryDialog`) and complex UI blocks (`TasksTab`, `UpdatesTab`) from monolithic presentation pages into their own `StatelessWidget` files in the `widgets/` subdirectory improves readability and maintainability.

Action:
Extracted `TerminalDialog`, `AIUpdateSummaryDialog`, `TasksTab`, and `UpdatesTab` from `download_page.dart` into the `lib/features/task_manager/presentation/widgets/` directory. Passed down minimal callbacks (e.g. `onUpdateStarted`) to handle state interactions cleanly.
## 2024-05-18 - Settings Page Widget Extraction

Learning:
Oversized Flutter UI files that try to manage multiple disparate state domains (AI settings, sources list, storage cleaning progress dialogs) become very difficult to read. By pulling discrete functional blocks into their own 'Stateless' or local 'Stateful' widgets and passing down only what's necessary (like the SettingsController), the main page file is reduced significantly in length, complexity and git-conflict surface.

Action:
Extracted `SourcesConfigCard`, `StorageCleanupCard`, and `AISettingsSection` out of `settings_page.dart` into the `widgets/` subdirectory to drastically improve readability and separation of concerns.
## 2026-06-15 - Extract Widgets in SearchPage

**Learning:** Extracting large inline UI building blocks into separate `StatelessWidget` and `StatefulWidget` classes significantly improves maintainability and readability of long files like `search_page.dart`. This decoupling makes the core page class focus on search state rather than UI composition, and the extracted widgets can be reused or modified more easily in isolation.

**Action:** Extracted `SearchResultTile`, `DiscoveryContent`, and `EmptyResults` from `search_page.dart` into the `lib/features/explore/presentation/widgets/` directory. Passed down minimal state and callbacks.
## 2024-06-16 - Extract Widgets in AdaptiveNavigationShell

**Learning:** Extracted oversized private UI components (e.g., `_DesktopTopBar`, `_TaskProgressBar`, `_HamburgerButton`, `_DownloadAction`, `_RailBottomActions`) from `adaptive_navigation_shell.dart` into cleanly segregated files within `lib/core/layout/widgets/`. This decouples the UI composition logic of the adaptive layout, making the main file significantly shorter, easier to read, and less prone to merge conflicts during navigation-related updates.

**Action:** Continue to break down complex layout shells that attempt to define all their platform-specific UI fragments inline. Move these fragments into dedicated `StatelessWidget` files in a `widgets/` subdirectory, passing down necessary state via simple callbacks or reading it directly via Provider/Selector if appropriate.
## 2026-06-17 - Extract Widgets in GitHubStorePage\n\n**Learning:** Extracted oversized and repetitive list view and skeleton UI components ( and ) from `github_store_page.dart` into a clean  widget within . This decouples the UI composition and significantly simplifies the main file. Ensuring exact preservation of edge cases (like custom empty states in search) is critical when extracting generalized widgets.\n\n**Action:** Replaced inline list building logic with the extracted  and  components, passing down minimal necessary state and callbacks, and supporting customizable empty state visualizations.
## 2026-06-17 - Extract Widgets in GitHubStorePage

**Learning:** Extracted oversized and repetitive list view and skeleton UI components (`_buildAppListView` and `_buildSkeletonList`) from `github_store_page.dart` into a clean `GitHubAppList` widget within `lib/features/explore/presentation/widgets/`. This decouples the UI composition and significantly simplifies the main file. Ensuring exact preservation of edge cases (like custom empty states in search) is critical when extracting generalized widgets.

**Action:** Replaced inline list building logic with the extracted `GitHubAppList` and `GitHubAppListSkeleton` components, passing down minimal necessary state and callbacks, and supporting customizable empty state visualizations.
## 2026-06-20 - Extract Widgets in HomePage

**Learning:** `home_page.dart` contained a large inline `_buildCategoryShelf` function for rendering horizontal lists of apps. Extracting this UI component out into its own `StatelessWidget` improves maintainability, readability, and modularity of the `HomePage` logic.

**Action:** Extracted the `_buildCategoryShelf` logic from `FlutterUI/lib/features/home/home_page.dart` into a new `AppShelf` widget located at `FlutterUI/lib/features/home/widgets/app_shelf.dart`. Replaced its usages in `HomePage` with the new standalone widget.
- Extracted duplicated loading text indicators consisting of a column of Skeletons into a reusable ParagraphSkeleton widget (FlutterUI/lib/core/widgets/skeleton.dart) to adhere to DRY principles and improve maintainability.
## 2026-06-25 - Extract InstalledAppListSkeleton in DownloadPage

**Learning:** Extracting inline skeleton UI components (like `_buildSkeletonList`) into dedicated `StatelessWidget` files reduces the size and complexity of main presentation pages (like `download_page.dart`). Passing the key to the root widget ensures animations (like `AnimatedSwitcher`) continue to work correctly.

**Action:** Extracted `_buildSkeletonList` from `download_page.dart` into `installed_app_list_skeleton.dart` within the `widgets/` subdirectory.
## 2024-06-26 - Extract Widgets in DownloadPage, HomePage, and AppsPage

**Learning:** Oversized presentation files containing complex logic and multiple inline widgets hurt readability and maintainability. In particular, `download_page.dart`, `home_page.dart`, and `apps_page.dart` had monolithic internal widget builders that made the file structures hard to parse and increased the risk of git conflicts.

**Action:**
- Extracted `_buildInstalledTab` from `download_page.dart` into `installed_tab.dart`.
- Extracted `_buildHeroSection`, `_buildCategoryQuickAccess`, `_buildAIPickSkeleton`, `_buildAIPickSection`, and `_buildSectionHeader` from `home_page.dart` into dedicated stateless widgets in `FlutterUI/lib/features/home/widgets/`.
- Extracted `_buildSkeletonList` and `_buildEmptyState` from `apps_page.dart` into `apps_page_skeleton.dart` and `apps_page_empty_state.dart` in `FlutterUI/lib/features/apps/widgets/`.
This drastically simplified the main page builds while ensuring exact behavioral preservation and better code localization.

## 2024-05-24 - Extract ImportPackagesDialog in HomePage
**Learning:** Extracting inline dialogs into standalone widgets improves code structure, but it is easy to miss related cleanup or accidentally break compilation when removing builder methods (`_buildHeroSection`, `_buildAIPickSkeleton`, etc.) without updating their usages.

**Action:** Extracted the inline package import confirmation `AlertDialog` from `home_page.dart` into a new `ImportPackagesDialog` widget located in `FlutterUI/lib/features/home/widgets/import_packages_dialog.dart`.
## 2026-06-30 - [Extract Widgets in AppDetailsPage]

Learning:
Extracting large UI building blocks into separate `StatelessWidget` classes significantly improves maintainability and readability of long files like `details_page.dart`. By passing down minimal state and callbacks, we can decouple the UI layout from the complex business logic residing in the `StatefulWidget`.

Action:
Extracted `AppAboutSection` and `AppTechnicalDetails` from `details_page.dart` into the `widgets` directory, replacing the inline builders in `_buildMainContent`.

## 2026-07-02 - Extract Widgets in SearchPage

**Learning:** Oversized presentation files containing complex logic and multiple inline widgets hurt readability and maintainability. `search_page.dart` had monolithic internal widget builders (`_buildSourceFilters`, `_buildSkeletonResults`, `_buildResults`) that made the file structures hard to parse and increased the risk of git conflicts.

**Action:**
- Extracted `_buildSourceFilters` from `search_page.dart` into a new `SearchFilters` stateless widget located in `FlutterUI/lib/features/explore/presentation/widgets/search_filters.dart`.
- Extracted `_buildSkeletonResults` and `_buildResults` into a new `SearchResultsView` stateless widget in `FlutterUI/lib/features/explore/presentation/widgets/search_results_view.dart`.
This drastically simplified the main page builds while ensuring exact behavioral preservation and better code localization.

* Applied redundant state guard in `search_page.dart` to prevent unnecessary rebuilds of discovery content.
* Extracted duplicated fetching logic in `github_store_page.dart` into a generic `_fetchCategory` helper method to improve maintainability.
* Extracted the oversized premium header widget in `github_store_page.dart` into a standalone `_GitHubStoreHeader` widget to improve readability.
- Extracted large inline settings sections from `SettingsPage` into `GeneralSettingsCard`, `UpdateSettingsCard`, and `TypographySettingsCard` widgets.
- This modularization reduces `SettingsPage.dart` file size and complexity, significantly improving maintainability without altering existing app behavior.
## 2026-07-06 - Extract Widgets in FlatpakStorePage

**Learning:** Extracting oversized and complex UI state logic (like `_isLoading`, `_apps` handling with `RefreshIndicator` and `AnimatedSwitcher`) from the monolithic `FlatpakStorePage` into a dedicated `FlatpakAppList` stateless widget improves maintainability, mirrors the structure of `GitHubStorePage`, and simplifies the main page.

**Action:** Extracted `buildListContent` and `_buildSkeletonList` into `FlatpakAppList` and `FlatpakAppListSkeleton` located in `FlutterUI/lib/features/explore/presentation/widgets/flatpak_app_list.dart`. Updated `FlatpakStorePage` to consume this widget, passing necessary state via callbacks.
## 2026-07-06 - Fixing RefreshIndicator regression

**Learning:** When passing down callbacks that are meant to be used by `RefreshIndicator.onRefresh`, the typed function must be a `Future<void> Function()` rather than a simple `VoidCallback` (which resolves immediately as it's synchronous), otherwise the visual loading indicator spin will instantly disappear without waiting for the task to finish.

**Action:** Adjusted `FlatpakAppList.onRetry` to be `Future<void> Function()` so `RefreshIndicator` properly awaits the refresh network request. Also reverted unneeded file changes to unrelated settings files that would have caused unresolved imports.
## 2024-03-24 - Extract Widgets in CategoryPage

**Learning:** Extracted the private `_CategoryCard` widget from `category_page.dart` into its own dedicated file (`category_card.dart`) as `CategoryCard` to improve maintainability and decouple UI logic.

**Action:** Moved `_CategoryCard` logic into `lib/features/explore/presentation/widgets/category_card.dart`, preserving its behavior while updating necessary file imports to ensure cleaner dependency isolation.
