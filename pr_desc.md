## 🛡️ Sentinel: Async Lifecycle Safety Hardening for WelcomePage

**What:**
- Added strict `if (!mounted) return;` checks inside `catch` blocks and stream listener callbacks (`onError`, `onDone`, and line parsers) in `WelcomePage`.

**Why:**
- While `WelcomePage` had `mounted` checks after `await` calls, its `catch` blocks and asynchronous stream subscriptions (for the bootstrap output) modified state (using `setState`) without verifying if the widget was still mounted. This could result in "setState() called after dispose()" and "use of BuildContext across async gaps" crashes if the user navigated away or closed the app during the onboarding setup.

**Result:**
- `WelcomePage` is now fully resilient to asynchronous lifecycle exceptions, particularly during the critical environment checking and bootstrapping phases.
