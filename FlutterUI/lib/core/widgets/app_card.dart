import 'package:flutter/material.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final Clip clipBehavior;
  final double? elevation;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = 16.0,
    this.clipBehavior = Clip.antiAlias,
    this.elevation,
    this.margin,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _ensureControllerInitialized() {
    if (_controller != null) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.99).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = widget.onTap != null;

    Widget content = Card(
      color: widget.color ?? theme.colorScheme.surfaceContainerLow,
      elevation: widget.elevation ?? 0,
      margin: widget.margin ?? EdgeInsets.zero,
      clipBehavior: widget.clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
          width: 1,
        ),
      ),
      child: isInteractive
          ? InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onTap: widget.onTap,
              child: widget.child,
            )
          : widget.child,
    );

    if (isInteractive) {
      _ensureControllerInitialized();
      content = MouseRegion(
        onEnter: (_) => _controller?.forward(),
        onExit: (_) => _controller?.reverse(),
        child: RepaintBoundary(
          child: ScaleTransition(scale: _scaleAnimation!, child: content),
        ),
      );
    }

    return content;
  }
}
