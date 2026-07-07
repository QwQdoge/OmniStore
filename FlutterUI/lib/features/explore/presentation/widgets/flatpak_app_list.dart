import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class FlatpakAppList extends StatelessWidget {
  final List<AppPackage> apps;
  final bool isLoading;
  final bool isDesktop;
  final AppPackage? selectedApp;
  final Future<void> Function() onRetry;
  final ValueChanged<AppPackage> onAppSelected;

  const FlatpakAppList({
    super.key,
    required this.apps,
    required this.isLoading,
    required this.isDesktop,
    this.selectedApp,
    required this.onRetry,
    required this.onAppSelected,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (apps.isEmpty && !isLoading) {
      content = Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noResults,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.checkNetwork,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    } else if (isLoading) {
      content = const FlatpakAppListSkeleton(key: ValueKey('loading'));
    } else {
      content = RefreshIndicator(
        key: const ValueKey('list'),
        onRefresh: onRetry,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          prototypeItem: const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppCard(borderRadius: 8, child: SizedBox(height: 100)),
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            final isSelected = selectedApp?.id == app.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                label: 'App: ${app.name}',
                button: true,
                child: AppCard(
                  borderRadius: 8,
                  color: isSelected && isDesktop
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  onTap: () {
                    if (isDesktop) {
                      onAppSelected(app);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppDetailsPage(app: app),
                        ),
                      );
                    }
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: app.icon!,
                              width: 44,
                              height: 44,
                              memCacheWidth: 88,
                              errorWidget: (c, e, s) =>
                                  const Icon(Icons.shopping_bag_rounded),
                            ),
                          )
                        : const Icon(Icons.shopping_bag_rounded, size: 44),
                    title: Text(
                      app.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      app.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: AppSourceTag(
                      source: app.primarySource,
                      mode: AppSourceTagMode.source,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.fastOutSlowIn,
      child: content,
    );
  }
}

class FlatpakAppListSkeleton extends StatelessWidget {
  const FlatpakAppListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppCard(
            borderRadius: 8,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Skeleton(width: 44, height: 44, borderRadius: 12),
              title: Skeleton(width: 120, height: 16),
              subtitle: Skeleton(
                width: double.infinity,
                height: 12,
                borderRadius: 8,
              ),
              trailing: Skeleton(width: 60, height: 24, borderRadius: 12),
            ),
          ),
        );
      },
    );
  }
}
