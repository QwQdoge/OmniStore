import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_shelf.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class RecommendationShelf extends StatelessWidget {
  final String categoryKey;
  final String Function(AppLocalizations) titleBuilder;
  final ScrollController scrollController;
  final String emptyMessage;

  const RecommendationShelf({
    super.key,
    required this.categoryKey,
    required this.titleBuilder,
    required this.scrollController,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<BrowseController, List<AppPackage>>(
      selector: (context, browse) =>
          browse.recommendations[categoryKey] ?? [],
      shouldRebuild: (prev, next) =>
          !const IterableEquality().equals(prev, next),
      builder: (context, apps, _) {
        return SmoothSizeSwitcher(
          alignment: Alignment.topCenter,
          child: apps.isEmpty
              ? _DynamicSectionEmpty(
                  key: ValueKey('empty_$categoryKey'),
                  message: emptyMessage,
                )
              : AppShelf(
                  key: ValueKey('${categoryKey}_shelf'),
                  title: titleBuilder(l10n),
                  apps: apps,
                  scrollController: scrollController,
                ),
        );
      },
    );
  }
}

class _DynamicSectionEmpty extends StatelessWidget {
  const _DynamicSectionEmpty({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
