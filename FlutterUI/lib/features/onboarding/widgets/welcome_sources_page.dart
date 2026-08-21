import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'welcome_config_card.dart';

class WelcomeSourcesPage extends StatelessWidget {
  final bool enableAur;
  final ValueChanged<bool> onAurChanged;
  final List<String> recommendedSources;
  final String nativeManager;

  const WelcomeSourcesPage({
    super.key,
    required this.enableAur,
    required this.onAurChanged,
    this.recommendedSources = const [],
    this.nativeManager = '',
  });

  String _displayName(String source) {
    switch (source.toLowerCase()) {
      case 'pacman':
        return 'Pacman';
      case 'aur':
        return 'AUR';
      case 'apt':
        return 'APT';
      case 'dnf':
        return 'DNF';
      case 'zypper':
        return 'Zypper';
      case 'apk':
        return 'APK';
      case 'flatpak':
        return 'Flatpak / Flathub';
      case 'appimage':
        return 'AppImage';
      case 'winget':
        return 'Winget';
      case 'brew':
        return 'Homebrew';
      default:
        return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final automaticSources = recommendedSources
        .where((source) => source.toLowerCase() != 'aur')
        .toList(growable: false);

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
          if (automaticSources.isNotEmpty) ...[
            WelcomeConfigCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nativeManager.isEmpty
                                ? 'Recommended sources for this device'
                                : 'Recommended sources for $nativeManager',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: automaticSources
                          .map(
                            (source) => Chip(
                              avatar: const Icon(Icons.check_rounded, size: 16),
                              label: Text(_displayName(source)),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'OmniStore enables only sources that match this operating system. Missing Flatpak/Flathub support can be prepared from the previous system setup step.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (recommendedSources.contains('aur')) ...[
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
            SmoothSizeSwitcher(
              alignment: Alignment.topCenter,
              child: enableAur
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
        ],
      ),
    );
  }
}
