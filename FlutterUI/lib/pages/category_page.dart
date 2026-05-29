import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/category_service.dart';
import 'searchpage.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categories = CategoryService.getCategories(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.category,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = categories[index];
                  return _buildCategoryCard(context, cat, colorScheme);
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryItem cat, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () {
          // Navigate to search page with the category filter
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(initialQuery: 'category:${cat.id}'),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              cat.icon,
              size: 40,
              color: cat.color,
            ),
            const SizedBox(height: 12),
            Text(
              cat.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
