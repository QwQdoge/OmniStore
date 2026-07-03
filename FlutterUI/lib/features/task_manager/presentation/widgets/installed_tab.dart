import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/task_manager/presentation/widgets/installed_app_list_skeleton.dart';

class InstalledTab extends StatelessWidget {
  final bool isLoading;
  final String selectedSourceFilter;
  final List<AppPackage> filteredApps;
  final ScrollController filterScrollController;
  final ValueChanged<String> onSourceFilterSelected;

  const InstalledTab({
    super.key,
    required this.isLoading,
    required this.selectedSourceFilter,
    required this.filteredApps,
    required this.filterScrollController,
    required this.onSourceFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = _buildFilters();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.fastOutSlowIn,
      child: isLoading
          ? const InstalledAppListSkeleton(key: ValueKey('loading'))
          : Column(
              key: const ValueKey('loaded'),
              children: [
                SizedBox(
                  height: 66,
                  child: Scrollbar(
                    controller: filterScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: filterScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: filters
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_filterLabel(context, s)),
                                  selected: selectedSourceFilter == s,
                                  onSelected: (v) {
                                    if (v) {
                                      onSourceFilterSelected(s);
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildInstalledList(context)),
              ],
            ),
    );
  }

  List<String> _buildFilters() {
    final sources =
        filteredApps
            .expand((app) => {...app.sources, app.primarySource})
            .where((source) => source.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['all', 'managed', 'unmanaged', ...sources];
  }

  String _filterLabel(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'all':
        return l10n.all;
      case 'managed':
        return l10n.managed;
      case 'unmanaged':
        return l10n.readOnly;
      default:
        return value;
    }
  }

  Widget _buildInstalledList(BuildContext context) {
    if (filteredApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noResults,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      prototypeItem: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          borderRadius: 8,
          child: ListTile(
            leading: const SizedBox(width: 40, height: 40),
            title: const SizedBox(height: 16),
            subtitle: const SizedBox(height: 12),
            trailing: const SizedBox(width: 60, height: 24),
          ),
        ),
      ),
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        final sizeText = app.diskSize ?? app.installedSize ?? app.downloadSize;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            label: 'Installed app: ${app.name}',
            button: true,
            child: AppCard(
              borderRadius: 8,
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
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: app.icon!,
                          width: 40,
                          height: 40,
                          memCacheWidth: 80,
                          placeholder: (context, url) => const Skeleton(
                            width: 40,
                            height: 40,
                            borderRadius: 0,
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
                subtitle: Row(
                  children: [
                    Chip(
                      label: Text(app.primarySource),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                    ),
                    const SizedBox(width: 6),
                    if (!app.managed) ...[
                      Chip(
                        label: Text(AppLocalizations.of(context)!.readOnly),
                        avatar: const Icon(Icons.visibility_rounded, size: 14),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (sizeText != null && sizeText.toString().isNotEmpty) ...[
                      Text(
                        sizeText.toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        app.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
