import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.terminalOutput,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<TaskController>(
                builder: (context, controller, _) {
                  final logs = controller.logs;
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
                              textColor = Colors.redAccent;
                            }
                            if (log.contains("[INFO]")) {
                              textColor = Colors.greenAccent.shade400;
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
