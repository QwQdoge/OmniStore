# Conductor Agent Journal

## Motion Polish: Eliminating Layout Jumps

When using `AnimatedSwitcher` to transition between widgets of different sizes (e.g., swapping a fixed-height loading skeleton for dynamically sized text or lists), Flutter's layout will immediately jump to the new widget's intrinsic size before the cross-fade animation completes. This causes an abrupt, jarring visual transition.

To fix this and maintain smooth, implicit motion, we can wrap the `AnimatedSwitcher` in an `AnimatedSize` widget. This ensures both the opacity cross-fade and the layout height transition occur concurrently and smoothly.

### Actions Taken
Wrapped the following `AnimatedSwitcher` instances in `AnimatedSize` using standard MD3 transition curves (`Curves.easeOutCubic`) and appropriate alignments:

1.  **`AppAboutSection`**: Transitioning from a loading `ParagraphSkeleton` to loaded `MarkdownBody`. Set alignment to `Alignment.topLeft`.
2.  **`AppMainContent`**: Consolidated multiple `AnimatedSize` wrappers into a single block that handles "About", "Screenshots", and "Details" sections as a unified unit. Set alignment to `Alignment.topLeft`.
3.  **`AIAppResolver`**: Transitioning from a 32dp `Skeleton`, an empty state, and a horizontal 100dp `ListView`. Set alignment to `Alignment.topCenter`.
4.  **`AppDetailsActions`**: Transitioning between the static Install/Uninstall buttons and the dynamic `SmoothProgressBar` active task widget. Updated alignment to `Alignment.topLeft` for consistency.
5.  **`AIUpdateSummaryDialog`**: Transitioning from a loading state to a variable-height AI response `MarkdownBody`. Set alignment to `Alignment.topLeft`.
6.  **`AppDetailsHeader`**: Transitioning the version selector height when asynchronous version data is loaded. Also added an `AnimatedSwitcher` to the app icon for smooth placeholder-to-image transitions. Set alignment to `Alignment.topLeft`.

These changes preserve responsiveness, apply subtle MD3 motion, and strictly eliminate layout jumps. In `AppMainContent`, I also consolidated the "Details" section into a single `AnimatedSize` block to ensure the title and content animate together.
7.  **`HomePage`**: Transitioning asynchronous sections (Featured, AI Pick, Trending, For You) between empty/loading states and populated states. Set alignment to `Alignment.topCenter`.

## 2026-07-20 - Standardized Layout Transitions with SmoothSizeSwitcher

**Learning:** Combining `AnimatedSize` and `AnimatedSwitcher` into a single reusable `SmoothSizeSwitcher` component simplifies UI code and ensures that all layout transitions across the app adhere to identical MD3-compliant easing curves (`Curves.easeOutCubic`, `Curves.fastOutSlowIn`) and timing (300ms). Granular application of these switchers to individual conditionally-loaded sections (like Screenshots) prevents massive atomic jumps that occur when a single large switcher is used for an entire page body.

**Action:** Created `SmoothSizeSwitcher` in `lib/core/widgets`. Refactored `AppMainContent` to use granular switchers for About, Screenshots, and Technical Details. Standardized `AppDetailsActions` and `AppDetailsHeader` to use the same component, eliminating boilerplate and unifying the app's motion language.
## 2024-07-20 - Refactored AnimatedSwitcher usage to SmoothSizeSwitcher

**Learning:** When animating state changes of a `FutureBuilder` using `SmoothSizeSwitcher` (or `AnimatedSwitcher`), place the switcher inside the `FutureBuilder`'s builder function. Wrapping the `FutureBuilder` itself prevents state change detection because the widget type and key remain constant, breaking the animation transitions.

**Action:** Refactored `ai_dialogs.dart`, `search_result_tile.dart`, and `github_star_badge.dart` to properly use `SmoothSizeSwitcher` internally for smoother layout transitions.
## 2024-08-01 - Avoid nesting AnimatedSwitcher in SmoothSizeSwitcher

**Learning:** Since `SmoothSizeSwitcher` encapsulates both `AnimatedSize` and `AnimatedSwitcher`, nesting another `AnimatedSwitcher` inside it is redundant and adds unnecessary layout overhead. We should apply `SmoothSizeSwitcher` directly to the conditional children, even for small constrained components like `AppDetailsHeader` icon, for cleaner and more performant motion transitions.

**Action:** Refactored `AppDetailsHeader` to use `SmoothSizeSwitcher` instead of manual `AnimatedSwitcher`. Removed redundant nested `AnimatedSwitcher` widgets from `HomePage` sections and `DownloadPage`.
