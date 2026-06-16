import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';

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
