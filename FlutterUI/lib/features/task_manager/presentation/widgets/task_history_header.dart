import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class TaskHistoryHeader extends StatelessWidget {
  const TaskHistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final historyLength = context.select<TaskController, int>(
      (c) => c.completedTasks.length,
    );

    return SmoothSizeSwitcher(
      alignment: Alignment.topCenter,
      child: historyLength > 0
          ? Column(
              key: const ValueKey('task_history_header'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        size: 18,
                      ),
                      label: Text(l10n.clearHistoryShort),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('task_history_header_hidden')),
    );
  }
}