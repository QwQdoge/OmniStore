## 🎨 Palette: UI / UX Refinement - MD3 Dropdown Standardization

### What
- Standardized `DropdownButton` components to align with Material Design 3 guidelines as outlined in `.Jules/palette.md`.
- Removed deprecated `DropdownButtonFormField` references in `welcome_ai_page.dart` (where externally-controlled `value` state updates dynamically, avoiding `initialValue` validation warnings) by transitioning to a styled `Container` + `DropdownButton`.
- Safely resolved severe Git merge conflict markers in `add_source_dialog.dart`, preserving the existing `Container` MD3 layout while adopting the `add_link_rounded` primary icon from the upstream main branch.

### Coverage
- `FlutterUI/lib/features/settings/presentation/widgets/add_source_dialog.dart`
- `FlutterUI/lib/features/onboarding/widgets/welcome_ai_page.dart`

### Result
- Eliminated Flutter compilation errors and deprecation warnings related to `value` assignment on FormFields.
- Re-established an uncorrupted widget tree without conflict markers.
- Maintained a polished UI with 12dp rounded dropdown boundaries, subtle `outlineVariant` styling, and MD3 surface contrast.
