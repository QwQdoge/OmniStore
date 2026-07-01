import 'package:flutter/material.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/update_service.dart';
import 'package:provider/provider.dart';

import 'download_action.dart';

class RailBottomActions extends StatelessWidget {
  const RailBottomActions({
    super.key,
    required this.isExpanded,
    required this.settingsIndex,
  });

  final bool isExpanded;
  final int settingsIndex;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.select<NavigationController, int>(
      (n) => n.selectedIndex,
    );
    final l10n = AppLocalizations.of(context)!;
    final isSettingsSelected = selectedIndex == settingsIndex;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Settings button
        isExpanded
            ? ExpandedActionTile(
                icon: isSettingsSelected
                    ? Icons.settings_rounded
                    : Icons.settings_outlined,
                label: l10n.settings,
                isSelected: isSettingsSelected,
                onTap: () => context.read<NavigationController>().setIndex(
                  settingsIndex,
                ),
              )
            : CompactActionButton(
                icon: isSettingsSelected
                    ? Icons.settings_rounded
                    : Icons.settings_outlined,
                tooltip: l10n.settings,
                isSelected: isSettingsSelected,
                onTap: () => context.read<NavigationController>().setIndex(
                  settingsIndex,
                ),
              ),
        const SizedBox(height: 8),
        // Download button
        isExpanded
            ? const ExpandedDownloadTile()
            : const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: DownloadAction(compact: false),
              ),
        if (!isExpanded) const SizedBox(height: 0),
      ],
    );
  }
}

class CompactActionButton extends StatelessWidget {
  const CompactActionButton({
    super.key,
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
    return Semantics(
      label: tooltip,
      button: true,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class ExpandedActionTile extends StatelessWidget {
  const ExpandedActionTile({
    super.key,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: isSelected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
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

class ExpandedDownloadTile extends StatelessWidget {
  const ExpandedDownloadTile({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.select<NavigationController, int>(
      (n) => n.selectedIndex,
    );
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isSelected = selectedIndex == 4;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: ListenableBuilder(
        listenable: UpdateService().availableUpdates,
        builder: (context, _) {
          final updates = UpdateService().availableUpdates.value;
          return Material(
            color: isSelected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.read<NavigationController>().setIndex(4),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Selector<TaskController, bool>(
                      selector: (context, task) => task.isBusy,
                      builder: (context, isBusy, child) => Icon(
                        isBusy
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
