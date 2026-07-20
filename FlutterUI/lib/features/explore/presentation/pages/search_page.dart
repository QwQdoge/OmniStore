import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:frontend/models/app_package.dart';
import "package:frontend/features/explore/presentation/widgets/discovery_content.dart";
import "package:frontend/features/explore/presentation/widgets/search_filters.dart";
import "package:frontend/features/explore/presentation/widgets/search_results_view.dart";
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

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
  final ScrollController _sourceFilterScrollController = ScrollController();
  bool _showDiscovery = true;
  final List<String> _selectedSources = [];
  final ValueNotifier<bool> _hasSearchText = ValueNotifier<bool>(false);
  BrowseController? _browseController;
  NavigationController? _navigationController;
  List<AppPackage>? _lastResults;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    _browseController = context.read<BrowseController>();
    _browseController?.addListener(_onBrowseChanged);

    _navigationController = context.read<NavigationController>();
    _navigationController?.addListener(_onNavigationChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browse = _browseController!;
      if (browse.pendingSearchQuery != null) {
        _searchController.text = browse.pendingSearchQuery!;
        _hasSearchText.value = _searchController.text.isNotEmpty;
        _performSearch(browse.pendingSearchQuery!);
        browse.pendingSearchQuery = null;
      }
    });
  }

  void _onNavigationChanged() {
    if (!mounted) return;
    if (_navigationController?.selectedIndex == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _browseController?.removeListener(_onBrowseChanged);
    _navigationController?.removeListener(_onNavigationChanged);
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
      // ⚡ Bolt: Only trigger setState if state actually changes to avoid redundant builds
      if (!_showDiscovery) {
        setState(() {
          _showDiscovery = true;
        });
      }
      context.read<BrowseController>().selectedApp = null;
      return;
    }

    if (_showDiscovery) {
      setState(() {
        _showDiscovery = false;
      });
    }
    context.read<BrowseController>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
            _hasSearchText.value = false;
            if (!_showDiscovery || _selectedSources.isNotEmpty) {
              setState(() {
                _showDiscovery = true;
                _selectedSources.clear();
              });
            }
            context.read<BrowseController>().selectedApp = null;
          } else if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
      },
      child: Scaffold(
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
                          if (!_showDiscovery || _selectedSources.isNotEmpty) {
                            setState(() {
                              _showDiscovery = true;
                              _selectedSources.clear();
                            });
                          }
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
          SmoothSizeSwitcher(
            child: !_showDiscovery
                ? Selector<SettingsController, Map<String, bool>>(
                    key: const ValueKey('source_filters'),
                    selector: (context, settings) {
                      final sourcesMap =
                          settings.config['search']?['sources']
                              as Map<dynamic, dynamic>? ??
                          {};
                      return Map<String, bool>.from(sourcesMap);
                    },
                    shouldRebuild: (prev, next) =>
                        !const MapEquality<String, bool>().equals(prev, next),
                    builder: (context, sourcesMap, _) => SearchFilters(
                      sourcesMap: sourcesMap,
                      selectedSources: _selectedSources,
                      onSelectedSourcesChanged: (newSources) {
                        setState(() {
                          _selectedSources.clear();
                          _selectedSources.addAll(newSources);
                        });
                        _autoSelectFirstApp();
                      },
                      scrollController: _sourceFilterScrollController,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty_filters')),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.fastOutSlowIn,
              child: _showDiscovery
                  ? _buildDiscovery(l10n)
                  : Selector<
                      BrowseController,
                      ({
                        List<AppPackage> filteredResults,
                        bool isSearching,
                        bool isDesktop,
                      })
                    >(
                    selector: (context, b) {
                      final results = b.searchResults;
                      final isDesktop = MediaQuery.sizeOf(context).width > 900;

                      final filtered = _selectedSources.isEmpty
                          ? results
                          : results.where((app) {
                              return _selectedSources.contains(
                                app.primarySource.toLowerCase(),
                              );
                            }).toList();

                      return (
                        filteredResults: filtered,
                        isSearching: b.isSearching,
                        isDesktop: isDesktop,
                      );
                    },
                    shouldRebuild: (prev, next) {
                      return prev.isSearching != next.isSearching ||
                          prev.isDesktop != next.isDesktop ||
                          !const IterableEquality().equals(
                            prev.filteredResults,
                            next.filteredResults,
                          );
                    },
                    builder: (context, data, _) {
                      return SearchResultsView(
                        filteredResults: data.filteredResults,
                        isSearching: data.isSearching,
                        isDesktop: data.isDesktop,
                        searchController: _searchController,
                        performSearch: _performSearch,
                        l10n: l10n,
                      );
                    },
                  ),
            ),
          ),
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
}
