import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';

import 'package:frontend/features/explore/presentation/widgets/app_details_shared.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_header.dart';
import 'package:frontend/features/explore/presentation/widgets/app_details_actions.dart';
import 'package:frontend/features/explore/presentation/widgets/app_about_section.dart';
import 'package:frontend/features/explore/presentation/widgets/app_technical_details.dart';
import 'package:frontend/features/explore/presentation/widgets/app_screenshots.dart';

class AppMainContent extends StatelessWidget {
  final AppPackage app;
  final AppPackage? extraDetails;
  final String selectedSource;
  final bool isAppInstalled;
  final String? githubRepositoryUrl;
  final ScrollController variantScrollController;
  final String? heroTag;
  final bool Function(String) hasCapability;
  final String? Function(String) getVersionForSource;
  final bool Function(String) isSourceInstalled;
  final ValueChanged<String> onSourceSelected;
  final VoidCallback onLocateApp;
  final Future<void> Function(String) onHandleAction;
  final VoidCallback onLaunchApp;
  final VoidCallback onCancelAction;
  final bool isLoadingDetails;
  final ScrollController screenshotScrollController;
  final ValueChanged<String> onShowScreenshotViewer;
  final AppVariant? Function(String) getVariantForSource;

  const AppMainContent({
    super.key,
    required this.app,
    required this.extraDetails,
    required this.selectedSource,
    required this.isAppInstalled,
    required this.githubRepositoryUrl,
    required this.variantScrollController,
    this.heroTag,
    required this.hasCapability,
    required this.getVersionForSource,
    required this.isSourceInstalled,
    required this.onSourceSelected,
    required this.onLocateApp,
    required this.onHandleAction,
    required this.onLaunchApp,
    required this.onCancelAction,
    required this.isLoadingDetails,
    required this.screenshotScrollController,
    required this.onShowScreenshotViewer,
    required this.getVariantForSource,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDetailsHeader(
          app: app,
          extraDetails: extraDetails,
          selectedSource: selectedSource,
          isAppInstalled: isAppInstalled,
          githubRepositoryUrl: githubRepositoryUrl,
          variantScrollController: variantScrollController,
          heroTag: heroTag,
          hasCapability: hasCapability,
          getVersionForSource: getVersionForSource,
          isSourceInstalled: isSourceInstalled,
          onSourceSelected: onSourceSelected,
        ),
        const SizedBox(height: 24),
        AppDetailsActions(
          appName: app.name,
          isAppInstalled: isAppInstalled,
          onLocateApp: onLocateApp,
          onHandleAction: onHandleAction,
          onLaunchApp: onLaunchApp,
          onCancelAction: onCancelAction,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              AppDetailsSectionTitle(title: AppLocalizations.of(context)!.about),
              AppAboutSection(
                isLoading: isLoadingDetails,
                description: extraDetails?.description,
                fallbackDescription: app.description,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCapability('has_screenshots') &&
                  extraDetails != null &&
                  extraDetails!.screenshots != null &&
                  extraDetails!.screenshots!.isNotEmpty) ...[
                const SizedBox(height: 24),
                AppDetailsSectionTitle(
                  title: AppLocalizations.of(context)!.screenshots,
                ),
                AppScreenshots(
                  screenshots: extraDetails!.screenshots!,
                  scrollController: screenshotScrollController,
                  onShowScreenshotViewer: onShowScreenshotViewer,
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              AppDetailsSectionTitle(
                title: AppLocalizations.of(context)!.details,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.fastOutSlowIn,
                child: AppTechnicalDetails(
                  key: ValueKey(extraDetails != null ? 'loaded' : 'loading'),
                  primarySource: app.primarySource,
                  allSources: app.sources,
                  version: app.version,
                  extraDetails: extraDetails,
                  currentVariant: getVariantForSource(selectedSource),
                  hasCapability: hasCapability,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
