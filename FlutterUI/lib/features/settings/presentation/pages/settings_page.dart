import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import '../widgets/storage_cleanup_card.dart';
import '../widgets/sources_config_card.dart';
import '../widgets/ai_settings_section.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/general_settings_card.dart';
import '../widgets/update_settings_card.dart';
import '../widgets/typography_settings_card.dart';

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
          Text(l10n.settings, style: OmnistoreTheme.standardHeader(context)),
          const SizedBox(height: 24),

          // Primary Settings
          SettingsSectionHeader(title: l10n.general, icon: Icons.settings_rounded),
          Semantics(
            label: l10n.general,
            explicitChildNodes: true,
            child:
                GeneralSettingsCard(
              showAdvanced: _showAdvanced,
              onAdvancedChanged: (val) => setState(() => _showAdvanced = val),
            ),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(
            title: l10n.systemCleaning,
            icon: Icons.cleaning_services_rounded,
          ),
          // Storage & Cleanup Card
          Semantics(
            label: l10n.systemCleaning,
            explicitChildNodes: true,
            child: const StorageCleanupCard(),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(
            title: l10n.repositories,
            icon: Icons.source_rounded,
          ),
          Semantics(
            label: l10n.repositories,
            explicitChildNodes: true,
            child: const SourcesConfigCard(),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(title: l10n.updates, icon: Icons.system_update_rounded),
          Semantics(
            label: l10n.updates,
            explicitChildNodes: true,
            child:
                const UpdateSettingsCard(),
          ),

          const SizedBox(height: 24),
          SettingsSectionHeader(
            title: l10n.typography,
            icon: Icons.text_fields_rounded,
          ),
          Semantics(
            label: l10n.typography,
            explicitChildNodes: true,
            child:
                const TypographySettingsCard(),
          ),

          const SizedBox(height: 24),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.fastOutSlowIn,
              child: _showAdvanced
                  ? Semantics(
                      key: const ValueKey('ai_settings'),
                      label: l10n.aiSettings,
                      explicitChildNodes: true,
                      child: const AISettingsSection(),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty_advanced')),
            ),
          ),
        ],
      ),
    );
  }
}
