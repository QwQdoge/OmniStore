import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class DiscoveryContent extends StatefulWidget {
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final Function(String) performSearch;

  const DiscoveryContent({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.performSearch,
  });

  @override
  State<DiscoveryContent> createState() => _DiscoveryContentState();
}

class _DiscoveryContentState extends State<DiscoveryContent> {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Semantics(
                        label: AppLocalizations.of(
                          context,
                        )!.categorySemantics(cat.name),
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            widget.searchController.text =
                                '/${cat.id.toLowerCase()}';
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
