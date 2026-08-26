
## Overview

The Librarian agent directives state: "State ownership must be obvious. Prefer minimal targeted fixes. Avoid: rewriting architecture, introducing unnecessary patterns. Focus areas: rebuild ownership, async lifecycle clarity, state duplication, invalidation correctness, and provider/bloc consistency."

From reviewing `.Jules/librarian.md`, a previous action was:
"Prematurely caching synchronous, derived data (like `CategoryService.getCategories(context)`) in a state variable using `didChangeDependencies()` creates state duplication and risks invalidation bugs. Because fetching localized strings from an InheritedWidget is typically an O(1) operation in Flutter, the small memory overhead does not justify the added lifecycle complexity.
Action: Removed `late List<CategoryItem> _categories;` and the `didChangeDependencies()` overrides from `HomePage`, `EmptyResults`, `DiscoveryContent`, and `CategoryPage`. Shifted the evaluation to `final categories = CategoryService.getCategories(context);` directly within each widget's `build()` method."

However, looking at the code in those files, this bad pattern (`didChangeDependencies` caching) is back! I need to remove `_categories` and `didChangeDependencies` overrides in `HomePage`, `EmptyResults`, `DiscoveryContent`, and `CategoryPage`, and compute `categories` inline in `build()`.

1. **Remove State Duplication in `HomePage`**
   - Remove `List<CategoryItem> _categories = [];` from `_HomePageState`.
   - Remove the `didChangeDependencies` override from `_HomePageState`.
   - In `build()`, change any usage of `_categories` to `CategoryService.getCategories(context)`.

2. **Remove State Duplication in `CategoryPage`**
   - Remove `List<CategoryItem> _categories = [];` from `_CategoryPageState`.
   - Remove the `didChangeDependencies` override from `_CategoryPageState`.
   - In `build()`, change `final categories = _categories;` to `final categories = CategoryService.getCategories(context);`.

3. **Remove State Duplication in `EmptyResults`**
   - Remove `List<CategoryItem> _categories = [];` from `_EmptyResultsState`.
   - Remove the `didChangeDependencies` override from `_EmptyResultsState`.
   - In `build()`, change any usage of `_categories` to `CategoryService.getCategories(context)`.

4. **Remove State Duplication in `DiscoveryContent`**
   - Remove `List<CategoryItem> _categories = [];` from `_DiscoveryContentState`.
   - Remove the `didChangeDependencies` override from `_DiscoveryContentState`.
   - In `build()`, change any usage of `_categories` to `CategoryService.getCategories(context)`.

5. **Complete pre commit steps**
   - Ensure proper testing, verification, review, and reflection are done.

6. **Submit the change**
   - Commit and push to `fix-state-duplication`.
