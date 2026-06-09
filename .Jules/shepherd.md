## 2026-06-08 - Global SnackBar Consistency
- Added global `SnackBarThemeData` to `omnistore_theme.dart` with `behavior: SnackBarBehavior.floating`.
- Removed hardcoded `SnackBarBehavior.floating` from individual `SnackBar` instantiations to ensure consistent floating behavior across the entire app.

## 2026-06-09 - Global SnackBar Consistency Update
- Re-verified implementation of global `SnackBarThemeData` in `omnistore_theme.dart` with `behavior: SnackBarBehavior.floating`.
- Removed newly introduced hardcoded `behavior: SnackBarBehavior.floating` from `FlutterUI/lib/features/explore/presentation/pages/details_page.dart` (copy item SnackBar).
