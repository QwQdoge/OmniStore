import 'dart:io';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../widgets/storage_cleanup_card.dart';
import '../widgets/sources_config_card.dart';
import '../widgets/ai_settings_section.dart';
import '../widgets/settings_section_header.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.settings,
            style: OmnistoreTheme.standardHeader(context),
          ),
          const SizedBox(height: 24),

          // Primary Settings
          SettingsSectionHeader(title: l10n.general),
          Semantics(
            label: l10n.general,
            explicitChildNodes: true,
            child: Selector<
              SettingsController,
              ({
                String language,
                bool closeToTray,
                bool useSystemTitleBar,
                bool isAIEnabled,
              })
            >(
              selector:
                  (context, s) => (
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
                        title: Text(l10n.language),
                        subtitle: Text(
                          data.language == 'zh-CN'
                              ? l10n.langSimplifiedChinese
                              : data.language == 'zh-TW'
                              ? l10n.langTraditionalChinese
                              : data.language == 'ja-JP'
                              ? l10n.langJapanese
                              : data.language == 'es-ES' ||
                                    data.language == 'es'
                              ? l10n.langSpanish
                              : l10n.langEnglish,
                        ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.configSaved)),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.aiEnabled),
                      subtitle: Text(l10n.aiAssistantDesc),
                      value: settings.isAIEnabled,
                      onChanged: (val) {
                        final config = Map<String, dynamic>.from(
                          settings.config,
                        );
                        config['ai'] = Map<String, dynamic>.from(
                          config['ai'] ?? {},
                        );
                        config['ai']['enabled'] = val;
                        settings.updateConfig(config);
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.advanced),
                      value: _showAdvanced,
                      onChanged: (val) => setState(() => _showAdvanced = val),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.systemCleaning),
          // Storage & Cleanup Card
          Semantics(
            label: l10n.systemCleaning,
            explicitChildNodes: true,
            child: const StorageCleanupCard(),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.repositories),
          Semantics(
            label: l10n.repositories,
            explicitChildNodes: true,
            child: Selector<SettingsController, Map<dynamic, dynamic>>(
              selector: (context, s) => s.config['search']?['sources'] ?? {},
              shouldRebuild: (prev, next) => !const MapEquality().equals(prev, next),
              builder: (context, _, child) =>
                  SourcesConfigCard(settings: context.read<SettingsController>()),
            ),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.updates),
          Semantics(
            label: l10n.updates,
            explicitChildNodes: true,
            child: Selector<
              SettingsController,
              ({
                bool daemonEnabled,
                bool autoUpdate,
                bool enableSystemdService,
                int checkIntervalHours,
              })
            >(
              selector:
                  (context, s) => (
                    daemonEnabled: s.daemonEnabled,
                    autoUpdate: s.autoUpdate,
                    enableSystemdService: s.enableSystemdService,
                    checkIntervalHours: s.checkIntervalHours,
                  ),
              builder: (context, data, _) {
                return AppCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(l10n.enableDaemon),
                        subtitle: Text(l10n.enableDaemonDesc),
                        value: data.daemonEnabled,
                        onChanged: (val) {
                          context.read<SettingsController>().setDaemonEnabled(
                            val,
                          );
                        },
                      ),
                      SwitchListTile(
                        title: Text(l10n.autoUpdate),
                        subtitle: Text(l10n.autoUpdateDesc),
                        value: data.autoUpdate,
                        onChanged: (val) {
                          context.read<SettingsController>().setAutoUpdate(val);
                        },
                      ),
                      if (Platform.isLinux)
                        SwitchListTile(
                          title: Text(l10n.enableSystemdService),
                          subtitle: Text(l10n.enableSystemdServiceDesc),
                          value: data.enableSystemdService,
                          onChanged: (val) {
                            context.read<SettingsController>().setDaemonEnabled(
                              val,
                            );
                          },
                        ),
                      ListTile(
                        title: Text(l10n.checkIntervalTitle),
                        subtitle: Text(
                          l10n.checkIntervalSubtitle(data.checkIntervalHours),
                        ),
                        trailing: DropdownButton<int>(
                          value: data.checkIntervalHours,
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
                              context
                                  .read<SettingsController>()
                                  .setCheckIntervalHours(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.typography),
          Semantics(
            label: l10n.typography,
            explicitChildNodes: true,
            child: Selector<
              SettingsController,
              ({String fontFamily, double fontScale})
            >(
              selector:
                  (context, s) => (fontFamily: s.fontFamily, fontScale: s.fontScale),
              builder: (context, data, _) {
                return AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(l10n.fontFamily),
                        subtitle: Text(
                          data.fontFamily == 'System'
                              ? l10n.systemDefault
                              : data.fontFamily,
                        ),
                        trailing: DropdownButton<String>(
                          value: data.fontFamily,
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
                              context.read<SettingsController>().setFontFamily(
                                val,
                              );
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.fontScale),
                        subtitle: Text("${(data.fontScale * 100).toInt()}%"),
                        trailing: SizedBox(
                          width: 150,
                          child: Slider(
                            value: data.fontScale,
                            min: 0.8,
                            max: 1.6,
                            divisions: 8,
                            label: "${(data.fontScale * 100).toInt()}%",
                            onChanged: (val) {
                              context.read<SettingsController>().setFontScale(
                                double.parse(val.toStringAsFixed(2)),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          Selector<SettingsController, Map<dynamic, dynamic>>(
            selector: (context, s) => s.config['ai'] ?? {},
            shouldRebuild: (prev, next) => !const MapEquality().equals(prev, next),
            builder: (context, aiConfig, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.fastOutSlowIn,
                child: _showAdvanced
                    ? Semantics(
                        key: const ValueKey('ai_settings'),
                        label: l10n.aiSettings,
                        explicitChildNodes: true,
                        child: AISettingsSection(
                          settings: context.read<SettingsController>(),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty_advanced')),
              );
            },
          ),
        ],
      ),
    );
  }
}
