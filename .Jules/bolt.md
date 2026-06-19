
## 2026-06-15 - MediaQuery Rebuild Optimization

**Learning:** Using `MediaQuery.of(context).size.width` triggers a rebuild of the entire widget whenever ANY property of `MediaQueryData` changes (e.g., keyboard visibility, system theme). Using `MediaQuery.sizeOf(context).width` (available in Flutter 3.10+) ensures the widget only rebuilds when the size specifically changes.

**Action:** Replaced `MediaQuery.of(context).size.width` with `MediaQuery.sizeOf(context).width` in `flatpak_store_page.dart` and `search_page.dart`.

## 2026-06-16 - Search Selection & AppCard Optimization

**Learning:** Managing selection state in a monolithic page using `setState` causes the entire list to rebuild, which is expensive for large datasets. Offloading selection to a `ChangeNotifier` and using `context.select` in list items isolates rebuilds. Additionally, `AppCard` animations can be skipped for non-interactive items by checking for the presence of `onTap`.

**Action:** Refactored `SearchPage` and `SearchResultTile` to use reactive selection via `BrowseController`. Optimized `AppCard` to conditionally enable `MouseRegion` and `ScaleTransition`. Ensure `Selector` in `SearchPage` also listens to local state (filters) and `MediaQuery.sizeOf` to avoid blocking valid UI updates.

## 2026-06-17 - Trending Shelf Rebuild Reduction

**Learning:**  widgets rebuild their child tree every time the provided controller's  is called. For a shelf that only cares about one specific list (e.g., 'trending' apps), this causes many unnecessary rebuilds. By switching to , we narrow the rebuild trigger to only fire when the specific property changes.

**Action:** Replaced  with  in  for the 'Trending' shelf, successfully isolating its build behavior without altering functionality.


## 2026-06-17 - Trending Shelf Rebuild Reduction

**Learning:** `Consumer` widgets rebuild their child tree every time the provided controller's `notifyListeners` is called. For a shelf that only cares about one specific list (e.g., 'trending' apps), this causes many unnecessary rebuilds. By switching to `Selector`, we narrow the rebuild trigger to only fire when the specific property changes.

**Action:** Replaced `Consumer<BrowseController>` with `Selector<BrowseController, List<AppPackage>>` in `home_page.dart` for the 'Trending' shelf, successfully isolating its build behavior without altering functionality.

## 2026-06-18 - HomePage Category Allocations

**Learning:** Allocating a new list and performing localization lookups in the `build()` method causes unnecessary allocations on every frame or state change. Caching lists that only change when dependencies (like localization) change reduces garbage collection overhead and makes `build()` faster.

**Action:** Added `_categories` state to `_HomePageState` and initialized it in `didChangeDependencies()` to memoize `CategoryService.getCategories(context)`, avoiding redundant evaluations in `_buildCategoryQuickAccess()`.
