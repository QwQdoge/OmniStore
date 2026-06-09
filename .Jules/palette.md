## 2026-06-25 - Task Progress and Accessibility Refinement

**Learning:** Subtle, integrated progress indicators (like a `LinearProgressIndicator` at the bottom of a surface container) feel more part of the OS/shell than abrupt circular spinners. `AnimatedSize` combined with `AnimatedSwitcher` is a powerful pattern for handling the appearance of layout-altering elements like task bars without causing jarring shifts.

**Action:** Always wrap shell-level status bars in layout animations. Use `Semantics` with descriptive prefixes (e.g., 'Category: ') for interactive tiles to provide better context than raw labels for screen reader users.

## 2026-06-25 - MD3 Standards

**Learning:** `ChipThemeData` and standard MD3 state layer alphas are essential for creating an authentic Material Design 3 experience across the app. Components like Chips require explicit theme alignment (e.g. 12dp border radius, 0.4 alpha outline variant) for consistency, while state layers like hover, focus, and splash need explicitly configured alphas (0.08, 0.12, 0.1 respectively) for visual feedback consistency.

**Action:** Standardize these elements at the shell level in `OmnistoreTheme` to ensure global consistency without requiring inline overriding across widget trees.

## 2026-06-09 - SnackBar Consistency and Layout Resiliency

**Learning:** `SnackBarBehavior.floating` should not be hardcoded onto individual instances. Doing so causes fragmentation across the app's error handling and messaging layers. Furthermore, `RenderFlex` overflows in localized information rows can be mitigated by ensuring labels (and not just values) are correctly wrapped in `Flexible` or `Expanded` constraints.
**Action:** Enforce `SnackBarThemeData(behavior: SnackBarBehavior.floating)` globally in `OmnistoreTheme`. Ensure long localized keys inside structured `Row` layouts use `Flexible` to allow truncation or wrapping instead of clipping.
