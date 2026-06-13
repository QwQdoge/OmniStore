import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/data/repositories/ai_repository.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AIUpdateSummaryDialog extends StatelessWidget {
  final String name;
  final String currentVersion;
  final String nextVersion;

  const AIUpdateSummaryDialog({
    super.key,
    required this.name,
    required this.currentVersion,
    required this.nextVersion,
  });

  @override
  Widget build(BuildContext context) {
    final aiRepo = context.read<AIRepository>();

    return AlertDialog(
      title: Row(
        children: [
          const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          Text(AppLocalizations.of(context)!.aiChangelogTitle),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: FutureBuilder<String>(
          future: aiRepo.aiSummarizeUpdate(name, currentVersion, nextVersion),
          builder: (context, snapshot) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: double.infinity, height: 14),
                          SizedBox(height: 8),
                          Skeleton(width: double.infinity, height: 14),
                          SizedBox(height: 8),
                          Skeleton(width: 200, height: 14),
                        ],
                      ),
                    )
                  : MarkdownBody(
                      key: const ValueKey('loaded'),
                      data: snapshot.data ?? "AI failed to summarize.",
                      selectable: true,
                    ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.confirm),
        ),
      ],
    );
  }
}
