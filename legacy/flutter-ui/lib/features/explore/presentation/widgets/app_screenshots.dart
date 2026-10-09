import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/app_card.dart';

class AppScreenshots extends StatelessWidget {
  final List<dynamic> screenshots;
  final ScrollController scrollController;
  final ValueChanged<String> onShowScreenshotViewer;

  const AppScreenshots({
    super.key,
    required this.screenshots,
    required this.scrollController,
    required this.onShowScreenshotViewer,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrls = screenshots
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => Uri.tryParse(value)?.hasScheme == true)
        .toList(growable: false);
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth * 0.78).clamp(240.0, 360.0);
        return SizedBox(
          height: itemWidth * 0.61 + 16,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: imageUrls.length > 1,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              // ⚡ Bolt: Use prototypeItem for better scroll virtualization and scrollbar accuracy
              prototypeItem: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(width: itemWidth),
              ),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = imageUrls[index];
                final labelText =
                    "${AppLocalizations.of(context)!.screenshots} ${index + 1}/${imageUrls.length}";
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Tooltip(
                    message: labelText,
                    child: Semantics(
                      label: labelText,
                      button: true,
                      child: Hero(
                        tag: 'screenshot-$imageUrl',
                        child: SizedBox(
                          width: itemWidth,
                          child: AppCard(
                            onTap: () => onShowScreenshotViewer(imageUrl),
                            borderRadius: 16.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16.0),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: itemWidth,
                                fit: BoxFit.cover,
                                memCacheWidth: 720,
                                placeholder: (context, url) => Skeleton(
                                  width: itemWidth,
                                  height: 220,
                                  borderRadius: 16.0,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: itemWidth,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
