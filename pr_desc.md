🧪 [testing improvement] Add comprehensive tests for HabitTracker

🎯 **What:** The `HabitTracker` class in `python/core/habit_tracker.py` was missing test coverage. This class is responsible for persisting user habits (like search queries and package install history) to disk, managing source weights, and providing recommendation tags based on history.

📊 **Coverage:**
A new test file `python/tests/test_habit_tracker.py` has been added which covers:
*   Initialization: Handling states where the configuration file does not exist, contains valid JSON, or contains invalid JSON.
*   `record_search`: Validating query incrementing, case-insensitivity, whitespace stripping, and ignoring short queries (< 2 characters).
*   `get_recommendation_tags`: Ensuring it aggregates the top searches and installed packages accurately.
*   `_save_habits`: Testing both asynchronous (with `asyncio` loop) and fallback synchronous (without loop) file saving.
*   Coalescing Logic: Validating that rapid successive save calls correctly set the `_needs_another_save` flag and don't trigger redundant simultaneous disk I/O.
*   Safety: Tests utilize `pytest`'s `tmp_path` fixture combined with `unittest.mock.patch` to redirect `Path.home()` safely to a temporary directory, ensuring no real user data is modified during test execution.

✨ **Result:** Significant improvement in test coverage and reliability for core backend components, providing a safety net for future refactoring of habit tracking and asynchronous I/O persistence.
