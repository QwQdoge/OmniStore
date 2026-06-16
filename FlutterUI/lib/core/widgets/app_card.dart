import 'package:flutter/material.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final bool showBorder;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = 16.0,
    this.showBorder = true,
    this.margin,
    this.clipBehavior = Clip.none,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovering) {
    if (widget.onTap != null) {
      if (isHovering) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          color: widget.color ?? theme.colorScheme.surfaceContainerLow,
          margin: widget.margin,
          clipBehavior: widget.clipBehavior,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            side: widget.showBorder
                ? BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
