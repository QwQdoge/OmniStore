import 'package:flutter/material.dart';
import 'package:frontend/app/external_install_request.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/task_manager/presentation/widgets/terminal_dialog.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Shows an OmniStore-owned confirmation and, only after acceptance, hands the
/// validated request to the existing package task pipeline.
Future<void> showExternalInstallPrompt(
  BuildContext context,
  ExternalInstallRequest request,
) async {
  final l10n = AppLocalizations.of(context)!;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        Icons.download_rounded,
        color: Theme.of(dialogContext).colorScheme.primary,
        size: 32,
      ),
      title: Text(l10n.confirmInstall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.confirmActionMsg(request.packageId)),
          const SizedBox(height: 12),
          Text(
            request.source,
            style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.download),
        ),
      ],
    ),
  );

  if (accepted != true || !context.mounted) return;

  final taskController = context.read<TaskController>();
  if (taskController.isBusy) {
    Toast.show(context, l10n.taskInProgress);
    return;
  }

  final succeeded = await taskController.runTask(
    '-I',
    request.packageId,
    request.source,
    l10n,
  );
  if (!context.mounted) return;
  if (succeeded) {
    Toast.show(context, l10n.success);
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => const TerminalDialog(),
    );
  }
}
