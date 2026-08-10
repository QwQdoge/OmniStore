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
## 2024-08-01 - Standardize UI Transitions with SmoothSizeSwitcher

**Learning:** Replacing `AnimatedSwitcher` with `SmoothSizeSwitcher` for typical UI state transitions (like route loaders and dynamic button states) unifies the app's motion language and fixes potential layout jumping without redundant wrapper constraints.

**Action:** Replaced plain `AnimatedSwitcher` with `SmoothSizeSwitcher` in `OmnistoreApp` and `AISettingsSection`.

## 2024-09-12 - Exposing transitionBuilder in SmoothSizeSwitcher

**Learning:** `SmoothSizeSwitcher` can fully replace `AnimatedSwitcher` across the entire app if it exposes the `transitionBuilder` property. This allows for custom transitions (like `RotationTransition` or `ScaleTransition`) while maintaining the unified MD3 layout-sizing wrapper provided by `SmoothSizeSwitcher`.

**Action:** Updated `SmoothSizeSwitcher` to accept an optional `transitionBuilder` parameter (defaulting to `AnimatedSwitcher.defaultTransitionBuilder`). Replaced all remaining raw `AnimatedSwitcher` instances in `github_star_badge.dart`, `smooth_progress_bar.dart`, `hamburger_button.dart`, `adaptive_navigation_shell.dart`, and `search_page.dart` with `SmoothSizeSwitcher`.
## 2024-10-27 - Smooth layout transitions for Data-Driven Layouts

**Learning:** When substituting complex data objects that dynamically alter layout height (e.g., app variants or dependency lists), wrapping the internal layout structure (like a `Column`) with a `SmoothSizeSwitcher` and assigning a `ValueKey` based on a specific, identifying data property (e.g., `ValueKey(variant.source ?? default)`) ensures Flutter recognizes the data change and smoothly animates both the crossfade and resize transitions instead of creating an abrupt visual jump.

**Action:** Refactored `AppTechnicalDetails` to wrap its internal `Column` with `SmoothSizeSwitcher` and assigned `ValueKey(currentVariant?.source ?? 'default')` to the `Column`.

## 2024-11-20 - Granular vs. Coordinated Switchers

**Learning:** While adjacent sections that share the same state trigger (e.g., screenshots and technical details appearing simultaneously) should be coordinated in a single `SmoothSizeSwitcher`, unrelated sections with independent loading states (e.g., an 'About' section versus conditionally loaded 'Extra Details') must use separate, granular switchers. Wrapping an entire page body or unrelated blocks in one massive switcher causes jarring atomic jumps where static elements unnecessarily cross-fade.

**Action:** Refactored `AppMainContent` to split the massive `SmoothSizeSwitcher` into granular switchers for the 'About' section, and a coordinated block for 'Screenshots' and 'Technical Details'.
## 2024-11-21 - Smooth Loading Transitions for Interactive Buttons

**Learning:** When toggling a UI component between an interactive state (like an action button) and a loading state (like a `CircularProgressIndicator`), a raw widget swap causes abrupt visual jumps. Wrapping these conditional state changes in `SmoothSizeSwitcher` and assigning clear `ValueKey`s ensures that the opacity cross-fade and size animation occur concurrently, eliminating the jarring transition. Furthermore, when implementing custom switchers globally across different sections (like `auth_page`, `ai_config_page`, `welcome_ai_page`), always ensure the supporting utility files (`smooth_size_switcher.dart`) are correctly imported to avoid analyzer and build failures.

**Action:** Wrapped loading transitions in `auth_page.dart` (save button area), `welcome_ai_page.dart` (test connection button), and `ai_config_page.dart` (test connection button) with `SmoothSizeSwitcher`. Ensured correct widget extraction and imported `package:frontend/core/widgets/smooth_size_switcher.dart` in all modified files.

- **Loading Transitions in Buttons**: When toggling between a text/icon and a `CircularProgressIndicator` within a button, always wrap the conditional expression in a `SmoothSizeSwitcher` (or `AnimatedSwitcher` if `SmoothSizeSwitcher` is unavailable) and assign distinct `ValueKey`s (e.g., `ValueKey('loading')` and `ValueKey('idle')`) to each child. This eliminates abrupt layout jumps and allows for smooth opacity cross-fading and size animations.
## 2024-11-21 - Smooth Loading Transitions for Interactive Buttons

**Learning:** When toggling a UI component between an interactive state (like an action button) and a loading state (like a `CircularProgressIndicator`), a raw widget swap causes abrupt visual jumps. Wrapping these conditional state changes in `SmoothSizeSwitcher` and assigning clear `ValueKey`s ensures that the opacity cross-fade and size animation occur concurrently, eliminating the jarring transition. Furthermore, when implementing custom switchers globally across different sections (like `auth_page`, `ai_config_page`, `welcome_ai_page`), always ensure the supporting utility files (`smooth_size_switcher.dart`) are correctly imported to avoid analyzer and build failures.

**Action:** Wrapped loading transitions in `auth_page.dart` (save button area), `welcome_ai_page.dart` (test connection button), and `ai_config_page.dart` (test connection button) with `SmoothSizeSwitcher`. Ensured correct widget extraction and imported `package:frontend/core/widgets/smooth_size_switcher.dart` in all modified files.

- **Loading Transitions in Buttons**: When toggling between a text/icon and a `CircularProgressIndicator` within a button, always wrap the conditional expression in a `SmoothSizeSwitcher` (or `AnimatedSwitcher` if `SmoothSizeSwitcher` is unavailable) and assign distinct `ValueKey`s (e.g., `ValueKey('loading')` and `ValueKey('idle')`) to each child. This eliminates abrupt layout jumps and allows for smooth opacity cross-fading and size animations.
