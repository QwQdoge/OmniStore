## 2026-08-20 - Material Design 3 EmptyState Container Badges and Semantics

**Learning:** Empty states in Material Design 3 benefit from housing illustrative icons inside explicit tonal surface container badges (`surfaceContainerHigh` circular container decorated with a subtle `outlineVariant` border and `primary` icon color) rather than unanchored low-contrast raw icons. Furthermore, wrapping the empty state title and subtitle in a single `Semantics` wrapper with `excludeSemantics: true` consolidates screen reader output into a single cohesive announcement (`$title. $subtitle`), avoiding fragmented or duplicated text readings.

**Action:** Standardize shared empty states with MD3 `surfaceContainerHigh` badge containers, high contrast `onSurface` title text, and consolidated `Semantics(excludeSemantics: true, label: ...)` wrappers.




## 2026-08-18 - Clean Up Redundant IconButton Semantics Wrappers

**Learning:** `IconButton` and `IconButton.filledTonal` widgets natively manage their accessibility properties through their `tooltip` and `isSelected` parameters in Flutter. Wrapping native `IconButton` instances in a redundant `Semantics(button: true, label: ...)` wrapper creates duplicate accessibility nodes in screen-reader trees and bloats widget layout hierarchies.

**Action:** Remove redundant `Semantics` wrappers around native `IconButton` widgets across layout bars and settings cards (`desktop_top_bar`, `download_action`, `rail_bottom_actions`, `adaptive_navigation_shell`, `storage_cleanup_card`, `sources_config_card`), relying directly on `IconButton.tooltip` and `isSelected`.

## 2026-08-17 - Material Design 3 Auth & Account Form Polish

**Learning:** Designing auth and account pages in MD3 requires framing form elements inside `surfaceContainerLow` elevation containers with 20dp border radii and clean subtle outline borders. Text fields should use 12dp `OutlineInputBorder` shapes with comfortable vertical padding, explicit hover/focused states, and intuitive tooltips on password visibility toggle buttons. Adding `SmoothSizeSwitcher` around button progress indicators avoids abrupt size jumps during loading state toggles.

**Action:** Standardize account profile and authentication forms by using Card containers with `surfaceContainerLow`, 12dp rounded `OutlineInputBorder`s, localized ARB strings, and `SmoothSizeSwitcher` transitions around loading states.

## 2026-08-08 - Dropdown Form Field Nesting and MD3 Input Hierarchy

**Learning:** Nesting standard `DropdownButton` elements inside the `child` parameter of a `DropdownButtonFormField` is an invalid configuration that causes layout errors and static compiler analysis failures. Under Material Design 3 guidelines, dropdown forms must define configuration properties (`items`, `onChanged`, and `value`) directly on the `DropdownButtonFormField` to ensure unified visual style, keyboard accessibility, and correct form validation behaviors.

**Action:** When creating form-based dropdown inputs, always supply `items` and `onChanged` directly to `DropdownButtonFormField` rather than nesting a hidden/legacy `DropdownButton` inside it.

## 2026-08-06 - Material Design 3 Dialog Input and Feedback Polish

**Learning:** Aligning custom form-based and feedback dialogs (such as `AddSourceDialog` and `AITestResultDialog`) with Material Design 3 guidelines requires using the native `icon` and `title` properties of `AlertDialog` for correct hierarchy and vertical stack pacing. TextFields and Dropdowns within form dialogs must be configured with consistent geometric parameters (e.g., 12dp rounded OutlineInputBorder and proper symmetric content padding) to guarantee focus accessibility and visual consistency. Wrapping transient feedback or diagnostic console messages in a zero-elevation `Card` utilizing `surfaceContainerLow` and a clean monospace font ensures the content is highly scan-able and comfortable to inspect on high-density displays.

**Action:** Update custom alert and input dialogs to leverage native `AlertDialog.icon` instead of inline title headers, style fields with custom 12dp `OutlineInputBorder` borders and symmetric padding, and structure diagnostic details inside zero-elevation `Card` containers using the `surfaceContainerLow` token and `monospace` fonts.

## 2026-07-28 - Full-Screen ImageViewer and Gallery Polish

**Learning:** Standardizing interactive full-screen screenshot viewers by adding a backdrop `GestureDetector` with `HitTestBehavior.opaque` enables comfortable single-tap dismissal anywhere on the screen (reducing visual search friction for dismiss actions). Accompanying this with native `MaterialLocalizations.of(context).closeButtonTooltip` on the close button ensures native accessibility. In horizontal galleries, wrapping preview cards in a `Tooltip` and `Semantics` widget using a localized index label (e.g., `"${AppLocalizations.of(context)!.screenshots} ${index + 1}/${screenshots.length}"`) provides robust hover discovery and screen-reader context.

**Action:** Wrap full-screen media/screenshot viewers with a full-screen backdrop `GestureDetector(behavior: HitTestBehavior.opaque, onTap: ...)` to enable fluid tap-to-dismiss behavior. Ensure close/action buttons use pre-localized localizations when possible, and wrap gallery items in localized `Tooltip` and `Semantics` wrappers.

## 2026-07-27 - Clipboard Copy SnackBar Duration Standardization

**Learning:** Clipboard copy confirmation SnackBars are highly repetitive, lightweight background confirmations rather than critical system errors or action prompts. Retaining the framework default 4-second duration for such transient UI feedback leads to visual crowding and delayed dismissed states when multiple text fields are copied in rapid succession. Standardizing clipboard copy feedback SnackBars globally to `const Duration(seconds: 2)` makes the UI feel significantly snappier and aligns with lightweight Material Design 3 transient notification timing patterns.

**Action:** Ensure all SnackBars used for copy-to-clipboard actions (such as copying package names, command lines, or metadata values) explicitly set their `duration` to `const Duration(seconds: 2)` instead of defaulting to 4 seconds.

## 2026-07-26 - Material Design 3 Dialog Extraction and Refinement

**Learning:** Keeping large, complex dialog structures as inline code inside stateful pages/controllers bloats the file size, reduces readability, and violates clean separation of concerns. Furthermore, hardcoding user-facing strings within these inline builders breaks internationalization. Extracting these structures to dedicated, self-contained widgets (like `InstallationDecisionDialog` in `action_dialogs.dart`) paired with robust `AppLocalizations` support ensures consistent localization across languages. Utilizing Material 3 design features—such as 28dp rounded corners, w800 headline typography, clean semantic lists with icons, and contextual color-coded containers (like errorContainer for risks)—dramatically elevates overall interaction clarity and accessibility.

**Action:** Extract oversized inline dialog builders into standalone `StatelessWidget`s in cohesive widget modules. Enforce complete localization, avoid inline hardcoded text, and design complex warning panels using explicit MD3 geometric and semantic color-scheme tokens.

## 2026-07-25 - Async FutureBuilder Layout Animations

**Learning:** Wrapping a `FutureBuilder` inside an `AnimatedSize` when its builder returns an `AnimatedSwitcher` prevents correct layout size change detection because the `FutureBuilder` widget's key and type remain constant across states. Scoping layout animation widgets (like `SmoothSizeSwitcher` or standard `AnimatedSize` + `AnimatedSwitcher`) *inside* the `FutureBuilder` builder function allows the subtree state changes to be animated smoothly as they switch between loading/skeleton states and the loaded content, while aligning with Material Design 3 motion pacing.

**Action:** Never wrap `FutureBuilder` itself in a sizing layout animation. Always place layout switchers and sizing transitions (like `SmoothSizeSwitcher`) inside the builder method of `FutureBuilder` to ensure state transition animations trigger reliably.

## 2026-07-27 - MD3 Layout Resizing inside FutureBuilder

**Learning:** When intrinsic size changes are involved inside a `FutureBuilder` (for example, switching from a large skeleton loading state to the final UI or vice versa), wrapping the state check in a plain `AnimatedSwitcher` causes abrupt resizing because `AnimatedSwitcher` only animates the cross-fade, not the layout boundaries. Using `SmoothSizeSwitcher` (which encapsulates both `AnimatedSize` and `AnimatedSwitcher` with correct MD3 curves) inside the `FutureBuilder`'s builder method ensures fluid layout resizing that aligns with MD3 motion standards.

**Action:** Replace `AnimatedSwitcher` with `SmoothSizeSwitcher` inside the builder method of `FutureBuilder`s where the loading state and loaded state have differing intrinsic sizes (e.g., in `_AppDetailsRouteLoader`).

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

## 2026-06-25 - Standardized Geometry and Accessibility for MD3

**Learning:** Aligning container radii to MD3 specifications (16dp for Medium, 28dp for Large/Dialogs) and replacing hardcoded accent colors with semantic theme tokens (error, primary) ensures a cohesive, accessible experience. Adding `Tooltip` widgets to technical metadata rows improves the discoverability of interactive features like "tap to copy" on desktop. Standardizing vertical rhythm with consistent gaps (24dp) and dividers creates a predictable content flow.

**Action:** Update all dialogs to 28dp radius. Standardize all `AppCard` and `InkWell` radii to 16dp. Use `theme.colorScheme` for all status-related colors. Ensure `AppDetailsPage` follows a consistent vertical spacing pattern.

## 2026-07-16 - Home Page Vertical Rhythm and Accessibility

**Learning:** Standardizing vertical spacing between major sections (Featured, AI Pick, Categories, Trending) to a consistent 32dp gap ensures a unified visual rhythm and improves scannability. Using localized semantic labels (e.g., `categorySemantics`) for interactive chips provides a more accessible and professional experience than hardcoded strings.

**Action:** Standardize top margins of all main sections in `HomePage` to 32dp. Ensure all `Semantics` labels use localized ARB keys.

## 2026-06-29 - details_page Layout Redundancy

**Learning:** When using conditionally rendered blocks (like an `if` statement for screenshots) that appear sequentially between other sections, including leading AND trailing structural spacing widgets (`SizedBox`) inside the block can cause double-spacing when combined with the layout rules of the adjacent sections.

**Action:** Standardized the structural spacing in `details_page.dart` by ensuring only a single `SizedBox(height: 24)` separates any two major sections, preventing visual jumps caused by doubled 24dp gaps.

## 2026-06-29 - Global MD3 Animation Curves

**Learning:** To fully embrace Material Design 3 motion guidelines, it is not enough to just standardize transition durations. The correct easing curves must be applied to implicit transition widgets like `AnimatedSwitcher` to avoid linear, unnatural motion. The standard MD3 recommendation for entering elements is `Curves.easeOutCubic` and for exiting elements is `Curves.fastOutSlowIn`.

**Action:** Injected `switchInCurve: Curves.easeOutCubic` and `switchOutCurve: Curves.fastOutSlowIn` into all `AnimatedSwitcher` components app-wide to ensure uniform and authentic MD3 interaction clarity.

## 2026-07-02 - Settings UI Refinement and Standardized Headers

**Learning:** Duplicating private `_buildSection` methods for headers leads to inconsistent spacing and styling. Extracting a shared `SettingsSectionHeader` widget ensures that Material 3 typography (`labelLarge`, primary color, bold) is applied consistently with uniform 8dp vertical padding. Furthermore, adding proper easing curves (`Curves.easeOutCubic`, `Curves.fastOutSlowIn`) to `AnimatedSwitcher` transitions significantly improves the perceived quality of the UI when revealing advanced sections.

**Action:** Use `SettingsSectionHeader` for all settings category headers. Always pair `AnimatedSwitcher` with standard MD3 easing curves and maintain a consistent 24dp gap (`SizedBox`) between layout sections.

## 2026-07-04 - Standardized App Metadata Tags

**Learning:** App metadata (source, trust, installation status) was displayed inconsistently across different features (Search, Installed, Updates), using a mix of custom widgets, raw Chips, and plain text. This reduced visual harmony and brand recognition.

**Action:** Standardized metadata display using a refined `AppSourceTag` widget. Added `managed` mode for read-only status and improved MD3 tonal color mapping using `ColorScheme` tokens. Applied this consistently across `InstalledTab` and `UpdatesTab`, improving scannability and visual consistency.

## 2026-07-06 - Global MD3 Geometric Token Standardization

**Learning:** Standardizing geometric tokens (border radii) across the app to align with Material Design 3 (16dp for Medium/Cards, 28dp for Extra Large/Banners/Dialogs, 12dp for Small/Tags) creates a rhythmic, predictable UI. Using a centralized `AppCard` component instead of manual `Container` decorations for feature blocks (like AI Pick) ensures consistent surface feedback and reduces styling fragmentation.

**Action:** Update `AppCard` default to 16dp. Use 28dp for prominent featured sections and dialogs. Replace manual `Container` styling with `AppCard` in feature widgets. Apply symmetric horizontal padding (10dp on list, 10dp on items) in horizontal shelves to maintain accurate scroll virtualization and a consistent 20dp visual rhythm.

## 2026-07-07 - Conditional Layout Animation Refinement

**Learning:** When dynamically rendering optional sections of a layout (like app screenshots or detailed technical specs) using `AnimatedSwitcher`, varying intrinsic heights cause the parent layout to jump abruptly. This breaks the perceived fluidity of Material Design 3.
**Action:** Always wrap `AnimatedSwitcher` widgets inside `AnimatedSize` when the switched children can have significantly different vertical heights. Set an appropriate `alignment` (e.g., `Alignment.topLeft` or `Alignment.topCenter`) to ensure the transition expands in the correct visual direction rather than awkwardly resizing from the center.
## 2026-07-12 - Semantics wrappers vs Tooltips

**Learning:** `IconButton` widgets in Flutter automatically use their `tooltip` property as their semantic label and mark themselves as buttons in the accessibility tree. Unnecessarily wrapping them in `Semantics(button: true, label: ...)` is redundant and bloats the layout tree.

**Action:** Ensure `IconButton` components provide semantic meaning natively by always passing a localized string to their `tooltip` parameter, rather than wrapping them in custom `Semantics` widgets.

## 2026-07-15 - Semantics Wrappers and Global Button Themes

**Learning:** Unnecessarily wrapping native Material buttons (`IconButton`, `FilledButton`, `OutlinedButton`) in `Semantics(button: true, label: ...)` creates redundant nodes in the semantic tree and bloats layout hierarchy. Material widgets inherently manage their own accessibility traits via their `tooltip` or child labels. Furthermore, declaring inline `shape` styles (e.g., `RoundedRectangleBorder`) on individual buttons fragments the app's visual identity when a unified `OmnistoreTheme` is already enforcing MD3 guidelines globally.

**Action:** Removed redundant `Semantics` wrappers around `IconButton`, `FilledButton`, and `OutlinedButton` components, relying on their native implementations (via `tooltip`). Cleaned up duplicated inline `shape` styling across action buttons in `AppDetailsActions`, falling back to the centralized `OmnistoreTheme` button geometry defaults (14dp radius).

## 2026-07-20 - Global SnackBar Duration Standardization

**Learning:** When multiple actions invoke informational `SnackBar` components without a specified `duration`, they fall back to the framework default (which can be overlapping or jarring if rapid). Explicitly setting `duration: const Duration(seconds: 4)` universally across the app creates a consistent, predictable pacing for informational interactions. However, when performing sweeping refactors to enforce this, extreme care must be taken to not mistakenly modify the `duration` parameters of nested or adjacent animation widgets (like `AnimatedSize` or `AnimatedSwitcher`), which typically use milliseconds (e.g., 300ms) rather than seconds.

**Action:** Standardized all informational `SnackBar` widgets across `home_page`, `settings`, `explore`, and `task_manager` to explicitly use a 4-second duration, ensuring overlapping messages are paced correctly and the user interaction loop feels unified.
## 2026-07-22 - Task Progress Layout Consistency

**Learning:** Abruptly inserting or removing layout blocks like active tasks or task histories creates visual jarring in a scroll view. Wrapping conditional blocks in `SmoothSizeSwitcher` is an effective pattern to provide organic transition fluidity consistent with MD3 principles without causing layout shifts.

**Action:** Applied `SmoothSizeSwitcher` wrappers around conditionally rendered active task and task history blocks in `TasksTab` (FlutterUI/lib/features/task_manager/presentation/widgets/tasks_tab.dart).

## 2026-07-24 - Typography and Accessibility Polish

**Learning:** Maintaining strict adherence to MD3 typographic scales (using `FontWeight.w800` instead of `w900` for expressive headers/labels) ensures visual harmony across components like `AppSourceTag` and `TaskProgressBar`. Additionally, dynamic action lists (like the category chips in `EmptyResults`) must consistently apply localized ARB semantic labels (via `categorySemantics`) to maintain screen reader accessibility parity with primary navigation elements.

**Action:** Standardized font weights to `w800` in `app_source_tag.dart` and `task_progress_bar.dart`. Wrapped category `ActionChip`s in `empty_results.dart` with localized `Semantics` labels.

## 2026-07-28 - Custom Dialogs MD3 Polish

**Learning:** Custom alert dialogs (such as ActionConfirmDialog and ImportPackagesDialog) must align with Material Design 3 guidelines to establish unified product consistency. Applying w800 headline typography, pairing dialogs with highly semantic leading icons (e.g. primary for downloads/imports, error for uninstall/warning prompts), and wrapping option structures (such as checkbox tiles) or details (such as preflight risks and suggestions) inside custom cards with explicit radii (16dp) and color-scheme context tokens (like errorContainer and primaryContainer) drastically increases readable visual flow and screen-reader context.

**Action:** Standardize all dialog titles with w800 headline styles and semantic MD3 icons. Wrap warning elements in errorContainer cards, recommended pathways in primaryContainer cards, and nested list tiles in surfaceContainerLow cards to preserve vertical rhythm.
## 2026-07-29 - Coordinated Layout Animations
Learning: When conditionally displaying multiple adjacent sections of a layout that may change intrinsic height simultaneously (e.g., screenshots and technical details), wrap the entire combined block (including structural titles and spacing) in a single SmoothSizeSwitcher. Avoid using separate switchers for each section to prevent uncoordinated transitions and statically hanging UI elements.
Action: Replaced multiple nested SmoothSizeSwitchers with a single SmoothSizeSwitcher in AppMainContent.

## 2026-07-29 - Material Design 3 Onboarding Wizards

**Learning:** When creating multi-step onboarding wizard screens in desktop-adapted Flutter applications, constraining the center width to 650px ensures comfortable visual scan-ability. Furthermore, integrating live environment check procedures (via Python backend execution) and streaming live setup bootstrap console logs directly into a specialized, zero-elevation card (featuring `surfaceContainerLow` decoration and 16dp rounded corners) builds outstanding visual trust and interaction clarity compared to static, plain-text mock pages.

**Action:** Standardize multi-page adaptive onboarding flows inside a center-constrained layout (650px max width), utilizing Card-wrapped Form fields, interactive bootstrap terminals, and live connection verification checks.

## 2026-07-29 - Semantics Wrappers and Dialog Corner Clipping

**Learning:** `IconButton` elements inherently provide semantic meaning to screen readers through their `tooltip` property. Unnecessarily wrapping them in `Semantics(button: true, label: ...)` in dialog headers (like `TerminalDialog`) creates redundant nodes in the semantic tree and bloats the layout hierarchy. Furthermore, when creating a custom `Dialog` containing child containers with rounded corners (like top header containers), it is crucial to apply `clipBehavior: Clip.antiAlias` to the `Dialog` itself to prevent the inner container's corners from bleeding over the dialogue's MD3 bounds.

**Action:** Removed redundant `Semantics` wrappers around native action buttons like `IconButton` in `TerminalDialog`. Enforced `clipBehavior: Clip.antiAlias` on custom dialog roots containing clipped sub-containers to ensure visual harmony with Material Design 3 guidelines.

## 2026-07-30 - Standardized Multi-Language HomePage Localization

**Learning:** Relying on hardcoded strings within primary screens and layout sections degrades user experience, breaks internationalization across varied desktop environments, and leads to inconsistent multi-language visual presentation. Standardizing empty messages, section headers, and error or fallback strings using Flutter's `AppLocalizations` system combined with robust synchronization scripts ensures seamless UI consistency for native Simplified Chinese, Traditional Chinese, Japanese, and Spanish users alike, fully satisfying Material Design 3 and global accessibility expectations.

**Action:** Extract all hardcoded Chinese UI strings and empty state descriptions on major page views (like `HomePage` and AI Recommendation blocks) into standard `.arb` resource keys, and run localized generation scripts (`sync_l10n.py` and `flutter gen-l10n`) to provide native internationalization.

## 2026-07-31 - Redundant Semantics Wrappers Clean Up

**Learning:** Unnecessarily wrapping native Material buttons (`IconButton`, `FilledButton`, `OutlinedButton`) in `Semantics(button: true, label: ...)` creates redundant nodes in the semantic tree and bloats layout hierarchy. Material widgets inherently manage their own accessibility traits via their `tooltip` or child labels.

**Action:** Cleaned up redundant `Semantics` wrappers specifically around `IconButton` components across navigation bars, dialog headers, settings cards, and layout widgets. Relied purely on `tooltip` property to provide semantic labeling.

## 2026-08-05 - Material Design 3 Inline Dropdowns

**Learning:** To align legacy inline DropdownButton widgets with Material Design 3 guidelines (such as trailing elements in ListTiles), wrap the DropdownButton with DropdownButtonHideUnderline inside a Container styled with MD3 tokens (e.g., color `theme.colorScheme.surfaceContainerHigh`, 12dp rounded corners, and a subtle border using `theme.colorScheme.outlineVariant` at 0.5 opacity). Override the standard dropdown icon with `Icons.keyboard_arrow_down_rounded` for softer, native-feeling MD3 transitions.

**Action:** Standardize the visual styling of Settings and Configuration inline DropdownButtons globally by wrapping them in matching M3 styled container boundaries and using soft keyboard arrow down icons to improve click targets, affordance, and visual harmony.

## 2026-08-06 - Material Design 3 Dialog Input & Result Polish

**Learning:** AlertDialog elements must adhere strictly to Material Design 3 geometry and typography. By utilizing native dialog components like `icon` paired with high-quality theme colors, styling titles with `theme.textTheme.headlineSmall` and `w800` weight, and enforcing `clipBehavior: Clip.antiAlias` on the dialog, the dialog structure becomes incredibly cohesive. To polish inputs (like DropdownButtonFormField or TextFields), use explicit 12dp rounded `OutlineInputBorder`s with comfortable content padding. When presenting dynamic message payloads (such as debug console outputs or API test descriptions), wrapping text in a themed Card (`surfaceContainerLow`, 12dp border radius, with outlineVariant border) nested in `SingleChildScrollView` prevents jarring layout overflows and keeps the focus entirely on content accessibility.

**Action:** Refactor all configuration and informational dialogs to leverage native AlertDialog `icon` slots, robust `w800` typography, custom `OutlineInputBorder`s for text/dropdown fields, and structured content Cards to avoid layout overflows.
## 2026-08-07 - Material Design 3 Standard Dialog Refinements

**Learning:** Across the OmniStore UI layer, numerous legacy `AlertDialog`s were utilizing manually nested `Row`s in the `title` attribute to display icons, coupled with unconstrained `Text` body contents that could potentially render-overflow. Conforming accurately to Material Design 3 dictates explicitly utilizing the `AlertDialog`'s native `icon` parameter, assigning `textAlign: TextAlign.center` alongside `w800` typography on the `title` element, and safely encapsulating lengthy instructional content inside scrollable `Card` boundaries (`elevation: 0`, `surfaceContainerLow` coloring, 12dp rounded borders). Furthermore, transitioning standard dialog cancellation paths from legacy `TextButton` to MD3 `FilledButton.tonal` enhances visual interactability without overshadowing primary primary `FilledButton` commitments.

**Action:** Upgraded legacy dialog widgets (e.g. `ActionConfirmDialog`, `AIUpdateSummaryDialog`, `ApiKeyInstructionsDialog`, `AIMarkdownDialog`, `ImportPackagesDialog`) globally to inject native `icon` properties, properly center-align header `w800` typography, securely enclose dense text blocks in MD3 surface cards bound within `SingleChildScrollView`s, and swapped weak text dismissal actions for clear `FilledButton.tonal` interactions.

## 2026-08-08 - Material Design 3 Dialog Title Alignment

**Learning:** When aligning custom form-based and feedback dialogs (such as `AITestResultDialog`) with Material Design 3 guidelines, it is important to explicitly set `textAlign: TextAlign.center` on the `AlertDialog` title in addition to assigning the `w800` font weight and `headlineSmall` text style to guarantee proper centering, especially when icons are used.

**Action:** Standardized custom dialog titles to explicitly include `textAlign: TextAlign.center` where native Material 3 dialog icons are used.
