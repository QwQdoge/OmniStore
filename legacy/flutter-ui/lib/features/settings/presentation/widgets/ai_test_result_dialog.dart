import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AITestResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String msg;
  final Map<String, dynamic> diagnostics;

  const AITestResultDialog({
    super.key,
    required this.isSuccess,
    required this.msg,
    this.diagnostics = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: Icon(
        isSuccess
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded,
        color: isSuccess ? theme.colorScheme.primary : theme.colorScheme.error,
        size: 32,
      ),
      title: Text(
        isSuccess ? l10n.aiTestSuccess : l10n.failed,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: msg.isNotEmpty || diagnostics.isNotEmpty
          ? SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: theme.colorScheme.surfaceContainerLow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(msg, style: theme.textTheme.bodyMedium),
                    ),
                  ),
                  if (diagnostics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DiagnosticRow(
                      label: l10n.aiProvider,
                      value: '${diagnostics['provider'] ?? '-'}',
                    ),
                    _DiagnosticRow(
                      label: l10n.aiModel,
                      value: '${diagnostics['model'] ?? '-'}',
                    ),
                    _DiagnosticRow(
                      label: 'Service',
                      value: diagnostics['service_reachable'] == true
                          ? 'Connected'
                          : 'Unavailable',
                    ),
                    _DiagnosticRow(
                      label: 'Model',
                      value: diagnostics['model_ready'] == true
                          ? 'Ready'
                          : 'Not ready',
                    ),
                    if (diagnostics['latency_ms'] != null)
                      _DiagnosticRow(
                        label: 'Latency',
                        value: '${diagnostics['latency_ms']} ms',
                      ),
                    if ('${diagnostics['suggestion'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        '${diagnostics['suggestion']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            )
          : null,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
