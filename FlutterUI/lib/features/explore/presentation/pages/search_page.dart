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

  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() => _showDiscovery = true);
      return;
    }
    setState(() => _showDiscovery = false);
    context.read<BrowseController>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final browse = context.watch<BrowseController>();
    final settings = context.watch<SettingsController>();

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
                      setState(() => _showDiscovery = true);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showDiscovery
                  ? _buildDiscovery(l10n)
                  : browse.isSearching
                  ? _buildSkeletonResults()
                  : _buildResults(browse, l10n, settings),
            ),
          ),
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
    if (browse.searchResults.isEmpty) {
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
      itemCount: browse.searchResults.length,
      itemBuilder: (context, index) {
        final app = browse.searchResults[index];
        final heroTag = 'search-result-${app.name}-${app.primarySource}';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AppDetailsPage(app: app, heroTag: heroTag),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscoveryContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final categories = CategoryService.getCategories(context);
    final browse = context.watch<BrowseController>();
    final trending = browse.recommendations['trending'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.categories,
              style: OmnistoreTheme.standardHeader(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        searchController.text = '/${cat.id.toLowerCase()}';
                        performSearch(searchController.text);
                      },
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cat.icon,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (trending.isNotEmpty) ...[
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.hotApps,
                style: OmnistoreTheme.standardHeader(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trending.length,
                itemBuilder: (context, index) {
                  final app = trending[index];
                  final trendingHeroTag =
                      'trending-shelf-${app.name}-${app.primarySource}';
                  return Container(
                    width: 150,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Card(
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
          ],
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
