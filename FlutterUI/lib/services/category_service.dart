import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class CategoryService {
  static List<CategoryItem> getCategories(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      CategoryItem(id: 'Development', name: l10n.catDevelopment, icon: Icons.code_rounded, color: Colors.blue),
      CategoryItem(id: 'AudioVideo', name: l10n.catMedia, icon: Icons.play_circle_outline_rounded, color: Colors.red),
      CategoryItem(id: 'Network', name: l10n.catInternet, icon: Icons.language_rounded, color: Colors.orange),
      CategoryItem(id: 'System', name: l10n.catSystem, icon: Icons.settings_input_component_rounded, color: Colors.green),
      CategoryItem(id: 'Office', name: l10n.catOffice, icon: Icons.description_outlined, color: Colors.teal),
      CategoryItem(id: 'Game', name: l10n.catGames, icon: Icons.sports_esports_rounded, color: Colors.purple),
      CategoryItem(id: 'Graphics', name: l10n.catGraphics, icon: Icons.palette_outlined, color: Colors.pink),
      CategoryItem(id: 'Utility', name: l10n.catUtility, icon: Icons.build_circle_outlined, color: Colors.blueGrey),
    ];
  }
}
