import 'package:flutter/material.dart';

/// A reusable widget that combines [AnimatedSize] and [AnimatedSwitcher]
/// to provide smooth layout transitions following Material Design 3 principles.
class SmoothSizeSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final Curve sizeCurve;

  const SmoothSizeSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.alignment = Alignment.topCenter,
    this.switchInCurve = Curves.easeOutCubic,
    this.switchOutCurve = Curves.fastOutSlowIn,
    this.sizeCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: sizeCurve,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: switchInCurve,
        switchOutCurve: switchOutCurve,
        child: child,
      ),
    );
  }
}
