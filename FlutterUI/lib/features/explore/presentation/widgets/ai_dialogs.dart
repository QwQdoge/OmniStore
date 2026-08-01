import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/magic_pulse_icon.dart';
import 'package:frontend/core/widgets/skeleton.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

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
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const MagicPulseIcon(icon: Icons.auto_awesome_rounded, size: 32),
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: width,
        child: FutureBuilder<String>(
          future: future,
          builder: (context, snapshot) {
            return SmoothSizeSwitcher(
              alignment: Alignment.topLeft,
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
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const MagicPulseIcon(icon: Icons.auto_awesome_rounded, size: 32),
      title: Text(
        AppLocalizations.of(context)!.aiCliTitle,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: FutureBuilder<String>(
        future: future,
        builder: (context, snapshot) {
          final cmd = snapshot.data ?? "";
          return SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Skeleton(width: double.infinity, height: 24)],
                    ),
                  )
                : Column(
                    key: const ValueKey('loaded'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        color: theme.colorScheme.surfaceContainerLow,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            cmd,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cmd));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.copiedToClipboard,
                              ),
                              duration: const Duration(seconds: 2),
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
