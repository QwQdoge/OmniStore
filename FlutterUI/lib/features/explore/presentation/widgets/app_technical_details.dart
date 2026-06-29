import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';
import 'package:frontend/features/explore/presentation/widgets/app_dependency_section.dart';

class AppTechnicalDetails extends StatelessWidget {
  final String primarySource;
  final List<String> allSources;
  final String version;
  final Map<String, dynamic>? extraDetails;
  final Map<String, dynamic>? currentVariant;
  final bool Function(String) hasCapability;

  const AppTechnicalDetails({
    super.key,
    required this.primarySource,
    required this.allSources,
    required this.version,
    this.extraDetails,
    this.currentVariant,
    required this.hasCapability,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDetailsInfoRow(
            icon: Icons.source_rounded,
            label: l10n.source,
            value: primarySource,
          ),
          AppDetailsInfoRow(
            icon: Icons.all_inclusive_rounded,
            label: l10n.variant,
            value: allSources.join(", "),
          ),
          AppDetailsInfoRow(
            icon: Icons.verified_rounded,
            label: l10n.version,
            value: version,
          ),
          if (extraDetails?['developer'] != null)
            AppDetailsInfoRow(
              icon: Icons.person_rounded,
              label: l10n.developer,
              value: extraDetails!['developer'],
            ),
          if (extraDetails?['license'] != null)
            AppDetailsInfoRow(
              icon: Icons.description_rounded,
              label: l10n.license,
              value: extraDetails!['license'],
            ),
          AppDependencySection(
            variant: currentVariant,
            hasCapability: hasCapability,
          ),
        ],
      ),
    );
  }
}
