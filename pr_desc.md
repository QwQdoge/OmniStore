## What
Fixed Provider contract violations where `context.read<GitHubClient>()` was improperly called directly within the `build()` methods of `GitHubAppList` and `AppDetailsHeader`.

## Why
Calling `context.read<T>()` inside a widget's `build` method is considered an anti-pattern by the `provider` package and throws assertion errors in debug mode. It prevents widgets from listening for and rebuilding correctly if the provided object (like the GitHub client instance) were to ever update. Using `context.watch<T>()` ensures safe and consistent behavior across the app.

## Impact
Improved state management robustness and removed runtime assertion risks without altering the intended UX.

## Verification
- Ran frontend test suite (`cd FlutterUI && flutter test`) — all tests passed.
- Analyzed and verified through code review.

## Accessibility
No changes to accessible elements.
