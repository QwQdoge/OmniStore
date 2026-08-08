# 🎨 Palette: Standardize Custom Dialogs and Inputs for Material Design 3

## 💡 What
Refined and standardized the layout, geometry, typography, and visual feedback of the custom dialogs in the application to fully align with Material Design 3 guidelines:
1. **AddSourceDialog (`add_source_dialog.dart`)**:
   - Upgraded to leverage the native `icon` parameter in `AlertDialog` with `Icons.add_link_rounded`, tinted with primary theme coloring.
   - Set the title style to use expressive `theme.textTheme.headlineSmall` with `FontWeight.w800` (Extra Bold).
   - Structured and modernized form inputs (`DropdownButtonFormField` and `TextField`s) with a cohesive `OutlineInputBorder` (12dp radius), custom symmetric content padding, and standard outline styling.
   - Refined the dropdown arrow icon to use `Icons.keyboard_arrow_down_rounded` for softer transitions.
2. **AITestResultDialog (`ai_test_result_dialog.dart`)**:
   - Replaced hardcoded `Colors.green` and `Colors.red` with standard semantic theme tokens (`colorScheme.primary` and `colorScheme.error`).
   - Standardized layout by utilizing native `AlertDialog.icon` with rounded check/error symbols.
   - Set title typography to `FontWeight.w800`.
   - Wrapped diagnostic/console test messages inside a zero-elevation `Card` utilizing `colorScheme.surfaceContainerLow` decoration, a 16dp rounded corner radius, and an elegant monospace font style.

## 🎯 Why
* **Legacy UI Contrast**: Dialog title structures were previously flat and inconsistent. The AI Test Result Dialog relied on raw text alignment and hardcoded, non-adaptive colors which failed to respect user color seeds/themes.
* **Input Alignment**: Input fields inside dialog forms lacked modern Material 3 geometry (12dp corners) and structured spacing, reducing interaction discoverability and click-target comfortable spacing.

## ♿ Accessibility
* **Semantic Structure**: Provides clean and distinct hierarchy with leading semantic icons, ensuring screen readers receive immediate context about the purpose of the dialog (info vs error vs addition).
* **Affordance & Usability**: Improved tap/click target safety with consistent input height boundaries and generous, standard-aligned inner padding. Monospace rendering on command/API output prevents text strain on wide paragraphs.

## 📱 MD3 Alignment
* Leverages proper surface container tokens (`surfaceContainerLow` for message details cards).
* Follows precise dialogue geometry standards: native `AlertDialog` properties (icon/title stack), 28dp overall dialogue shape tokens, and 12dp/16dp corner tokens for elements within the dialog.

## 📊 Coverage
- Ran `flutter analyze` successfully with zero new analyzer issues.
- Ran `flutter test test/widget_test.dart` successfully with all checks passing.
