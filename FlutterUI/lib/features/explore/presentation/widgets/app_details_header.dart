import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/app_source_tag.dart';
import 'package:frontend/core/widgets/github_star_badge.dart';

class AppDetailsHeader extends StatelessWidget {
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

  const AppDetailsHeader({
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
  });

  Widget? _getSourceIcon(String source) {
    IconData? iconData;
    if (source == "Pacman" || source == "Native") {
      iconData = Icons.apps_rounded;
    } else if (source == "AUR") {
      iconData = Icons.cloud_outlined;
    } else if (source == "Flatpak") {
      iconData = Icons.inventory_2_outlined;
    } else if (source == "AppImage") {
      iconData = Icons.insert_drive_file_outlined;
    }
    if (iconData == null) {
      return null;
    }
    return Icon(iconData, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconUrl = app.icon ?? extraDetails?.icon;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: heroTag ?? 'app-icon-${app.name}-${app.primarySource}',
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28.0),
            ),
            alignment: Alignment.center,
            child: iconUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28.0),
                    child: CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 240,
                      placeholder: (context, url) => const Skeleton(
                        width: 120,
                        height: 120,
                        borderRadius: 28.0,
                      ),
                    ),
                  )
                : Text(
                    app.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 56,
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Semantics(
                    label: AppLocalizations.of(context)!.copyName,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: AppLocalizations.of(context)!.copyName,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: app.name));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.copiedToClipboard,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (githubRepositoryUrl != null &&
                      hasCapability('has_rating'))
                    GitHubStarBadge(repositoryUrl: githubRepositoryUrl!),
                  if (isAppInstalled)
                    AppSourceTag(
                      source: selectedSource,
                      mode: AppSourceTagMode.ready,
                    ),
                  AppSourceTag(
                    source: selectedSource,
                    mode: AppSourceTagMode.trust,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasCapability('has_versions'))
                Scrollbar(
                  controller: variantScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: variantScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.comfortable,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      segments:
                          <String>{
                            for (var v in app.variants) v.source,
                            if (extraDetails != null)
                              for (var v in extraDetails!.variants) v.source,
                            selectedSource,
                          }.map((String source) {
                            final version = getVersionForSource(source);
                            return ButtonSegment<String>(
                              value: source,
                              label: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      source,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (version != null)
                                      Text(
                                        "v$version",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              icon: _getSourceIcon(source),
                            );
                          }).toList(),
                      selected: {selectedSource},
                      onSelectionChanged: (Set<String> newSelection) {
                        final newValue = newSelection.first;
                        onSourceSelected(newValue);
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
