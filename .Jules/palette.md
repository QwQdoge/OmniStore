## 2025-05-15 - Immersive Media Viewer & MD3 Selection

**Learning:** Users benefit from being able to inspect app screenshots in detail, especially on desktop where UI details matter. Combining `Hero` transitions with `InteractiveViewer` in a full-screen dialog provides a high-quality, frictionless experience.

**Action:** Prefer `Hero` + `InteractiveViewer` for media-heavy pages.

**Learning:** `SegmentedButton` is superior to `DropdownButton` for source selection when the number of options is small (2-4). It provides immediate visibility and is more consistent with MD3's emphasis on horizontal containers.

**Action:** Use `SegmentedButton` for explicit, mutually exclusive choices. Wrap in `SingleChildScrollView` to prevent overflow on smaller widths.

**Learning:** UI consistency across different pages (HomePage, SearchPage, DetailsPage) is critical for "felt quality". Using shared background tokens like `surfaceContainerHigh` for labels improves visual hierarchy.

**Action:** Standardize small UI elements like tags and labels across all screens early in the design phase.
