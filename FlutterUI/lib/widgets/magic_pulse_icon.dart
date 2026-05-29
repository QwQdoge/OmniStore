import 'package:flutter/material.dart';

class MagicPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const MagicPulseIcon({
    super.key,
    required this.icon,
    this.color = Colors.purple,
    this.size = 24.0,
  });

  @override
  State<MagicPulseIcon> createState() => _MagicPulseIconState();
}

class _MagicPulseIconState extends State<MagicPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        widget.icon,
        color: widget.color,
        size: widget.size,
        shadows: [
          Shadow(
            color: widget.color.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
