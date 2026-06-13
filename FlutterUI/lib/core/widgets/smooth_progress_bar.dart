import 'package:flutter/material.dart';
import 'package:frontend/models/task_state.dart';
import 'package:frontend/l10n/app_localizations.dart';

/// A premium progress bar that supports smooth transitions, customizable theme styling,
/// and color seed mapping. Includes micro-animations/transitions for state changes.
class SmoothProgressBar extends StatelessWidget {
  final TaskState taskState;
  final VoidCallback? onCancel;
  final Color? customColor;
  final Color? customBackgroundColor;
  final double? height;
  final BorderRadius? borderRadius;

  const SmoothProgressBar({
    super.key,
    required this.taskState,
    this.onCancel,
    this.customColor,
    this.customBackgroundColor,
    this.height,
    this.borderRadius,
  });

  String _getDisplayMessage(AppLocalizations l10n) {
    String displayMessage = taskState.message;
    if (taskState.messageKey != null) {
      switch (taskState.messageKey) {
        case "taskInitializing":
          displayMessage = l10n.taskInitializing;
          break;
        case "taskStarting":
          displayMessage = l10n.taskStarting;
          break;
        case "taskSuccess":
          displayMessage = l10n.taskSuccess;
          break;
        case "taskFailedWithCode":
          displayMessage = l10n.taskFailedWithCode(
            taskState.messageArgs?['code'] ?? -1,
          );
          break;
        case "taskCancelledByUser":
          displayMessage = l10n.taskCancelledByUser;
          break;
        case "taskError":
          displayMessage = l10n.taskError(
            taskState.messageArgs?['error'] ?? "Unknown error",
          );
          break;
      }
    }
    return displayMessage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = taskState.status == TaskStatus.failed;
    final isSuccess = taskState.status == TaskStatus.success;
    final isIndeterminate = taskState.progress < 0;

    // Determine target color based on task status and custom theme override
    final Color targetColor;
    if (customColor != null) {
      targetColor = customColor!;
    } else if (isFailed) {
      targetColor = theme.colorScheme.error;
    } else if (isSuccess) {
      targetColor = const Color(0xFF10B981); // Premium emerald green for success
    } else {
      targetColor = theme.colorScheme.primary;
    }

    final l10n = AppLocalizations.of(context)!;
    final displayMessage = _getDisplayMessage(l10n);

    // Transition colors smoothly when state changes
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: targetColor),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, animatedColor, _) {
        final currentColor = animatedColor ?? targetColor;
        final currentBgColor = customBackgroundColor ?? currentColor.withValues(alpha: 0.1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TaskHeaderRow(
              taskState: taskState,
              isFailed: isFailed,
              displayMessage: displayMessage,
              textColor: isFailed ? theme.colorScheme.error : null,
            ),
            const SizedBox(height: 8),
            _ProgressIndicatorStack(
              taskState: taskState,
              isFailed: isFailed,
              isIndeterminate: isIndeterminate,
              color: currentColor,
              backgroundColor: currentBgColor,
              height: height ?? 12,
              borderRadius: borderRadius ?? BorderRadius.circular(6.0),
              onCancel: onCancel,
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
      },
    );
  }
}

class _TaskHeaderRow extends StatelessWidget {
  final TaskState taskState;
  final bool isFailed;
  final String displayMessage;
  final Color? textColor;

  const _TaskHeaderRow({
    required this.taskState,
    required this.isFailed,
    required this.displayMessage,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (taskState.stage.isNotEmpty && !isFailed)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                taskState.stage.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              displayMessage,
              key: ValueKey<String>(displayMessage),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: textColor ?? theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    );
  }
}

class _ProgressIndicatorStack extends StatelessWidget {
  final TaskState taskState;
  final bool isFailed;
  final bool isIndeterminate;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onCancel;

  const _ProgressIndicatorStack({
    required this.taskState,
    required this.isFailed,
    required this.isIndeterminate,
    required this.color,
    required this.backgroundColor,
    required this.height,
    required this.borderRadius,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: isIndeterminate && !isFailed
                ? LinearProgressIndicator(
                    backgroundColor: backgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: isFailed ? 1.0 : taskState.progress,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: backgroundColor,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      );
                    },
                  ),
          ),
        ),
        if (onCancel != null &&
            taskState.status != TaskStatus.success &&
            taskState.status != TaskStatus.failed)
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  taskState.status == TaskStatus.failed ||
                          taskState.status == TaskStatus.success
                      ? Icons.check
                      : Icons.close,
                  size: 14,
                  color: taskState.status == TaskStatus.failed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
