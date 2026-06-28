import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:frontend/core/widgets/skeleton.dart';
import "package:frontend/core/widgets/app_card.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:frontend/models/app_package.dart';
import "package:frontend/features/explore/presentation/widgets/search_result_tile.dart";
import "package:frontend/features/explore/presentation/widgets/discovery_content.dart";
import "package:frontend/features/explore/presentation/widgets/empty_results.dart";

class SearchPage extends StatefulWidget {
  final bool autoFocus;
  const SearchPage({super.key, this.autoFocus = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Map<String, String> _sourceNameMapping = {
    'pacman': 'Pacman',
    'aur': 'AUR',
    'flatpak': 'Flatpak',
    'appimage': 'AppImage',
    'snap': 'Snap',
    'github': 'GitHub',
    'bitu': 'Bitu',
    'winget': 'Winget',
    'scoop': 'Scoop',
    'brew': 'Homebrew',
  };

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _quickFilterScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _sourceFilterScrollController = ScrollController();
  bool _showDiscovery = true;
  final List<String> _selectedSources = [];
  final ValueNotifier<bool> _hasSearchText = ValueNotifier<bool>(false);
  BrowseController? _browseController;
  List<AppPackage>? _lastResults;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browse = context.read<BrowseController>();
      if (browse.pendingSearchQuery != null) {
        _searchController.text = browse.pendingSearchQuery!;
        _hasSearchText.value = _searchController.text.isNotEmpty;
        _performSearch(browse.pendingSearchQuery!);
        browse.pendingSearchQuery = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBrowse = Provider.of<BrowseController>(context);
    if (_browseController != newBrowse) {
      _browseController?.removeListener(_onBrowseChanged);
      _browseController = newBrowse;
      _browseController?.addListener(_onBrowseChanged);
    }
  }

  @override
  void dispose() {
    _browseController?.removeListener(_onBrowseChanged);
    _hasSearchText.dispose();
    _searchController.dispose();
    _quickFilterScrollController.dispose();
    _focusNode.dispose();
    _sourceFilterScrollController.dispose();
    super.dispose();
  }

  void _onBrowseChanged() {
    if (!mounted) return;
    if (_browseController == null) return;

    // Only trigger auto-selection when a search completes and results have changed.
    // This prevents redundant filtering logic when selecting an app in the sidebar.
    if (!_browseController!.isSearching &&
        _lastResults != _browseController!.searchResults) {
      _lastResults = _browseController!.searchResults;
      _autoSelectFirstApp();
    }
  }

  void _autoSelectFirstApp() {
    if (!mounted) return;
    final browse = context.read<BrowseController>();
    var filteredResults = browse.searchResults;
    if (_selectedSources.isNotEmpty) {
      filteredResults = browse.searchResults.where((app) {
        return _selectedSources.contains(app.primarySource.toLowerCase());
      }).toList();
    }

    if (filteredResults.isNotEmpty) {
      browse.selectedApp = filteredResults.first;
    } else {
      browse.selectedApp = null;
    }
  }

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() {
        _showDiscovery = true;
      });
      context.read<BrowseController>().selectedApp = null;
      return;
    }
    setState(() {
      _showDiscovery = false;
    });
    context.read<BrowseController>().search(query);
  }

  String _displayName(String key) {
    return _sourceNameMapping[key.toLowerCase()] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: SearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              hintText: l10n.searchHint,
              onChanged: (val) => _hasSearchText.value = val.isNotEmpty,
              onSubmitted: _performSearch,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                ValueListenableBuilder<bool>(
                  valueListenable: _hasSearchText,
                  builder: (context, hasText, child) {
                    if (hasText) {
                      return IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _searchController.clear();
                          _hasSearchText.value = false;
                          setState(() {
                            _showDiscovery = true;
                            _selectedSources.clear();
                          });
                          context.read<BrowseController>().selectedApp = null;
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !_showDiscovery
                  ? Selector<SettingsController, Map<String, bool>>(
                      key: const ValueKey('source_filters'),
                      selector: (context, settings) {
                        final sourcesMap = settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};
                        return Map<String, bool>.from(sourcesMap);
                      },
                      shouldRebuild: (prev, next) => !const MapEquality<String, bool>().equals(prev, next),
                      builder: (context, sourcesMap, _) => _buildSourceFilters(sourcesMap),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty_filters')),
            ),
          ),
          Expanded(
            child: _showDiscovery
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildDiscovery(l10n),
                  )
                : Selector<BrowseController, ({List<AppPackage> results, bool isSearching, int filtersHash, bool isDesktop})>(
                    selector: (context, b) => (
                      results: b.searchResults,
                      isSearching: b.isSearching,
                      filtersHash: Object.hashAll(_selectedSources),
                      isDesktop: MediaQuery.sizeOf(context).width > 900,
                    ),
                    builder: (context, data, _) {
                      final resultsContent = data.isSearching
                          ? _buildSkeletonResults()
                          : _buildResults(data.results, l10n, data.isDesktop);

                      if (data.isDesktop) {
                        return Row(
                          children: [
                            Expanded(flex: 4, child: resultsContent),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 6,
                              child: Selector<BrowseController, AppPackage?>(
                                selector: (context, b) => b.selectedApp,
                                builder: (context, selectedApp, _) {
                                  if (selectedApp == null) {
                                    return Center(
                                      child: Text(
                                        l10n.noResults,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    );
                                  }
                                  return AppDetailsPage(
                                    app: selectedApp,
                                    isEmbedded: true,
                                    key: ValueKey(selectedApp.id ?? selectedApp.name),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: resultsContent,
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFilters(Map<String, bool> sourcesMap) {
    final enabledSources = sourcesMap.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    if (enabledSources.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Scrollbar(
        controller: _sourceFilterScrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _sourceFilterScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(AppLocalizations.of(context)!.all),
                selected: _selectedSources.isEmpty,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedSources.clear();
                    });
                    _autoSelectFirstApp();
                  }
                },
              ),
            ),
            ...enabledSources.map((src) {
              final name = _displayName(src);
              final isSelected = _selectedSources.contains(name.toLowerCase());
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSources.add(name.toLowerCase());
                      } else {
                        _selectedSources.remove(name.toLowerCase());
                      }
                    });
                    _autoSelectFirstApp();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscovery(AppLocalizations l10n) {
    return DiscoveryContent(
      key: const ValueKey('discovery'),
      l10n: l10n,
      searchController: _searchController,
      performSearch: _performSearch,
    );
  }

  Widget _buildSkeletonResults() {
    return ListView.builder(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(16),
      prototypeItem: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppCard(
          borderRadius: 16,
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 12),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(
              width: double.infinity,
              height: 12,
              borderRadius: 8,
            ),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 12),
          ),
        ),
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppCard(
            borderRadius: 16,
            child: ListTile(
              leading: Skeleton(width: 40, height: 40, borderRadius: 12),
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

  Widget _buildResults(
    List<AppPackage> searchResults,
    AppLocalizations l10n,
    bool isDesktop,
  ) {
    var filteredResults = searchResults;
    if (_selectedSources.isNotEmpty) {
      filteredResults = searchResults.where((app) {
        return _selectedSources.contains(app.primarySource.toLowerCase());
      }).toList();
    }

    if (filteredResults.isEmpty) {
      return EmptyResults(
        key: const ValueKey('empty'),
        l10n: l10n,
        searchController: _searchController,
        performSearch: _performSearch,
      );
    }

    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(16),
      prototypeItem: SearchResultTile(
        app: AppPackage(
          name: 'Prototype',
          description: 'Prototype Description',
          installed: false,
          primarySource: 'Native',
          version: '1.0.0',
          variants: [],
        ),
        isDesktop: isDesktop,
        onTap: () {},
      ),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final app = filteredResults[index];
        return SearchResultTile(
          app: app,
          isDesktop: isDesktop,
          onTap: () {
            if (isDesktop) {
              context.read<BrowseController>().selectedApp = app;
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppDetailsPage(
                    app: app,
                    heroTag: 'search-result-${app.name}-${app.primarySource}',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
