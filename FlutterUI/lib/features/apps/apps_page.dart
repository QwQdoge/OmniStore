import 'dart:async';

import "package:frontend/data/repositories/package_repository.dart";
import "package:provider/provider.dart";
import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/apps/widgets/apps_page_skeleton.dart';
import 'package:collection/collection.dart';
import 'package:frontend/features/apps/widgets/apps_page_empty_state.dart';
import 'package:frontend/features/apps/widgets/installed_app_list.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

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
  String _lastSearchText = '';

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
    if (_searchController.text == _lastSearchText) return;
    _lastSearchText = _searchController.text;

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
      return app.nameLower.contains(query) ||
          app.descriptionLower.contains(query);
    }).toList();

    if (!const ListEquality().equals(_filteredAppsNotifier.value, filtered)) {
      _filteredAppsNotifier.value = filtered;
    }
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    if (!mounted) return;
    _isLoadingNotifier.value = true;
    final packageRepo = context.read<PackageRepository>();
    final results = await packageRepo.listInstalled(forceRefresh: forceRefresh);
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    final hasText = value.text.isNotEmpty;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.fastOutSlowIn,
                      child: hasText
                          ? IconButton(
                              key: const ValueKey('clear_button'),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: l10n.clear,
                              onPressed: () => _searchController.clear(),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('clear_empty'),
                            ),
                    );
                  },
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
                      child = InstalledAppList(
                        filteredApps: filteredApps,
                        onRefresh: _refresh,
                      );
                    }

                    return SmoothSizeSwitcher(
                      alignment: Alignment.topCenter,
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
