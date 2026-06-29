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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
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

  const AIPickSection({
    super.key,
    required this.aiPickBlurb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(28),
      ),
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(data: aiPickBlurb),
          const SizedBox(height: 12),
          AIAppResolver(aiText: aiPickBlurb, jsonPrefix: "PICK_JSON:"),
        ],
      ),
    );
  }
}
