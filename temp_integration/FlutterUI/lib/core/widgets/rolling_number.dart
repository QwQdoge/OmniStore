import 'package:flutter/material.dart';

class RollingNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const RollingNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          val.toInt().toString(),
          style: style,
        );
      },
    );
  }
}
