import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import "package:frontend/features/explore/presentation/pages/details_page.dart";
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/widgets/app_source_tag.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/services/category_service.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/models/app_package.dart';

class SearchPage extends StatefulWidget {
  final bool autoFocus;
  const SearchPage({super.key, this.autoFocus = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width > 900;

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
              onChanged: (value) => setState(() {}),
              onSubmitted: _performSearch,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.clearSearch,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _showDiscovery = true;
                        _selectedSources.clear();
                        _selectedApp = null;
                      });
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
                : Consumer2<BrowseController, SettingsController>(
                    builder: (context, browse, settings, _) {
                      final resultsContent = browse.isSearching
                          ? _buildSkeletonResults()
                          : _buildResults(browse, l10n, settings);

                      if (isDesktop) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: resultsContent,
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 6,
                              child: _selectedApp == null
                                  ? Center(
                                      child: Text(
                                        l10n.noResults,
                                        style: Theme.of(context).textTheme.bodyLarge,
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
    final sourcesMap = settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};
    final enabledSources = sourcesMap.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();

    if (enabledSources.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ListView(
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
    );
  }

  Widget _buildDiscovery(AppLocalizations l10n) {
    return _DiscoveryContent(
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
        return const Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 8),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(width: double.infinity, height: 12, borderRadius: 4),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
          ),
        );
      },
    );
  }

  Widget _buildResults(
    BrowseController browse,
    AppLocalizations l10n,
    SettingsController settings,
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    var filteredResults = browse.searchResults;
    if (_selectedSources.isNotEmpty) {
      filteredResults = browse.searchResults.where((app) {
        return _selectedSources.contains(app.primarySource.toLowerCase());
      }).toList();
    }

    if (filteredResults.isEmpty) {
      return _EmptyResults(
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
        final heroTag = 'search-result-${app.name}-${app.primarySource}';
        final isSelected = _selectedApp?.id == app.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected && isDesktop
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: ListTile(
            leading: Hero(
              tag: heroTag,
              child: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
            onTap: () {
              if (isDesktop) {
                setState(() {
                  _selectedApp = app;
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AppDetailsPage(app: app, heroTag: heroTag),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

class _DiscoveryContent extends StatefulWidget {
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final Function(String) performSearch;

  const _DiscoveryContent({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.performSearch,
  });

  @override
  State<_DiscoveryContent> createState() => _DiscoveryContentState();
}

class _DiscoveryContentState extends State<_DiscoveryContent> {
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _trendingScrollController = ScrollController();

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _trendingScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoryService.getCategories(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.l10n.categories,
              style: OmnistoreTheme.standardHeader(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 156,
            child: Scrollbar(
              controller: _categoryScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Semantics(
                        label: 'Category: ${cat.name}',
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            widget.searchController.text = '/${cat.id.toLowerCase()}';
                            widget.performSearch(widget.searchController.text);
                          },
                          child: SizedBox(
                            width: 100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    cat.icon,
                                    size: 28,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Consumer<BrowseController>(
            builder: (context, browse, _) {
              final trending = browse.recommendations['trending'] ?? [];
              if (trending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.l10n.hotApps,
                      style: OmnistoreTheme.standardHeader(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 196,
                    child: Scrollbar(
                      controller: _trendingScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _trendingScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: trending.length,
                        itemBuilder: (context, index) {
                          final app = trending[index];
                          final trendingHeroTag =
                              'trending-shelf-${app.name}-${app.primarySource}';
                          return Container(
                            width: 150,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AppDetailsPage(
                                      app: app,
                                      heroTag: trendingHeroTag,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Hero(
                                        tag: trendingHeroTag,
                                        child: app.icon != null
                                            ? CachedNetworkImage(
                                                imageUrl: app.icon!,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 300,
                                              )
                                            : const Icon(Icons.apps, size: 48),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        app.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final Function(String) performSearch;

  const _EmptyResults({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.performSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = CategoryService.getCategories(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResults,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              l10n.categories,
              style: OmnistoreTheme.standardHeader(context),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: categories
                  .map(
                    (cat) => ActionChip(
                      onPressed: () {
                        searchController.text = '/${cat.id.toLowerCase()}';
                        performSearch(searchController.text);
                      },
                      label: Text(cat.name),
                      avatar: Icon(cat.icon, size: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
