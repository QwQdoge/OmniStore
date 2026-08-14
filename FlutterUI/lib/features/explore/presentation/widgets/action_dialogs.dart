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
      clipBehavior: Clip.antiAlias,
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
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
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

class _DecisionSectionCard extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final BorderSide? borderSide;
  final IconData icon;
  final String title;
  final List<dynamic> items;

  const _DecisionSectionCard({
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderSide,
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && title.isEmpty) return const SizedBox.shrink();

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderSide ?? BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: foregroundColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: TextStyle(
                            color: foregroundColor,
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
    );
  }
}

class InstallationDecisionDialog extends StatelessWidget {
  final Map<String, dynamic> decision;

  const InstallationDecisionDialog({super.key, required this.decision});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recommended = decision['recommendedVariant']?.toString();

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
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
              _DecisionSectionCard(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                icon: Icons.recommend_rounded,
                title: localizations.recommendedSource(recommended),
                items: decision['reasons'] as List? ?? const [],
              ),
            ],
            if ((decision['preflightChecks'] as List? ?? const [])
                .isNotEmpty) ...[
              const SizedBox(height: 16),
              _DecisionSectionCard(
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                foregroundColor: theme.colorScheme.onSurface,
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                icon: Icons.playlist_add_check_rounded,
                title: localizations.preflightChecks,
                items: decision['preflightChecks'] as List? ?? const [],
              ),
            ],
            if ((decision['risks'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 16),
              _DecisionSectionCard(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                borderSide: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
                icon: Icons.warning_amber_rounded,
                title: localizations.potentialRisks,
                items: decision['risks'] as List? ?? const [],
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
      clipBehavior: Clip.antiAlias,
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
