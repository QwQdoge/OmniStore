import 'package:flutter/material.dart';
import 'package:frontend/data/repositories/config_repository.dart';

class SettingsController with ChangeNotifier {
  final ConfigRepository _configRepository;
  Map<String, dynamic> _config = {};
  bool _isAIEnabled = false;
  bool _isRailExpanded = true;

  SettingsController(this._configRepository);

  Map<String, dynamic> get config => _config;
  bool get isAIEnabled => _isAIEnabled;
  bool get isRailExpanded => _isRailExpanded;

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
    await updateConfig(config);
  }

  bool get autoUpdate => _config['daemon']?['auto_update'] ?? false;

  Future<void> setAutoUpdate(bool value) async {
    final config = Map<String, dynamic>.from(_config);
    config['daemon'] = Map<String, dynamic>.from(config['daemon'] ?? {});
    config['daemon']['auto_update'] = value;
    await updateConfig(config);
  }

  int get checkIntervalHours => _config['updates']?['check_interval_hours'] ?? 1;

  Future<void> setCheckIntervalHours(int value) async {
    final config = Map<String, dynamic>.from(_config);
    config['updates'] = Map<String, dynamic>.from(config['updates'] ?? {});
    config['updates']['check_interval_hours'] = value;
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

  // ─── Config Lifecycle ────────────────────────────────
  Future<void> loadConfig() async {
    _config = await _configRepository.loadConfig();
    _isAIEnabled = _config['ai']?['enabled'] ?? false;
    _isRailExpanded = _config['ui']?['rail_expanded'] ?? true;
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    final success = await _configRepository.saveConfig(newConfig);
    if (success) {
      _config = newConfig;
      _isAIEnabled = _config['ai']?['enabled'] ?? false;
      _isRailExpanded = _config['ui']?['rail_expanded'] ?? true;
      notifyListeners();
    }
    return success;
  }
}
