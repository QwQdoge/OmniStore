import 'package:flutter/material.dart';
import 'package:frontend/core/layout/breakpoints.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
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
    final nav = context.watch<NavigationController>();
    final settings = context.watch<SettingsController>();
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

        final taskBar = Consumer<TaskController>(
          builder: (context, task, child) {
            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: task.isBusy ? _TaskProgressBar(task: task) : const SizedBox.shrink(),
              ),
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
                      tooltip: AppLocalizations.of(context)!.search,
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
                    selectedIndex: _navBarIndex(compactDests, nav.selectedIndex),
                    onDestinationSelected: (i) =>
                        nav.setIndex(compactDests[i].index),
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
        final isExpanded = settings.isRailExpanded;

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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      width: isExpanded ? 180 : 72,
                      child: NavigationRail(
                        extended: isExpanded,
                        minExtendedWidth: 180,
                        selectedIndex: _railIndex(railDestinations, nav.selectedIndex),
                        onDestinationSelected: (i) =>
                            nav.setIndex(railDestinations[i].index),
                        labelType: isExpanded
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        leading: _HamburgerButton(
                          isExpanded: isExpanded,
                          onToggle: () => settings.setRailExpanded(!isExpanded),
                        ),
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
                          child: _RailBottomActions(
                            isExpanded: isExpanded,
                            settingsIndex: settingsIndex,
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

// ─── Hamburger Toggle Button ────────────────────────────
class _HamburgerButton extends StatelessWidget {
  const _HamburgerButton({
    required this.isExpanded,
    required this.onToggle,
  });

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IconButton(
        onPressed: onToggle,
        tooltip: isExpanded ? l10n.collapse : l10n.expand,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              RotationTransition(turns: Tween(begin: 0.5, end: 1.0).animate(anim), child: child),
          child: Icon(
            isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
            key: ValueKey(isExpanded),
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Actions: Settings + Download ────────────────
class _RailBottomActions extends StatelessWidget {
  const _RailBottomActions({
    required this.isExpanded,
    required this.settingsIndex,
  });

  final bool isExpanded;
  final int settingsIndex;

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final l10n = AppLocalizations.of(context)!;
    final isSettingsSelected = nav.selectedIndex == settingsIndex;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Settings button
        isExpanded
            ? _ExpandedActionTile(
                icon: isSettingsSelected
                    ? Icons.settings_rounded
                    : Icons.settings_outlined,
                label: l10n.settings,
                isSelected: isSettingsSelected,
                onTap: () => nav.setIndex(settingsIndex),
              )
            : _CompactActionButton(
                icon: isSettingsSelected
                    ? Icons.settings_rounded
                    : Icons.settings_outlined,
                tooltip: l10n.settings,
                isSelected: isSettingsSelected,
                onTap: () => nav.setIndex(settingsIndex),
              ),
        const SizedBox(height: 4),
        // Download button
        isExpanded
            ? _ExpandedDownloadTile()
            : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DownloadAction(compact: false),
              ),
        if (!isExpanded) const SizedBox(height: 0),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _ExpandedActionTile extends StatelessWidget {
  const _ExpandedActionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: isSelected
            ? scheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedDownloadTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isSelected = nav.selectedIndex == 4;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
      child: ListenableBuilder(
        listenable: UpdateService().availableUpdates,
        builder: (context, _) {
          final updates = UpdateService().availableUpdates.value;
          return Material(
            color: isSelected
                ? scheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => nav.setIndex(4),
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Consumer<TaskController>(
                      builder: (context, task, child) => Icon(
                        task.isBusy
                            ? Icons.downloading_rounded
                            : Icons.download_for_offline_rounded,
                        size: 24,
                        color: isSelected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.downloads,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (updates.isNotEmpty)
                      Badge(label: Text('${updates.length}')),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Existing widgets, kept intact ──────────────────────
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
              icon: Consumer<TaskController>(
                builder: (context, task, child) => Icon(
                  task.isBusy
                      ? Icons.downloading_rounded
                      : Icons.download_for_offline_rounded,
                  color: nav.selectedIndex == 4
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
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
