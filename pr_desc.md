🧪 [testing] add tests for habit tracker fallback logic

🎯 **What:**
Added explicit unit tests to cover the exception-handling fallback logic inside `HabitTracker._load_habits`. Previously, this fallback logic (returning a default initial state) when the config file was corrupted or inaccessible was untested.

📊 **Coverage:**
- Added `test_load_habits_fallback_invalid_json`: Verifies that a corrupted JSON file triggers the fallback.
- Added `test_load_habits_fallback_read_error`: Verifies that an unreadable file (e.g., `PermissionError`) triggers the fallback.

✨ **Result:**
The test suite now explicitly covers error conditions during habit tracking initialization, increasing overall reliability and test coverage for the `HabitTracker` module.
