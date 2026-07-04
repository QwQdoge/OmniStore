import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    return SizedBox(
      height: 236,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // ⚡ Bolt: Use prototypeItem for better scroll virtualization and scrollbar accuracy
          prototypeItem: const SizedBox(
            width: 376, // 360 + 16 (manual spacing)
            child: SizedBox.shrink(),
          ),
          itemCount: screenshots.length,
          itemBuilder: (context, index) {
            final imageUrl = screenshots[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Hero(
                tag: 'screenshot-$imageUrl',
                child: SizedBox(
                  width: 360,
                  child: AppCard(
                    onTap: () => onShowScreenshotViewer(imageUrl),
                    borderRadius: 16.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 360,
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        placeholder: (context, url) => const Skeleton(
                          width: 360,
                          height: 220,
                          borderRadius: 16.0,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 360,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_rounded),
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
  }
}
