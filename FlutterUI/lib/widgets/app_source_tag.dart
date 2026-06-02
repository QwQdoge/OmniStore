import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum AppSourceTagMode {
  /// Displays the trust level (Official, Verified, Community)
  trust,

  /// Displays the raw source name (Pacman, AUR, Flatpak, etc.)
  source,
}

class AppSourceTag extends StatelessWidget {
  final String source;
  final AppSourceTagMode mode;
  final bool isSmall;

  const AppSourceTag({
    super.key,
    required this.source,
    this.mode = AppSourceTagMode.source,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    String label;
    Color color;
    IconData? icon;

    if (mode == AppSourceTagMode.trust) {
      if (source == "Pacman" || source == "Native") {
        label = l10n.official;
        color = Colors.blue;
        icon = Icons.verified_user_rounded;
      } else if (source == "Flatpak") {
        label = l10n.verified;
        color = Colors.green;
        icon = Icons.verified_rounded;
      } else {
        label = l10n.community;
        color = Colors.orange;
        icon = Icons.people_rounded;
      }
    } else {
      label = source;
      if (source == "Pacman" || source == "Native") {
        color = Colors.blue;
      } else if (source == "AUR") {
        color = Colors.orange;
      } else if (source == "Flatpak") {
        color = Colors.purple;
      } else if (source == "AppImage") {
        color = Colors.teal;
      } else {
        color = theme.colorScheme.onSurfaceVariant;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 12 : 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
