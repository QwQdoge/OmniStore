<<<<<<< HEAD
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
# 🚀 OmniStore: Unified PR for Auth Redesign, Dropdown MD3 Standardizations, and Code Health Optimizations

## 🎯 What

This pull request consolidates and resolves several major development streams:

1. **Authentication Redesign (MeoArch Supabase Integration):**
   - Replaced standalone GitHub OAuth sign-in flow with MeoArch Account Authentication via Supabase Auth.
   - Refactored `AuthService` into a unified authentication manager supporting Email/Password, Google, and GitHub logins, while managing deep links via `AppLinks` with the `omnistore://auth/callback` custom scheme.
   - Redesigned the auth page into a new MD3-compliant `AccountPage` which offers standard log in methods and shows the user profile details with Account settings access.
   - Moved the existing GitHub PAT configuration into `Settings` -> `Integrations` as `GitHubIntegrationPage` (renamed from old `AuthPage`) to decouple GitHub package repository identity from the main user authentication identity.

2. **Material Design 3 Dropdown Selection Inputs:**
   - Standardized styling of all configuration dropdown selectors (`DropdownButton`) within the settings pages (Language, Font Family, Update Interval, AI Provider) inside a Container utilizing Material Design 3 tokens.
   - Replaced legacy sharp arrow icon with soft `keyboard_arrow_down_rounded` icon.

3. **Compiler Error Cleanup & Code Health:**
   - Resolved duplicate copy-pasted member and method declarations in `SettingsController` (`bool _disposed`, `dispose()`, `notifyListeners()`) causing severe Dart compile errors.
   - Resolved duplicate copy-pasted fields in `AppPackage` (`nameLower`, `descriptionLower`, `primarySourceLower`) causing Dart compile errors.
   - Fully preserved the critical defensive guards (`_disposed` check in `notifyListeners` and lazy-initialized lowering properties) to ensure the application remains robust.

## 🎯 Why

- **Authentication Cohesion:** Decoupling package registry identity (GitHub PAT) from the user's primary application account identity provides a cleaner UX.
- **UI Consistency:** Legacy unstyled dropdown buttons lacked clean boundaries and hover effects. Standardizing these elements under Material Design 3 guidelines establishes consistent tap targets and boundaries.
- **Code Health & Safety:** Eliminating duplicate class properties resolves critical build blockers while safeguarding lifecycle and performance optimizations.

## ⚡ Impact

- **Security & Stability:** Improved deep-link handling and async state transition safety prevents post-dispose setState crashes.
- **Accessibility:** Large click/tap targets on dropdown selectors, and clear visual boundaries improve readability.
- **Performance:** Optimized lazy-caching on model fields prevents unnecessary string allocations inside high-frequency filtration loops.

## 📊 Verification & Coverage

- **Flutter Analysis:** `flutter analyze` runs successfully with zero warnings/errors.
- **Testing:**
  - Ran the full Python unit/widget test suite successfully with **69 passed tests**.
  - Ran Flutter frontend widget & unit tests successfully (`flutter test test/widget_test.dart`).
