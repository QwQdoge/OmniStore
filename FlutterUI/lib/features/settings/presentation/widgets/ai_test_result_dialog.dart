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

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: Icon(
        isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
        color: isSuccess ? theme.colorScheme.primary : theme.colorScheme.error,
        size: 32,
      ),
      title: Text(
        isSuccess ? l10n.aiTestSuccess : l10n.failed,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: msg.isNotEmpty
          ? SingleChildScrollView(
              child: Card(
                color: theme.colorScheme.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SelectableText(
                    msg,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            )
          : null,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
