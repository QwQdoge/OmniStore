import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      icon: Icon(
        Icons.terminal_rounded,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: Text(
        l10n.terminalOutput,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Card(
          color: theme.colorScheme.surfaceContainerLow,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Selector<
                TaskController,
                ({String status, double? progress, bool isBusy})
              >(
                selector: (context, c) =>
                    (status: c.status, progress: c.progress, isBusy: c.isBusy),
                builder: (context, data, _) {
                  if (!data.isBusy && data.status == "Ready") {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: theme.colorScheme.surfaceContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        SmoothSizeSwitcher(
                          alignment: Alignment.topCenter,
                          child: data.progress != null
                              ? TweenAnimationBuilder<double>(
                                  key: const ValueKey('determinate'),
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: data.progress!,
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return LinearProgressIndicator(
                                      value: value,
                                    );
                                  },
                                )
                              : const LinearProgressIndicator(
                                  key: ValueKey('indeterminate'),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child:
                    Selector<TaskController, ({int length, List<String> logs})>(
                      selector: (context, c) =>
                          (length: c.logs.length, logs: c.logs),
                      shouldRebuild: (prev, next) =>
                          prev.length != next.length ||
                          !const IterableEquality().equals(
                            prev.logs,
                            next.logs,
                          ),
                      builder: (context, data, _) {
                        final logs = data.logs;
                        return logs.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.waitingForOutput,
                                  style: TextStyle(
                                    color: theme.colorScheme.outline,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(16),
                                itemCount: logs.length,
                                prototypeItem: const Text(
                                  '',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                itemBuilder: (context, i) {
                                  final log = logs[logs.length - 1 - i];
                                  Color textColor = theme.colorScheme.onSurface;
                                  if (log.contains("[ERROR]")) {
                                    textColor = theme.colorScheme.error;
                                  }
                                  if (log.contains("[INFO]")) {
                                    textColor = theme.colorScheme.primary;
                                  }
                                  return Text(
                                    log,
                                    style: TextStyle(
                                      color: textColor,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  );
                                },
                              );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
