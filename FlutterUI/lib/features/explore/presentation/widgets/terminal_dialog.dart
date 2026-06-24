import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/explore/presentation/widgets/ai_dialogs.dart';
import 'package:frontend/data/repositories/ai_repository.dart';

class TerminalDialog extends StatelessWidget {
  const TerminalDialog({super.key});

  Future<void> _showAIErrorAnalysis(BuildContext context, String logs) async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiAnalyzeError(logs);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiPromptError,
        future: future,
        width: 600,
        height: 450,
      ),
    );
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: AppLocalizations.of(context)!.windowClose,
                    button: true,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: AppLocalizations.of(context)!.windowClose,
                    ),
                  ),
                ],
              ),
            ),
            Consumer2<SettingsController, TaskController>(
              builder: (context, settings, task, _) {
                if (!task.logs.any((l) => l.contains("[ERROR]"))) {
                  return const SizedBox.shrink();
                }
                if (!settings.isAIEnabled) {
                  return const SizedBox.shrink();
                }

                return Container(
                  width: double.infinity,
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.3,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.aiAnalysisPrompt,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            _showAIErrorAnalysis(context, task.logs.join("\n")),
                        child: Text(
                          AppLocalizations.of(context)!.analyzeNow,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Selector<TaskController, ({int length, List<String> logs})>(
                selector: (context, c) => (length: c.logs.length, logs: c.logs),
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
