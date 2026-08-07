import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'config_card.dart';

class AiConfigPage extends StatelessWidget {
  final bool enableAI;
  final ValueChanged<bool> onEnableAIChanged;
  final String aiProvider;
  final ValueChanged<String?> onAiProviderChanged;
  final TextEditingController aiEndpointController;
  final TextEditingController aiApiKeyController;
  final bool isTestingAI;
  final String? aiTestResult;
  final bool aiTestSuccess;
  final VoidCallback onTestAIConnection;

  const AiConfigPage({
    super.key,
    required this.enableAI,
    required this.onEnableAIChanged,
    required this.aiProvider,
    required this.onAiProviderChanged,
    required this.aiEndpointController,
    required this.aiApiKeyController,
    required this.isTestingAI,
    required this.aiTestResult,
    required this.aiTestSuccess,
    required this.onTestAIConnection,
  });

  void _showApiKeyInstructions(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
      clipBehavior: Clip.antiAlias,
          title: Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                l10n.howToGetApiKey,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            l10n.howToGetApiKeyDesc,
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final enableAIVal = enableAI;
    final aiProviderVal = aiProvider;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiAssistant,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiAssistantDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ConfigCard(
            child: SwitchListTile(
              title: Text(
                l10n.aiAssistant,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Enable intelligence integration features'),
              value: enableAIVal,
              onChanged: onEnableAIChanged,
            ),
          ),
          const SizedBox(height: 16),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: enableAIVal
                ? Column(
                    key: const ValueKey('ai-details'),
                    children: [
                      ConfigCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.aiProviderDesc,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: aiProviderVal,
                                    borderRadius: BorderRadius.circular(12),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'ollama',
                                        child: Text('Ollama (Local / Offline)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'openai',
                                        child: Text('OpenAI API (Cloud)'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        onAiProviderChanged(val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: aiEndpointController,
                                decoration: InputDecoration(
                                  labelText: 'Endpoint URL',
                                  hintText: aiProviderVal == 'ollama'
                                      ? l10n.aiEndpointHelper
                                      : 'e.g. https://api.openai.com/v1',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: aiApiKeyController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'API Key',
                                  hintText: l10n.aiApiKeyHelper,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _showApiKeyInstructions(
                                        context,
                                        l10n,
                                        theme,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.help_outline_rounded,
                                      size: 18,
                                    ),
                                    label: Text(l10n.howToGetApiKey),
                                  ),
                                  const Spacer(),
                                  SmoothSizeSwitcher(
                                    child: isTestingAI
                                        ? const SizedBox(
                                            key: ValueKey('testing'),
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : FilledButton.tonalIcon(
                                            key: const ValueKey('idle'),
                                            onPressed: onTestAIConnection,
                                            icon: const Icon(
                                              Icons.network_ping_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Test Connection'),
                                          ),
                                  ),
                                ],
                              ),
                              if (aiTestResult != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: aiTestSuccess
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : theme.colorScheme.error.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: aiTestSuccess
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.3)
                                          : theme.colorScheme.error.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        aiTestSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.error_outline_rounded,
                                        size: 18,
                                        color: aiTestSuccess
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          aiTestResult!,
                                          style: TextStyle(
                                            color: aiTestSuccess
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                      if (aiProviderVal == 'ollama') ...[
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.aiOllamaNote,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('ai-empty')),
          ),
        ],
      ),
    );
  }
}
