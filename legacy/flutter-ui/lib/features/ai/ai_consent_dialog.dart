import 'package:flutter/material.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';

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
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final fingerprint = summary.payloadSha256.length >= 12
        ? summary.payloadSha256.substring(0, 12)
        : summary.payloadSha256;

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      icon: const AiMark(size: 32),
      title: Text(
        isChinese ? '允许这一次 AI 调用？' : 'Allow this AI request?',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
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
                isChinese
                    ? 'OmniStore 只会发送下列请求。授权仅对本次摘要有效，不能记住或重放。'
                    : 'OmniStore will send only the request below. Approval is bound to this one-time fingerprint and cannot be remembered or replayed.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _ConsentRow(
                label: isChinese ? '服务' : 'Provider',
                value: summary.providerName,
              ),
              _ConsentRow(
                label: isChinese ? '发送到' : 'Destination',
                value: summary.destination,
              ),
              _ConsentRow(
                label: isChinese ? '模型' : 'Model',
                value: summary.model,
              ),
              _ConsentRow(
                label: isChinese ? '用途' : 'Purpose',
                value: summary.purpose,
              ),
              _ConsentRow(
                label: isChinese ? '数据类别' : 'Data categories',
                value: summary.dataCategories.join(' · '),
              ),
              _ConsentRow(
                label: isChinese ? '字符数' : 'Characters',
                value: '${summary.promptCharacters}',
              ),
              _ConsentRow(
                label: isChinese ? '请求指纹' : 'Fingerprint',
                value: fingerprint,
                monospace: true,
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(isChinese ? '查看将发送的完整内容' : 'Review full content'),
                children: [
                  if (summary.systemPrompt.isNotEmpty)
                    _PromptPreview(
                      label: isChinese ? '系统指令' : 'System instruction',
                      value: summary.systemPrompt,
                    ),
                  _PromptPreview(
                    label: isChinese ? '用户内容' : 'User content',
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
                  isChinese
                      ? '我确认以上内容将发送给 ${summary.providerName}'
                      : 'I confirm this content will be sent to ${summary.providerName}',
                ),
                subtitle: Text(
                  isChinese
                      ? 'API 密钥不会发送到 OmniStore，也不会显示在此处。'
                      : 'The API key is never returned to OmniStore or shown here.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isChinese ? '拒绝' : 'Deny'),
        ),
        FilledButton.icon(
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(isChinese ? '仅同意这一次并发送' : 'Allow once and send'),
        ),
      ],
    );
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
