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
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/features/ai/account_ai_service.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/features/auth/presentation/pages/account_page.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
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
  bool _showApiKey = false;
  bool _isLoadingAccountCredentials = false;
  bool _accountCredentialsLoaded = false;
  String? _accountCredentialError;
  List<AccountAiCredential> _accountCredentials = const [];
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
    switch (provider) {
      case 'account':
        return 'Account 只代为调用你已保存的连接；API 密钥不会下发到 OmniStore。';
      case 'ollama':
        return 'Ollama 仅连接本机服务；不需要 API 密钥。';
      case 'openai_compatible':
        return '仅使用你信任的 HTTPS 兼容端点；密钥仍保存在本机安全凭据库。';
      default:
        return '此服务商的密钥单独保存在 Secret Service/KWallet，无法读回明文。';
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
      Toast.show(context, '无法打开 Meo Account。');
    }
  }

  Future<bool> _persistCurrentInputs() async {
    for (final timer in _debounces.values) {
      timer?.cancel();
    }
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    final accountBacked = config['ai']['provider'] == 'account';
    config['ai']['endpoint'] = accountBacked
        ? ''
        : _endpointController.text.trim();
    config['ai']['model'] = _modelController.text.trim();
    if (accountBacked) {
      config['ai']['api_key'] = '******';
    } else if (_apiKeyController.text.trim().isNotEmpty) {
      final saved = await settings.saveLocalAiCredential(
        _apiKeyController.text.trim(),
      );
      if (!saved) {
        if (mounted) Toast.show(context, '无法写入系统安全凭据库。');
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
    }
  }

  Future<void> _saveLocalCredential() async {
    final value = _apiKeyController.text.trim();
    if (value.isEmpty) {
      Toast.show(context, '请先填写新的 API 密钥。');
      return;
    }
    final settings = context.read<SettingsController>();
    final saved = await settings.saveLocalAiCredential(value);
    if (!mounted) return;
    if (!saved) {
      Toast.show(context, '无法写入系统安全凭据库；不会退回明文存储。');
      return;
    }
    _apiKeyController.clear();
    Toast.show(context, 'API 密钥已写入系统安全凭据库。');
  }

  Future<void> _deleteLocalCredential() async {
    final settings = context.read<SettingsController>();
    final deleted = await settings.deleteLocalAiCredential();
    if (!mounted) return;
    Toast.show(context, deleted ? '本地 API 密钥已删除。' : '无法访问系统安全凭据库。');
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
    required Color background,
    required String title,
    required String detail,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onPressed,
  }) {
    return Container(
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
    if (!_authService.isAuthenticated) {
      return _buildAccountCallout(
        background: colors.secondaryContainer.withValues(alpha: 0.55),
        title: '先登录 Meo Account',
        detail: '登录后即可选择账号中加密保存的 AI 连接；API 密钥不会下发到 OmniStore。',
        actionLabel: '登录账号',
        actionIcon: Icons.login_rounded,
        onPressed: _openAccountSignIn,
      );
    }

    if (_isLoadingAccountCredentials) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: Text('正在读取账号 AI 连接'),
        subtitle: Text('只读取名称、服务商和密钥掩码。'),
      );
    }

    if (_accountCredentialError != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_off_rounded, color: colors.error),
        title: const Text('无法读取账号 AI 连接'),
        subtitle: Text(_accountCredentialError!),
        trailing: IconButton(
          tooltip: '重试',
          onPressed: () => _loadAccountCredentials(forceRefresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    if (_accountCredentials.isEmpty) {
      return _buildAccountCallout(
        background: colors.surfaceContainerHigh,
        title: '账号中还没有 AI 连接',
        detail: '前往 Account 填写你自己的 API 密钥并安全保存，然后回到这里刷新。',
        actionLabel: '去连接',
        actionIcon: Icons.open_in_new_rounded,
        onPressed: _openAccountAiSettings,
      );
    }

    final configuredId = '${aiConfig['account_credential_id'] ?? ''}';
    final selectedId =
        _accountCredentials.any((credential) => credential.id == configuredId)
        ? configuredId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: '账号 AI 连接',
            helperText: '密钥只在 Account Edge broker 内解密，OmniStore 不可读取。',
            prefixIcon: Icon(Icons.account_circle_outlined),
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
              label: const Text('管理 AI 连接'),
            ),
            TextButton.icon(
              onPressed: () => _loadAccountCredentials(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '每次发送前，OmniStore 都会显示服务商、模型、用途、数据类别、完整内容和请求指纹，并要求“仅同意这一次”。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
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
            provider != 'ollama' && provider != 'account';
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
                      title: const Text('启用 AI 辅助'),
                      subtitle: const Text('默认关闭；开启后每次发送仍需单独确认。'),
                      value: aiConfig['enabled'] == true,
                      onChanged: (value) => _updateAIConfig('enabled', value),
                      secondary: const AiMark(size: 42),
                    ),
                    const Divider(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: aiConfig['enabled'] == true
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.68,
                              )
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            aiConfig['enabled'] == true
                                ? Icons.verified_user_rounded
                                : Icons.pause_circle_outline_rounded,
                            color: aiConfig['enabled'] == true
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  aiConfig['enabled'] == true
                                      ? 'AI 辅助已启用'
                                      : 'AI 辅助保持关闭',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  aiConfig['enabled'] == true
                                      ? '每次实际发送仍会展示内容与用途，并要求单次授权。'
                                      : '可以先配置连接；保存连接不会自动启用 AI。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        const DropdownMenuItem(
                          value: 'openai',
                          child: Text('OpenAI（本地安全密钥）'),
                        ),
                        const DropdownMenuItem(
                          value: 'gemini',
                          child: Text('Gemini（本地安全密钥）'),
                        ),
                        const DropdownMenuItem(
                          value: 'deepseek',
                          child: Text('DeepSeek（本地安全密钥）'),
                        ),
                        const DropdownMenuItem(
                          value: 'openrouter',
                          child: Text('OpenRouter（本地安全密钥）'),
                        ),
                        const DropdownMenuItem(
                          value: 'openai_compatible',
                          child: Text('OpenAI Compatible（自定义 HTTPS）'),
                        ),
                        const DropdownMenuItem(
                          value: 'account',
                          child: Text('Meo Account（可选同步 / 逐次授权）'),
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
                    if (provider == 'ollama' || provider == 'openai_compatible')
                      _buildTextField(
                        l10n.aiEndpoint,
                        _endpointController,
                        _endpointFocus,
                        (val) => _debounceUpdateAIConfig('endpoint', val),
                        helperText: provider == 'ollama'
                            ? '默认连接本机 Ollama；请保留回环地址以避免意外访问局域网服务。'
                            : '仅填写你信任的 HTTPS 兼容端点，不包含密钥或查询参数。',
                        keyboardType: TextInputType.url,
                        autofillHints: const [AutofillHints.url],
                      ),
                    _buildTextField(
                      provider == 'account' ? '覆盖账号默认模型（可选）' : l10n.aiModel,
                      _modelController,
                      _modelFocus,
                      (val) => _debounceUpdateAIConfig('model', val),
                      helperText: provider == 'account'
                          ? '留空会使用所选 Account AI 连接的默认模型。'
                          : '实际模型会在每次发送前再次展示，供你确认。',
                    ),
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
                              ? '当前服务商已有独立安全密钥'
                              : '当前服务商尚未保存 API 密钥',
                        ),
                        subtitle: const Text(
                          '每个服务商分别保存在 Secret Service/KWallet；只能替换或删除，不能读回明文。',
                        ),
                      ),
                      _buildTextField(
                        '新的 API 密钥（写入后清空）',
                        _apiKeyController,
                        _apiKeyFocus,
                        (_) {},
                        isPassword: true,
                        helperText: '仅填写要替换的新密钥；保存后不能读取或复制旧密钥。',
                        autofillHints: const <String>[],
                        suffixIcon: IconButton(
                          tooltip: _showApiKey ? '隐藏输入' : '显示输入',
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
                            label: const Text('安全保存 / 替换'),
                          ),
                          if (context
                              .read<SettingsController>()
                              .hasLocalAiCredential)
                            TextButton.icon(
                              onPressed: _deleteLocalCredential,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('删除本地密钥'),
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
                      helperText: '0–2；较低数值通常更稳定，范围外不会保存。',
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
                      '测试只验证当前连接，不会改变“启用 AI 辅助”开关；实际发送仍需单次确认。',
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
