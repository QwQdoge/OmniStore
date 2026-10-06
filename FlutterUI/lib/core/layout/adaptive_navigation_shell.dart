import 'package:flutter/material.dart';
import 'package:frontend/core/layout/breakpoints.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'widgets/task_progress_bar.dart';
import 'widgets/download_action.dart';
import 'widgets/desktop_top_bar.dart';
import 'widgets/route_sidebar.dart';
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

/// Responsive shell with one searchable sidebar, persistent or modal.
/// Compact shortcuts retain the application route identity.
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
        final wide = constraints.maxWidth >= 1180;
        final allDestinations = [
          ...destinations,
          ...secondaryDestinations,
          NavDestination(
            index: 2,
            icon: Icons.search,
            selectedIcon: Icons.search,
            label: l10n.search,
          ),
          NavDestination(
            index: settingsIndex,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.settings,
          ),
          NavDestination(
            index: 4,
            icon: Icons.download_outlined,
            selectedIcon: Icons.download,
            label: l10n.downloads,
          ),
        ];
        Widget sidebar(BuildContext sidebarContext, bool modal) => RouteSidebar(
          selectedRoute: selectedIndex.toString(),
          searchLabel: l10n.search,
          emptyLabel: l10n.noResults,
          autofocus: modal,
          routes: [
            for (final d in allDestinations)
              SidebarRoute(
                id: d.index.toString(),
                title: d.label,
                icon: d.icon,
              ),
          ],
          onSelected: (route) {
            if (modal) Navigator.of(sidebarContext).pop();
            context.read<NavigationController>().setIndex(int.parse(route));
          },
        );

        final content = SmoothSizeSwitcher(
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
              drawer: Drawer(
                width: 360,
                child: Builder(builder: (context) => sidebar(context, true)),
              ),
              appBar: AppBar(
                title: Text(pageTitle),
                centerTitle: false,
                actions: [
                  if (showSearch && selectedIndex != 2)
                    IconButton(
                      onPressed: onSearch,
                      tooltip: l10n.search,
                      icon: const Icon(Icons.search_rounded),
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

        // Wide layouts persist the full sidebar; medium layouts keep icon shortcuts.
        final railDestinations = allDestinations;

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          drawer: wide
              ? null
              : Drawer(
                  width: 360,
                  child: Builder(builder: (context) => sidebar(context, true)),
                ),
          body: Column(
            children: [
              DesktopTopBar(
                showNavigation: !wide,
                title: pageTitle,
                showSearch: showSearch && selectedIndex != 2,
                onSearch: onSearch,
              ),
              taskBar,
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      SizedBox(width: 360, child: sidebar(context, false))
                    else
                      NavigationRail(
                        minWidth: 88,
                        labelType: NavigationRailLabelType.none,
                        selectedIndex: _railIndex(
                          railDestinations,
                          selectedIndex,
                        ),
                        onDestinationSelected: (i) => context
                            .read<NavigationController>()
                            .setIndex(railDestinations[i].index),
                        destinations: [
                          for (final d in railDestinations)
                            NavigationRailDestination(
                              icon: Tooltip(
                                message: d.label,
                                child: Icon(d.icon),
                              ),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ),
                        ],
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
