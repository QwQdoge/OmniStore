import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/data/repositories/ai_repository.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AIUpdateSummaryDialog extends StatefulWidget {
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
  State<AIUpdateSummaryDialog> createState() => _AIUpdateSummaryDialogState();
}

class _AIUpdateSummaryDialogState extends State<AIUpdateSummaryDialog> {
  late final Future<String> _summaryFuture;

  @override
  void initState() {
    super.initState();
    final aiRepo = context.read<AIRepository>();
    _summaryFuture = aiRepo.aiSummarizeUpdate(
      widget.name,
      widget.currentVersion,
      widget.nextVersion,
    );
  }

  Widget _buildAIMarkdown(
    AsyncSnapshot<String> snapshot,
    AppLocalizations l10n,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
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
      );
    }
    String data = snapshot.data ?? l10n.aiResponseFailed;
    if (data == "AI_TIMEOUT") data = l10n.aiTimeout;
    if (data == "AI_NO_RESPONSE") data = l10n.aiNoResponse;
    if (data == "AI_PARSE_FAILED") data = l10n.aiParseFailed;
    if (data.startsWith("AI_CALL_FAILED:")) {
      data = l10n.aiCallFailed(data.replaceFirst("AI_CALL_FAILED:", ""));
    }

    return SingleChildScrollView(
      key: const ValueKey('loaded'),
      child: MarkdownBody(data: data, selectable: true),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          future: _summaryFuture,
          builder: (context, snapshot) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 200,
                      child: ParagraphSkeleton(),
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
