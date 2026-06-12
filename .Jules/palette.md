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
