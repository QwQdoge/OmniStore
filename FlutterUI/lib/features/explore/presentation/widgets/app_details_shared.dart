import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AppDetailsSectionTitle extends StatelessWidget {
  final String title;
  final bool isSubSection;

  const AppDetailsSectionTitle({
    super.key,
    required this.title,
    this.isSubSection = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isSubSection
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.secondary,
          )
        : theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
            letterSpacing: 0,
          );

    return Padding(
      padding: isSubSection
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(title, style: style),
    );
  }
}

class AppDetailsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const AppDetailsInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.copiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: "${l10n.tapToCopy} $label: $value",
      child: InkWell(
        onTap: () => _copyToClipboard(context),
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          label: "${l10n.tapToCopy} $label: $value",
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
