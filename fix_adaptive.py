import re

with open('FlutterUI/lib/core/layout/adaptive_navigation_shell.dart', 'r') as f:
    content = f.read()

# 1. Remove `final settings = context.watch<SettingsController>();` from AdaptiveNavigationShell.build
content = re.sub(
    r'\s*final settings = context\.watch<SettingsController>\(\);',
    '',
    content
)

# 2. Replace settings usages with context.select and context.read
content = content.replace("final isExpanded = settings.isRailExpanded;", "final isExpanded = context.select<SettingsController, bool>((s) => s.isRailExpanded);")
content = content.replace("settings.setRailExpanded(!isExpanded)", "context.read<SettingsController>().setRailExpanded(!isExpanded)")

# 3. For NavigationController:
# AdaptiveNavigationShell.build
content = content.replace(
    "final nav = context.watch<NavigationController>();",
    "final nav = context.read<NavigationController>();\n    final selectedIndex = context.select<NavigationController, int>((n) => n.selectedIndex);"
)

# 4. Replace `nav.selectedIndex` with `selectedIndex`
content = content.replace("nav.selectedIndex", "selectedIndex")

# 5. Fix `_ExpandedDownloadTile`
content = content.replace(
    "class _ExpandedDownloadTile extends StatelessWidget {\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.read<NavigationController>();\n    final selectedIndex = context.select<NavigationController, int>((n) => n.selectedIndex);\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;\n    final isSelected = selectedIndex == 4;",
    "class _ExpandedDownloadTile extends StatelessWidget {\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.read<NavigationController>();\n    final selectedIndex = context.select<NavigationController, int>((n) => n.selectedIndex);\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;\n    final isSelected = selectedIndex == 4;"
)
# Actually, since I did `git checkout HEAD`, I need to replace from the original text!
content = content.replace(
    "class _ExpandedDownloadTile extends StatelessWidget {\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.watch<NavigationController>();\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;\n    final isSelected = nav.selectedIndex == 4;",
    "class _ExpandedDownloadTile extends StatelessWidget {\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.read<NavigationController>();\n    final selectedIndex = context.select<NavigationController, int>((n) => n.selectedIndex);\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;\n    final isSelected = selectedIndex == 4;"
)

# 6. Fix `_DownloadAction`
content = content.replace(
    "class _DownloadAction extends StatelessWidget {\n  const _DownloadAction({required this.compact});\n\n  final bool compact;\n\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.watch<NavigationController>();\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;",
    "class _DownloadAction extends StatelessWidget {\n  const _DownloadAction({required this.compact});\n\n  final bool compact;\n\n  @override\n  Widget build(BuildContext context) {\n    final nav = context.read<NavigationController>();\n    final selectedIndex = context.select<NavigationController, int>((n) => n.selectedIndex);\n    final scheme = Theme.of(context).colorScheme;\n    final l10n = AppLocalizations.of(context)!;"
)

with open('FlutterUI/lib/core/layout/adaptive_navigation_shell.dart', 'w') as f:
    f.write(content)
