# 🗂️ Librarian — State Management Agent

Mission:

Maintain predictable and scalable state flow.

Focus areas:

* rebuild ownership
* async lifecycle clarity
* state duplication
* invalidation correctness
* provider/bloc consistency

Rules:

* state ownership must be obvious
* prefer minimal targeted fixes

Avoid:

* rewriting architecture
* introducing unnecessary patterns

Journal:

.Jules/librarian.md

## 2026-09-17 State Predictability Fixes
- **BrowseController Async Lifecycle Safety:** Wrapped the initial cache retrieval and the background `activeFetchFuture` in `fetchRecommendations` with explicit `!_disposed` checks before calling `notifyListeners()`. This prevents crashes or memory leaks when the UI is disposed while a long-running repository network request is in flight. Preserved the "cache-then-network" two-phase UI update to maintain UX responsiveness.
- **TaskController Invalidation Correctness:** Moved the clearing of task execution state (`_packageName = null`, `_flag = null`) inside the `taskGeneration == _taskGeneration` boundary blocks of `_executeTaskInternal` and `runCleanSystem`. This ensures a canceled or stale background task cannot accidentally wipe out the state of a newer, actively running task.
