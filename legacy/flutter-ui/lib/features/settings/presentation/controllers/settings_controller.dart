import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/data/python_bridge.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/services/update_service.dart';
import 'package:frontend/services/backend_service.dart';

typedef DaemonEnvironmentUpdater =
    Future<bool> Function(Map<String, String> environment);
typedef UpdateConfigRefresher = Future<void> Function();

class SettingsController with ChangeNotifier {
  static const Set<String> _localCredentialProviders = {
    'openai',
    'gemini',
    'deepseek',
    'openrouter',
    'openai_compatible',
  };

  bool _disposed = false;

  final ConfigRepository _configRepository;
  final DaemonEnvironmentUpdater _updateDaemonEnvironment;
  final UpdateConfigRefresher _refreshUpdateService;

  Map<String, dynamic> _config = {};
  bool _isAIEnabled = false;
  bool _isRailExpanded = true;
  bool _hasLocalAiCredential = false;
  bool _credentialStateKnown = false;

  SettingsController(
    this._configRepository, {
    DaemonEnvironmentUpdater? updateDaemonEnvironment,
    UpdateConfigRefresher? refreshUpdateService,
  }) : _updateDaemonEnvironment =
           updateDaemonEnvironment ?? BackendService.instance.updateDaemonEnv,
       _refreshUpdateService =
           refreshUpdateService ?? (() => UpdateService().updateConfig());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Map<String, dynamic> get config => _config;
  bool get isAIEnabled => _isAIEnabled;
  bool get hasLocalAiCredential => _hasLocalAiCredential;
  bool get localAiCredentialStateKnown => _credentialStateKnown;
  bool get isRailExpanded => _isRailExpanded;

  String? _credentialProvider(Object? aiConfig) {
    if (aiConfig is! Map) return null;
    final raw = aiConfig['provider']?.toString().trim().toLowerCase() ?? '';
    final normalized = raw == 'custom' ? 'openai_compatible' : raw;
    return _localCredentialProviders.contains(normalized) ? normalized : null;
  }

  Future<void> _readCredentialMarker(String? provider) async {
    if (provider == null) {
      _hasLocalAiCredential = false;
      _credentialStateKnown = true;
      return;
    }
    final apiKey = await PythonBridge.getApiKey(
      provider: provider,
      throwOnError: true,
    );
    _hasLocalAiCredential = apiKey != null && apiKey.isNotEmpty;
    _credentialStateKnown = true;
  }

  // ─── Theme Mode ──────────────────────────────────────
  ThemeMode get themeMode {
    final appearance = _config['ui']?['appearance'] ?? 'system';
    switch (appearance) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final String appearance;
    switch (mode) {
      case ThemeMode.dark:
        appearance = 'dark';
      case ThemeMode.light:
        appearance = 'light';
      case ThemeMode.system:
        appearance = 'system';
    }

    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['appearance'] = appearance;
    await updateConfig(config);
  }

  // ─── Language / Locale ──────────────────────────────
  Locale? get locale {
    final lang = _config['ui']?['language'];
    if (lang == null) return null;
    switch (lang) {
      case 'zh-CN':
      case 'zh':
        return const Locale('zh');
      case 'zh-TW':
      case 'zh_Hant':
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      case 'en-US':
      case 'en':
        return const Locale('en');
      case 'ja-JP':
      case 'ja':
        return const Locale('ja');
      case 'es-ES':
      case 'es':
        return const Locale('es');
      default:
        return null;
    }
  }

  String get language {
    final lang = _config['ui']?['language'] ?? 'zh-CN';
    if (lang == 'zh') return 'zh-CN';
    if (lang == 'zh_Hant') return 'zh-TW';
    if (lang == 'en') return 'en-US';
    if (lang == 'ja') return 'ja-JP';
    if (lang == 'es') return 'es-ES';
    return lang;
  }

  Future<void> setLanguage(String value) async {
    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['language'] = value;
    await updateConfig(config);
  }

  // ─── Close to Tray ───────────────────────────────────
  bool get closeToTray => _config['ui']?['close_to_tray'] ?? true;

  Future<void> setCloseToTray(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['close_to_tray'] = value;
    await updateConfig(config);
  }

  // ─── System Title Bar ─────────────────────────────────
  bool get useSystemTitleBar => _config['ui']?['use_system_title_bar'] ?? false;

  Future<void> setUseSystemTitleBar(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['use_system_title_bar'] = value;
    await updateConfig(config);
  }

  // ─── Daemon / Updates ───────────────────────────────
  bool get daemonEnabled => _config['daemon']?['enabled'] ?? true;

  Future<void> setDaemonEnabled(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['daemon'] = Map<String, dynamic>.from(config['daemon'] ?? {});
    config['daemon']['enabled'] = value;
    config['updates'] = Map<String, dynamic>.from(config['updates'] ?? {});
    if (!value) {
      config['updates']['enable_systemd_service'] = false;
    }
    final saved = await updateConfig(config);
    if (!saved) return;
    await BackendService.instance.setBackgroundDaemonEnabled(value);
    if (!value) {
      await UpdateService().removeSystemdBackgroundTimer();
    }
  }

  bool get autoUpdate => _config['daemon']?['auto_update'] ?? false;

  Future<void> setAutoUpdate(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['daemon'] = Map<String, dynamic>.from(config['daemon'] ?? {});
    config['daemon']['auto_update'] = value;
    await updateConfig(config);
  }

  int get checkIntervalHours =>
      _config['updates']?['check_interval_hours'] ?? 1;

  Future<void> setCheckIntervalHours(int value) async {
    final config = Map<String, dynamic>.from(_config);
    config['updates'] = Map<String, dynamic>.from(config['updates'] ?? {});
    config['updates']['check_interval_hours'] = value;
    await updateConfig(config);
  }

  bool get enableSystemdService =>
      _config['updates']?['enable_systemd_service'] ?? false;

  Future<void> setEnableSystemdService(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['updates'] = Map<String, dynamic>.from(config['updates'] ?? {});
    config['updates']['enable_systemd_service'] = value;
    await updateConfig(config);
  }

  // ─── Rail Expanded State ─────────────────────────────
  void setRailExpanded(bool expanded) {
    if (_isRailExpanded != expanded) {
      _isRailExpanded = expanded;
      // Persist to config
      final config = Map<String, dynamic>.from(_config);
      config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
      config['ui']['rail_expanded'] = expanded;
      _configRepository.saveConfig(config);
      _config = config;
      notifyListeners();
    }
  }

  // ─── Auto-Detect Sources ──────────────────────────────
  Future<bool> autoDetectSources() async {
    final Map<String, bool> detectedSources = {
      "pacman": false,
      "aur": false,
      "flatpak": false,
      "appimage": false,
      "snap": false,
      "github": true,
      "bitu": true,
      "winget": false,
      "scoop": false,
      "brew": false,
    };

    if (kIsWeb) {
      // Browser: keep defaults (github, bitu)
    } else {
      if (Platform.isLinux) {
        detectedSources["pacman"] = File("/usr/bin/pacman").existsSync();
        detectedSources["aur"] =
            detectedSources["pacman"]! &&
            (File("/usr/bin/yay").existsSync() ||
                File("/usr/bin/paru").existsSync());
        detectedSources["flatpak"] = _isCommandAvailable("flatpak");
        detectedSources["appimage"] = true;
        detectedSources["snap"] = _isCommandAvailable("snap");
        detectedSources["brew"] = _isCommandAvailable("brew");
      } else if (Platform.isWindows) {
        detectedSources["winget"] = _isCommandAvailable("winget");
        detectedSources["scoop"] = _isCommandAvailable("scoop");
      } else if (Platform.isMacOS) {
        detectedSources["brew"] = _isCommandAvailable("brew");
      }
    }

    final config = Map<String, dynamic>.from(_config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(
      config['search']['sources'] ?? {},
    );

    detectedSources.forEach((key, value) {
      config['search']['sources'][key] = value;
    });

    return await updateConfig(config);
  }

  bool _isCommandAvailable(String cmd) {
    try {
      final check = Platform.isWindows ? 'where' : 'which';
      final res = Process.runSync(check, [cmd]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ─── Config Lifecycle ────────────────────────────────
  Future<void> loadConfig() async {
    _config = await _configRepository.loadConfig();
    _isAIEnabled = _config['ai']?['enabled'] ?? false;
    _isRailExpanded = _config['ui']?['rail_expanded'] ?? true;

    // Bind legacy credentials to the configured provider inside the platform
    // vault. Plaintext from an older config is moved only after the secure
    // write succeeds, then the ordinary config is scrubbed.
    final aiConfig = Map<String, dynamic>.from(_config['ai'] ?? {});
    final credentialProvider = _credentialProvider(aiConfig);
    final legacyPlaintext = aiConfig['api_key'] is String
        ? (aiConfig['api_key'] as String).trim()
        : '';
    var migratedPlaintext = false;
    try {
      if (credentialProvider != null) {
        if (legacyPlaintext.isNotEmpty &&
            legacyPlaintext != '******' &&
            legacyPlaintext.length >= 8 &&
            !legacyPlaintext.contains(RegExp(r'[\r\n\x00]'))) {
          await PythonBridge.saveApiKey(
            legacyPlaintext,
            provider: credentialProvider,
          );
          migratedPlaintext = true;
        } else {
          await PythonBridge.migrateLegacyApiKey(provider: credentialProvider);
        }
      }
      await _readCredentialMarker(credentialProvider);
    } catch (error) {
      _hasLocalAiCredential = false;
      _credentialStateKnown = false;
      debugPrint('Failed to read AI credential storage: ${error.runtimeType}');
    }
    aiConfig['api_key'] = _hasLocalAiCredential ? '******' : '';
    _config['ai'] = aiConfig;
    if (migratedPlaintext) {
      final sanitized = Map<String, dynamic>.from(_config);
      sanitized['ai'] = Map<String, dynamic>.from(aiConfig)..['api_key'] = '';
      try {
        final scrubbed = await _configRepository.saveConfig(sanitized);
        if (!scrubbed) {
          debugPrint(
            'Secure AI credential migrated, but legacy config scrubbing failed.',
          );
        }
      } catch (error) {
        debugPrint(
          'Failed to scrub legacy AI credential config: ${error.runtimeType}',
        );
      }
    }
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    final aiConfig = newConfig['ai'];
    final credentialProvider = _credentialProvider(aiConfig);
    final apiKeyValue = aiConfig is Map ? aiConfig['api_key'] : null;
    final String? submittedApiKey =
        apiKeyValue is String && apiKeyValue != '******' ? apiKeyValue : null;

    final currentAiConfig = _config['ai'];
    final currentCredentialProvider = _credentialProvider(currentAiConfig);
    final currentUiApiKey = currentAiConfig is Map
        ? currentAiConfig['api_key']
        : null;
    final credentialWasEdited =
        credentialProvider != null &&
        submittedApiKey != null &&
        submittedApiKey.isNotEmpty &&
        submittedApiKey != currentUiApiKey;

    String? previousApiKey;
    if (credentialWasEdited) {
      final editedApiKey = submittedApiKey;
      final provider = credentialProvider;
      try {
        previousApiKey = await PythonBridge.getApiKey(
          provider: provider,
          throwOnError: true,
        );
        if (editedApiKey.isEmpty) {
          await PythonBridge.deleteApiKey(provider: provider);
        } else {
          await PythonBridge.saveApiKey(editedApiKey, provider: provider);
        }
      } catch (error) {
        debugPrint(
          'Failed to update AI credential storage: '
          '${error.runtimeType}',
        );
        return false;
      }
    }

    // Never persist the credential in the ordinary configuration file.
    final configToSave = Map<String, dynamic>.from(newConfig);
    if (configToSave['ai'] != null) {
      configToSave['ai'] = Map<String, dynamic>.from(configToSave['ai']);
      configToSave['ai']['api_key'] = '';
    }

    bool success;
    try {
      success = await _configRepository.saveConfig(configToSave);
    } catch (error) {
      debugPrint('Failed to persist settings: ${error.runtimeType}');
      success = false;
    }

    if (!success) {
      if (credentialWasEdited) {
        final restored = await _restoreApiKey(
          credentialProvider,
          previousApiKey,
        );
        if (restored) {
          _hasLocalAiCredential =
              previousApiKey != null && previousApiKey.isNotEmpty;
          _credentialStateKnown = true;
        } else {
          _credentialStateKnown = false;
        }
      }
      return false;
    }

    if (credentialWasEdited) {
      final editedApiKey = submittedApiKey;
      _hasLocalAiCredential = editedApiKey.isNotEmpty;
      _credentialStateKnown = true;
    } else if (credentialProvider != currentCredentialProvider) {
      try {
        await _readCredentialMarker(credentialProvider);
      } catch (error) {
        _hasLocalAiCredential = false;
        _credentialStateKnown = false;
        debugPrint(
          'Failed to refresh provider-bound AI credential state: '
          '${error.runtimeType}',
        );
      }
    }

    _config = Map<String, dynamic>.from(newConfig);
    if (_config['ai'] is Map) {
      _config['ai'] = Map<String, dynamic>.from(_config['ai'] as Map);
      _config['ai']['api_key'] = _hasLocalAiCredential ? '******' : '';
    }
    _isAIEnabled = _config['ai']?['enabled'] ?? false;
    _isRailExpanded = _config['ui']?['rail_expanded'] ?? true;
    notifyListeners();

    try {
      await _refreshUpdateService();
    } catch (error) {
      debugPrint(
        'Failed to refresh background update settings: '
        '${error.runtimeType}',
      );
    }

    try {
      final savedAi = newConfig['ai'] is Map
          ? Map<String, dynamic>.from(newConfig['ai'] as Map)
          : <String, dynamic>{};
      final daemonEnvironment = <String, String>{
        // Every new AI call is made by Flutter after the exact consent surface.
        // Keep the legacy Python provider path disabled for every provider so
        // it cannot bypass consent or receive a platform-vault credential.
        'OMNISTORE_AI_ENABLED': 'false',
        'OMNISTORE_AI_PROVIDER': '${savedAi['provider'] ?? 'ollama'}',
        'OMNISTORE_AI_ENDPOINT': '${savedAi['endpoint'] ?? ''}',
        'OMNISTORE_AI_MODEL': '${savedAi['model'] ?? ''}',
        'OMNISTORE_AI_TEMPERATURE': '${savedAi['temperature'] ?? 0.7}',
        'OMNISTORE_AI_MAX_TOKENS': '${savedAi['max_tokens'] ?? 2048}',
        'OMNISTORE_AI_PROXY': '${savedAi['proxy'] ?? ''}',
      };
      daemonEnvironment['OMNISTORE_AI_API_KEY'] = '';
      // The daemon is long-lived and otherwise keeps the AI configuration it
      // read at startup. Synchronize the complete provider tuple atomically;
      // syncing only the credential makes the UI and backend disagree.
      final daemonUpdated = await _updateDaemonEnvironment(daemonEnvironment);
      if (!daemonUpdated &&
          !kIsWeb &&
          !Platform.environment.containsKey('FLUTTER_TEST')) {
        debugPrint(
          'Failed to synchronize the AI configuration with the daemon.',
        );
      }
    } catch (error) {
      debugPrint(
        'Failed to synchronize the AI configuration with the daemon: '
        '${error.runtimeType}',
      );
    }

    return true;
  }

  Future<bool> _restoreApiKey(String provider, String? previousApiKey) async {
    try {
      if (previousApiKey == null || previousApiKey.isEmpty) {
        await PythonBridge.deleteApiKey(provider: provider);
      } else {
        await PythonBridge.saveApiKey(previousApiKey, provider: provider);
      }
      return true;
    } catch (error) {
      debugPrint(
        'Failed to roll back AI credential storage: '
        '${error.runtimeType}',
      );
      return false;
    }
  }

  Future<bool> saveLocalAiCredential(String value) async {
    final normalized = value.trim();
    if (normalized.length < 8 || normalized.contains(RegExp(r'[\r\n\x00]'))) {
      return false;
    }
    final provider = _credentialProvider(_config['ai']);
    if (provider == null) return false;
    try {
      await PythonBridge.saveApiKey(normalized, provider: provider);
      _hasLocalAiCredential = true;
      _credentialStateKnown = true;
      if (_config['ai'] is Map) {
        _config['ai'] = Map<String, dynamic>.from(_config['ai'] as Map);
        _config['ai']['api_key'] = '******';
      }
      notifyListeners();
      return true;
    } catch (error) {
      _credentialStateKnown = false;
      debugPrint('Failed to save local AI credential: ${error.runtimeType}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLocalAiCredential() async {
    final provider = _credentialProvider(_config['ai']);
    if (provider == null) return false;
    try {
      await PythonBridge.deleteApiKey(provider: provider);
      _hasLocalAiCredential = false;
      _credentialStateKnown = true;
      if (_config['ai'] is Map) {
        _config['ai'] = Map<String, dynamic>.from(_config['ai'] as Map);
        _config['ai']['api_key'] = '';
      }
      notifyListeners();
      return true;
    } catch (error) {
      _credentialStateKnown = false;
      debugPrint('Failed to delete local AI credential: ${error.runtimeType}');
      notifyListeners();
      return false;
    }
  }

  // ─── Font Customization ──────────────────────────────
  String get fontFamily => _config['ui']?['font_family'] ?? 'System';

  double get fontScale {
    final scale = _config['ui']?['font_scale'];
    if (scale is num) return scale.toDouble();
    return 1.0;
  }

  Future<void> setFontFamily(String value) async {
    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['font_family'] = value;
    await updateConfig(config);
  }

  Future<void> setFontScale(double value) async {
    final config = Map<String, dynamic>.from(_config);
    config['ui'] = Map<String, dynamic>.from(config['ui'] ?? {});
    config['ui']['font_scale'] = value;
    await updateConfig(config);
  }
}
