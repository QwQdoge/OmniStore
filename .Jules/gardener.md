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
## 2024-10-24 - Extract Widgets in HomePage

**Learning:** Extracting large inline UI building blocks like banner cards into separate `StatelessWidget` files significantly improves maintainability and readability of long files like `home_page.dart`.

**Action:** Extracted the `_buildBannerCard` inline widget builder from `FlutterUI/lib/features/home/home_page.dart` into a reusable `BannerCard` stateless widget (`FlutterUI/lib/features/home/widgets/banner_card.dart`) to clean up complex logic, reduce file size, and improve readability without altering behavior.
