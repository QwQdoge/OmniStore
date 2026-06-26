## 2026-06-27 - Technical Metadata Grouping and MD3 Interaction

**Learning:** Grouping technical metadata (Version, Source, License, etc.) into a single `Card` with `surfaceContainerLow` significantly improves scan-ability and visual hierarchy on details pages compared to a flat list. Using a standardized `AppCard` wrapper for interactive tiles across the app (Home, Search) ensures consistent Material 3 hover/tap feedback (1.0 to 0.98 scale) and simplifies state layer management.

**Action:** Standardize metadata grouping in `AppDetailsPage` and replace standard `Card`/`ListTile` combinations with `AppCard` + `Semantics` for all primary app entry points to maintain MD3 consistency and accessibility.

## 2026-06-25 - Task Progress and Accessibility Refinement

**Learning:** Subtle, integrated progress indicators (like a `LinearProgressIndicator` at the bottom of a surface container) feel more part of the OS/shell than abrupt circular spinners. `AnimatedSize` combined with `AnimatedSwitcher` is a powerful pattern for handling the appearance of layout-altering elements like task bars without causing jarring shifts.

**Action:** Always wrap shell-level status bars in layout animations. Use `Semantics` with descriptive prefixes (e.g., 'Category: ') for interactive tiles to provide better context than raw labels for screen reader users.

## 2026-06-25 - MD3 Standards

**Learning:** `ChipThemeData` and standard MD3 state layer alphas are essential for creating an authentic Material Design 3 experience across the app. Components like Chips require explicit theme alignment (e.g. 12dp border radius, 0.4 alpha outline variant) for consistency, while state layers like hover, focus, and splash need explicitly configured alphas (0.08, 0.12, 0.1 respectively) for visual feedback consistency.

**Action:** Standardize these elements at the shell level in `OmnistoreTheme` to ensure global consistency without requiring inline overriding across widget trees.

## 2026-06-09 - SnackBar Consistency and Layout Resiliency

**Learning:** `SnackBarBehavior.floating` should not be hardcoded onto individual instances. Doing so causes fragmentation across the app's error handling and messaging layers. Furthermore, `RenderFlex` overflows in localized information rows can be mitigated by ensuring labels (and not just values) are correctly wrapped in `Flexible` or `Expanded` constraints.
**Action:** Enforce `SnackBarThemeData(behavior: SnackBarBehavior.floating)` globally in `OmnistoreTheme`. Ensure long localized keys inside structured `Row` layouts use `Flexible` to allow truncation or wrapping instead of clipping.

## 2026-06-26 - Horizontal Scroll Discoverability and MD3 Token Alignment

**Learning:** Horizontal scrolling lists on desktop and web lack discoverability if they don't have visible scrollbars. In MD3, using `Scrollbar` with `thumbVisibility: true` and a dedicated `ScrollController` is the standard for improving mouse-based navigation. Additionally, aligning container radii to MD3 tokens (e.g., 28dp for Extra Large, 16dp for Medium/Cards) ensures visual consistency and prevents artifacts during Hero transitions.

**Action:** Wrap all horizontal `ListView` and `SingleChildScrollView` widgets in a `Scrollbar` with `thumbVisibility: true`. Use a `Map<String, ScrollController>` to manage dynamic shelf controllers. Standardize radii to 16dp for cards/icons and 28dp for large hero banners.

## 2026-06-13 - Metadata Grouping and Visual Hierarchy

**Learning:** Wrapping technical metadata in a specialized surface container like `AppCard` with `surfaceContainerLow` color and zero elevation significantly improves the visual hierarchy of detail pages. It separates descriptive content from technical specifications without adding visual noise. Standardizing border radii to MD3 medium tokens (16dp) across cards and their placeholders (Skeletons) ensures a polished, cohesive look.

**Action:** Prefer grouping flat lists of key-value technical data into `AppCard` components to establish clear content boundaries. Ensure Skeletons match the parent's border radius exactly.
## 2026-06-28 - Strict Accessibility Semantics

**Learning:** `IconButton` elements, especially those integrated deeply within complex layouts like detail headers, need explicit `Semantics` wrappers. Relying on default semantic properties can lead to insufficient context for screen reader users.

**Action:** Ensure all interactive elements, particularly icon-only buttons like the 'Copy' button in app details, are wrapped in a `Semantics` widget with `button: true` and a localized, descriptive `label`.


## 2026-06-17 - AppCard Standardization and Surface Interactivity

**Learning:** Decoupling interactivity (InkWell) and motion (ScaleTransition) from the core surface definition (Card) within a reusable widget like `AppCard` ensures that non-interactive surfaces don't carry unnecessary widget overhead or visual state (hover/splash). Standardizing on Material 3 surface container tokens (`surfaceContainerLow`) and explicit border radii (16dp/28dp) creates a rhythmic, predictable UI.

**Action:** Ensure all primary entry points (Discovery, Banners, Search Results) use `AppCard` with localized `Semantics` to unify the app's interactive language.

## 2026-06-18 - Standardize Settings Grouping with AppCard

**Learning:** Grouping settings into specialized containers with MD3 layout features significantly improves hierarchy. Relying strictly on `Card` defaults does not convey MD3 principles sufficiently, thus wrapping such specialized components like `StorageCleanupCard` and `SourcesConfigCard` with `AppCard` paired with `Semantics` achieves UI consistency and accessibility effectively.

**Action:** Refactored `StorageCleanupCard` and `SourcesConfigCard` to leverage `AppCard`. Removed legacy shape overrides and ensured correct `explicitChildNodes` mapping within `Semantics` wrapper to align with core MD3 app tokens.

## 2026-06-20 - Task Progress Layout Consistency

**Learning:** `AnimatedSize` combined with `AnimatedSwitcher` is a powerful pattern for handling the appearance of layout-altering elements like task bars without causing jarring shifts. Using this around conditionally rendered sections like the active task block and task history lists prevents sudden jumps in the UI.

**Action:** Applied `AnimatedSize` and `AnimatedSwitcher` wrappers to the active task and history blocks in `FlutterUI/lib/features/task_manager/presentation/widgets/tasks_tab.dart`.

## 2026-06-26 - Standardized Border Radii and MD3 Dialog Tokens

**Learning:** Standardizing border radii across the application creates a more cohesive and professional feel. In this MD3 environment, 16dp is the standard for cards and list items (Medium token), while 28dp is reserved for large surfaces like Dialogs and Hero icons (Extra Large token). Internal elements (like 40x40 icons inside 16dp cards) benefit from a slightly smaller 12dp radius to maintain visual rhythm. Category-related elements consistently use 24dp for distinctiveness.

**Action:** Enforce 16dp for AppCard defaults, 28dp for Dialog shapes and their headers, and 24dp for Category-related chips or cards. Ensure skeletons match these radii exactly to prevent flickering during state transitions.
