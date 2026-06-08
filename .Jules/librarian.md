## 2024-05-24 - State Management: Scoping Rebuilds for High-Frequency Updates

**Learning:** Watching providers that update frequently (like `TaskController` emitting download progress logs and percentages) at the root level of a page or navigation shell causes excessive and expensive widget rebuilds. This leads to UI jank and poor performance, particularly with complex nested widgets like `AdaptiveNavigationShell` and `AppDetailsPage`.

**Action:**
- Instead of using `context.watch<TaskController>()` at the top of a `build` method, state ownership and reactivity must be localized.
- Wrap only the precise UI components that require the data (e.g., progress bars, terminal badges, status icons) inside a `Consumer<TaskController>`.
- Always check top-level structural components (like navigation shells or scaffold bodies) for misplaced `.watch()` calls that could trigger full subtree rebuilds on minor state changes.
