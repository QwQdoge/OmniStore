import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const Skeleton({super.key, this.width, this.height, this.borderRadius = 8.0});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );
    final highlightColor = colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                (_animation.value - 0.5).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.5).clamp(0.0, 1.0),
                1.0,
              ],
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ParagraphSkeleton extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final double lastLineWidth;

  const ParagraphSkeleton({
    super.key,
    this.lines = 3,
    this.lineHeight = 14.0,
    this.spacing = 8.0,
    this.lastLineWidth = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (int i = 0; i < lines; i++) {
      final isLast = i == lines - 1;
      children.add(
        Skeleton(
          width: isLast ? lastLineWidth : double.infinity,
          height: lineHeight,
        ),
      );
      if (!isLast) {
        children.add(SizedBox(height: spacing));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
