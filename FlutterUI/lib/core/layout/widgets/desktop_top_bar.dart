import 'package:flutter/material.dart';
import 'package:frontend/features/auth/auth_page.dart';
import 'package:frontend/l10n/app_localizations.dart';

class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({
    super.key,
    required this.title,
    required this.showSearch,
    required this.onSearch,
  });

  final String title;
  final bool showSearch;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(28, 16, 20, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          if (showSearch)
            FilledButton.tonalIcon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(l10n.search),
            ),
          const SizedBox(width: 8),
          Semantics(
            label: l10n.githubAuthTitle,
            button: true,
            child: IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: l10n.githubAuthTitle,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
