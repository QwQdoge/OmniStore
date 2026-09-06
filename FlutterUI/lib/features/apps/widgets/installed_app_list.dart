import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class InstalledAppList extends StatelessWidget {
  final List<AppPackage> filteredApps;
  final Future<void> Function() onRefresh;

  const InstalledAppList({
    super.key,
    required this.filteredApps,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredApps.length,
        itemBuilder: (context, index) {
          final app = filteredApps[index];
          final heroTag = 'installed-app-${app.name}-${app.primarySource}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              label:
                  '${l10n.installedApps}: ${app.name} (${app.primarySource})',
              button: true,
              child: AppCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AppDetailsPage(app: app, heroTag: heroTag),
                  ),
                ),
                child: ListTile(
                  leading: Hero(
                    tag: heroTag,
                    child: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: app.icon!,
                              width: 40,
                              height: 40,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                              errorWidget: (c, e, s) => const Icon(Icons.apps),
                            ),
                          )
                        : const Icon(Icons.apps, size: 40),
                  ),
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
}
