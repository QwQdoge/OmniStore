import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class WelcomeBottomBar extends StatelessWidget {
  final int currentPage;
  final bool isBootstrapping;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const WelcomeBottomBar({
    super.key,
    required this.currentPage,
    required this.isBootstrapping,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (currentPage > 0)
            TextButton.icon(
              onPressed: isBootstrapping ? null : onPrevious,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.back),
            ),
          const Spacer(),
          Text(
            'Step ${currentPage + 1} of 4',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: isBootstrapping
                ? null
                : () {
                    if (currentPage < 3) {
                      onNext();
                    } else {
                      onFinish();
                    }
                  },
            icon: Icon(
              currentPage < 3
                  ? Icons.arrow_forward_rounded
                  : Icons.login_rounded,
              size: 18,
            ),
            label: Text(
              currentPage == 0
                  ? l10n.getStarted
                  : currentPage < 3
                  ? l10n.next
                  : l10n.enterStore,
            ),
          ),
        ],
      ),
    );
  }
}
