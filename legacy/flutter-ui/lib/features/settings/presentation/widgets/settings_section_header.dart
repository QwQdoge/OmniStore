import 'package:flutter/material.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? iconWidget;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconWidget,
  }) : assert(icon == null || iconWidget == null);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null || icon != null) ...[
            iconWidget ?? Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
