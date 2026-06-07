## 2026-06-25 - Task Progress and Accessibility Refinement

**Learning:** Subtle, integrated progress indicators (like a `LinearProgressIndicator` at the bottom of a surface container) feel more part of the OS/shell than abrupt circular spinners. `AnimatedSize` combined with `AnimatedSwitcher` is a powerful pattern for handling the appearance of layout-altering elements like task bars without causing jarring shifts.

**Action:** Always wrap shell-level status bars in layout animations. Use `Semantics` with descriptive prefixes (e.g., 'Category: ') for interactive tiles to provide better context than raw labels for screen reader users.
