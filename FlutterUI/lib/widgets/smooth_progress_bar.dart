import 'package:flutter/material.dart';
import '../models/task_state.dart';

class SmoothProgressBar extends StatelessWidget {
  final TaskState taskState;
  final VoidCallback? onCancel;

  const SmoothProgressBar({
    super.key,
    required this.taskState,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = taskState.status == TaskStatus.failed;
    final isIndeterminate = taskState.progress < 0;

    final color = isFailed ? theme.colorScheme.error : theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                taskState.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isFailed ? theme.colorScheme.error : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (taskState.speed.isNotEmpty && !isFailed)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  taskState.speed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            SizedBox(
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: isIndeterminate && !isFailed
                    ? LinearProgressIndicator(
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: isFailed ? 1.0 : taskState.progress),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          );
                        },
                      ),
              ),
            ),
            if (onCancel != null && taskState.status != TaskStatus.success && taskState.status != TaskStatus.failed)
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: Icon(
                      taskState.status == TaskStatus.failed || taskState.status == TaskStatus.success
                          ? Icons.check
                          : Icons.close,
                      size: 14,
                      color: taskState.status == TaskStatus.failed ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!isIndeterminate && !isFailed)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "${(taskState.progress * 100).toInt()}%",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
