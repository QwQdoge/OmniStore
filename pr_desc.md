## What
- Replaced the standalone GitHub OAuth sign-in flow with MeoArch Account Authentication via Supabase Auth (Option A: Shared Identity).
- Implemented `MeoArchEnvironment` logic mapping `SUPABASE_PUBLISHABLE_KEY` and `SUPABASE_URL` via `--dart-define`.
- Refactored `AuthService` into a unified authentication manager supporting Email/Password, Google, and GitHub logins, while managing deep links via `AppLinks` with the `omnistore://auth/callback` custom scheme.
- Redesigned the auth page into a new MD3-compliant `AccountPage` which offers standard log in methods and shows the user profile details with Account settings access.
- Moved the existing GitHub PAT configuration into `Settings` -> `Integrations` as `GitHubIntegrationPage` (renamed from old `AuthPage`) to decouple GitHub package repository identity from the main user authentication identity.
- Refactored `DesktopWindowService` to rely on `MeoArchEnvironment` configs.
- Initialized Supabase on app boot via `bootstrapOmniStore`.
- Enabled and verified Linux Deep Linking handling logic (`omnistore://` uri scheme support).
- Assured Sync mechanisms rely correctly on Supabase UUIDs (`auth.uid()`).

## Coverage
- Refactored `AuthService` and mapped `desktop_top_bar.dart` and `window_title_bar.dart` UI bindings.
- Linux Application C++ bootstrap file modifications to delegate URI Scheme `command-line` processing.
- Verified widget and flutter runtime builds correctly without compile-time anomalies.

## Result
OmniStore now acts natively as an extension of the MeoArch Account Identity system (through shared Supabase instances). Auth and Session properties are automatically saved via standard Supabase persistence. GitHub REST API connections are unblocked and properly segmented into the Settings integrations layer, allowing offline behavior to function as usual when Supabase instances are unreachable.
