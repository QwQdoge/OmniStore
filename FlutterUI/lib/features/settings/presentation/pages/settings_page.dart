import 'package:frontend/data/repositories/task_repository.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showAdvanced = false;
  
  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late TextEditingController _tempController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _endpointController = TextEditingController(text: settings.config['ai']?['endpoint'] ?? '');
    _modelController = TextEditingController(text: settings.config['ai']?['model'] ?? '');
    _apiKeyController = TextEditingController(text: settings.config['ai']?['api_key'] ?? '');
    _tempController = TextEditingController(text: (settings.config['ai']?['temperature'] ?? 0.7).toString());
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.settings,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
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
          SwitchListTile(
            title: Text(l10n.aiEnabled),
            subtitle: Text(l10n.aiEnabledDesc),
            value: settings.isAIEnabled,
            onChanged: (val) {
              final config = Map<String, dynamic>.from(settings.config);
              config['ai'] ??= {};
              config['ai']['enabled'] = val;
              settings.updateConfig(config);
            },
          ),
          ListTile(
            title: Text(l10n.systemCleaning),
            subtitle: Text(l10n.systemCleaningDesc),
            trailing: const Icon(Icons.delete_sweep_rounded),
            onTap: () {
              context.read<TaskRepository>().cleanSystem().listen((_) {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.processing)),
              );
            },
          ),

          if (_showAdvanced) ...[
            const SizedBox(height: 32),
            _buildSection(l10n.aiProvider),
            _buildTextField(
              l10n.aiEndpoint,
              _endpointController,
              (val) => _updateAIConfig('endpoint', val, settings),
            ),
            _buildTextField(
              l10n.aiModel,
              _modelController,
              (val) => _updateAIConfig('model', val, settings),
            ),
            _buildTextField(
              l10n.aiApiKey,
              _apiKeyController,
              (val) => _updateAIConfig('api_key', val, settings),
              isPassword: true,
            ),
            _buildTextField(
              l10n.aiTemperature,
              _tempController,
              (val) {
                final d = double.tryParse(val);
                if (d != null) _updateAIConfig('temperature', d, settings);
              },
            ),
            const SizedBox(height: 24),
            _buildSection(l10n.repositories),
            CheckboxListTile(
              title: const Text("AUR (Arch User Repository)"),
              value: settings.config['sources']?['aur'] ?? true,
              onChanged: (val) => _updateSourceConfig('aur', val, settings),
            ),
            CheckboxListTile(
              title: const Text("Flatpak (Flathub)"),
              value: settings.config['sources']?['flatpak'] ?? true,
              onChanged: (val) => _updateSourceConfig('flatpak', val, settings),
            ),
          ],
        ],
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

  Widget _buildTextField(String label, TextEditingController controller, Function(String) onChanged, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        obscureText: isPassword,
        onChanged: onChanged,
      ),
    );
  }

  void _updateAIConfig(String key, dynamic value, SettingsController settings) {
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] ??= {};
    config['ai'][key] = value;
    settings.updateConfig(config);
  }

  void _updateSourceConfig(String key, dynamic value, SettingsController settings) {
    final config = Map<String, dynamic>.from(settings.config);
    config['sources'] ??= {};
    config['sources'][key] = value;
    settings.updateConfig(config);
  }
}
