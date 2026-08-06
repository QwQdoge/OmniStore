# PR Description

### 💡 What
This pull request refactors and polishes `AddSourceDialog` and `AITestResultDialog` in the Settings configuration feature to bring them fully up to Material Design 3 (MD3) design, motion, and visual standards.

Key layout refinements implemented:
* **`AddSourceDialog`**:
  - Leverages the native `icon` slot of `AlertDialog` with `Icons.add_link_rounded` in the primary theme color.
  - Aligns title typography with `theme.textTheme.headlineSmall` and an expressive bold weight of `FontWeight.w800`.
  - Upgrades inputs (`DropdownButtonFormField` and `TextField`) to use a polished `OutlineInputBorder` (with custom 12dp rounded corners) and comfortable content padding.
  - Customized dropdown icon with standard soft `Icons.keyboard_arrow_down_rounded`.
  - Added anti-aliased clipping on the dialog boundary to prevent inner element bleeding.

* **`AITestResultDialog`**:
  - Migrated the icon directly into the native dialog `icon` slot, dynamically selecting check/error styles based on testing success.
  - Applies identical standard `w800` headline styling.
  - Groups complex dynamic messages inside a defined, zero-elevation `Card` styled with Material 3 tokens (`surfaceContainerLow` background, a 12dp border radius, and a subtle border with `outlineVariant` at 0.3 opacity).
  - Placed the card inside a `SingleChildScrollView` container to fully eliminate any potential layout or scroll overflow issues for large payloads.

### 🎯 Why
The custom source and AI connection test feedback dialogs previously used flat, legacy layouts without defined input borders, modern MD3 shapes, or clear contrast boundaries. These improvements ensure the user experience is highly tactile, intuitive, and consistent with other Material Design 3 refined surfaces across the OmniStore ecosystem.

### ♿ Accessibility
* Form fields inside `AddSourceDialog` now feature comfortable tap targets and extremely readable placeholder hints.
* Feedback results in `AITestResultDialog` use high-contrast text and are fully selectable via `SelectableText` for easier copying or debug assistance.
* Status icon colors utilize standard theme primary/error colors to maintain accessible contrast relative to their surfaces.

### 📱 MD3 Alignment
* Replaced manual, sharp widgets with standardized MD3 geometric tokens (12dp small container/input curves and native tonal elevation styling).
* Organized technical response information into defined, low-elevation surface containers (`surfaceContainerLow`), providing clear physical boundaries without heavy shadows or borders.
