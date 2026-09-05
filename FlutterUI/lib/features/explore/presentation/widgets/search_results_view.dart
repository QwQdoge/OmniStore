import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';
import 'package:frontend/features/explore/presentation/widgets/search_result_tile.dart';
import 'package:frontend/features/explore/presentation/widgets/empty_results.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class SearchResultsView extends StatelessWidget {
  final List<AppPackage> filteredResults;
  final bool isSearching;
  final bool hasError;
  final bool isDesktop;
  final TextEditingController searchController;
  final Function(String) performSearch;
  final AppLocalizations l10n;

  const SearchResultsView({
    super.key,
    required this.filteredResults,
    required this.isSearching,
    required this.hasError,
    required this.isDesktop,
    required this.searchController,
    required this.performSearch,
    required this.l10n,
  });

  Widget _buildSkeletonResults() {

    const skeletonItem = Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: ListTile(
          leading: Skeleton(width: 40, height: 40, borderRadius: 12),
          title: Skeleton(width: 120, height: 16),
          subtitle: Skeleton(width: double.infinity, height: 12),
          trailing: Skeleton(width: 60, height: 24, borderRadius: 12),
        ),
      ),
    );

    return ListView.builder(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(16),
      prototypeItem: skeletonItem,
      itemCount: 6,
      itemBuilder: (context, index) => skeletonItem,
    );
  }

  Widget _buildResults(BuildContext context) {
    if (hasError) {
      return EmptyState(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        title: l10n.failed,
        subtitle: l10n.searchFailedSubtitle,
        child: FilledButton.icon(
          onPressed: () => performSearch(searchController.text),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      );
    }
    if (filteredResults.isEmpty) {
      return EmptyResults(
        key: const ValueKey('empty'),
        l10n: l10n,
        searchController: searchController,
        performSearch: performSearch,
      );
    }

    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(16),
      prototypeItem: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppCard(
          borderRadius: 16,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: SizedBox(width: 40, height: 40),
              title: SizedBox(height: 16),
              subtitle: SizedBox(height: 14),
            ),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final resultsContent = isSearching
        ? _buildSkeletonResults()
        : _buildResults(context);

    if (isDesktop) {
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
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.noResults,
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
      return SmoothSizeSwitcher(
        alignment: Alignment.topCenter,
        child: resultsContent,
      );
    }
  }
}
