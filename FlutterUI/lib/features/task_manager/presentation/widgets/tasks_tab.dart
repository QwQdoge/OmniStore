import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/widgets/smooth_progress_bar.dart';
import 'terminal_dialog.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TaskController, bool>(
      selector: (context, controller) => controller.isBusy,
      builder: (context, isBusy, _) {
        if (!isBusy) {
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
                  AppLocalizations.of(context)!.noActiveTasks,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.currentTask,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Consumer<TaskController>(
                        builder: (context, taskController, _) =>
                            SmoothProgressBar(
                              taskState: TaskState(
                                id: "active",
                                packageName: AppLocalizations.of(
                                  context,
                                )!.taskProcessing,
                                status: TaskStatus.downloading,
                                progress: taskController.progress ?? 0.0,
                                stage: taskController.status,
                                speed: taskController.speed,
                              ),
                              onCancel: () => taskController.cancelTask(
                                AppLocalizations.of(context)!,
                              ),
                            ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const TerminalDialog(),
                            ),
                            icon: const Icon(Icons.terminal, size: 18),
                            label: Text(AppLocalizations.of(context)!.viewLogs),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
