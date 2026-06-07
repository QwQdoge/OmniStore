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
