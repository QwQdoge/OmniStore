import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/core/widgets/section_header.dart';

class AppShelf extends StatelessWidget {
  final String title;
  final List<AppPackage> apps;
  final ScrollController scrollController;

  const AppShelf({
    super.key,
    required this.title,
    required this.apps,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        SectionHeader(title: title),
        const SizedBox(height: 16),
        SizedBox(
          height: 182,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: apps.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final app = apps[index];
                final heroTag = 'app-shelf-${key.toString()}-${app.name}-${app.primarySource}';
                return SizedBox(
                  width: 130,
                  child: AppCard(
                    borderRadius: 16,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AppDetailsPage(app: app, heroTag: heroTag),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Hero(
                          tag: heroTag,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: app.icon != null
                                ? CachedNetworkImage(
                                    imageUrl: app.icon!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    memCacheHeight: 200,
                                    errorWidget: (c, e, s) =>
                                        const Icon(Icons.apps),
                                  )
                                : const Icon(Icons.apps, size: 40),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
