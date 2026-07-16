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

## 2024-07-23 - Smooth Layout Transitions for Discovery Mode and Search Tiles
**Learning:** When dynamically hiding/showing major sections like Discovery Mode or specific active task states within a search list, utilizing an `AnimatedSwitcher` alone causes layout jumps to the intrinsic heights of children.
**Action:** Wrapped the `_showDiscovery` ternary switch in `search_page.dart` and the task active state switch in `search_result_tile.dart` with `AnimatedSize` (using MD3 curve `Curves.easeOutCubic`, 300ms, and top/center alignments). This prevents layout jarring and maintains smooth implicit animations globally.
**Update (Correction):**
**Learning:** Wrapping an `Expanded` child with `AnimatedSize` when the size should be completely flexible (e.g. `Expanded` -> `AnimatedSize` -> `AnimatedSwitcher`) makes no sense and negates the animation because `Expanded` forces a tight fit.
**Action:** Replaced the `AnimatedSize` with just `AnimatedSwitcher` around the `_showDiscovery` ternary in `search_page.dart` so cross-fading occurs appropriately. The inner `AnimatedSwitcher` was removed to let the outer one handle the transition between Discovery mode and Search mode.
