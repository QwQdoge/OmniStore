import 'package:flutter/material.dart';
import 'package:frontend/core/network/github_client.dart';

/// Fetches GitHub stars asynchronously with skeleton + animated count.
class GitHubStarBadge extends StatefulWidget {
  const GitHubStarBadge({
    super.key,
    required this.client,
    this.repositoryUrl,
    this.owner,
    this.repo,
    this.compact = false,
  });

  final GitHubClient client;
  final String? repositoryUrl;
  final String? owner;
  final String? repo;
  final bool compact;

  @override
  State<GitHubStarBadge> createState() => _GitHubStarBadgeState();
}

class _GitHubStarBadgeState extends State<GitHubStarBadge> {
  int? _stars;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GitHubStarBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repositoryUrl != widget.repositoryUrl ||
        oldWidget.owner != widget.owner ||
        oldWidget.repo != widget.repo) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });

    int? count;
    try {
      if (widget.owner != null && widget.repo != null) {
        count = await widget.client.getStarCount(widget.owner!, widget.repo!);
      } else {
        count = await widget.client.getStarCountFromUrl(widget.repositoryUrl);
      }
    } catch (_) {
      count = null;
    }

    if (!mounted) return;
    setState(() {
      _stars = count;
      _loading = false;
      _failed = count == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return _StarChip(
        compact: widget.compact,
        child: SizedBox(
          width: widget.compact ? 48 : 64,
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (_failed) {
      return _StarChip(
        compact: widget.compact,
        child: Icon(
          Icons.star_outline_rounded,
          size: widget.compact ? 16 : 18,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final label = _formatCount(_stars!);
    return _StarChip(
      compact: widget.compact,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: widget.compact ? 16 : 18,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.fastOutSlowIn,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              label,
              key: ValueKey<String>(label),
              style: TextStyle(
                fontSize: widget.compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        child: child,
      ),
    );
  }
}
