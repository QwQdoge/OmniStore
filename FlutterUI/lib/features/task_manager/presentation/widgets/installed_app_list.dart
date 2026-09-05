import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/empty_state.dart';

class InstalledAppList extends StatelessWidget {
  final List<AppPackage> filteredApps;

  const InstalledAppList({super.key, required this.filteredApps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (filteredApps.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: AppLocalizations.of(context)!.noResults,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        final sizeText = app.diskSize ?? app.installedSize ?? app.downloadSize;
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            label: '${l10n.installedApps}: ${app.name}',
            button: true,
            child: AppCard(
              borderRadius: 16,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppDetailsPage(app: app),
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: app.icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: app.icon!,
                          width: 40,
                          height: 40,
                          memCacheWidth: 80,
                          memCacheHeight: 80,
                          placeholder: (context, url) => const Skeleton(
                            width: 40,
                            height: 40,
                            borderRadius: 16,
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.apps),
                        ),
                      )
                    : const Icon(Icons.apps, size: 40),
                title: Text(
                  app.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      AppSourceTag(
                        source: app.primarySource,
                        mode: AppSourceTagMode.source,
                        isSmall: true,
                      ),
                      if (!app.managed) ...[
                        const SizedBox(width: 6),
                        const AppSourceTag(
                          source: '',
                          mode: AppSourceTagMode.managed,
                          isSmall: true,
                        ),
                      ],
                      if (sizeText != null &&
                          sizeText.toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          sizeText.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
