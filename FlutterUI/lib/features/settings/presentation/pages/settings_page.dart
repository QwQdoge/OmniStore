import 'dart:async';

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
  final Map<String, Timer?> _debounces = {};
  
  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late TextEditingController _tempController;

  final FocusNode _endpointFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();
  final FocusNode _tempFocus = FocusNode();

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
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final settings = context.read<SettingsController>();
    _updateIfChanged(_endpointController, settings.config['ai']?['endpoint'] ?? '', _endpointFocus);
    _updateIfChanged(_modelController, settings.config['ai']?['model'] ?? '', _modelFocus);
    _updateIfChanged(_apiKeyController, settings.config['ai']?['api_key'] ?? '', _apiKeyFocus);
    _updateIfChanged(_tempController, (settings.config['ai']?['temperature'] ?? 0.7).toString(), _tempFocus);
  }

  void _updateIfChanged(TextEditingController controller, String value, FocusNode focus) {
    if (controller.text != value && !focus.hasFocus) {
      final selection = controller.selection;
      controller.text = value;
      // Maintain cursor position if it was within bounds (just in case)
      if (selection.baseOffset <= value.length && selection.extentOffset <= value.length) {
        controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _debounces.values) {
      timer?.cancel();
    }
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _tempController.dispose();
    _endpointFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    _tempFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    // We still call sync here in case of external config changes (like from another page)
    _syncControllers();
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
            subtitle: Text(l10n.aiAssistantDesc),
            value: settings.isAIEnabled,
            onChanged: (val) {
              final config = Map<String, dynamic>.from(settings.config);
              config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
              config['ai']['enabled'] = val;
              settings.updateConfig(config);
            },
          ),
          ListTile(
            title: Text(l10n.systemCleaning),
            subtitle: Text(l10n.systemCleaningSubtitle),
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
              _endpointFocus,
              (val) => _debounceUpdateAIConfig('endpoint', val, settings),
            ),
            _buildTextField(
              l10n.aiModel,
              _modelController,
              _modelFocus,
              (val) => _debounceUpdateAIConfig('model', val, settings),
            ),
            _buildTextField(
              l10n.aiApiKey,
              _apiKeyController,
              _apiKeyFocus,
              (val) => _debounceUpdateAIConfig('api_key', val, settings),
              isPassword: true,
            ),
            _buildTextField(
              l10n.aiTemperature,
              _tempController,
              _tempFocus,
              (val) {
                final d = double.tryParse(val);
                if (d != null) {
                  _debounceUpdateAIConfig('temperature', d, settings);
                }
              },
            ),
            const SizedBox(height: 24),
            _buildSection(l10n.repositories),
            CheckboxListTile(
              title: Text(l10n.aurFull),
              value: settings.config['search']?['sources']?['aur'] ?? true,
              onChanged: (val) => _updateSourceConfig('aur', val, settings),
            ),
            CheckboxListTile(
              title: Text(l10n.flatpakFull),
              value: settings.config['search']?['sources']?['flatpak'] ?? true,
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

  Widget _buildTextField(String label, TextEditingController controller, FocusNode focusNode, Function(String) onChanged, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
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
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    config['ai'][key] = value;
    settings.updateConfig(config);
  }

  void _debounceUpdateAIConfig(String key, dynamic value, SettingsController settings) {
    if (_debounces[key]?.isActive ?? false) _debounces[key]?.cancel();
    _debounces[key] = Timer(const Duration(milliseconds: 500), () {
      _updateAIConfig(key, value, settings);
    });
  }

  void _updateSourceConfig(String key, dynamic value, SettingsController settings) {
    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(config['search']['sources'] ?? {});
    config['search']['sources'][key] = value;
    settings.updateConfig(config);
  }
}
