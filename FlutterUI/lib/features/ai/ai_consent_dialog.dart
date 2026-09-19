import 'package:flutter/material.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AiConsentSummary {
  const AiConsentSummary({
    required this.providerName,
    required this.destination,
    required this.model,
    required this.purpose,
    required this.dataCategories,
    required this.promptCharacters,
    required this.payloadSha256,
    required this.systemPrompt,
    required this.userPrompt,
  });

  final String providerName;
  final String destination;
  final String model;
  final String purpose;
  final List<String> dataCategories;
  final int promptCharacters;
  final String payloadSha256;
  final String systemPrompt;
  final String userPrompt;
}

Future<bool> showAiConsentDialog(
  BuildContext context,
  AiConsentSummary summary,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AiConsentDialog(summary: summary),
  );
  return result == true;
}

class _AiConsentDialog extends StatefulWidget {
  const _AiConsentDialog({required this.summary});

  final AiConsentSummary summary;

  @override
  State<_AiConsentDialog> createState() => _AiConsentDialogState();
}

class _AiConsentDialogState extends State<_AiConsentDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final fingerprint = summary.payloadSha256.length >= 12
        ? summary.payloadSha256.substring(0, 12)
        : summary.payloadSha256;

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: const AiMark(size: 32),
      title: Text(
        l10n.aiConsentTitle,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiConsentIntro,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _ConsentRow(
                label: l10n.aiConsentProvider,
                value: summary.providerName,
              ),
              _ConsentRow(
                label: l10n.aiConsentDestination,
                value: summary.destination,
              ),
              _ConsentRow(label: l10n.aiConsentModel, value: summary.model),
              _ConsentRow(label: l10n.aiConsentPurpose, value: summary.purpose),
              _ConsentRow(
                label: l10n.aiConsentDataCategories,
                value: summary.dataCategories
                    .map((category) => _displayDataCategory(l10n, category))
                    .join(' · '),
              ),
              _ConsentRow(
                label: l10n.aiConsentCharacters,
                value: '${summary.promptCharacters}',
              ),
              _ConsentRow(
                label: l10n.aiConsentFingerprint,
                value: fingerprint,
                monospace: true,
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(l10n.aiConsentReviewContent),
                children: [
                  if (summary.systemPrompt.isNotEmpty)
                    _PromptPreview(
                      label: l10n.aiConsentSystemInstruction,
                      value: summary.systemPrompt,
                    ),
                  _PromptPreview(
                    label: l10n.aiConsentUserContent,
                    value: summary.userPrompt,
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acknowledged,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) =>
                    setState(() => _acknowledged = value == true),
                title: Text(
                  l10n.aiConsentConfirmWithProvider(summary.providerName),
                ),
                subtitle: Text(l10n.aiConsentKeyNotExposed),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.aiConsentDeny),
        ),
        FilledButton.icon(
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(l10n.aiConsentAllowOnce),
        ),
      ],
    );
  }

  String _displayDataCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'app_name':
        return l10n.aiConsentCategoryAppName;
      case 'app_description':
        return l10n.aiConsentCategoryAppDescription;
      case 'version_metadata':
        return l10n.aiConsentCategoryVersionMetadata;
      case 'package_source':
        return l10n.aiConsentCategoryPackageSource;
      case 'package_variants':
        return l10n.aiConsentCategoryPackageVariants;
      case 'preference_request':
        return l10n.aiConsentCategoryPreferenceRequest;
      case 'search_query':
        return l10n.aiConsentCategorySearchQuery;
      case 'system_environment_summary':
        return l10n.aiConsentCategorySystemEnvironment;
      case 'error_log':
        return l10n.aiConsentCategoryErrorLog;
      case 'recommendation_request':
        return l10n.aiConsentCategoryRecommendationRequest;
      case 'synthetic_test':
        return l10n.aiConsentCategoryConnectionTest;
      default:
        return category.replaceAll('_', ' ');
    }
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? const TextStyle(fontFamily: 'monospace')
                  : const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptPreview extends StatelessWidget {
  const _PromptPreview({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SelectableText(value),
        ],
      ),
    );
  }
}
