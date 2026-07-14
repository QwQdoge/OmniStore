import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/app_shelf.dart';
import 'package:frontend/core/widgets/section_header.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final _categories = CategoryService.getCategories(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: widget.l10n.categories),
          const SizedBox(height: 16),
          SizedBox(
            height: 186,
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
                prototypeItem: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 100,
                    child: AppCard(

                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Semantics(
                      label: widget.l10n.categorySemantics(cat.name),
                      button: true,
                      child: AppCard(

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
                  );
                },
              ),
            ),
          ),
          Selector<BrowseController, List<AppPackage>>(
            selector: (context, browse) =>
                browse.recommendations['trending'] ?? [],
            shouldRebuild: (prev, next) =>
                !const IterableEquality().equals(prev, next),
            builder: (context, trending, _) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.fastOutSlowIn,
                  child: trending.isEmpty
                      ? const SizedBox.shrink(key: ValueKey('empty_trending'))
                      : AppShelf(
                          key: const ValueKey('trending_content'),
                          title: widget.l10n.hotApps,
                          apps: trending,
                          scrollController: _trendingScrollController,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
