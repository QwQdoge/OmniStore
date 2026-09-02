# Bolt Agent - Performance Optimization

## Observation
- `TaskController` updates `_completedTasks` by inserting new task states when processes finish and by clearing history.
- The UI in `tasks_tab.dart` uses a `Selector` to rebuild the completed tasks list. The `shouldRebuild` callback was performing an $O(N)$ operation `!const IterableEquality().equals(prev.history, next.history)` which iterates over all items in the history list.
- A similar anti-pattern was previously resolved for terminal logs, but `_completedTasks` was still using `IterableEquality`.

## Solution
1. Introduced a monotonically increasing integer `_completedTasksVersion` in `TaskController`.
2. Incremented this version in `clearHistory` and whenever a new completed task is inserted.
3. Added a getter `completedTasksVersion` to `TaskController`.
4. Updated `tasks_tab.dart` to use $O(1)$ scalar integer equality on `version` instead of `IterableEquality` in the `Selector`'s `shouldRebuild`.
5. Updated `backend_service.dart` to use `DeepCollectionEquality` for `availableSources.value` updates.

## Verification
- Code changes have been verified to replace the $O(N)$ list comparison with an $O(1)$ integer comparison.
