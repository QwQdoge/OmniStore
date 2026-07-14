import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../controllers/settings_controller.dart';

class GeneralSettingsCard extends StatelessWidget {
  final bool showAdvanced;
  final ValueChanged<bool> onAdvancedChanged;

  const GeneralSettingsCard({
    super.key,
    required this.showAdvanced,
    required this.onAdvancedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<
      SettingsController,
      ({
        String language,
        bool closeToTray,
        bool useSystemTitleBar,
        bool isAIEnabled,
      })
    >(
      selector: (context, s) => (
        language: s.language,
        closeToTray: s.closeToTray,
        useSystemTitleBar: s.useSystemTitleBar,
        isAIEnabled: s.isAIEnabled,
      ),
      builder: (context, data, _) {
        return AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: Text(l10n.language),
                subtitle: Text(l10n.languageSubtitle),
                trailing: DropdownButton<String>(
                  value: data.language,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    DropdownMenuItem(
                      value: 'en-US',
                      child: Text(l10n.langEnglish),
                    ),
                    DropdownMenuItem(
                      value: 'zh-CN',
                      child: Text(l10n.langSimplifiedChinese),
                    ),
                    DropdownMenuItem(
                      value: 'zh-TW',
                      child: Text(l10n.langTraditionalChinese),
                    ),
                    DropdownMenuItem(
                      value: 'ja-JP',
                      child: Text(l10n.langJapanese),
                    ),
                    DropdownMenuItem(
                      value: 'es-ES',
                      child: Text(l10n.langSpanish),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      context.read<SettingsController>().setLanguage(val);
                    }
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.archive_rounded),
                title: Text(l10n.closeToTray),
                value: data.closeToTray,
                onChanged: (val) {
                  context.read<SettingsController>().setCloseToTray(val);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.window_rounded),
                title: Text(l10n.useSystemTitleBar),
                subtitle: Text(l10n.restartTitleBar),
                value: data.useSystemTitleBar,
                onChanged: (val) {
                  context.read<SettingsController>().setUseSystemTitleBar(val);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.configSaved)));
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_rounded),
                title: Text(l10n.aiEnabled),
                subtitle: Text(l10n.aiAssistantDesc),
                value: data.isAIEnabled,
                onChanged: (val) {
                  final settings = context.read<SettingsController>();
                  final config = Map<String, dynamic>.from(settings.config);
                  config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
                  config['ai']['enabled'] = val;
                  settings.updateConfig(config);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.tune_rounded),
                title: Text(l10n.advanced),
                value: showAdvanced,
                onChanged: onAdvancedChanged,
              ),
            ],
          ),
        );
      },
    );
  }
}
