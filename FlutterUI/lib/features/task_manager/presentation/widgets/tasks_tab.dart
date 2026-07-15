import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/core/widgets/smooth_progress_bar.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'terminal_dialog.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isBusy = context.select<TaskController, bool>((c) => c.isBusy);
    final historyLength = context.select<TaskController, int>(
      (c) => c.completedTasks.length,
    );
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget content;

    if (!isBusy && historyLength == 0) {
      content = EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.task_alt,
        title: l10n.noActiveTasks,
      );
    } else {
      content = SingleChildScrollView(
        key: const ValueKey('list'),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBusy) ...[
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
                                  data.packageName ?? l10n.taskProcessing,
                              status: TaskStatus.downloading,
                              progress: data.progress ?? 0.0,
                              stage: data.status,
                              speed: data.speed,
                            ),
                            onCancel: () =>
                                context.read<TaskController>().cancelTask(l10n),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
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
            if (historyLength > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.taskHistory,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        context.read<TaskController>().clearHistory(),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text(l10n.clearHistoryShort),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Selector<TaskController, ({int length, List<TaskState> history})>(
                selector: (context, c) => (
                  length: c.completedTasks.length,
                  history: c.completedTasks,
                ),
                shouldRebuild: (prev, next) =>
                    prev.length != next.length ||
                    !const IterableEquality().equals(
                      prev.history,
                      next.history,
                    ),
                builder: (context, data, child) {
                  final history = data.history;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final task = history[index];
                      final isSuccess = task.status == TaskStatus.success;
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        borderRadius: 12.0,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSuccess
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            child: Icon(
                              isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: isSuccess ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                task.packageName ?? l10n.unknownApp,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  task.stage,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            isSuccess
                                ? l10n.taskSuccessMsg
                                : l10n.failureReason(task.message),
                            style: TextStyle(
                              color: isSuccess
                                  ? Colors.grey
                                  : Colors.red.shade900,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            task.source ?? "",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.fastOutSlowIn,
        child: content,
      ),
    );
  }
}
