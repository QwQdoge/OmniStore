import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ActionConfirmDialog extends StatefulWidget {
  final bool isUninstall;
  final String appName;
  final String selectedSource;

  const ActionConfirmDialog({
    super.key,
    required this.isUninstall,
    required this.appName,
    required this.selectedSource,
  });

  @override
  State<ActionConfirmDialog> createState() => _ActionConfirmDialogState();
}

class _ActionConfirmDialogState extends State<ActionConfirmDialog> {
  bool cleanOrphans = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.isUninstall
            ? localizations.confirmUninstall
            : localizations.confirmInstall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.confirmActionMsg(widget.appName)),
          if (widget.isUninstall && widget.selectedSource == "Native") ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: cleanOrphans,
              onChanged: (val) {
                setState(() => cleanOrphans = val ?? false);
              },
              title: Text(
                localizations.cleanOrphans,
                style: const TextStyle(fontSize: 14),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          style: widget.isUninstall
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, cleanOrphans),
          child: Text(localizations.confirm),
        ),
      ],
    );
  }
}

class InstallationDecisionDialog extends StatelessWidget {
  final Map<String, dynamic> decision;

  const InstallationDecisionDialog({
    super.key,
    required this.decision,
  });

  @override
  Widget build(BuildContext context) {
    final recommended = decision['recommendedVariant']?.toString();
    return AlertDialog(
      title: const Text('安装决策助手'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended != null) Text('推荐来源：$recommended'),
            for (final reason in (decision['reasons'] as List? ?? const []))
              Text('• $reason'),
            const SizedBox(height: 12),
            const Text(
              '安装前检查',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final check
                in (decision['preflightChecks'] as List? ?? const []))
              Text('• $check'),
            if ((decision['risks'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '风险提示',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final risk in (decision['risks'] as List? ?? const []))
                Text('• $risk'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('继续安装'),
        ),
      ],
    );
  }
}

class AurSecurityDialog extends StatelessWidget {
  const AurSecurityDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 48,
      ),
      title: Text(localizations.securityWarning),
      content: Text(localizations.aurSecurityDesc),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localizations.continueInstall),
        ),
      ],
    );
  }
}
