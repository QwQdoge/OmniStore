import 'dart:io';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import '../widgets/storage_cleanup_card.dart';
import '../widgets/sources_config_card.dart';
import '../widgets/ai_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<SettingsController>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.settings,
                    style: OmnistoreTheme.standardHeader(context),
                  ),
                  FilterChip(
                    label: Text(l10n.advanced),
                    selected: _showAdvanced,
                    onSelected: (val) => setState(() => _showAdvanced = val),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Primary Settings
              _buildSection(l10n.general),
              ListTile(
                title: Text(l10n.language),
                subtitle: Text(
                  settings.language == 'zh-CN'
                      ? l10n.langSimplifiedChinese
                      : settings.language == 'zh-TW'
                      ? l10n.langTraditionalChinese
                      : settings.language == 'ja-JP'
                      ? l10n.langJapanese
                      : settings.language == 'es-ES' ||
                            settings.language == 'es'
                      ? l10n.langSpanish
                      : l10n.langEnglish,
                ),
                trailing: DropdownButton<String>(
                  value: settings.language,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    DropdownMenuItem(
                      value: 'zh-CN',
                      child: Text(l10n.langSimplifiedChinese),
                    ),
                    DropdownMenuItem(
                      value: 'zh-TW',
                      child: Text(l10n.langTraditionalChinese),
                    ),
                    DropdownMenuItem(
                      value: 'en-US',
                      child: Text(l10n.langEnglish),
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
                      settings.setLanguage(val);
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: Text(l10n.closeToTray),
                value: settings.closeToTray,
                onChanged: (val) {
                  settings.setCloseToTray(val);
                },
              ),
              SwitchListTile(
                title: Text(l10n.useSystemTitleBar),
                subtitle: Text(l10n.configSaved),
                value: settings.useSystemTitleBar,
                onChanged: (val) {
                  settings.setUseSystemTitleBar(val);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.configSaved)));
                },
              ),
              SwitchListTile(
                title: Text(l10n.aiEnabled),
                subtitle: Text(l10n.aiAssistantDesc),
                value: settings.isAIEnabled,
                onChanged: (val) {
                  final config = Map<String, dynamic>.from(settings.config);
                  config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
                  config['ai']['enabled'] = val;
                  settings.updateConfig(config);
                },
              ),
              // Storage & Cleanup Card
              const StorageCleanupCard(),

              const SizedBox(height: 24),
              _buildSection(l10n.repositories),
              SourcesConfigCard(settings: settings),

              const SizedBox(height: 24),
              _buildSection(l10n.updates),
              SwitchListTile(
                title: Text(l10n.enableDaemon),
                subtitle: Text(l10n.enableDaemonDesc),
                value: settings.daemonEnabled,
                onChanged: (val) {
                  settings.setDaemonEnabled(val);
                },
              ),
              SwitchListTile(
                title: Text(l10n.autoUpdate),
                subtitle: Text(l10n.autoUpdateDesc),
                value: settings.autoUpdate,
                onChanged: (val) {
                  settings.setAutoUpdate(val);
                },
              ),
              if (Platform.isLinux)
                SwitchListTile(
                  title: Text(l10n.enableSystemdService),
                  subtitle: Text(l10n.enableSystemdServiceDesc),
                  value: settings.enableSystemdService,
                  onChanged: (val) {
                    settings.setEnableSystemdService(val);
                  },
                ),
              ListTile(
                title: Text(l10n.checkIntervalTitle),
                subtitle: Text(
                  l10n.checkIntervalSubtitle(settings.checkIntervalHours),
                ),
                trailing: DropdownButton<int>(
                  value: settings.checkIntervalHours,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [1, 2, 4, 8, 12, 24].map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text(l10n.hourValue(h)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      settings.setCheckIntervalHours(val);
                    }
                  },
                ),
              ),

              const SizedBox(height: 24),
              _buildSection(l10n.typography),
              ListTile(
                title: Text(l10n.fontFamily),
                subtitle: Text(
                  settings.fontFamily == 'System'
                      ? l10n.systemDefault
                      : settings.fontFamily,
                ),
                trailing: DropdownButton<String>(
                  value: settings.fontFamily,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    DropdownMenuItem(
                      value: 'System',
                      child: Text(l10n.systemDefault),
                    ),
                    const DropdownMenuItem(
                      value: 'Inter',
                      child: Text('Inter'),
                    ),
                    const DropdownMenuItem(
                      value: 'Roboto',
                      child: Text('Roboto'),
                    ),
                    const DropdownMenuItem(
                      value: 'Outfit',
                      child: Text('Outfit'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      settings.setFontFamily(val);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(l10n.fontScale),
                subtitle: Text("${(settings.fontScale * 100).toInt()}%"),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: settings.fontScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: "${(settings.fontScale * 100).toInt()}%",
                    onChanged: (val) {
                      settings.setFontScale(
                        double.parse(val.toStringAsFixed(2)),
                      );
                    },
                  ),
                ),
              ),

              if (_showAdvanced)
                AISettingsSection(settings: settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
