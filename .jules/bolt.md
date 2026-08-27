## 2026-08-27 - Scoop and Brew Installed Checks Optimization

**Learning:** Invoking list_installed() inside package search methods in Scoop and Brew sources triggered heavy filesystem directory scans and per-package subprocesses (brew --prefix) for every search result.

**Action:** Use fast _get_installed_ids() helper methods (scoop list or brew list --versions) to retrieve installed IDs in a single CLI call without invoking metadata/size logic.
