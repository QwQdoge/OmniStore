import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;

  CategoryItem({required this.id, required this.name, required this.icon});
}

class CategoryService {
  static List<CategoryItem> getCategories(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      CategoryItem(
        id: 'Development',
        name: l10n.catDevelopment,
        icon: Icons.code_rounded,
      ),
      CategoryItem(
        id: 'AudioVideo',
        name: l10n.catMedia,
        icon: Icons.movie_rounded,
      ),
      CategoryItem(
        id: 'Network',
        name: l10n.catInternet,
        icon: Icons.language_rounded,
      ),
      CategoryItem(
        id: 'System',
        name: l10n.catSystem,
        icon: Icons.settings_suggest_rounded,
      ),
      CategoryItem(
        id: 'Office',
        name: l10n.catOffice,
        icon: Icons.description_rounded,
      ),
      CategoryItem(
        id: 'Game',
        name: l10n.catGames,
        icon: Icons.sports_esports_rounded,
      ),
      CategoryItem(
        id: 'Graphics',
        name: l10n.catGraphics,
        icon: Icons.brush_rounded,
      ),
      CategoryItem(
        id: 'Utility',
        name: l10n.catUtility,
        icon: Icons.construction_rounded,
      ),
    ];
  }
}
