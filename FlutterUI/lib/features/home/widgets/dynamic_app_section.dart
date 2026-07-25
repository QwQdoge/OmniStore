import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_shelf.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'dynamic_section_empty.dart';

class DynamicAppSection extends StatelessWidget {
  final String recommendationKey;
  final ValueKey emptyKey;
  final String emptyMessage;
  final ValueKey shelfKey;
  final String title;
  final ScrollController scrollController;

  const DynamicAppSection({
    super.key,
    required this.recommendationKey,
    required this.emptyKey,
    required this.emptyMessage,
    required this.shelfKey,
    required this.title,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<BrowseController, List<AppPackage>>(
      selector: (context, browse) =>
          browse.recommendations[recommendationKey] ?? [],
      shouldRebuild: (prev, next) =>
          !const IterableEquality().equals(prev, next),
      builder: (context, apps, _) {
        return SmoothSizeSwitcher(
          alignment: Alignment.topCenter,
          child: apps.isEmpty
              ? DynamicSectionEmpty(
                  key: emptyKey,
                  message: emptyMessage,
                )
              : AppShelf(
                  key: shelfKey,
                  title: title,
                  apps: apps,
                  scrollController: scrollController,
                ),
        );
      },
    );
  }
}
