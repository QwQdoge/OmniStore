import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AppAboutSection extends StatelessWidget {
  final bool isLoading;
  final String? description;
  final String fallbackDescription;

  const AppAboutSection({
    super.key,
    required this.isLoading,
    this.description,
    required this.fallbackDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return const ParagraphSkeleton();
    }

    return MarkdownBody(
      data:
          description ??
          (fallbackDescription.isEmpty ? l10n.noResults : fallbackDescription),
      selectable: true,
      styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyLarge),
    );
  }
}
