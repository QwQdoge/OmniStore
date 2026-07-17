import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/ai_app_resolver.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/app_card.dart';

class AIPickSkeleton extends StatelessWidget {
  const AIPickSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 28,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(width: 24, height: 24, borderRadius: 12),
                SizedBox(width: 8),
                Skeleton(width: 140, height: 16),
              ],
            ),
            SizedBox(height: 16),
            Skeleton(width: double.infinity, height: 14),
            SizedBox(height: 8),
            Skeleton(width: 240, height: 14),
            SizedBox(height: 16),
            Skeleton(width: 120, height: 36, borderRadius: 18),
          ],
        ),
      ),
    );
  }
}

class AIPickSection extends StatelessWidget {
  final String aiPickBlurb;
  final VoidCallback? onRefresh;
  final bool isFallback;

  const AIPickSection({
    super.key,
    required this.aiPickBlurb,
    this.onRefresh,
    this.isFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 28,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MagicPulseIcon(
                  icon: Icons.auto_awesome_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.aiPickDay,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '根据你的搜索、安装历史和当前可用来源生成；不会影响安装选择。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (isFallback)
              Text(aiPickBlurb, style: theme.textTheme.bodyMedium)
            else ...[
              MarkdownBody(data: aiPickBlurb),
              const SizedBox(height: 16),
              AIAppResolver(aiText: aiPickBlurb, jsonPrefix: "PICK_JSON:"),
            ],
            if (onRefresh != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('换一个推荐'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
