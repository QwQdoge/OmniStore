import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'welcome_config_card.dart';

class WelcomeAiPage extends StatefulWidget {
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
  State<WelcomeAiPage> createState() => _WelcomeAiPageState();
}

class _WelcomeAiPageState extends State<WelcomeAiPage> {
  bool _isObscure = true;

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
              subtitle: Text(l10n.aiIntegrationDesc),
              value: widget.enableAI,
              onChanged: widget.onEnableAIChanged,
            ),
          ),
          const SizedBox(height: 16),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: widget.enableAI
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
                                initialValue: widget.aiProvider,
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
                                items: [
                                  DropdownMenuItem(
                                    value: 'ollama',
                                    child: Text(l10n.ollamaLocalOffline),
                                  ),
                                  DropdownMenuItem(
                                    value: 'openai',
                                    child: Text(l10n.openaiCloud),
                                  ),
                                ],
                                onChanged: widget.onAiProviderChanged,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: widget.endpointController,
                                decoration: InputDecoration(
                                  labelText: 'Endpoint URL',
                                  hintText: widget.aiProvider == 'ollama'
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
                                controller: widget.apiKeyController,
                                obscureText: _isObscure,
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
                                  suffixIcon: IconButton(
                                    icon: Icon(_isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                    onPressed: () => setState(() => _isObscure = !_isObscure),
                                    tooltip: _isObscure ? l10n.showPassword : l10n.hidePassword,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: widget.onShowApiKeyInstructions,
                                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                                    label: Text(l10n.howToGetApiKey),
                                  ),
                                  const Spacer(),
                                  FilledButton.tonalIcon(
                                    onPressed: widget.isTestingAI ? null : widget.onTestAI,
                                    icon: SmoothSizeSwitcher(
                                      child: widget.isTestingAI
                                          ? const SizedBox(
                                              key: ValueKey('testing'),
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.network_ping_rounded, size: 18, key: ValueKey('idle')),
                                    ),
                                    label: Text(l10n.testConnection),
                                  ),
                                ],
                              ),
                              if (widget.testResult != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: widget.testSuccess
                                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                        : theme.colorScheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.testSuccess
                                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                          : theme.colorScheme.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        widget.testSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.error_outline_rounded,
                                        size: 18,
                                        color: widget.testSuccess
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.testResult!,
                                          style: TextStyle(
                                            color: widget.testSuccess
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
                      if (widget.aiProvider == 'ollama') ...[
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
