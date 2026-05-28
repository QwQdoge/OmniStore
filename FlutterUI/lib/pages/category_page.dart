import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'searchpage.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // TODO: Define a proper category model and fetch from backend if possible.
    // For now, we use a static list based on common Linux app categories.
    final List<Map<String, dynamic>> categories = [
      {'id': 'Development', 'name': l10n.catDevelopment, 'icon': Icons.code_rounded, 'color': Colors.blue},
      {'id': 'AudioVideo', 'name': l10n.catMedia, 'icon': Icons.play_circle_outline_rounded, 'color': Colors.red},
      {'id': 'Network', 'name': l10n.catInternet, 'icon': Icons.language_rounded, 'color': Colors.orange},
      {'id': 'System', 'name': l10n.catSystem, 'icon': Icons.settings_input_component_rounded, 'color': Colors.green},
      {'id': 'Office', 'name': l10n.catOffice, 'icon': Icons.description_outlined, 'color': Colors.teal},
      {'id': 'Game', 'name': l10n.catGames, 'icon': Icons.sports_esports_rounded, 'color': Colors.purple},
      {'id': 'Graphics', 'name': '图形设计', 'icon': Icons.palette_outlined, 'color': Colors.pink},
      {'id': 'Utility', 'name': '工具配件', 'icon': Icons.build_circle_outlined, 'color': Colors.blueGrey},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
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
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () {
          // Navigate to search page with the category filter
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(initialQuery: 'category:${cat['id']}'),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              cat['icon'] as IconData,
              size: 40,
              color: cat['color'] as Color,
            ),
            const SizedBox(height: 12),
            Text(
              cat['name'] as String,
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
