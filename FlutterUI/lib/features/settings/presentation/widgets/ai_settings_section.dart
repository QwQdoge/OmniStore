import 'dart:async';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/features/settings/presentation/widgets/ai_test_result_dialog.dart';
import 'package:frontend/core/widgets/app_card.dart';

import '../controllers/settings_controller.dart';
import 'settings_section_header.dart';
import 'ai_settings/ai_status_card.dart';

import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/features/ai/account_ai_service.dart';
import 'package:frontend/features/ai/local_ai_service.dart';
import 'package:frontend/features/ai/system_ai_service.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/features/auth/presentation/pages/account_page.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/app/external_install_request.dart';
import 'package:frontend/features/external_install/external_install_prompt.dart';
import 'package:url_launcher/url_launcher.dart';

class AISettingsSection extends StatefulWidget {
  const AISettingsSection({super.key});

  @override
  State<AISettingsSection> createState() => _AISettingsSectionState();
}

class _AISettingsSectionState extends State<AISettingsSection> {
  final Map<String, Timer?> _debounces = {};
  String? _tempError;
  bool _isTestingAI = false;
  bool _isDiscoveringModels = false;
  List<String> _discoveredModels = const [];
  String? _modelDiscoveryMessage;
  bool _showApiKey = false;
  bool _isLoadingAccountCredentials = false;
  bool _accountCredentialsLoaded = false;
  String? _accountCredentialError;
  List<AccountAiCredential> _accountCredentials = const [];
  bool _isLoadingSystemConnections = false;
  String? _systemConnectionError;
  List<SystemAiConnection> _systemConnections = const [];
  late final AuthService _authService;

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
    _authService = AuthService()..addListener(_handleAuthChanged);
    final settings = context.read<SettingsController>();
    _endpointController = TextEditingController(
      text: settings.config['ai']?['endpoint'] ?? '',
    );
    _modelController = TextEditingController(
      text: settings.config['ai']?['model'] ?? '',
    );
    _apiKeyController = TextEditingController(text: '');
    _tempController = TextEditingController(
      text: (settings.config['ai']?['temperature'] ?? 0.7).toString(),
    );
    if (settings.config['ai']?['provider'] == 'account') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAccountCredentials();
      });
    } else if (settings.config['ai']?['provider'] == 'system') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSystemConnections();
      });
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    setState(() {
      _accountCredentialsLoaded = false;
      if (!_authService.isAuthenticated) {
        _accountCredentials = const [];
        _accountCredentialError = null;
      }
    });
    if (_authService.isAuthenticated) {
      _loadAccountCredentials(forceRefresh: true);
    }
  }

  void _syncControllers(Map<dynamic, dynamic> aiConfig) {
    _updateIfChanged(
      _endpointController,
      aiConfig['endpoint'] ?? '',
      _endpointFocus,
    );
    _updateIfChanged(_modelController, aiConfig['model'] ?? '', _modelFocus);
    // API keys are write-only. Never hydrate the editor from secure storage or
    // from the masked config marker.
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

  String _providerSetupHint(String provider) {
    final l10n = AppLocalizations.of(context)!;
    switch (provider) {
      case 'account':
        return l10n.aiAccountProviderHint;
      case 'system':
        return l10n.aiSystemProviderHint;
      case 'ollama':
        return l10n.aiOllamaProviderHint;
      case 'openai_compatible':
        return l10n.aiCompatibleProviderHint;
      default:
        return l10n.aiLocalKeyProviderHint;
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
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

  Future<void> _loadAccountCredentials({bool forceRefresh = false}) async {
    if (_isLoadingAccountCredentials) return;
    if (_accountCredentialsLoaded && !forceRefresh) return;
    if (!_authService.isAuthenticated) {
      if (mounted) {
        setState(() {
          _accountCredentials = const [];
          _accountCredentialError = null;
          _accountCredentialsLoaded = false;
        });
      }
      return;
    }
    setState(() {
      _isLoadingAccountCredentials = true;
      _accountCredentialError = null;
    });
    try {
      final credentials = await AccountAiService.instance.listCredentials(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _accountCredentials = credentials;
        _accountCredentialsLoaded = true;
      });

      final settings = context.read<SettingsController>();
      final selected =
          '${settings.config['ai']?['account_credential_id'] ?? ''}';
      if (selected.isEmpty && credentials.length == 1) {
        await _selectAccountCredential(credentials.single.id);
      }
    } on AccountAiException catch (error) {
      if (mounted) {
        setState(() {
          _accountCredentialError = error.message;
          _accountCredentialsLoaded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingAccountCredentials = false);
    }
  }

  Future<void> _selectAccountCredential(String? credentialId) async {
    if (credentialId == null) return;
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    config['ai']['account_credential_id'] = credentialId;
    config['ai']['api_key'] = '';
    await settings.updateConfig(config);
  }

  Future<void> _loadSystemConnections() async {
    if (_isLoadingSystemConnections) return;
    setState(() {
      _isLoadingSystemConnections = true;
      _systemConnectionError = null;
    });
    try {
      final connections = await SystemAiService.instance.listConnections();
      if (!mounted) return;
      setState(() => _systemConnections = connections);
      final settings = context.read<SettingsController>();
      final selected =
          '${settings.config['ai']?['system_connection_id'] ?? ''}';
      if (selected.isEmpty && connections.length == 1) {
        await _selectSystemConnection(connections.single.id);
      }
    } on SystemAiException catch (error) {
      if (mounted) setState(() => _systemConnectionError = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingSystemConnections = false);
    }
  }

  Future<void> _selectSystemConnection(String connectionId) async {
    final settings = context.read<SettingsController>();
    final connection = _systemConnections
        .where((item) => item.id == connectionId)
        .firstOrNull;
    if (connection == null) return;
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    config['ai']['system_connection_id'] = connection.id;
    config['ai']['endpoint'] = '';
    config['ai']['api_key'] = '';
    config['ai']['model'] = connection.defaultModel;
    _modelController.text = connection.defaultModel;
    await settings.updateConfig(config);
  }

  Future<void> _openAccountSignIn() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const AccountPage()));
    if (mounted && _authService.isAuthenticated) {
      await _loadAccountCredentials(forceRefresh: true);
    }
  }

  Future<void> _openAccountAiSettings() async {
    final uri = Uri.parse('${MeoArchEnvironment.accountUrl}/settings/services');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      Toast.show(context, AppLocalizations.of(context)!.meoAccountOpenFailed);
    }
  }

  Future<bool> _persistCurrentInputs() async {
    for (final timer in _debounces.values) {
      timer?.cancel();
    }
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    final brokerBacked =
        config['ai']['provider'] == 'account' ||
        config['ai']['provider'] == 'system';
    config['ai']['endpoint'] = brokerBacked
        ? ''
        : _endpointController.text.trim();
    config['ai']['model'] = _modelController.text.trim();
    if (brokerBacked) {
      config['ai']['api_key'] = '******';
    } else if (_apiKeyController.text.trim().isNotEmpty) {
      final saved = await settings.saveLocalAiCredential(
        _apiKeyController.text.trim(),
      );
      if (!saved) {
        if (mounted) {
          Toast.show(
            context,
            AppLocalizations.of(context)!.secureCredentialWriteFailed,
          );
        }
        return false;
      }
      _apiKeyController.clear();
      config['ai']['api_key'] = '******';
    } else {
      config['ai']['api_key'] = settings.hasLocalAiCredential ? '******' : '';
    }
    final temperature = double.tryParse(_tempController.text.trim());
    if (temperature == null || temperature < 0 || temperature > 2) {
      setState(
        () => _tempError = AppLocalizations.of(context)!.temperatureRangeError,
      );
      return false;
    }
    config['ai']['temperature'] = temperature;
    return settings.updateConfig(config);
  }

  Future<void> _changeProvider(String provider) async {
    final settings = context.read<SettingsController>();
    final current = Map<String, dynamic>.from(settings.config);
    final ai = Map<String, dynamic>.from(current['ai'] ?? {});
    final oldProvider = ai['provider'] ?? 'ollama';
    ai['provider'] = provider;
    if (provider == 'ollama' && oldProvider != 'ollama') {
      ai['endpoint'] = 'http://localhost:11434';
      ai['model'] = 'qwen2.5:1.5b';
    } else if (provider == 'account' && oldProvider != 'account') {
      ai['endpoint'] = '';
      ai['api_key'] = '';
      ai['model'] = '';
    } else if (provider == 'system' && oldProvider != 'system') {
      ai['endpoint'] = '';
      ai['api_key'] = '';
      ai['model'] = '';
    } else if (provider == 'openai' && oldProvider != 'openai') {
      ai['endpoint'] = 'https://api.openai.com/v1';
      ai['model'] = 'gpt-5';
    } else if (provider == 'gemini' && oldProvider != 'gemini') {
      ai['endpoint'] = 'https://generativelanguage.googleapis.com/v1beta';
      ai['model'] = 'gemini-2.5-pro';
    } else if (provider == 'deepseek' && oldProvider != 'deepseek') {
      ai['endpoint'] = 'https://api.deepseek.com';
      ai['model'] = 'deepseek-chat';
    } else if (provider == 'openrouter' && oldProvider != 'openrouter') {
      ai['endpoint'] = 'https://openrouter.ai/api/v1';
      ai['model'] = '';
    } else if (provider == 'openai_compatible' &&
        oldProvider != 'openai_compatible') {
      ai['endpoint'] = '';
      ai['model'] = '';
    }
    current['ai'] = ai;
    await settings.updateConfig(current);
    if (provider == 'account' && mounted) {
      await _loadAccountCredentials(forceRefresh: true);
    } else if (provider == 'system' && mounted) {
      await _loadSystemConnections();
    } else if (provider == 'ollama' && mounted) {
      await _discoverModels(autoSelect: true);
    }
  }

  Future<void> _discoverModels({bool autoSelect = false}) async {
    if (_isDiscoveringModels) return;
    final settings = context.read<SettingsController>();
    final ai = Map<String, dynamic>.from(settings.config['ai'] ?? {});
    final provider = '${ai['provider'] ?? 'ollama'}';
    if (provider == 'account') return;
    setState(() {
      _isDiscoveringModels = true;
      _modelDiscoveryMessage = null;
    });
    try {
      final models = provider == 'system'
          ? await SystemAiService.instance.discoverModels(
              '${ai['system_connection_id'] ?? ''}',
            )
          : await LocalAiService.instance.discoverModels(
              provider: provider,
              endpoint: _endpointController.text.trim(),
            );
      if (!mounted) return;
      var selected = _modelController.text.trim();
      if (models.length == 1 ||
          (autoSelect && provider == 'ollama' && models.isNotEmpty)) {
        selected = models.first;
        _modelController.text = selected;
        _updateAIConfig('model', selected);
      }
      setState(() {
        final l10n = AppLocalizations.of(context)!;
        _discoveredModels = models;
        _modelDiscoveryMessage = models.isEmpty
            ? l10n.modelsNoneFound
            : models.length == 1 || selected == models.first
            ? l10n.modelsAutofilled
            : l10n.modelsFoundChoose;
      });
    } on LocalAiException catch (error) {
      if (mounted) {
        setState(() {
          _discoveredModels = const [];
          _modelDiscoveryMessage = error.message;
        });
      }
    } on SystemAiException catch (error) {
      if (mounted) {
        setState(() {
          _discoveredModels = const [];
          _modelDiscoveryMessage = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _isDiscoveringModels = false);
    }
  }

  Future<void> _installOllama() async {
    await showExternalInstallPrompt(
      context,
      const ExternalInstallRequest(packageId: 'ollama', source: 'Native'),
    );
    if (mounted) await _discoverModels(autoSelect: true);
  }

  Future<void> _saveLocalCredential() async {
    final value = _apiKeyController.text.trim();
    if (value.isEmpty) {
      Toast.show(context, AppLocalizations.of(context)!.apiKeyRequired);
      return;
    }
    final settings = context.read<SettingsController>();
    final saved = await settings.saveLocalAiCredential(value);
    if (!mounted) return;
    if (!saved) {
      Toast.show(
        context,
        AppLocalizations.of(context)!.secureCredentialWriteFailed,
      );
      return;
    }
    _apiKeyController.clear();
    Toast.show(context, AppLocalizations.of(context)!.secureCredentialSaved);
    await _discoverModels();
  }

  Future<void> _deleteLocalCredential() async {
    final settings = context.read<SettingsController>();
    final deleted = await settings.deleteLocalAiCredential();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    Toast.show(
      context,
      deleted ? l10n.localApiKeyDeleted : l10n.secureCredentialUnavailable,
    );
  }

  Future<void> _testAIConnection() async {
    if (!mounted) return;
    setState(() => _isTestingAI = true);

    // Capture l10n before the async gap where context is known to be valid
    final l10n = AppLocalizations.of(context)!;

    try {
      final saved = await _persistCurrentInputs();
      if (!saved) {
        if (mounted) setState(() => _isTestingAI = false);
        return;
      }
      final res = await BackendService.instance.testAiConnection();
      if (!mounted) return;
      setState(() => _isTestingAI = false);

      final isSuccess = res["status"] == "success";
      final msg = res["response"] ?? "";
      final diagnostics = res["diagnostics"] is Map
          ? Map<String, dynamic>.from(res["diagnostics"] as Map)
          : <String, dynamic>{};

      showDialog(
        context: context,
        builder: (c) => AITestResultDialog(
          isSuccess: isSuccess,
          msg: msg.toString(),
          diagnostics: diagnostics,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTestingAI = false);
      Toast.show(context, l10n.aiTestFailed(e.toString()));
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    Function(String) onChanged, {
    bool isPassword = false,
    String? errorText,
    String? helperText,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    Widget? suffixIcon,
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
          helperText: helperText,
          suffixIcon: suffixIcon,
        ),
        obscureText: isPassword && !_showApiKey,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        enableSuggestions: !isPassword,
        autocorrect: !isPassword,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAccountCallout({
    Key? key,
    required Color background,
    required String title,
    required String detail,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onPressed,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final detailColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(detail),
            ],
          );
          final action = FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiMark(size: 48),
                    const SizedBox(width: 14),
                    Expanded(child: detailColumn),
                  ],
                ),
                const SizedBox(height: 12),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiMark(size: 48),
              const SizedBox(width: 14),
              Expanded(child: detailColumn),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountConnectionCard(Map<dynamic, dynamic> aiConfig) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    Widget content;

    if (!_authService.isAuthenticated) {
      content = _buildAccountCallout(
        key: const ValueKey('unauthenticated'),
        background: colors.secondaryContainer.withValues(alpha: 0.55),
        title: l10n.signInMeoAccount,
        detail: l10n.signInMeoAccountDetail,
        actionLabel: l10n.signIn,
        actionIcon: Icons.login_rounded,
        onPressed: _openAccountSignIn,
      );
    } else if (_isLoadingAccountCredentials) {
      content = ListTile(
        key: const ValueKey('loading'),
        contentPadding: EdgeInsets.zero,
        leading: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: Text(l10n.accountAiLoading),
        subtitle: Text(l10n.accountAiMetadataOnly),
      );
    } else if (_accountCredentialError != null) {
      content = ListTile(
        key: const ValueKey('error'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_off_rounded, color: colors.error),
        title: Text(l10n.accountAiLoadError),
        subtitle: Text(_accountCredentialError!),
        trailing: IconButton(
          tooltip: l10n.retry,
          onPressed: () => _loadAccountCredentials(forceRefresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    } else if (_accountCredentials.isEmpty) {
      content = _buildAccountCallout(
        key: const ValueKey('empty'),
        background: colors.surfaceContainerHigh,
        title: l10n.accountAiNone,
        detail: l10n.accountAiNoneDetail,
        actionLabel: l10n.connect,
        actionIcon: Icons.open_in_new_rounded,
        onPressed: _openAccountAiSettings,
      );
    } else {
      final configuredId = '${aiConfig['account_credential_id'] ?? ''}';
      final selectedId =
          _accountCredentials.any((credential) => credential.id == configuredId)
          ? configuredId
          : null;

      content = Column(
        key: const ValueKey('content'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: InputDecoration(
              labelText: l10n.accountAiSelectLabel,
              helperText: l10n.accountAiConnectionHelper,
              prefixIcon: const Icon(Icons.account_circle_outlined),
            ),
            items: [
              for (final credential in _accountCredentials)
                DropdownMenuItem(
                  value: credential.id,
                  child: Text(
                    '${credential.displayName} · ${credential.secretHint}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _selectAccountCredential,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: _openAccountAiSettings,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l10n.manageAiConnections),
              ),
              TextButton.icon(
                onPressed: () => _loadAccountCredentials(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.aiPerRequestConsentDetail,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SmoothSizeSwitcher(alignment: Alignment.topCenter, child: content);
  }

  Widget _buildSystemConnectionCard(Map<dynamic, dynamic> aiConfig) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingSystemConnections) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: Text(l10n.systemAiLoadingTitle),
        subtitle: Text(l10n.systemAiMetadataOnly),
      );
    }
    if (_systemConnectionError != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.lock_outline_rounded, color: colors.error),
        title: Text(l10n.systemAiLoadErrorTitle),
        subtitle: Text(_systemConnectionError!),
        trailing: IconButton(
          tooltip: l10n.retry,
          onPressed: _loadSystemConnections,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }
    final configuredId = '${aiConfig['system_connection_id'] ?? ''}';
    final selectedId = _systemConnections.any((item) => item.id == configuredId)
        ? configuredId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: InputDecoration(
            labelText: l10n.systemAiSelectLabel,
            helperText: l10n.systemAiConnectionHelper,
            prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          items: [
            for (final connection in _systemConnections)
              DropdownMenuItem(
                value: connection.id,
                child: Text(
                  '${connection.displayName} · ${connection.defaultModel}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) _selectSystemConnection(value);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () async {
                if (!await SystemAiService.instance.openSettings() && mounted) {
                  Toast.show(context, l10n.meoSettingsOpenFailed);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.manageInMeoSettings),
            ),
            TextButton.icon(
              onPressed: _loadSystemConnections,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.refresh),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Selector<SettingsController, Map<dynamic, dynamic>>(
      selector: (context, s) => s.config['ai'] as Map<dynamic, dynamic>? ?? {},
      shouldRebuild: (prev, next) => !const MapEquality().equals(prev, next),
      builder: (context, aiConfig, _) {
        _syncControllers(aiConfig);
        final provider = aiConfig['provider']?.toString() ?? 'ollama';
        final localCloudProvider =
            provider != 'ollama' &&
            provider != 'account' &&
            provider != 'system';
        if (provider == 'account' &&
            _authService.isAuthenticated &&
            !_isLoadingAccountCredentials &&
            !_accountCredentialsLoaded &&
            _accountCredentials.isEmpty &&
            _accountCredentialError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAccountCredentials();
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(
              title: l10n.aiSettings,
              iconWidget: const AiMark(size: 20),
            ),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.aiEnabled),
                      subtitle: Text(l10n.aiEnabledConsentDesc),
                      value: aiConfig['enabled'] == true,
                      onChanged: (value) => _updateAIConfig('enabled', value),
                      secondary: const AiMark(size: 42),
                    ),
                    const Divider(height: 24),
                    AiStatusCard(enabled: aiConfig['enabled'] == true),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('ai-provider-$provider'),
                      initialValue: provider,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.aiProvider,
                        helperText: _providerSetupHint(provider),
                        prefixIcon: const Icon(Icons.hub_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ollama',
                          child: Text(l10n.ollamaLocal),
                        ),
                        DropdownMenuItem(
                          value: 'openai',
                          child: Text(l10n.providerLocalSecureKey('OpenAI')),
                        ),
                        DropdownMenuItem(
                          value: 'gemini',
                          child: Text(l10n.providerLocalSecureKey('Gemini')),
                        ),
                        DropdownMenuItem(
                          value: 'deepseek',
                          child: Text(l10n.providerLocalSecureKey('DeepSeek')),
                        ),
                        DropdownMenuItem(
                          value: 'openrouter',
                          child: Text(
                            l10n.providerLocalSecureKey('OpenRouter'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'openai_compatible',
                          child: Text(l10n.providerCompatibleHttps),
                        ),
                        DropdownMenuItem(
                          value: 'account',
                          child: Text(l10n.providerMeoAccount),
                        ),
                        DropdownMenuItem(
                          value: 'system',
                          child: Text(l10n.systemAiProviderLabel),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) _changeProvider(value);
                      },
                    ),
                    if (provider == 'account') ...[
                      const SizedBox(height: 12),
                      _buildAccountConnectionCard(aiConfig),
                    ],
                    if (provider == 'system') ...[
                      const SizedBox(height: 12),
                      _buildSystemConnectionCard(aiConfig),
                    ],
                    if (provider == 'ollama' || provider == 'openai_compatible')
                      _buildTextField(
                        l10n.aiEndpoint,
                        _endpointController,
                        _endpointFocus,
                        (val) => _debounceUpdateAIConfig('endpoint', val),
                        helperText: provider == 'ollama'
                            ? l10n.ollamaEndpointSafety
                            : l10n.compatibleEndpointSafety,
                        keyboardType: TextInputType.url,
                        autofillHints: const [AutofillHints.url],
                      ),
                    _buildTextField(
                      provider == 'account'
                          ? l10n.accountModelOverride
                          : l10n.aiModel,
                      _modelController,
                      _modelFocus,
                      (val) => _debounceUpdateAIConfig('model', val),
                      helperText: provider == 'account'
                          ? l10n.accountModelDefaultHelper
                          : l10n.modelReviewHelper,
                    ),
                    if (provider != 'account') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isDiscoveringModels
                                ? null
                                : () => _discoverModels(autoSelect: true),
                            icon: _isDiscoveringModels
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.manage_search_rounded),
                            label: Text(
                              provider == 'ollama'
                                  ? l10n.detectLocalModels
                                  : l10n.readModelCatalog,
                            ),
                          ),
                          if (provider == 'ollama' &&
                              _modelDiscoveryMessage != null &&
                              _discoveredModels.isEmpty)
                            FilledButton.tonalIcon(
                              onPressed: _installOllama,
                              icon: const Icon(Icons.download_rounded),
                              label: Text(l10n.installOllamaWithOmniStore),
                            ),
                          if (_discoveredModels.isNotEmpty)
                            DropdownButton<String>(
                              hint: Text(l10n.chooseDiscoveredModel),
                              value:
                                  _discoveredModels.contains(
                                    _modelController.text.trim(),
                                  )
                                  ? _modelController.text.trim()
                                  : null,
                              items: _discoveredModels
                                  .map(
                                    (model) => DropdownMenuItem<String>(
                                      value: model,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 360,
                                        ),
                                        child: Text(
                                          model,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (model) {
                                if (model == null) return;
                                _modelController.text = model;
                                _updateAIConfig('model', model);
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                      if (_modelDiscoveryMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _modelDiscoveryMessage!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                    if (localCloudProvider) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          context
                                  .read<SettingsController>()
                                  .localAiCredentialStateKnown
                              ? (context
                                        .read<SettingsController>()
                                        .hasLocalAiCredential
                                    ? Icons.key_rounded
                                    : Icons.key_off_rounded)
                              : Icons.lock_clock_rounded,
                        ),
                        title: Text(
                          context
                                  .read<SettingsController>()
                                  .hasLocalAiCredential
                              ? l10n.localKeyStored
                              : l10n.localKeyNotStored,
                        ),
                        subtitle: Text(l10n.localKeysHelper),
                      ),
                      _buildTextField(
                        l10n.newApiKeyLabel,
                        _apiKeyController,
                        _apiKeyFocus,
                        (_) {},
                        isPassword: true,
                        helperText: l10n.newApiKeyHelper,
                        autofillHints: const <String>[],
                        suffixIcon: IconButton(
                          tooltip: _showApiKey
                              ? l10n.hideInput
                              : l10n.showInput,
                          onPressed: () =>
                              setState(() => _showApiKey = !_showApiKey),
                          icon: Icon(
                            _showApiKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _saveLocalCredential,
                            icon: const Icon(Icons.lock_rounded),
                            label: Text(l10n.saveOrReplace),
                          ),
                          if (context
                              .read<SettingsController>()
                              .hasLocalAiCredential)
                            TextButton.icon(
                              onPressed: _deleteLocalCredential,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(l10n.deleteLocalKey),
                            ),
                        ],
                      ),
                    ],
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
                      helperText: l10n.temperatureHelper,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _isTestingAI ? null : _testAIConnection,
                        icon: SmoothSizeSwitcher(
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
                    const SizedBox(height: 8),
                    Text(
                      l10n.aiTestScopeHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
