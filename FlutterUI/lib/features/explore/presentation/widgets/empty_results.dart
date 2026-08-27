import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/widgets/empty_state.dart';

class EmptyResults extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final Function(String) performSearch;

  const EmptyResults({
    super.key,
    required this.l10n,
    required this.searchController,
    required this.performSearch,
  });

  @override
  Widget build(BuildContext context) {
    final categories = CategoryService.getCategories(context);

    return EmptyState(
      icon: Icons.search_off_rounded,
      title: l10n.noResults,
      child: Column(
        children: [
          Text(
            l10n.categories,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: categories
                .map(
                  (cat) => ActionChip(
                    onPressed: () {
                      searchController.text =
                          '/${cat.id.toLowerCase()}';
                      performSearch(searchController.text);
                    },
                    label: Text(cat.name),
                    tooltip: l10n.categorySemantics(cat.name),
                    avatar: Icon(cat.icon, size: 18),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
