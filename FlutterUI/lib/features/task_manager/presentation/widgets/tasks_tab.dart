import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

import 'active_task_section.dart';
import 'task_history_header.dart';
import 'task_history_list.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isBusy = context.select<TaskController, bool>((c) => c.isBusy);
    final historyLength = context.select<TaskController, int>(
      (c) => c.completedTasks.length,
    );
    final l10n = AppLocalizations.of(context)!;

    Widget content;

    if (!isBusy && historyLength == 0) {
      content = EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.task_alt,
        title: l10n.noActiveTasks,
      );
    } else {
      content = CustomScrollView(
        key: const ValueKey('list'),
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
              child: ActiveTaskSection(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 24.0, right: 24.0),
              child: TaskHistoryHeader(),
            ),
          ),
          const TaskHistoryList(),
        ],
      );
    }

    return SmoothSizeSwitcher(alignment: Alignment.topCenter, child: content);
  }
}