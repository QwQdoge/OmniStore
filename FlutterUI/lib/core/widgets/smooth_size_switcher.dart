import 'package:flutter/material.dart';

/// A reusable widget that combines `AnimatedSize` and `AnimatedSwitcher`
/// with standard Material Design 3 motion curves (easeOutCubic, fastOutSlowIn)
/// and a default duration of 300ms.
class SmoothSizeSwitcher extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  final Duration duration;

  const SmoothSizeSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.fastOutSlowIn,
        child: child,
      ),
    );
  }
}
