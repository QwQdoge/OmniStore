import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/app_package.dart';
import "package:frontend/features/explore/presentation/widgets/search_result_tile.dart";
import "package:frontend/features/explore/presentation/widgets/discovery_content.dart";
import "package:frontend/features/explore/presentation/widgets/empty_results.dart";
import "package:frontend/core/widgets/app_card.dart";

class SearchPage extends StatefulWidget {
  final bool autoFocus;
  const SearchPage({super.key, this.autoFocus = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _quickFilterScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _hasSearchText = ValueNotifier(false);
  bool _showDiscovery = true;
  final List<String> _selectedSources = [];
  AppPackage? _selectedApp;
  BrowseController? _browseController;

  String _displayName(String key) {
    final mapping = {
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
    return mapping[key.toLowerCase()] ?? key;
  }

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
    super.dispose();
  }

  void _onBrowseChanged() {
    if (!mounted) return;
    if (_browseController == null) return;
    if (!_browseController!.isSearching) {
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

    setState(() {
      if (filteredResults.isNotEmpty) {
        _selectedApp = filteredResults.first;
      } else {
        _selectedApp = null;
      }
    });
  }

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() {
        _showDiscovery = true;
        _selectedApp = null;
      });
      return;
    }
    setState(() {
      _showDiscovery = false;
      _selectedApp = null;
    });
    context.read<BrowseController>().search(query);
  }

  // Duplicate dispose removed

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.sizeOf(context).width > 900;

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
                            _selectedApp = null;
                          });
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          if (!_showDiscovery)
            Consumer<SettingsController>(
              builder: (context, settings, _) => _buildSourceFilters(settings),
            ),
          Expanded(
            child: _showDiscovery
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildDiscovery(l10n),
                  )
                : Consumer<BrowseController>(
                    builder: (context, browse, _) {
                      final resultsContent = browse.isSearching
                          ? _buildSkeletonResults()
                          : _buildResults(browse, l10n);

                      if (isDesktop) {
                        return Row(
                          children: [
                            Expanded(flex: 4, child: resultsContent),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 6,
                              child: _selectedApp == null
                                  ? Center(
                                      child: Text(
                                        l10n.noResults,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    )
                                  : AppDetailsPage(
                                      app: _selectedApp!,
                                      isEmbedded: true,
                                      key: ValueKey(_selectedApp!.id),
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

  Widget _buildSourceFilters(SettingsController settings) {
    final sourcesMap =
        settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};
    final enabledSources = sourcesMap.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();

    if (enabledSources.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Scrollbar(
        controller: _quickFilterScrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _quickFilterScrollController,
          scrollDirection: Axis.horizontal,
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
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            borderRadius: 12,
            child: ListTile(
              leading: Skeleton(width: 40, height: 40, borderRadius: 8),
              title: Skeleton(width: 120, height: 16),
              subtitle: Skeleton(
                width: double.infinity,
                height: 12,
                borderRadius: 4,
              ),
              trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults(
    BrowseController browse,
    AppLocalizations l10n,
  ) {
    final isDesktop = MediaQuery.sizeOf(context).width > 900;
    var filteredResults = browse.searchResults;
    if (_selectedSources.isNotEmpty) {
      filteredResults = browse.searchResults.where((app) {
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
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final app = filteredResults[index];
        return SearchResultTile(
          app: app,
          isSelected: _selectedApp?.id == app.id,
          isDesktop: isDesktop,
          onTap: () {
            if (isDesktop) {
              setState(() {
                _selectedApp = app;
              });
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
