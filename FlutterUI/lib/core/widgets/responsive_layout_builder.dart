import 'package:flutter/material.dart';

/// A self-contained widget that caches its built child to isolate MediaQuery rebuilding.
class ResponsiveLayoutBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isDesktop) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  State<ResponsiveLayoutBuilder> createState() => _ResponsiveLayoutBuilderState();
}

class _ResponsiveLayoutBuilderState extends State<ResponsiveLayoutBuilder> {
  bool? _lastIsDesktop;
  Widget? _cachedChild;

  @override
  void didUpdateWidget(covariant ResponsiveLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent state changed (e.g. apps loaded, details changed). Clear cache to rebuild.
    _cachedChild = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 900;

    if (_cachedChild == null || _lastIsDesktop != isDesktop) {
      _lastIsDesktop = isDesktop;
      _cachedChild = widget.builder(context, isDesktop);
    }

    return _cachedChild!;
  }
}
