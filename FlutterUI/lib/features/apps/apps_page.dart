import 'dart:async';

import 'package:frontend/core/widgets/app_card.dart';
import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/apps/widgets/apps_page_skeleton.dart';
import 'package:frontend/features/apps/widgets/apps_page_empty_state.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<AppPackage> _apps = [];
  final ValueNotifier<List<AppPackage>> _filteredAppsNotifier = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _filteredAppsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    final query = _searchController.text;
    if (query.isEmpty) {
      _applyFilter();
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase();
    final filtered = _apps.where((app) {
      return app.name.toLowerCase().contains(query) ||
          app.description.toLowerCase().contains(query);
    }).toList();
    _filteredAppsNotifier.value = filtered;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    _isLoadingNotifier.value = true;
    final packageRepo = context.read<PackageRepository>();
    final results = await packageRepo.listInstalled();
    if (mounted) {
      _apps = results;
      _applyFilter();
      _isLoadingNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              l10n.installedApps,
              style: OmnistoreTheme.standardHeader(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SearchBar(
              controller: _searchController,
              hintText: l10n.searchInstalledHint,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.clear,
                    onPressed: () => _searchController.clear(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoadingNotifier,
              builder: (context, isLoading, _) {
                return ValueListenableBuilder<List<AppPackage>>(
                  valueListenable: _filteredAppsNotifier,
                  builder: (context, filteredApps, _) {
                    Widget child;
                    if (isLoading) {
                      child = const AppsPageSkeleton(key: ValueKey('loading'));
                    } else if (filteredApps.isEmpty) {
                      child = const AppsPageEmptyState(key: ValueKey('empty'));
                    } else {
                      child = RefreshIndicator(
                        key: const ValueKey('list'),
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          prototypeItem: const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: ListTile(
                                leading: SizedBox(width: 40, height: 40),
                                title: SizedBox(height: 16),
                                subtitle: Row(
                                  children: [
                                    SizedBox(width: 40, height: 12),
                                    SizedBox(width: 8),
                                    Expanded(child: SizedBox(height: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final heroTag =
                                'installed-app-${app.name}-${app.primarySource}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                label:
                                    'Installed app: ${app.name} from ${app.primarySource}',
                                button: true,
                                child: AppCard(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AppDetailsPage(
                                        app: app,
                                        heroTag: heroTag,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Hero(
                                      tag: heroTag,
                                      child: app.icon != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: app.icon!,
                                                width: 40,
                                                height: 40,
                                                memCacheWidth: 80,
                                                errorWidget: (c, e, s) =>
                                                    const Icon(Icons.apps),
                                              ),
                                            )
                                          : const Icon(Icons.apps, size: 40),
                                    ),
                                    title: Text(
                                      app.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.fastOutSlowIn,
                      duration: const Duration(milliseconds: 300),
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
