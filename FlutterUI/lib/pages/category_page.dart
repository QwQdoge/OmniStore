import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? colorScheme.surface
          : colorScheme.surfaceContainerLow,
      child: Center(
            child: Text(
              l10n.category,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }
}
