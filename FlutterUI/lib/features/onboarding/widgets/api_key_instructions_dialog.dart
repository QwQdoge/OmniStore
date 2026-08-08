import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ApiKeyInstructionsDialog extends StatelessWidget {
  const ApiKeyInstructionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: Row(
        children: [
          Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            l10n.howToGetApiKey,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: Text(
        l10n.howToGetApiKeyDesc,
        style: const TextStyle(height: 1.5),
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
