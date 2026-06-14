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
