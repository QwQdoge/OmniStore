import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';

class AppDependencySection extends StatelessWidget {
  final Map<String, dynamic>? variant;
  final bool Function(String) hasCapability;

  const AppDependencySection({
    super.key,
    required this.variant,
    required this.hasCapability,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final deps = variant!['depends'] as List?;
    final dlSize = variant!['download_size'];
    final insSize = variant!['installed_size'];
    if ((deps == null || deps.isEmpty) && dlSize == null && insSize == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: AppDetailsSectionTitle(
            title: l10n.installInfo,
            isSubSection: true,
          ),
        ),
        if (hasCapability('has_size') && dlSize != null)
          AppDetailsInfoRow(
            icon: Icons.downloading_rounded,
            label: AppLocalizations.of(context)!.downloadSize,
            value: dlSize.toString(),
          ),
        if (hasCapability('has_size') && insSize != null)
          AppDetailsInfoRow(
            icon: Icons.storage_rounded,
            label: AppLocalizations.of(context)!.installedSize,
            value: insSize.toString(),
          ),
        if (deps != null && deps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dependenciesCount(deps.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: deps
                      .map(
                        (d) => Chip(
                          label: Text(
                            d.toString(),
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
