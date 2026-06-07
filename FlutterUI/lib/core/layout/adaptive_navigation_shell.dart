import 'package:flutter/material.dart';
import 'package:frontend/core/layout/breakpoints.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/update_service.dart';
import 'package:frontend/widgets/window_title_bar.dart';
import 'package:provider/provider.dart';

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
  });

  final List<NavDestination> destinations;
  final List<NavDestination> secondaryDestinations;
  final String pageTitle;
  final Widget pageChild;
  final VoidCallback onSearch;
  final bool showSearch;
  final bool useWindowTitleBar;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final task = context.watch<TaskController>();
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = Breakpoints.isCompact(constraints.maxWidth);

        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.fastOutSlowIn,
          child: KeyedSubtree(
            key: ValueKey<int>(nav.selectedIndex),
            child: pageChild,
          ),
        );

        final pageSurface = Material(
          color: Theme.of(context).brightness == Brightness.light
              ? scheme.surface
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(compact ? 16 : 28),
          clipBehavior: Clip.antiAlias,
          child: content,
        );

        final taskBar = AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: task.isBusy ? _TaskProgressBar(task: task) : const SizedBox.shrink(),
          ),
        );

        if (compact) {
          return PopScope(
            canPop: nav.selectedIndex == destinations.first.index,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              nav.setIndex(destinations.first.index);
            },
            child: Scaffold(
              backgroundColor: scheme.surface,
              appBar: AppBar(
                title: Text(pageTitle),
                centerTitle: false,
                actions: [
                  if (showSearch && nav.selectedIndex != 2)
                    IconButton(
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  _DownloadAction(compact: true),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: pageSurface,
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  taskBar,
                  NavigationBar(
                    selectedIndex: _navBarIndex(destinations, nav.selectedIndex),
                    onDestinationSelected: (i) =>
                        nav.setIndex(destinations[i].index),
                    destinations: [
                      for (final d in destinations)
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

        final railDestinations = [...destinations, ...secondaryDestinations];

        return Scaffold(
          backgroundColor: scheme.surface,
          body: Column(
            children: [
              if (useWindowTitleBar)
                WindowTitleBar(
                  title: pageTitle,
                  showSearch: showSearch && nav.selectedIndex != 2,
                  onSearchPressed: onSearch,
                )
              else
                _DesktopTopBar(
                  title: pageTitle,
                  showSearch: showSearch && nav.selectedIndex != 2,
                  onSearch: onSearch,
                ),
              taskBar,
              Expanded(
                child: Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= Breakpoints.expanded,
                      minExtendedWidth: 180,
                      selectedIndex: _railIndex(railDestinations, nav.selectedIndex),
                      onDestinationSelected: (i) =>
                          nav.setIndex(railDestinations[i].index),
                      labelType: constraints.maxWidth >= Breakpoints.expanded
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: [
                        for (final d in railDestinations)
                          NavigationRailDestination(
                            icon: Semantics(
                              label: d.label,
                              child: Icon(d.icon),
                            ),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _DownloadAction(compact: false),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
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

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.showSearch,
    required this.onSearch,
  });

  final String title;
  final bool showSearch;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: scheme.surface,
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (showSearch)
            FilledButton.tonalIcon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(AppLocalizations.of(context)!.search),
            ),
        ],
      ),
    );
  }
}

class _TaskProgressBar extends StatelessWidget {
  const _TaskProgressBar({required this.task});

  final TaskController task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.downloading_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.processing} ${task.status} ${task.speed}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.progress != null)
                  Text(
                    '${(task.progress! * 100).toInt()}%',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: task.progress,
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final task = context.watch<TaskController>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: l10n.downloads,
              onPressed: () => nav.setIndex(4),
              icon: Icon(
                task.isBusy
                    ? Icons.downloading_rounded
                    : Icons.download_for_offline_rounded,
                color: nav.selectedIndex == 4
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (updates.isNotEmpty)
              Positioned(
                top: compact ? 4 : 8,
                right: compact ? 4 : 8,
                child: Badge(label: Text('${updates.length}')),
              ),
          ],
        );
      },
    );
  }
}
