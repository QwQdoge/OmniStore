import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
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
                  TextButton.icon(
                    onPressed: () async {
                      final logs = context.read<TaskController>().logs;
                      if (logs.isEmpty) return;
                      showDialog(
                        context: context,
                        builder: (context) => FutureBuilder<String>(
                          future: BackendService.instance.aiAnalyzeError(logs.join('\n')),
                          builder: (context, snapshot) {
                            return AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text('AI 错误日志诊断分析'),
                                ],
                              ),
                              content: SingleChildScrollView(
                                child: Text(
                                  snapshot.data ?? (snapshot.hasError ? '诊断时出现错误: ${snapshot.error}' : '正在分析错误日志并生成排查建议...'),
                                  style: const TextStyle(height: 1.4),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('关闭'),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                    label: const Text('AI 诊断'),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: AppLocalizations.of(context)!.windowClose,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: AppLocalizations.of(context)!.windowClose,
                      onPressed: () => Navigator.pop(context),
                    ),
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
              child:
                  Selector<TaskController, ({int length, List<String> logs})>(
                    selector: (context, c) =>
                        (length: c.logs.length, logs: c.logs),
                    shouldRebuild: (prev, next) =>
                        prev.length != next.length ||
                        !const IterableEquality().equals(prev.logs, next.logs),
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
    );
  }
}
