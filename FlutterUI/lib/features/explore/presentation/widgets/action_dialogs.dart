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
      icon: Icon(
        widget.isUninstall
            ? Icons.delete_sweep_rounded
            : Icons.download_rounded,
        color: widget.isUninstall
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        size: 32,
      ),
      title: Text(
        widget.isUninstall
            ? localizations.confirmUninstall
            : localizations.confirmInstall,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.confirmActionMsg(widget.appName),
            style: theme.textTheme.bodyMedium,
          ),
          if (widget.isUninstall && widget.selectedSource == "Native") ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surfaceContainerLow,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: CheckboxListTile(
                value: cleanOrphans,
                onChanged: (val) {
                  setState(() => cleanOrphans = val ?? false);
                },
                title: Text(
                  localizations.cleanOrphans,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
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
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recommended = decision['recommendedVariant']?.toString();

    return AlertDialog(
      icon: Icon(
        Icons.info_outline_rounded,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: Text(
        localizations.installationDecisionTitle,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.recommend_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localizations.recommendedSource(recommended),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((decision['reasons'] as List? ?? const []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final reason in (decision['reasons'] as List? ?? const []))
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    reason.toString(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if ((decision['preflightChecks'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_add_check_rounded,
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.preflightChecks,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final check in (decision['preflightChecks'] as List? ?? const []))
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  check.toString(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if ((decision['risks'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.potentialRisks,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final risk in (decision['risks'] as List? ?? const []))
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  risk.toString(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localizations.continueInstallation),
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
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.gpp_maybe_rounded,
        color: theme.colorScheme.error,
        size: 32,
      ),
      title: Text(
        localizations.securityWarning,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        localizations.aurSecurityDesc,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
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
