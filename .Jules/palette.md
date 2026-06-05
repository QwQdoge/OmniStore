## 2025-05-15 - Immersive Media Viewer & MD3 Selection

**Learning:** Users benefit from being able to inspect app screenshots in detail, especially on desktop where UI details matter. Combining `Hero` transitions with `InteractiveViewer` in a full-screen dialog provides a high-quality, frictionless experience.

**Action:** Prefer `Hero` + `InteractiveViewer` for media-heavy pages.

**Learning:** `SegmentedButton` is superior to `DropdownButton` for source selection when the number of options is small (2-4). It provides immediate visibility and is more consistent with MD3's emphasis on horizontal containers.

**Action:** Use `SegmentedButton` for explicit, mutually exclusive choices. Wrap in `SingleChildScrollView` to prevent overflow on smaller widths.

**Learning:** UI consistency across different pages (HomePage, SearchPage, DetailsPage) is critical for "felt quality". Using shared background tokens like `surfaceContainerHigh` for labels improves visual hierarchy.

**Action:** Standardize small UI elements like tags and labels across all screens early in the design phase.

## 2026-06-01 - Unified Source Tags & UI Refinement

**Learning:** Unifying trust levels and source tags into a single  widget improves visual consistency and maintainability. Differentiating between "Installed" status and "Trust" level is crucial for user clarity.

**Action:** Use  for all package source/trust displays. Always display the "Ready" badge alongside the tag in details pages to avoid information loss.

**Learning:** Hardcoded colors and font sizes lead to inconsistency and theme breakage.

**Action:** Prefer  tokens (like ) and standardized typography styles (e.g., 26px w900 for section headers) across all pages.

## 2026-06-01 - Unified Source Tags & UI Refinement

**Learning:** Unifying trust levels and source tags into a single `AppSourceTag` widget improves visual consistency and maintainability. Differentiating between "Installed" status and "Trust" level is crucial for user clarity.

**Action:** Use `AppSourceTag` for all package source/trust displays. Always display the "Ready" badge alongside the tag in details pages to avoid information loss.

**Learning:** Hardcoded colors and font sizes lead to inconsistency and theme breakage.

**Action:** Prefer `theme.colorScheme` tokens (like `onSurfaceVariant`) and standardized typography styles (e.g., 26px w900 for section headers) across all pages.

## 2026-06-02 - Enhanced Search Discovery & Interaction

**Learning:** Search discovery can be significantly improved by preloading trending data and displaying it when the search field is empty, reducing "empty screen" fatigue on large viewports. Additionally, "No Results" states should never be dead ends; always provide alternatives like categories or AI-driven suggestions.

**Action:** Implement discovery shelves in empty states and ensure that input logic (like clear buttons) remains responsive even when the main results view hasn't triggered yet.

## 2026-06-03 - Search Discovery & Empty State Resilience

**Learning:** "No Results" states should never be dead ends. By providing actionable alternatives like category chips, we keep users in the "flow" even when their specific query fails. Using `SingleChildScrollView` ensures this discovery content is accessible across different screen orientations.

**Action:** Always include alternative discovery paths (e.g., categories, trending) in empty search result states.

**Learning:** Consistency in "loud" UI elements (like section headers) requires a unified typography standard. Standardizing on 26px, w900, -1.0 spacing, and `primary` color ensures a modern, high-contrast look that feels native to the app's design language.

**Action:** Use the standardized headline style (26px, w900, -1.0 spacing) for all major section headers to maintain visual hierarchy.

## 2026-06-04 - Hero Tag Management & Immersive Banner UI

**Learning:** `Hero` tags must be unique within a single route. In complex pages like `HomePage` where an app might appear in multiple sections (Featured Banner vs. Trending Shelf), using simple tags like `'icon-${name}'` leads to runtime crashes.

**Action:** Use section-specific prefixes for Hero tags (e.g., `hero-banner-`, `app-shelf-`, `search-result-`) and pass these tags explicitly to the target page's constructor to ensure smooth, error-free transitions.

**Learning:** Featured sections benefit from immersive visuals. Using an app's screenshot as a background with a content-aware gradient overlay provides a more high-end feel than simple icon/text cards.

**Action:** For "Hero" or "Featured" cards, prefer large aspect ratios (e.g., width 440), high corner radii (24px), and background screenshots with bottom-aligned text on a dark gradient.

**Learning:** Duplicating complex `TextStyle` definitions for headers across multiple files makes theme updates difficult.

**Action:** Consolidate standardized typography into static methods in the theme class (e.g., `OmnistoreTheme.standardHeader(context)`) to ensure effortless consistency.

## 2026-06-05 - Refined Badge System & Header Responsiveness

**Learning:** Combining multiple metadata tags (Stars, Status, Source) in a `Row` is a common source of overflow on narrow viewports. Using a `Wrap` with consistent spacing ensures a graceful layout across all devices.

**Action:** Prefer `Wrap` for metadata clusters in page headers.

**Learning:** Unifying "Installed/Ready" status with existing source/trust tags into a single `AppSourceTag` widget reduces visual noise and ensures consistent styling (padding, radius, typography).

**Action:** Use a single polymorphic widget (like `AppSourceTag`) for all similar "badge" elements.

**Learning:** Accessibility isn't just about labels; it's also about providing context. Adding `Tooltip` and `Semantics` to small visual tags ensures they are useful for both mouse users and screen reader users.

**Action:** Always wrap small status tags in `Tooltip` and `Semantics`.
