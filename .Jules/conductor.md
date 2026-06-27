- Replaced generic LinearProgressIndicator with Skeleton inside AnimatedSwitcher in ai_app_resolver.dart and storage_cleanup_card.dart.
- Wrapped content resolution in github_app_list.dart with AnimatedSwitcher to prevent abrupt jumps between loading/empty/list states.
- Ensured all new and existing AnimatedSwitchers use a standard duration of 300ms.
- Added TweenAnimationBuilder to animate progress value changes in TaskProgressBar to reduce abrupt transitions.\n- Reverted replacing the indeterminate standard LinearProgressIndicator with a Skeleton to maintain UI clarity.
-- - Updated HamburgerButton AnimatedSwitcher to 300ms.
- Updated AppDetailsPage AnimatedOpacity and TweenAnimationBuilder to 300ms.
- Updated AdaptiveNavigationShell AnimatedContainer to 300ms.
- Updated SmoothProgressBar AnimatedContainer to 300ms.
- Wrapped TasksTab conditional empty/list rendering in AnimatedSwitcher (300ms).
- Wrapped UpdatesTab conditional empty/list rendering in AnimatedSwitcher (300ms).
- Wrapped AppShelfs (forYou, hotApps) and _buildHeroSection in HomePage with AnimatedSwitcher (300ms) to ensure smooth transitions from empty to populated states.
- Wrapped trending AppShelf in DiscoveryContent with AnimatedSwitcher (300ms).
- Wrapped TabBar and main TabBarView/SearchResults in GitHubStorePage with AnimatedSwitcher (300ms) to prevent abrupt UI changes when toggling search mode.

## YYYY-MM-DD
- Added `switchInCurve: Curves.easeOutCubic` and `switchOutCurve: Curves.fastOutSlowIn` to all `AnimatedSwitcher` instances in the Flutter UI to make the transition smoother, adhering to subtle MD3 motion rules.
