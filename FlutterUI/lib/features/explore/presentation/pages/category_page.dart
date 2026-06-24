import "package:provider/provider.dart";
import "package:frontend/core/navigation_controller.dart";
import "package:frontend/features/explore/presentation/controllers/browse_controller.dart";
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/core/widgets/app_card.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = CategoryService.getCategories(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.explore,
                    style: OmnistoreTheme.standardHeader(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.categories,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 140,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final cat = categories[index];
                return _CategoryCard(category: cat);
              }, childCount: categories.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryItem category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context)!.categorySemantics(category.name),
      button: true,
      child: AppCard(
        borderRadius: 24.0,
        onTap: () {
          final browse = context.read<BrowseController>();
          final nav = context.read<NavigationController>();
          browse.pendingSearchQuery = '/${category.id.toLowerCase()}';
          nav.setIndex(2); // Search page
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
