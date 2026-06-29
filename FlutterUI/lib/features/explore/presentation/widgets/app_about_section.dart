import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';

class AppAboutSection extends StatelessWidget {
  final bool isLoadingDetails;
  final Map<String, dynamic>? extraDetails;
  final String appDescription;

  const AppAboutSection({
    super.key,
    required this.isLoadingDetails,
    required this.extraDetails,
    required this.appDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailsSectionTitle(title: AppLocalizations.of(context)!.about),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoadingDetails
              ? const ParagraphSkeleton(key: ValueKey('loading'))
              : MarkdownBody(
                  key: const ValueKey('loaded'),
                  data: extraDetails?['description'] ??
                      (appDescription.isEmpty
                          ? AppLocalizations.of(context)!.noResults
                          : appDescription),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyLarge),
                ),
        ),
      ],
    );
  }
}
