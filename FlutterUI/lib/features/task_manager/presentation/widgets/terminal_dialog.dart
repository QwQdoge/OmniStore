import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _logColor(ThemeData theme, TaskLogLevel level) {
    return switch (level) {
      TaskLogLevel.debug => theme.colorScheme.onSurfaceVariant,
      TaskLogLevel.info => theme.colorScheme.onSurface,
      TaskLogLevel.warning => theme.colorScheme.tertiary,
      TaskLogLevel.error => theme.colorScheme.error,
      TaskLogLevel.success => theme.colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28.0),
                  topRight: Radius.circular(28.0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.terminalOutput,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: AppLocalizations.of(context)!.windowClose,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
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
                    vertical: 8,
                  ),
                  color: theme.colorScheme.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                                  return LinearProgressIndicator(value: value);
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
              // ⚡ Bolt: Selector uses O(1) logVersion scalar integer comparison instead of O(N)
              // IterableEquality iteration over all log items on every notification.
              child:
                  Selector<
                    TaskController,
                    ({int version, List<TaskLogEntry> logs})
                  >(
                    selector: (context, c) =>
                        (version: c.logVersion, logs: c.logEntries),
                    shouldRebuild: (prev, next) => prev.version != next.version,
                    builder: (context, data, _) {
                      final logs = data.logs;
                      return logs.isEmpty
                          ? Center(
                              child: Text(
                                AppLocalizations.of(context)!.waitingForOutput,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(12),
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
                                final entry = logs[logs.length - 1 - i];
                                final time = _formatTime(entry.timestamp);
                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$time  ',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      TextSpan(
                                        text: entry.message,
                                        style: TextStyle(
                                          color: _logColor(theme, entry.level),
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(
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
    );
  }
}
