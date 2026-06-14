import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/data/repositories/package_repository.dart';
import 'package:frontend/services/update_service.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'ai_update_summary_dialog.dart';
import 'package:frontend/core/widgets/app_card.dart';

class UpdatesTab extends StatelessWidget {
  final VoidCallback onUpdateStarted;

  const UpdatesTab({super.key, required this.onUpdateStarted});

  @override
  Widget build(BuildContext context) {
    final packageRepo = context.read<PackageRepository>();
    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;
        if (updates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.allUpdated,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.foundUpdates(updates.length),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final taskController = context.read<TaskController>();
                      final l10n = AppLocalizations.of(context)!;
                      if (taskController.isBusy) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.taskInProgress)),
                        );
                        return;
                      }
                      taskController.updateAll('all', l10n);
                      onUpdateStarted();
                    },
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: Text(AppLocalizations.of(context)!.updateAll),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final update = updates[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      label: 'Update available: ${update['name']}',
                      button: true,
                      child: AppCard(
                        borderRadius: 16,
                        onTap: () async {
                          final results = await packageRepo.searchPackages(
                            update['name'],
                          );
                          if (!context.mounted) return;
                          if (results.isNotEmpty) {
                            final app = results[0];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppDetailsPage(app: app),
                              ),
                            );
                          }
                        },
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            update['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${update['current_version']} → ${update['new_version']}",
                          ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Consumer<SettingsController>(
                              builder: (context, settings, _) {
                                if (!settings.isAIEnabled) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  icon: const MagicPulseIcon(
                                    icon: Icons.auto_awesome_rounded,
                                    size: 20,
                                  ),
                                  tooltip: AppLocalizations.of(
                                    context,
                                  )!.aiExplainUpdate,
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => AIUpdateSummaryDialog(
                                      name: update['name'],
                                      currentVersion: update['current_version'],
                                      nextVersion: update['new_version'],
                                    ),
                                  ),
                                );
                              },
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final taskController = context.read<TaskController>();
                                final l10n = AppLocalizations.of(context)!;
                                if (taskController.isBusy) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.taskInProgress)),
                                  );
                                  return;
                                }
                                UpdateService().startUpdate(
                                  update['id'] ?? update['name'],
                                  update['source'] == 'Pacman'
                                      ? 'Native'
                                      : update['source'],
                                );
                                onUpdateStarted();
                              },
                              child: Text(AppLocalizations.of(context)!.update),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
