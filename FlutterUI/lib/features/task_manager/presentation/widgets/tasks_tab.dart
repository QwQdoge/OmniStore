import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/core/widgets/smooth_progress_bar.dart';
import 'terminal_dialog.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isBusy = context.select<TaskController, bool>((c) => c.isBusy);
    final historyLength = context.select<TaskController, int>((c) => c.completedTasks.length);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!isBusy && historyLength == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noActiveTasks,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBusy) ...[
            Text(
              l10n.currentTask,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Consumer<TaskController>(
                      builder: (context, taskController, child) {
                        return SmoothProgressBar(
                          taskState: TaskState(
                            id: "active",
                            packageName:
                                taskController.packageName ?? l10n.taskProcessing,
                            status: TaskStatus.downloading,
                            progress: taskController.progress ?? 0.0,
                            stage: taskController.status,
                            speed: taskController.speed,
                          ),
                          onCancel: () => taskController.cancelTask(l10n),
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
                          icon: const Icon(Icons.terminal_outlined),
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
                const Text(
                  "任务历史记录 (History)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                TextButton.icon(
                  onPressed: () => context.read<TaskController>().clearHistory(),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text("清空历史"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<TaskController>(
              builder: (context, taskController, child) {
                final history = taskController.completedTasks;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final task = history[index];
                    final isSuccess = task.status == TaskStatus.success;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                              task.packageName ?? "Unknown App",
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                          isSuccess ? "任务执行成功" : "失败原因: ${task.message}",
                          style: TextStyle(
                            color: isSuccess ? Colors.grey : Colors.red.shade900,
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
}
