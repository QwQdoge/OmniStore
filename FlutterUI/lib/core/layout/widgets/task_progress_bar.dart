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
      child:
          Selector<
            TaskController,
            ({double? progress, String status, String speed})
          >(
            selector: (context, c) =>
                (progress: c.progress, status: c.status, speed: c.speed),
            builder: (context, data, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
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
                          data.status.isEmpty ? l10n.processing : data.status,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (data.progress != null && data.progress! >= 0)
                        Text(
                          '${(data.progress! * 100).toInt()}%',
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (data.progress != null && data.progress! >= 0)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      end: data.progress!.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.primary,
                        ),
                      );
                    },
                  )
                else
                  LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
              ],
            ),
          ),
    );
  }
}
