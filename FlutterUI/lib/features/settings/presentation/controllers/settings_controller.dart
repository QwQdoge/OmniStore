import 'package:flutter/material.dart';
import 'package:frontend/backend/repositories/config_repository.dart';

class SettingsController with ChangeNotifier {
  final ConfigRepository _configRepository;
  Map<String, dynamic> _config = {};
  bool _isAIEnabled = false;

  SettingsController(this._configRepository);

  Map<String, dynamic> get config => _config;
  bool get isAIEnabled => _isAIEnabled;

  Future<void> loadConfig() async {
    _config = await _configRepository.loadConfig();
    _isAIEnabled = _config['ai']?['enabled'] ?? false;
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    final success = await _configRepository.saveConfig(newConfig);
    if (success) {
      _config = newConfig;
      _isAIEnabled = _config['ai']?['enabled'] ?? false;
      notifyListeners();
    }
    return success;
  }
}
