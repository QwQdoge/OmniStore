* 🎯 **What:** Addressed the missing test coverage for `python/core/env_manager.py`, specifically for the `EnvManager` class which handles environment capability discovery and bootstrapping.
* 📊 **Coverage:** The new `python/tests/test_env_manager.py` test suite now successfully covers:
  * Architecture detection via `_check_arch` (handling missing files, non-Arch, and Arch systems).
  * System command availability checks via `_has_cmd`.
  * Package installation verification via `_has_pkg`.
  * The `check_env` method's aggregation of system capabilities into status dictionaries.
  * The `bootstrap` method's conditional logic, ensuring it correctly rejects non-Arch environments and properly chains `pacman` and `yay` installations when dependencies are missing.
* ✨ **Result:** Increased the reliability of the core environment manager by validating all conditional paths using mocked subprocess calls, ensuring regressions won't break the critical bootstrapping phase of the application.
