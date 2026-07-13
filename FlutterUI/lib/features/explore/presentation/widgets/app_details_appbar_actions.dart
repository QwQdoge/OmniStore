import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/data/repositories/ai_repository.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/explore/presentation/widgets/ai_dialogs.dart';

class AppDetailsAppBarActions {
  static List<Widget> buildActions({
    required BuildContext context,
    required AppPackage app,
    required bool isAIEnabled,
    required String selectedSource,
    required VoidCallback onShowTerminalDialog,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (app.url != null && app.url!.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.language_rounded),
          tooltip: l10n.visitWebsite,
          onPressed: () async {
            final uri = Uri.parse(app.url!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
      if (isAIEnabled) ...[
        IconButton(
          icon: const Icon(Icons.auto_awesome_rounded),
          tooltip: l10n.aiPromptExplain,
          onPressed: () => _showAIExplainDialog(context, app),
        ),
        if (app.variants.length > 1)
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: l10n.aiCompareTitle,
            onPressed: () => _showAICompareDialog(context, app),
          ),
        IconButton(
          icon: const Icon(Icons.terminal_rounded),
          tooltip: l10n.aiCliTitle,
          onPressed: () => _showAICliDialog(context, app, selectedSource),
        ),
        IconButton(
          icon: const Icon(Icons.report_problem_rounded),
          tooltip: l10n.aiConflictTitle,
          onPressed: () => _showAIConflictDialog(context, app),
        ),
      ],
      IconButton(
        icon: Selector<TaskController, bool>(
          selector: (context, tc) => tc.isBusy,
          builder: (context, isBusy, child) => Badge(
            isLabelVisible: isBusy,
            child: const Icon(Icons.terminal_rounded),
          ),
        ),
        tooltip: l10n.terminalOutput,
        onPressed: onShowTerminalDialog,
      ),
      const SizedBox(width: 8),
    ];
  }

  static Future<void> _showAIExplainDialog(BuildContext context, AppPackage app) async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiExplain(app.name, app.description);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiPromptExplain,
        future: future,
      ),
    );
  }

  static Future<void> _showAICompareDialog(BuildContext context, AppPackage app) async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiCompareVariants(app.name);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiCompareTitle,
        future: future,
        width: 600,
        height: 450,
      ),
    );
  }

  static Future<void> _showAICliDialog(BuildContext context, AppPackage app, String selectedSource) async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiGenerateCLI(app.name, selectedSource);
    showDialog(
      context: context,
      builder: (ctx) => AICliDialog(future: future),
    );
  }

  static Future<void> _showAIConflictDialog(BuildContext context, AppPackage app) async {
    final aiRepo = context.read<AIRepository>();
    final future = aiRepo.aiDetectConflicts(app.name);
    showDialog(
      context: context,
      builder: (ctx) => AIMarkdownDialog(
        title: AppLocalizations.of(context)!.aiConflictTitle,
        future: future,
      ),
    );
  }
}
