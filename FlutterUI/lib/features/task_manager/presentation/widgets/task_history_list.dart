import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/core/widgets/app_card.dart';

class TaskHistoryList extends StatelessWidget {
  const TaskHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final historyLength = context.select<TaskController, int>(
      (c) => c.completedTasks.length,
    );

    if (historyLength == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
      sliver: Selector<
        TaskController,
        ({int length, List<TaskState> history})
      >(
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
          return SliverList.builder(
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
                      color: isSuccess
                          ? Colors.green
                          : Colors.red,
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
                          color: theme
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(
                            6,
                          ),
                        ),
                        child: Text(
                          task.stage,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme
                                .colorScheme
                                .onPrimaryContainer,
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
    );
  }
}