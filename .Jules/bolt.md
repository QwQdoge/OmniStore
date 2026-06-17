
## 2026-06-15 - MediaQuery Rebuild Optimization

**Learning:** Using `MediaQuery.of(context).size.width` triggers a rebuild of the entire widget whenever ANY property of `MediaQueryData` changes (e.g., keyboard visibility, system theme). Using `MediaQuery.sizeOf(context).width` (available in Flutter 3.10+) ensures the widget only rebuilds when the size specifically changes.

**Action:** Replaced `MediaQuery.of(context).size.width` with `MediaQuery.sizeOf(context).width` in `flatpak_store_page.dart` and `search_page.dart`.

## 2026-06-16 - Search Selection & AppCard Optimization

**Learning:** Managing selection state in a monolithic page using `setState` causes the entire list to rebuild, which is expensive for large datasets. Offloading selection to a `ChangeNotifier` and using `context.select` in list items isolates rebuilds. Additionally, `AppCard` animations can be skipped for non-interactive items by checking for the presence of `onTap`.

**Action:** Refactored `SearchPage` and `SearchResultTile` to use reactive selection via `BrowseController`. Optimized `AppCard` to conditionally enable `MouseRegion` and `ScaleTransition`. Ensure `Selector` in `SearchPage` also listens to local state (filters) and `MediaQuery.sizeOf` to avoid blocking valid UI updates.

## 2026-06-17 - HomePage & SearchPage Performance Cleanup

**Learning:** Duplicate controller definitions and broad Consumer usage can lead to both memory leaks and unnecessary rebuild overhead. Extracted widgets in  were left as duplicates in the main file, causing name collisions. Selective rebuilding with `Selector` in high-traffic pages like `HomePage` significantly narrows the rebuild scope for recommendation shelves.

**Action:** Consolidated `ScrollController` lifecycle in `HomePage`, converted broad `Consumer` to `Selector` for trending shelves in `HomePage` and `DiscoveryContent`, and purged redundant class definitions in `SearchPage`.

## 2026-06-17 - HomePage & SearchPage Performance Cleanup

**Learning:** Duplicate controller definitions and broad Consumer usage can lead to both memory leaks and unnecessary rebuild overhead. Extracted widgets in search_page.dart were left as duplicates in the main file, causing name collisions. Selective rebuilding with `Selector` in high-traffic pages like `HomePage` significantly narrows the rebuild scope for recommendation shelves.

**Action:** Consolidated `ScrollController` lifecycle in `HomePage`, converted broad `Consumer` to `Selector` for trending shelves in `HomePage` and `DiscoveryContent`, and purged redundant class definitions in `SearchPage`.
