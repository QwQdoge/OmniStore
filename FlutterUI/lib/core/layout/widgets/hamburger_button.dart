import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class HamburgerButton extends StatelessWidget {
  const HamburgerButton({super.key, required this.isExpanded, required this.onToggle});

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: isExpanded ? l10n.collapse : l10n.expand,
        button: true,
        child: IconButton(
          onPressed: onToggle,
          tooltip: isExpanded ? l10n.collapse : l10n.expand,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: 0.5, end: 1.0).animate(anim),
              child: child,
            ),
            child: Icon(
              isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              key: ValueKey(isExpanded),
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
