import 'package:flutter/material.dart';


class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? colorScheme.surface
          : colorScheme.surfaceContainerLow,
      child: Center(
            child: const Text(
              'Category',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }
}
