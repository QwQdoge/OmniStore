
## 2026-06-15 - MediaQuery Rebuild Optimization

**Learning:** Using `MediaQuery.of(context).size.width` triggers a rebuild of the entire widget whenever ANY property of `MediaQueryData` changes (e.g., keyboard visibility, system theme). Using `MediaQuery.sizeOf(context).width` (available in Flutter 3.10+) ensures the widget only rebuilds when the size specifically changes.

**Action:** Replaced `MediaQuery.of(context).size.width` with `MediaQuery.sizeOf(context).width` in `flatpak_store_page.dart` and `search_page.dart`.
