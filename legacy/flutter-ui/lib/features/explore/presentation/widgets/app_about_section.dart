import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AppAboutSection extends StatelessWidget {
  final String? description;
  final String fallbackDescription;

  const AppAboutSection({
    super.key,
    this.description,
    required this.fallbackDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MarkdownBody(
      key: const ValueKey('loaded'),
      data:
          description ??
          (fallbackDescription.isEmpty ? l10n.noResults : fallbackDescription),
      selectable: true,
      styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyLarge),
    );
  }
}
