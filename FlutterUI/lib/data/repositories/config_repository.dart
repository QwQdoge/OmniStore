import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../python_bridge.dart';
import '../../services/backend_service.dart';

class ConfigRepository {
  static const String _webConfigKey = 'omnistore_config';

  Timer? _saveTimer;
  Map<String, dynamic>? _pendingConfig;
  Completer<bool>? _pendingCompleter;

  final Map<String, dynamic> _defaultWebConfig = {
    "first_run": true,
    "search": {
      "sources": {
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
        "ai": false,
      },
      "max_results": 50,
    },
    "ui": {
      "appearance": "system",
      "color_seed": "#4E7EEF",
      "language": "zh-CN",
      "enable_system_tray": false,
      "close_to_tray": false,
    },
    "ai": {
      "enabled": false,
      "provider": "openai",
      "endpoint": "",
      "model": "",
      "api_key": "",
    },
  };

  Map<String, dynamic>? _cachedConfig;
  Map<String, dynamic>? _cachedEnv;

  Future<Map<String, dynamic>> loadConfig({bool forceRefresh = false}) async {
    if (_cachedConfig != null && !forceRefresh) {
      return _cachedConfig!;
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw == null) {
          await prefs.setString(_webConfigKey, jsonEncode(_defaultWebConfig));
          _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
          return _cachedConfig!;
        }
        _cachedConfig = jsonDecode(raw) as Map<String, dynamic>;
        return _cachedConfig!;
      } catch (e) {
        debugPrint("Web loadConfig Exception: $e");
        _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
        return _cachedConfig!;
      }
    }

    try {
      final configMap = await BackendService.instance.loadConfig();
      if (configMap.isNotEmpty) {
        _cachedConfig = configMap;
        return _cachedConfig!;
      }
    } catch (e) {
      debugPrint("loadConfig Exception: $e");
      // Fallback to SharedPreferences on desktop if python is broken
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webConfigKey);
        if (raw != null) {
          _cachedConfig = jsonDecode(raw) as Map<String, dynamic>;
          return _cachedConfig!;
        }
      } catch (_) {}
      _cachedConfig = Map<String, dynamic>.from(_defaultWebConfig);
      return _cachedConfig!;
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    _cachedConfig = config;
    _cachedEnv =
        null; // Invalidate env check cache in case source configs changed

    // Save to preferences instantly (web or desktop backup)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webConfigKey, jsonEncode(config));
    } catch (_) {}

    if (kIsWeb) {
      return true;
    }

    _pendingConfig = config;
    _pendingCompleter ??= Completer<bool>();

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final configToSave = _pendingConfig;
      final completer = _pendingCompleter;
      _pendingConfig = null;
      _pendingCompleter = null;

      if (configToSave == null) {
        completer?.complete(true);
        return;
      }

      try {
        final success = await BackendService.instance.saveConfig(configToSave);
        completer?.complete(success);
      } catch (e) {
        debugPrint("saveConfig Exception: $e");
        completer?.complete(false);
      }
    });

    return _pendingCompleter!.future;
  }

  Future<Map<String, dynamic>> checkEnv({bool forceRefresh = false}) async {
    if (_cachedEnv != null && !forceRefresh) {
      return _cachedEnv!;
    }

    if (kIsWeb) {
      _cachedEnv = {
        "platform": "Web / Browser",
        "python_status": "Not supported (Browser Sandbox)",
        "available_sources": ["GitHub", "Bitu"],
        "os_details": "Chrome / Web browser environment",
      };
      return _cachedEnv!;
    }

    try {
      final envRes = await BackendService.instance.checkEnv();
      if (envRes.isNotEmpty) {
        _cachedEnv = envRes;
        return _cachedEnv!;
      }
    } catch (e) {
      debugPrint("checkEnv Exception: $e");
      _cachedEnv = {
        "platform": "Unknown/Desktop",
        "python_status": "Error: $e",
        "available_sources": ["GitHub", "Bitu"],
      };
      return _cachedEnv!;
    }
  }
}
