import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../controllers/settings_controller.dart';
import 'ai_test_connection_dialog.dart';
import 'settings_section_header.dart';

class AISettingsSection extends StatefulWidget {
  const AISettingsSection({super.key});

  @override
  State<AISettingsSection> createState() => _AISettingsSectionState();
}

class _AISettingsSectionState extends State<AISettingsSection> {
  final Map<String, Timer?> _debounces = {};
  String? _tempError;
  bool _isTestingAI = false;

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
    _endpointController = TextEditingController(
      text: settings.config['ai']?['endpoint'] ?? '',
    );
    _modelController = TextEditingController(
      text: settings.config['ai']?['model'] ?? '',
    );
    _apiKeyController = TextEditingController(
      text: settings.config['ai']?['api_key'] ?? '',
    );
    _tempController = TextEditingController(
      text: (settings.config['ai']?['temperature'] ?? 0.7).toString(),
    );
  }

  void _syncControllers(Map<dynamic, dynamic> aiConfig) {
    _updateIfChanged(
      _endpointController,
      aiConfig['endpoint'] ?? '',
      _endpointFocus,
    );
    _updateIfChanged(_modelController, aiConfig['model'] ?? '', _modelFocus);
    _updateIfChanged(
      _apiKeyController,
      aiConfig['api_key'] ?? '',
      _apiKeyFocus,
    );
    _updateIfChanged(
      _tempController,
      (aiConfig['temperature'] ?? 0.7).toString(),
      _tempFocus,
    );
  }

  void _updateIfChanged(
    TextEditingController controller,
    String value,
    FocusNode focus,
  ) {
    if (controller.text != value && !focus.hasFocus) {
      final selection = controller.selection;
      controller.text = value;
      if (selection.baseOffset <= value.length &&
          selection.extentOffset <= value.length) {
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

  void _updateAIConfig(String key, dynamic value) {
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    config['ai'][key] = value;
    settings.updateConfig(config);
  }

  void _debounceUpdateAIConfig(String key, dynamic value) {
    if (_debounces[key]?.isActive ?? false) _debounces[key]?.cancel();
    _debounces[key] = Timer(const Duration(milliseconds: 500), () {
      _updateAIConfig(key, value);
    });
  }

  Future<void> _testAIConnection() async {
    if (!mounted) return;
    setState(() => _isTestingAI = true);

    // Capture l10n before the async gap where context is known to be valid
    final l10n = AppLocalizations.of(context)!;

    try {
      final res = await BackendService.instance.testAiConnection();
      if (!mounted) return;
      setState(() => _isTestingAI = false);

      final isSuccess = res["status"] == "success";
      final msg = res["response"] ?? "";

      showDialog(
        context: context,
        builder: (c) => AITestConnectionDialog(
          isSuccess: isSuccess,
          msg: msg.toString(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTestingAI = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiTestFailed(e.toString())),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    Function(String) onChanged, {
    bool isPassword = false,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          errorText: errorText,
        ),
        obscureText: isPassword,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<SettingsController, Map<dynamic, dynamic>>(
      selector: (context, s) => s.config['ai'] as Map<dynamic, dynamic>? ?? {},
      shouldRebuild: (prev, next) => !const MapEquality().equals(prev, next),
      builder: (context, aiConfig, _) {
        _syncControllers(aiConfig);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(
              title: l10n.aiSettings,
              icon: Icons.auto_awesome_rounded,
            ),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.aiProvider),
                      trailing: DropdownButton<String>(
                        value: aiConfig['provider'] ?? 'ollama',
                        underline: const SizedBox(),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          DropdownMenuItem(
                            value: 'ollama',
                            child: Text(l10n.ollamaLocal),
                          ),
                          DropdownMenuItem(
                            value: 'openai',
                            child: Text(l10n.openaiCompatible),
                          ),
                          DropdownMenuItem(
                            value: 'gemini',
                            child: Text(l10n.googleGemini),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _updateAIConfig('provider', val);
                          }
                        },
                      ),
                    ),
                    _buildTextField(
                      l10n.aiEndpoint,
                      _endpointController,
                      _endpointFocus,
                      (val) => _debounceUpdateAIConfig('endpoint', val),
                    ),
                    _buildTextField(
                      l10n.aiModel,
                      _modelController,
                      _modelFocus,
                      (val) => _debounceUpdateAIConfig('model', val),
                    ),
                    _buildTextField(
                      l10n.aiApiKey,
                      _apiKeyController,
                      _apiKeyFocus,
                      (val) => _debounceUpdateAIConfig('api_key', val),
                      isPassword: true,
                    ),
                    _buildTextField(
                      l10n.aiTemperature,
                      _tempController,
                      _tempFocus,
                      (val) {
                        final d = double.tryParse(val);
                        if (d == null) {
                          setState(() => _tempError = l10n.failed);
                        } else if (d < 0.0 || d > 2.0) {
                          setState(
                            () => _tempError = l10n.temperatureRangeError,
                          );
                        } else {
                          setState(() => _tempError = null);
                          _debounceUpdateAIConfig('temperature', d);
                        }
                      },
                      errorText: _tempError,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _isTestingAI ? null : _testAIConnection,
                        icon: AnimatedSwitcher(
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.fastOutSlowIn,
                          duration: const Duration(milliseconds: 300),
                          child: _isTestingAI
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.network_check_rounded,
                                  key: ValueKey('idle'),
                                ),
                        ),
                        label: Text(l10n.aiTestButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
