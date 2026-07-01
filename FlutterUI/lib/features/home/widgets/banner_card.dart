import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class BannerCard extends StatelessWidget {
  final AppPackage app;

  const BannerCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenshot = (app.screenshots != null && app.screenshots!.isNotEmpty)
        ? app.screenshots!.first
        : null;
    final heroTag = 'hero-banner-${app.name}-${app.primarySource}';

    return Semantics(
      label: 'Featured app: ${app.name}',
      button: true,
      child: AppCard(
        borderRadius: 28,
        clipBehavior: Clip.antiAlias,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppDetailsPage(app: app, heroTag: heroTag),
          ),
        ),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
          ),
          child: Stack(
            children: [
              if (screenshot != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: screenshot,
                    fit: BoxFit.cover,
                    memCacheWidth: 880,
                    errorWidget: (c, e, s) => const Icon(Icons.image, size: 48),
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.apps_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                right: 20,
                child: Row(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: app.icon != null
                            ? CachedNetworkImage(
                                imageUrl: app.icon!,
                                fit: BoxFit.cover,
                                memCacheWidth: 108,
                                errorWidget: (c, e, s) =>
                                    const Icon(Icons.apps, color: Colors.black),
                              )
                            : const Icon(Icons.apps, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            app.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
