import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'welcome_config_card.dart';

class WelcomeAiPage extends StatelessWidget {
  final bool enableAI;
  final ValueChanged<bool> onEnableAIChanged;
  final String aiProvider;
  final ValueChanged<String?> onAiProviderChanged;
  final TextEditingController endpointController;
  final TextEditingController apiKeyController;
  final bool isTestingAI;
  final VoidCallback onTestAI;
  final String? testResult;
  final bool testSuccess;
  final VoidCallback onShowApiKeyInstructions;

  const WelcomeAiPage({
    super.key,
    required this.enableAI,
    required this.onEnableAIChanged,
    required this.aiProvider,
    required this.onAiProviderChanged,
    required this.endpointController,
    required this.apiKeyController,
    required this.isTestingAI,
    required this.onTestAI,
    this.testResult,
    required this.testSuccess,
    required this.onShowApiKeyInstructions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
          WelcomeConfigCard(
            child: SwitchListTile(
              title: Text(
                l10n.aiAssistant,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Enable intelligence integration features'),
              value: enableAI,
              onChanged: onEnableAIChanged,
            ),
          ),
          const SizedBox(height: 16),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: enableAI
                ? Column(
                    key: const ValueKey('ai-details'),
                    children: [
                      WelcomeConfigCard(
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
                              DropdownButtonFormField<String>(
                                initialValue: aiProvider,
                                borderRadius: BorderRadius.circular(12),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
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
                                onChanged: onAiProviderChanged,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: endpointController,
                                decoration: InputDecoration(
                                  labelText: 'Endpoint URL',
                                  hintText: aiProvider == 'ollama'
                                      ? l10n.aiEndpointHelper
                                      : 'e.g. https://api.openai.com/v1',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: apiKeyController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'API Key',
                                  hintText: l10n.aiApiKeyHelper,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: onShowApiKeyInstructions,
                                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                                    label: Text(l10n.howToGetApiKey),
                                  ),
                                  const Spacer(),
                                  SmoothSizeSwitcher(
                                    child: isTestingAI
                                        ? const SizedBox(
                                            key: ValueKey('testing'),
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : FilledButton.tonalIcon(
                                            key: const ValueKey('idle'),
                                            onPressed: onTestAI,
                                            icon: const Icon(Icons.network_ping_rounded, size: 18),
                                            label: const Text('Test Connection'),
                                          ),
                                  ),
                                ],
                              ),
                              if (testResult != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: testSuccess
                                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                        : theme.colorScheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: testSuccess
                                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                          : theme.colorScheme.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        testSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.error_outline_rounded,
                                        size: 18,
                                        color: testSuccess
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          testResult!,
                                          style: TextStyle(
                                            color: testSuccess
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
                      if (aiProvider == 'ollama') ...[
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
                                Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
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
