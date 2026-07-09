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

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.fastOutSlowIn,
        child: isLoading
          ? const ParagraphSkeleton(key: ValueKey('loading'))
          : MarkdownBody(
              key: const ValueKey('loaded'),
              data: description ??
                  (fallbackDescription.isEmpty
                      ? l10n.noResults
                      : fallbackDescription),
              selectable: true,
              styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyLarge),
            ),
      ),
    );
  }
}
