import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/data/python_bridge.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/services/update_service.dart';

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

    // Read secure API key and merge into UI-facing config map
    final apiKey = await PythonBridge.getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _config['ai'] = Map<String, dynamic>.from(_config['ai'] ?? {});
      _config['ai']['api_key'] = apiKey;
    }
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    // Extract and save key to SecureStorage
    if (newConfig['ai'] != null && newConfig['ai']['api_key'] != null) {
      final apiKey = newConfig['ai']['api_key'] as String;
      if (apiKey != '******') {
        await PythonBridge.saveApiKey(apiKey);
      }
    }

    // Prepare config to save to disk with key scrubbed
    final configToSave = Map<String, dynamic>.from(newConfig);
    if (configToSave['ai'] != null) {
      configToSave['ai'] = Map<String, dynamic>.from(configToSave['ai']);
      configToSave['ai']['api_key'] = ''; // Scrubbed!
    }

    final success = await _configRepository.saveConfig(configToSave);
    if (success) {
      _config = newConfig;
      _isAIEnabled = _config['ai']?['enabled'] ?? false;
      _isRailExpanded = _config['ui']?['rail_expanded'] ?? true;
      notifyListeners();
      // Propagate configuration updates dynamically to the background updates manager
      UpdateService().updateConfig();
    }
    return success;
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
