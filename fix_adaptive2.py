import re

with open('FlutterUI/lib/core/layout/adaptive_navigation_shell.dart', 'r') as f:
    content = f.read()

# Wait, the `final nav = context.read<NavigationController>();` and `final selectedIndex = context.select...` were inserted but maybe in the wrong place?
# Ah! In AdaptiveNavigationShell, the original `context.watch<NavigationController>()` was at `lib/core/layout/adaptive_navigation_shell.dart:52`.
# Let's check where `nav.selectedIndex` were replaced with `selectedIndex`.

content = content.replace("ValueKey<int>(selectedIndex)", "ValueKey<int>(nav.selectedIndex)")
content = content.replace("canPop: selectedIndex == destinations.first.index", "canPop: nav.selectedIndex == destinations.first.index")
content = content.replace("selectedIndex != 2", "nav.selectedIndex != 2")
content = content.replace("selectedIndex: _navBarIndex(compactDests, selectedIndex)", "selectedIndex: _navBarIndex(compactDests, nav.selectedIndex)")
content = content.replace("selectedIndex: _railIndex(railDestinations, selectedIndex)", "selectedIndex: _railIndex(railDestinations, nav.selectedIndex)")
content = content.replace("final isSettingsSelected = selectedIndex == settingsIndex;", "final isSettingsSelected = nav.selectedIndex == settingsIndex;")

# Wait, if I revert `selectedIndex` back to `nav.selectedIndex`, I need to use `context.watch`?
# NO. The reviewer said: "In _RailBottomActions and AdaptiveNavigationShell, the agent changed context.watch to context.read but left nav.selectedIndex evaluations intact. This removes reactivity, meaning the navigation UI will no longer update its selected state when the user switches tabs."
# Ah! Because `context.read` DOES NOT trigger rebuilds! So we MUST use `context.select` or `context.watch`.
# Since `nav.selectedIndex` is the ONLY property used, `context.select<NavigationController, int>((n) => n.selectedIndex)` is exactly what we want, and we should use it!
# The reviewer complained because I changed it to `context.read` but STILL USED `nav.selectedIndex`. Wait, if I used `nav.selectedIndex` on a `context.read` instance, it will just read the current value once, but not subscribe to changes, so NO rebuilds happen.
# That makes sense!
# SO I MUST replace `nav.selectedIndex` with the variable that is assigned the result of `context.select`.
