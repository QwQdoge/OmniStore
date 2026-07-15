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

These changes preserve responsiveness, apply subtle MD3 motion, and strictly eliminate layout jumps.
## Motion Polish: Eliminating UI Layout Jumps

Added `AnimatedSize` wrappers to multiple `AnimatedSwitcher` usages across the app (in `home_page.dart`, `discovery_content.dart`, `search_results_view.dart`, `flatpak_store_page.dart`, `github_store_page.dart`, and `installed_tab.dart`). This effectively eliminates abrupt layout jumps when transitioning between UI states of varying sizes, such as empty states and fully populated item lists. Alignments were set according to the content (e.g. `Alignment.topCenter` for lists). Standard MD3 transitions curves were applied.

## Motion Polish: Fixing Remaining AnimatedSwitcher Layout Jumps
In continuation of previous work, identified and wrapped several remaining `AnimatedSwitcher` instances across the app with `AnimatedSize` to strictly prevent layout jumps. Specifically, this was applied to:
- `AppsPage` (list/empty states)
- `TasksTab` and `UpdatesTab` (content blocks)
- `FlatpakAppList` and `GitHubAppList` (state transitions)
- `StorageCleanupCard` (loading vs loaded data)
- `GitHubStoreTabs` (search vs tab layout)
- `DownloadPage` (checking updates indicator)
These wrappers were configured with `Curves.easeOutCubic` for duration and layout transitions, and used alignment specific to the UI context (e.g., `Alignment.topCenter` for lists and `Alignment.topLeft` for settings rows) to maintain consistent MD3 motion patterns across the app.
