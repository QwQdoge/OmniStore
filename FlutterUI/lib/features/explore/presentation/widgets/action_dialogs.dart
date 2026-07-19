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
  final String? recommended;

  const InstallationDecisionDialog({
    super.key,
    required this.decision,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final reasons = decision['reasons'] as List? ?? const [];
    final preflightChecks = decision['preflightChecks'] as List? ?? const [];
    final risks = decision['risks'] as List? ?? const [];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0), // MD3 Extra Large Radius
      ),
      icon: Icon(
        Icons.assistant_rounded,
        color: colorScheme.primary,
        size: 28,
      ),
      title: Text(
        l10n.installationDecisionTitle,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recommended Source Block
              if (recommended != null) ...[
                Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.recommendedSource(recommended!),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reasons.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...reasons.map((reason) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 28.0,
                                  bottom: 4.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        reason.toString(),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Preflight Checks Block
              if (preflightChecks.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.preflightChecks,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...preflightChecks.map((check) => Padding(
                      padding: const EdgeInsets.only(
                        left: 4.0,
                        bottom: 8.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: colorScheme.secondary.withValues(alpha: 0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              check.toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // Risks Block
              if (risks.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.potentialRisks,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...risks.map((risk) => Padding(
                              padding: const EdgeInsets.only(
                                left: 4.0,
                                bottom: 8.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.gavel_rounded,
                                    color: colorScheme.error.withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      risk.toString(),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.continueInstallation),
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
