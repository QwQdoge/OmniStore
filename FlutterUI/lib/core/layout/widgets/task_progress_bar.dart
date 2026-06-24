import 'package:flutter/material.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Consumer<TaskController>(
        builder: (context, task, child) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.downloading_rounded,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.processing} ${task.status} ${task.speed}',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.progress != null)
                    Text(
                      '${(task.progress! * 100).toInt()}%',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: task.progress != null && task.progress! >= 0
                  ? TweenAnimationBuilder<double>(
                      key: const ValueKey('determinate'),
                      tween: Tween<double>(
                        begin: 0,
                        end: task.progress!,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 3,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        );
                      },
                    )
                  : LinearProgressIndicator(
                      key: const ValueKey('indeterminate'),
                      minHeight: 3,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
