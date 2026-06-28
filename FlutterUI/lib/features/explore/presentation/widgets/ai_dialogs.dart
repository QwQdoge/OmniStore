import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AIMarkdownDialog extends StatelessWidget {
  final Future<String> future;
  final String title;
  final double width;
  final double height;

  const AIMarkdownDialog({
    super.key,
    required this.future,
    required this.title,
    this.width = 500,
    this.height = 400,
  });

  Widget _buildAIMarkdown(
    AsyncSnapshot<String> snapshot,
    AppLocalizations l10n,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 200,
        child: ParagraphSkeleton(),
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
          Text(title),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<String>(
          future: future,
          builder: (context, snapshot) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildAIMarkdown(snapshot, AppLocalizations.of(context)!),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.ok),
        ),
      ],
    );
  }
}

class AICliDialog extends StatelessWidget {
  final Future<String> future;

  const AICliDialog({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          Text(AppLocalizations.of(context)!.aiCliTitle),
        ],
      ),
      content: FutureBuilder<String>(
        future: future,
        builder: (context, snapshot) {
          final cmd = snapshot.data ?? "";
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(
                          width: double.infinity,
                          height: 24,
                          borderRadius: 8,
                        ),
                      ],
                    ),
                  )
                : Column(
                    key: const ValueKey('loaded'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cmd,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cmd));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.aiCommandCopied,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(
                          AppLocalizations.of(context)!.aiCopyCommand,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.ok),
        ),
      ],
    );
  }
}
