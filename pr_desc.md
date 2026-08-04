🧹 [Fix empty catch blocks in platform environment]

🎯 **What:** Replaced empty `catch (_)` blocks with `catch (e) { debugPrint(...); }` in `platform_environment.dart`.
💡 **Why:** Empty catch blocks hide exceptions, making it impossible to debug path resolution issues when `Platform.script` or `Platform.resolvedExecutable` fail to resolve properly.
✅ **Verification:** Verified by running `flutter analyze` and `flutter test test/backend_service_test.dart` to ensure syntax is correct and functionality remains identical.
✨ **Result:** Path resolution failures are now visibly logged to the console without altering the fallback mechanics of the method.
