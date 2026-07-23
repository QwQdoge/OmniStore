import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AITestResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String message;

  const AITestResultDialog({
    super.key,
    required this.isSuccess,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(isSuccess ? l10n.aiTestSuccess : l10n.failed),
        ],
      ),
      content: message.isNotEmpty ? SelectableText(message) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
