import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/core/widgets/smooth_progress_bar.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'terminal_dialog.dart';

class ActiveTaskSection extends StatelessWidget {
  const ActiveTaskSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = context.select<TaskController, bool>((c) => c.isBusy);

    return SmoothSizeSwitcher(
      alignment: Alignment.topCenter,
      child: isBusy
          ? Column(
              key: const ValueKey('active_task_block'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentTask,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  elevation: 2,
                  borderRadius: 16.0,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Selector<
                          TaskController,
                          ({
                            String? packageName,
                            double? progress,
                            String status,
                            String speed,
                          })
                        >(
                          selector: (context, c) => (
                            packageName: c.packageName,
                            progress: c.progress,
                            status: c.status,
                            speed: c.speed,
                          ),
                          builder: (context, data, child) {
                            return SmoothProgressBar(
                              taskState: TaskState(
                                id: "active",
                                packageName:
                                    data.packageName ??
                                    l10n.taskProcessing,
                                status: TaskStatus.downloading,
                                progress: data.progress ?? 0.0,
                                stage: data.status,
                                speed: data.speed,
                              ),
                              onCancel: () => context
                                  .read<TaskController>()
                                  .cancelTask(l10n),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const TerminalDialog(),
                              ),
                              icon: const Icon(Icons.terminal_rounded),
                              label: Text(l10n.terminalOutput),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('active_task_hidden')),
    );
  }
}