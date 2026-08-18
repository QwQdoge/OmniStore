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
      icon: Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
      title: Text(
        l10n.howToGetApiKey,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        l10n.howToGetApiKeyDesc,
        style: const TextStyle(height: 1.5),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
