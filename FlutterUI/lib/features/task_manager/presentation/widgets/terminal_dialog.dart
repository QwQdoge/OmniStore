import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:collection/collection.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
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
