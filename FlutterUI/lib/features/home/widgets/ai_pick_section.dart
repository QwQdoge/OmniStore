import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/ai_app_resolver.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';

class AIPickSkeleton extends StatelessWidget {
  const AIPickSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.3,
          ),
          width: 1,
        ),
      ),
      child: const Column(
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
    );
  }
}

class AIPickSection extends StatelessWidget {
  final String aiPickBlurb;

  const AIPickSection({super.key, required this.aiPickBlurb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MagicPulseIcon(
                icon: Icons.auto_awesome_rounded,
                color: theme.colorScheme.tertiary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.aiPickDay,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MarkdownBody(data: aiPickBlurb),
          const SizedBox(height: 16),
          AIAppResolver(aiText: aiPickBlurb, jsonPrefix: "PICK_JSON:"),
        ],
      ),
    );
  }
}
