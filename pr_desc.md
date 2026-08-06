# ⚡ Bolt: Optimize InstalledTab filter calculation latency

### 💡 What
Optimized the installed app list filter chip generation. The calculation of unique available source filter chips (`_buildFilters()`) has been removed from the build method of `InstalledTab` (which runs on every single frame/repaint/rebuild, e.g. when scrolling or typing) and is now computed once in `_DownloadPageState` inside `DownloadPage` only when the raw underlying dataset (`_installedApps`) is successfully loaded or refreshed.

### 🎯 Why
In the original implementation, `_buildFilters()` utilized heavy O(N) list operations:
1. `filteredApps.expand((app) => {...app.sources, app.primarySource})` which is extremely costly for long lists of packages.
2. Converting the results into a `Set` to deduplicate.
3. Sorting the list alphabetically.

Since `InstalledTab` is rebuilt on every scroll, search text keystroke, tab switch, and loading status change, this resulted in massive CPU overhead and high garbage collection pressure.
Furthermore, calculating the filter chips from `filteredApps` meant that once a source filter (e.g. `Flatpak`) was chosen, the other chips would completely disappear from the UI since the list of filtered apps now only contained Flatpak packages. Computing them from the stable `_installedApps` list keeps the UI intuitive and stable.

### 📊 Impact
- **Drastically Reduced Build Complexity:** Reduces O(N) collection flattening, set allocation, and sorting operations down to a one-time O(N) evaluation on data retrieval, rendering all subsequent widget repaints and scroll events O(1).
- **Reduced GC Pressure:** Prevents hundreds of transient Set/List allocations during fast typing or rapid scrolling.
- **Improved UI Stability:** Filter chips do not disappear when a filter is applied, aligning with modern Material-3 expectations.

### 🔬 Verification
- Ran `flutter analyze` inside the `FlutterUI` directory (Zero errors or warnings).
- Executed unit and widget tests (All 100% passed).
- Confirmed correct parameter mapping from parent state to children.
