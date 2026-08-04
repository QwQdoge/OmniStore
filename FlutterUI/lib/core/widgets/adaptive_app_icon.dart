import 'package:flutter/material.dart';

/// OmniStore logo that remains legible in both light and dark themes.
class AdaptiveAppIcon extends StatelessWidget {
  const AdaptiveAppIcon({
    super.key,
    this.size = 48,
    this.showUpdateBadge = false,
  });

  final double size;
  final bool showUpdateBadge;

  @override
  Widget build(BuildContext context) {
    final suffix = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    final state = showUpdateBadge ? 'omnistore_update' : 'omnistore';
    return Image.asset(
      'assets/icons/${state}_$suffix.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'OmniStore',
    );
  }
}
