# Conductor Agent Journal

## Motion Polish: Eliminating Layout Jumps

When using `AnimatedSwitcher` to transition between widgets of different sizes (e.g., swapping a fixed-height loading skeleton for dynamically sized text or lists), Flutter's layout will immediately jump to the new widget's intrinsic size before the cross-fade animation completes. This causes an abrupt, jarring visual transition.

To fix this and maintain smooth, implicit motion, we can wrap the `AnimatedSwitcher` in an `AnimatedSize` widget. This ensures both the opacity cross-fade and the layout height transition occur concurrently and smoothly.

### Actions Taken
Wrapped the following `AnimatedSwitcher` instances in `AnimatedSize` using standard MD3 transition curves (`Curves.easeOutCubic`) and appropriate alignments:

1.  **`AppAboutSection`**: Transitioning from a loading `ParagraphSkeleton` to loaded `MarkdownBody`. Set alignment to `Alignment.topLeft`.
2.  **`AppMainContent`**: Transitioning the `AppTechnicalDetails` block when extra asynchronous details are loaded. Set alignment to `Alignment.topCenter`.
3.  **`AIAppResolver`**: Transitioning from a 32dp `Skeleton`, an empty state, and a horizontal 100dp `ListView`. Set alignment to `Alignment.topCenter`.
4.  **`AppDetailsActions`**: Transitioning between the static Install/Uninstall buttons and the dynamic `SmoothProgressBar` active task widget. Set alignment to `Alignment.topCenter`.
5.  **`AIUpdateSummaryDialog`**: Transitioning from a loading state to a variable-height AI response `MarkdownBody`. Set alignment to `Alignment.topLeft`.
6.  **`AppDetailsHeader`**: Transitioning the version selector height when asynchronous version data is loaded. Set alignment to `Alignment.topLeft`.

These changes preserve responsiveness, apply subtle MD3 motion, and strictly eliminate layout jumps. In `AppMainContent`, I also consolidated the "Details" section into a single `AnimatedSize` block to ensure the title and content animate together.

7.  **`HomePage`**: Transitioning the `featured`, AI `_aiPickBlurb`, `trending`, and `for_you` sections from an empty `SizedBox.shrink()` when loaded asynchronously. Set alignments to `Alignment.topCenter`.
8.  **`DiscoveryContent`**: Transitioning the dynamically loaded `trending` shelf. Set alignment to `Alignment.topCenter`.
9.  **`GitHubStoreTabs`**: Transitioning between search results and the GitHub specific tabs header. Set alignment to `Alignment.topCenter`.
10. **`StorageCleanupCard`**: Transitioning between the static height loading `Skeleton` layout and the dynamic stats readout. Set alignment to `Alignment.topLeft`.
