import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AITestResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String msg;

  const AITestResultDialog({
    super.key,
    required this.isSuccess,
    required this.msg,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: isSuccess ? colorScheme.primary : colorScheme.error,
        size: 32,
      ),
      title: Text(
        isSuccess ? l10n.aiTestSuccess : l10n.failed,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: msg.isNotEmpty
          ? Card(
              color: colorScheme.surfaceContainerLow,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSuccess
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  msg,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            )
          : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
