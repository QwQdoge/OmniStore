import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

import 'welcome_config_card.dart';

class WelcomeSourcesPage extends StatelessWidget {
  final bool enableAur;
  final ValueChanged<bool> onAurChanged;
  final List<String> recommendedSources;
  final bool supportsAur;
  final bool isBootstrapping;
  final VoidCallback? onBootstrapAur;

  const WelcomeSourcesPage({
    super.key,
    required this.enableAur,
    required this.onAurChanged,
    this.recommendedSources = const [],
    this.supportsAur = false,
    this.isBootstrapping = false,
    this.onBootstrapAur,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sourceConfigTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sourceConfigSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (recommendedSources.isNotEmpty) ...[
            Text(l10n.recommended, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in recommendedSources.where(
                  (source) => source != 'aur',
                ))
                  Chip(
                    label: Text(
                      source == 'flatpak' ? l10n.flatpakFull : source,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (supportsAur)
            WelcomeConfigCard(
              child: SwitchListTile(
                title: Text(
                  l10n.enableAur,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(l10n.yayDesc),
                value: enableAur,
                onChanged: onAurChanged,
              ),
            ),
          const SizedBox(height: 16),
          if (supportsAur && enableAur && onBootstrapAur != null) ...[
            FilledButton.tonalIcon(
              onPressed: isBootstrapping ? null : onBootstrapAur,
              icon: isBootstrapping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(l10n.installAurHelper),
            ),
            const SizedBox(height: 16),
          ],
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: supportsAur && enableAur
                ? Card(
                    key: const ValueKey('aur-warning'),
                    elevation: 0,
                    color: theme.colorScheme.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.aurWarning,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('aur-empty')),
          ),
        ],
      ),
    );
  }
}
