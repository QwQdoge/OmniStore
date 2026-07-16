import 'package:flutter/material.dart';
import 'package:frontend/core/layout/breakpoints.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/auth/auth_page.dart';
import 'package:provider/provider.dart';

import 'widgets/task_progress_bar.dart';
import 'widgets/download_action.dart';
import 'widgets/desktop_top_bar.dart';
import 'widgets/hamburger_button.dart';
import 'widgets/rail_bottom_actions.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class NavDestination {
  const NavDestination({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Responsive shell: [NavigationBar] on compact widths, [NavigationRail] on wide.
/// Features a collapsible hamburger menu and bottom action icons (Settings + Downloads).
class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
    super.key,
    required this.destinations,
    required this.secondaryDestinations,
    required this.pageTitle,
    required this.pageChild,
    required this.onSearch,
    this.showSearch = true,
    this.useWindowTitleBar = false,
    this.settingsIndex = 3,
  });

  final List<NavDestination> destinations;
  final List<NavDestination> secondaryDestinations;
  final String pageTitle;
  final Widget pageChild;
  final VoidCallback onSearch;
  final bool showSearch;
  final bool useWindowTitleBar;
  final int settingsIndex;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.select<NavigationController, int>(
      (n) => n.selectedIndex,
    );
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = Breakpoints.isCompact(constraints.maxWidth);

        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.fastOutSlowIn,
          child: KeyedSubtree(
            key: ValueKey<int>(selectedIndex),
            child: pageChild,
          ),
        );

        final pageSurface = ColoredBox(
          color: Theme.of(context).brightness == Brightness.light
              ? scheme.surface
              : scheme.surfaceContainerLow,
          child: content,
        );

        final taskBar = Selector<TaskController, bool>(
          selector: (context, task) => task.isBusy,
          builder: (context, isBusy, child) {
            return SmoothSizeSwitcher(
              child: isBusy ? const TaskProgressBar() : const SizedBox.shrink(),
            );
          },
        );

        if (compact) {
          // ─── Compact Layout (Bottom Navigation Bar) ───
          // Include Settings as the last item in bottom nav
          final compactDests = [
            ...destinations,
            NavDestination(
              index: settingsIndex,
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: AppLocalizations.of(context)!.settings,
            ),
          ];

          return PopScope(
            canPop: selectedIndex == destinations.first.index,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              context.read<NavigationController>().setIndex(
                destinations.first.index,
              );
            },
            child: Scaffold(
              backgroundColor: scheme.surfaceContainerLowest,
              appBar: AppBar(
                title: Text(pageTitle),
                centerTitle: false,
                actions: [
                  if (showSearch && selectedIndex != 2)
                    Semantics(
                      label: l10n.search,
                      button: true,
                      child: IconButton(
                        onPressed: onSearch,
                        tooltip: l10n.search,
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  Semantics(
                    label: l10n.githubAuthTitle,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.account_circle_outlined),
                      tooltip: l10n.githubAuthTitle,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const DownloadAction(compact: true),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: pageSurface,
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  taskBar,
                  NavigationBar(
                    selectedIndex: _navBarIndex(compactDests, selectedIndex),
                    onDestinationSelected: (i) => context
                        .read<NavigationController>()
                        .setIndex(compactDests[i].index),
                    destinations: [
                      for (final d in compactDests)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // ─── Desktop Layout (Navigation Rail) ───
        final railDestinations = [...destinations, ...secondaryDestinations];
        final isExpanded = context.select<SettingsController, bool>(
          (s) => s.isRailExpanded,
        );
        final railWidth = isExpanded ? 216.0 : 88.0;

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          body: Column(
            children: [
              DesktopTopBar(
                title: pageTitle,
                showSearch: showSearch && selectedIndex != 2,
                onSearch: onSearch,
              ),
              taskBar,
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: railWidth,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          right: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.42,
                            ),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: NavigationRail(
                            extended: isExpanded,
                            minWidth: 88,
                            minExtendedWidth: 216,
                            groupAlignment: -0.9,
                            useIndicator: true,
                            selectedIndex: _railIndex(
                              railDestinations,
                              selectedIndex,
                            ),
                            onDestinationSelected: (i) => context
                                .read<NavigationController>()
                                .setIndex(railDestinations[i].index),
                            labelType: isExpanded
                                ? NavigationRailLabelType.none
                                : NavigationRailLabelType.all,
                            leading: HamburgerButton(
                              isExpanded: isExpanded,
                              onToggle: () => context
                                  .read<SettingsController>()
                                  .setRailExpanded(!isExpanded),
                            ),
                            destinations: [
                              for (final d in railDestinations)
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: d.label,
                                    child: Icon(d.icon),
                                  ),
                                  selectedIcon: Tooltip(
                                    message: d.label,
                                    child: Icon(d.selectedIcon),
                                  ),
                                  label: Text(
                                    d.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            trailing: Expanded(
                              child: RailBottomActions(
                                isExpanded: isExpanded,
                                settingsIndex: settingsIndex,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: pageSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _navBarIndex(List<NavDestination> items, int selected) {
    final i = items.indexWhere((d) => d.index == selected);
    return i >= 0 ? i : 0;
  }

  int _railIndex(List<NavDestination> items, int selected) {
    final i = items.indexWhere((d) => d.index == selected);
    return i >= 0 ? i : 0;
  }
}
