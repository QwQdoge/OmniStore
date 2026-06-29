import 'package:flutter/material.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';
import 'package:frontend/features/explore/presentation/widgets/app_dependency_section.dart';

class AppTechnicalDetails extends StatelessWidget {
  final AppPackage app;
  final Map<String, dynamic>? extraDetails;
  final String selectedSource;
  final Map<String, dynamic>? Function(String) getVariantForSource;
  final bool Function(String) hasCapability;

  const AppTechnicalDetails({
    super.key,
    required this.app,
    required this.extraDetails,
    required this.selectedSource,
    required this.getVariantForSource,
    required this.hasCapability,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailsSectionTitle(title: AppLocalizations.of(context)!.details),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDetailsInfoRow(
                icon: Icons.source_rounded,
                label: AppLocalizations.of(context)!.source,
                value: app.primarySource,
              ),
              AppDetailsInfoRow(
                icon: Icons.all_inclusive_rounded,
                label: AppLocalizations.of(context)!.variant,
                value: app.sources.join(", "),
              ),
              AppDetailsInfoRow(
                icon: Icons.verified_rounded,
                label: AppLocalizations.of(context)!.version,
                value: app.version,
              ),
              if (extraDetails?['developer'] != null)
                AppDetailsInfoRow(
                  icon: Icons.person_rounded,
                  label: AppLocalizations.of(context)!.developer,
                  value: extraDetails!['developer'],
                ),
              if (extraDetails?['license'] != null)
                AppDetailsInfoRow(
                  icon: Icons.description_rounded,
                  label: AppLocalizations.of(context)!.license,
                  value: extraDetails!['license'],
                ),
              AppDependencySection(
                variant: getVariantForSource(selectedSource),
                hasCapability: hasCapability,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
