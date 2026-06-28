import 'package:flutter/material.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/update_service.dart';
import 'package:provider/provider.dart';

class DownloadAction extends StatelessWidget {
  const DownloadAction({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.select<NavigationController, int>(
      (n) => n.selectedIndex,
    );
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              label: l10n.downloads,
              button: true,
              child: IconButton(
                tooltip: l10n.downloads,
                onPressed: () =>
                    context.read<NavigationController>().setIndex(4),
                icon: Selector<TaskController, bool>(
                  selector: (context, task) => task.isBusy,
                  builder: (context, isBusy, child) => Icon(
                    isBusy
                        ? Icons.downloading_rounded
                        : Icons.download_for_offline_rounded,
                    color: selectedIndex == 4
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (updates.isNotEmpty)
              Positioned(
                top: compact ? 4 : 8,
                right: compact ? 4 : 8,
                child: Badge(label: Text(l10n.resultsFound(updates.length))),
              ),
          ],
        );
      },
    );
  }
}
