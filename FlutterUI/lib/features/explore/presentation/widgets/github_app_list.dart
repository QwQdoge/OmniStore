import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/github_star_badge.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class GitHubAppList extends StatelessWidget {
  final List<AppPackage> apps;
  final bool isLoading;
  final String keyPrefix;
  final VoidCallback onRetry;
  final String emptyText;
  final IconData emptyIcon;
  final String emptySubtitle;
  final bool showRetry;

  const GitHubAppList({
    super.key,
    required this.apps,
    required this.isLoading,
    required this.keyPrefix,
    required this.onRetry,
    this.emptyText = "No packages available",
    this.emptyIcon = Icons.cloud_off_rounded,
    this.emptySubtitle = "",
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isLoading) {
      content = const GitHubAppListSkeleton(key: ValueKey('loading'));
    } else if (apps.isEmpty) {
      content = Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (emptySubtitle.isNotEmpty) ...[
              Text(
                emptySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            if (showRetry)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
              ),
          ],
        ),
      );
    } else {
      final client = context.read<GitHubClient>();
      final scheme = Theme.of(context).colorScheme;

      content = ListView.builder(
      key: PageStorageKey<String>('github_store_$keyPrefix'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final repoUrl = app.url ?? app.homepage;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            label: 'App: ${app.name}',
            button: true,
            child: AppCard(
              borderRadius: 16,
              color: scheme.surfaceContainerLow,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
              ),
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Icon
                  Hero(
                    tag: 'app_icon_${app.id}_$keyPrefix',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        width: 56,
                        height: 56,
                        child: app.icon != null
                            ? CachedNetworkImage(
                                imageUrl: app.icon!,
                                width: 56,
                                height: 56,
                                memCacheWidth: 112,
                                memCacheHeight: 112,
                                fit: BoxFit.cover,
                                errorWidget: (c, e, s) =>
                                    const Icon(Icons.code_rounded, size: 28),
                              )
                            : const Icon(Icons.code_rounded, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // App Info Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stars Badge
                            if (GitHubClient.parseUrl(repoUrl) != null)
                              GitHubStarBadge(
                                client: client,
                                repositoryUrl: repoUrl,
                                compact: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.description.isNotEmpty
                              ? app.description
                              : "No description provided.",
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Show source
                            AppSourceTag(
                              source: app.primarySource,
                              mode: AppSourceTagMode.source,
                            ),
                            const Spacer(),
                            // Detail link indication
                            Text(
                              "View Details",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: content,
    );
  }
}

class GitHubAppListSkeleton extends StatelessWidget {
  const GitHubAppListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card.filled(
          margin: const EdgeInsets.only(bottom: 12),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 56, height: 56, borderRadius: 16),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Skeleton(width: 140, height: 18),
                          Skeleton(width: 60, height: 20, borderRadius: 6),
                        ],
                      ),
                      SizedBox(height: 8),
                      Skeleton(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      Skeleton(width: 200, height: 14),
                      SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Skeleton(width: 80, height: 22, borderRadius: 6),
                          Skeleton(width: 70, height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
