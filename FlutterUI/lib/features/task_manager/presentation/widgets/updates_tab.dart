import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/data/repositories/package_repository.dart';
import 'package:frontend/services/update_service.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'ai_update_summary_dialog.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class UpdatesTab extends StatelessWidget {
  final VoidCallback onUpdateStarted;

  const UpdatesTab({super.key, required this.onUpdateStarted});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;

        Widget content;

        if (updates.isEmpty) {
          content = EmptyState(
            key: const ValueKey('empty'),
            icon: Icons.check_circle_outline,
            title: AppLocalizations.of(context)!.allUpdated,
          );
        } else {
          content = Column(
            key: const ValueKey('list'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.foundUpdates(updates.length),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final taskController = context.read<TaskController>();
                        final l10n = AppLocalizations.of(context)!;
                        if (taskController.isBusy) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.taskInProgress),
                              duration: const Duration(seconds: 4),
                            ),
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
                  prototypeItem: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      borderRadius: 16,
                      child: ListTile(
                        leading: const SizedBox(width: 44, height: 44),
                        title: const SizedBox(height: 16),
                        subtitle: const SizedBox(height: 12),
                        trailing: const SizedBox(width: 80, height: 32),
                      ),
                    ),
                  ),
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
                            final packageRepo = context
                                .read<PackageRepository>();
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  AppSourceTag(
                                    source: update['source'] ?? 'Native',
                                    mode: AppSourceTagMode.source,
                                    isSmall: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${update['current_version']} → ${update['new_version']}",
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Selector<SettingsController, bool>(
                                  selector: (context, settings) =>
                                      settings.isAIEnabled,
                                  builder: (context, isAIEnabled, _) {
                                    if (!isAIEnabled) {
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
                                          currentVersion:
                                              update['current_version'],
                                          nextVersion: update['new_version'],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final taskController = context
                                        .read<TaskController>();
                                    final l10n = AppLocalizations.of(context)!;
                                    if (taskController.isBusy) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.taskInProgress),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      return;
                                    }
                                    taskController.runTask(
                                      '-U',
                                      update['id'] ?? update['name'],
                                      update['source'] == 'Pacman'
                                          ? 'Native'
                                          : update['source'],
                                      l10n,
                                    );
                                    onUpdateStarted();
                                  },
                                  child: Text(
                                    AppLocalizations.of(context)!.update,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return SmoothSizeSwitcher(
          alignment: Alignment.topCenter,
          child: content,
        );
      },
    );
  }
}
