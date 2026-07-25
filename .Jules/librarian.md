## 2026-06-14 - State Management: Scoping Rebuilds for High-Frequency Updates

**Learning:** Watching providers that update frequently (like `TaskController` emitting download progress logs and percentages) at the root level of a page or navigation shell causes excessive and expensive widget rebuilds. This leads to UI jank and poor performance, particularly with complex nested widgets like `AdaptiveNavigationShell` and `AppDetailsPage`.

**Action:**
- Instead of using `context.watch<TaskController>()` at the top of a `build` method, state ownership and reactivity must be localized.
- Wrap only the precise UI components that require the data (e.g., progress bars, terminal badges, status icons) inside a `Consumer<TaskController>`.
- Always check top-level structural components (like navigation shells or scaffold bodies) for misplaced `.watch()` calls that could trigger full subtree rebuilds on minor state changes.

## 2026-06-14 - State Management: Proper Use of `context.watch` vs `Selector`

**Learning:**
Using `context.watch<T>()` at the root of a `build` method in structural widgets (like `AdaptiveNavigationShell` or `AppDetailsPage`) forces the entire widget tree to rebuild whenever any property in the watched controller changes. This leads to performance regressions, even with supposedly low-frequency controllers like `SettingsController`.
Furthermore, automated scripts (like global `sed` replacements) are highly dangerous for refactoring Python code, as they easily break block indentation and introduce critical `SyntaxError`s, especially when dealing with merge conflict resolutions.

**Action:**
- Replaced `context.watch<SettingsController>()` with `context.read<SettingsController>()` at the top level of `build` methods where only static reads or action callbacks are needed.
- Wrapped specific UI components that *do* need to react to state changes in `Selector<SettingsController, T>` (e.g., extracting `settings.isRailExpanded` or `settings.isAIEnabled`). This scopes the reactivity down to only the necessary child widgets, preventing full page rebuilds.
- Avoided using `sed` or ad-hoc Bash scripts to resolve complex Python merge conflicts. Used manual diff/patch application or checked out specific file versions to ensure syntactic integrity.

## 2026-06-14 - State Management: Scoping `NavigationController` and `SettingsController` Rebuilds

**Learning:**
Calling `context.watch<T>()` at the top level of the `build` method in core UI structures (like `OmnistoreApp`, `AdaptiveNavigationShell`, `MainNavigationEntry`) causes the entire widget subtree to rebuild on any state change. Additionally, replacing `context.watch<T>()` with `context.read<T>()` synchronously inside the `build` method to assign a local variable is forbidden by the Provider contract and will cause a crash.

**Action:**
- Localized `SettingsController` updates in `OmnistoreApp` and `SettingsPage` by wrapping sub-components in `Consumer<SettingsController>`.
- Migrated usage of `SettingsController` properties (like `isAIEnabled`, `useSystemTitleBar`) and `NavigationController` (`selectedIndex`) to use `context.select<T, R>` in `AppDetailsPage`, `WindowTitleBar`, and navigation layout files.
- Ensured `context.read<T>()` is only used inside action callbacks (like `onTap`) rather than directly in the `build()` tree.

## 2026-06-14 - State Management: Optimizing Task Updates

**Learning:**
Similar to navigation and settings controllers, using `context.watch<TaskController>()` at the top level of high-traffic or dynamic widgets (like `TasksTab` or items within `search_page.dart`) causes unacceptable rebuild spam whenever a task progress tick occurs.

**Action:**
- Extracted boolean/structural checks into targeted `context.select<TaskController, bool>((tc) => ...)` statements.
- Confined high-frequency reads (progress, status strings, download speeds) exclusively to small inner `Consumer<TaskController>` widgets to surgically update just the relevant text or progress bar UI without dirtying the parent element.

## 2026-06-15 - State Management: Proper Use of `context.read` in Widget Lifecycle

**Learning:** Calling `context.read<T>()` directly inside a `build()` method violates Provider contracts and causes errors in newer Provider versions. Additionally, instantiating Futures directly inside `build()` (e.g., for a `FutureBuilder`) causes the Future to re-execute every time the widget rebuilds, leading to redundant API calls and janky UI.

**Action:**
- Moved `context.read<PackageRepository>()` in `UpdatesTab` out of the `build()` method and directly into the async `onTap` callback where it is actually needed.
- Refactored `AIUpdateSummaryDialog` from a `StatelessWidget` to a `StatefulWidget`. Retrieved `context.read<AIRepository>()` inside `initState()` and cached the resulting Future to ensure it is only executed once, significantly improving efficiency and safety.
## 2026-06-16 - State Management: Scoping Future Instantiations for Dialogs

**Learning:** Instantiating `Future` objects directly inside the `builder` callback of methods like `showDialog` (e.g., `future: context.read<AIRepository>().aiExplain(...)`) causes the `Future` to re-execute unnecessarily if the dialog's `Builder` is rebuilt by the framework (e.g., during window resizes, keyboard toggles, or theme changes). This leads to redundant network requests and unintended state duplication.

**Action:**
- Refactored `_showAIExplainDialog`, `_showAICompareDialog`, `_showAICliDialog`, and `_showAIConflictDialog` in `details_page.dart` to instantiate their respective `Future` variables *before* invoking `showDialog`.
- Refactored `_showAIErrorAnalysis` in `terminal_dialog.dart` similarly, ensuring `context.read<AIRepository>()` is evaluated and the `Future` is cached locally before the dialog is built.
## 2026-06-16 - State Management: Scoping Future Instantiations for Routes

**Learning:** Instantiating `Future` objects directly inside the `builder` callback of route structures like `MaterialPageRoute` (e.g., `future: PackageRepository().getAppDetails(...)`) causes the `Future` to re-execute unnecessarily if the route transitions or the navigation tree is rebuilt by the framework. This violates async lifecycle clarity and triggers redundant API calls that can stutter navigation transitions.

**Action:**
- Refactored `onGenerateRoute` in `omnistore_app.dart` to extract the `FutureBuilder` logic for `AppDetailsPage` into a dedicated `StatefulWidget` (`_AppDetailsRouteLoader`).
- Ensured `context.read<PackageRepository>().getAppDetails` is evaluated and the `Future` is cached locally within the `initState()` of the new widget before the view is constructed, isolating network requests from Flutter's rebuild cycle.
## 2026-06-17 - State Management: Scoping Rebuilds for High-Frequency Updates (TaskController)

**Learning:** Watching or consuming providers that update frequently at a high tick rate (like `TaskController` emitting download progress and log events) causes excessive UI rebuilds. Using `List.unmodifiable` dynamically inside getters triggers O(N) allocation on every property access, which breaks `Selector` equality checks, resulting in false-positive redraws even when the data hasn't conceptually changed.

**Action:**
- Replaced dynamic `List.unmodifiable` instantiations in `TaskController` with cached `UnmodifiableListView` fields. This ensures consistent memory references for immutable view exposure, fixing the O(N) penalty and fixing equality checks.
- Migrated broad `Consumer<TaskController>` implementations to precise `Selector<TaskController, T>` widgets using Dart Records (e.g., `({double? progress, String status})`) across all relevant presentation files (`tasks_tab.dart`, `terminal_dialog.dart`, `task_progress_bar.dart`, `app_details_actions.dart`, `search_result_tile.dart`, `download_page.dart`).
- This restricts widget rebuilds exactly to the specific fields they depend on (like showing terminal logs only when logs are not empty, or updating an individual app card only if its own `progress` changes).
## 2026-06-18 - State Management: Deep Collection Equality for Selectors

**Learning:** When using `Selector` in Provider, returning a collection (like a `Map` or `List`) inside the `selector` parameter requires careful consideration of equality. Using `jsonEncode` inside the `selector` to force deep equality string comparisons is a major anti-pattern, as it triggers expensive JSON parsing every time `notifyListeners` is called, leading to performance degradation and potential crashes if the object contains non-encodable types.

**Action:**
- Replaced dangerous `jsonEncode` logic inside `Selector<SettingsController, String>` with a direct `Map` return type.
- Leveraged the `shouldRebuild` parameter combined with `mapEquals` from `package:flutter/foundation.dart` (or `DeepCollectionEquality().equals` from `package:collection`) to safely and performantly check for deep equality, ensuring the widget only rebuilds when the actual data inside the map changes.
## 2026-06-25 - State Management: Scoped Consumers for SettingsPage

**Learning:** Wrapping a large structural widget like `ListView` at the top of a page (e.g., `SettingsPage`) in a `Consumer<SettingsController>` violates the "rebuild ownership" rule. It forces the framework to redundantly recreate headers, layout spacers, and independent widgets (like `StorageCleanupCard` which manages its own state) on every minor settings tick.

**Action:**
- Removed the top-level `Consumer<SettingsController>` from `SettingsPage` to leave the `ListView` static.
- Wrapped only the exact `AppCard` elements (Primary Settings, Updates, Typography), `SourcesConfigCard`, and `AISettingsSection` that actually require `settings` dependencies in their own localized `Consumer<SettingsController>` blocks.
- This targeted approach effectively isolates the "blast radius" of state updates, ensuring smooth performance and adhering to the directive for minimal and specific rebuild targets.
## 2026-06-30 - State Management: Iterable Equality for List Selectors

**Learning:** When using `Selector` in Provider that returns a List or a Record containing a List, the default equality check fails because two different list instances with the same content are not considered equal (`[] == []` is false). This causes redundant widget rebuilds even when the list content hasn't changed.

**Action:**
- Added `shouldRebuild` parameter using `const IterableEquality().equals(prev, next)` to `Selector`s in `home_page.dart`, `discovery_content.dart`, `tasks_tab.dart`, and `terminal_dialog.dart` that return Lists of apps or logs.
- This ensures that widgets only rebuild when the actual content of the list changes, improving UI performance.

## Actions Taken
* Removed `context.watch<SettingsController>()` from `SourcesConfigCard` and `AISettingsSection` to fix performance issues ("rebuild ownership", "state duplication") where widgets would over-rebuild on unrelated changes.
* Replaced `context.watch` with localized `Selector` usage encapsulating the widgets directly in `sources_config_card.dart` and `ai_settings_section.dart`.
* Refactored `SettingsPage` to drop redundant outer `Selector`s and `AnimatedSwitcher` wrappers that didn't pass state correctly.
* Removed `context.watch` from `didChangeDependencies` inside `AISettingsSection` and merged `_syncControllers` safely inside its own `Selector` builder payload ("invalidation correctness").
## 2026-07-02 - State Management: Scoping Listeners for SearchPage

**Learning:** Using `Provider.of<T>(context)` (which defaults to `listen: true`) inside `didChangeDependencies` causes the entire widget to rebuild every time the provider notifies its listeners. This completely defeats the purpose of granular `Selector` and `Consumer` blocks used lower in the tree. In `SearchPage`, listening to `BrowseController` this way caused expensive full UI redraws on unrelated state changes (like download progress).

**Action:**
- Moved the listener attachment logic out of `didChangeDependencies` into `initState`.
- Used `context.read<BrowseController>()` to safely grab the provider instance without subscribing the entire page to its broadcast stream.
- Explicitly added the manual callback `_onBrowseChanged` which only executes targeted logic (auto-selecting the first result) without invalidating the whole widget.
## 2026-07-06 - State Management: Proper  typing\n\n**Learning:** Passing a  to  bypasses the wait functionality of the refresh indicator. The framework will drop the visual loading spinner instantly because it does not know to wait for the future. The callback should always be strongly typed as .\n\n**Action:**\n- Modified  to correct the  signature from  to , preserving async continuation semantics.
## 2026-07-06 - State Management: Proper `RefreshIndicator` typing

**Learning:** Passing a `VoidCallback` to `RefreshIndicator.onRefresh` bypasses the wait functionality of the refresh indicator. The framework will drop the visual loading spinner instantly because it does not know to wait for the future. The callback should always be strongly typed as `Future<void> Function()`.

**Action:**
- Modified `github_app_list.dart` to correct the `onRetry` signature from `VoidCallback` to `Future<void> Function()`, preserving async continuation semantics.
## [2026-07-13] - State Duplication Removal

**Issue:** Multiple widgets (, , , ) were caching the result of  in a  state variable during .

**Action Taken:** Removed  and the  state variable from these widgets. Updated the  method in each to call  directly, assigning the result to a local  variable.

**Action:**
- Removed `didChangeDependencies` overrides in `HomePage`, `EmptyResults`, `DiscoveryContent`, and `CategoryPage`.
- Refactored category evaluation to evaluate `final _categories = CategoryService.getCategories(context);` directly within the `build` method. This leverages Flutter's built-in reactivity and eliminates unnecessary state fields.
## 2026-07-15 - Memoize Category Service Calls

**Learning:** Calling services that generate objects based on `BuildContext` (like localizations or themes) directly inside the `build()` method causes unnecessary object re-allocation and garbage collection every time the widget calls `setState`.

**Action:** Moved `CategoryService.getCategories(context)` calls in high-visibility pages (`HomePage`, `DiscoveryContent`, `CategoryPage`, `EmptyResults`) to `didChangeDependencies()`. This ensures the category list is only regenerated when the underlying `InheritedWidget` (like `AppLocalizations`) updates, optimizing local rebuilds without breaking reactivity.

## 2024-07-21 - [Async State Safety]

**Learning:** High-frequency controllers can trigger `notifyListeners()` after they have been unmounted during async operations, leading to crashes.

**Action:** Overrode `dispose()` and `notifyListeners()` to include a `_disposed` check for `NavigationController`, `BrowseController`, and `SettingsController` to ensure safe async state flow.
