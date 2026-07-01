import 'package:flutter/material.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: OmnistoreTheme.standardHeader(context)),
    );
  }
}
