import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/python_bridge.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';

Map<String, dynamic> _copyConfig(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic> _initialConfig() {
  return {
    'ui': {
      'appearance': 'system',
      'language': 'en-US',
      'rail_expanded': true,
    },
    'ai': {
      'enabled': true,
      'provider': 'openai',
      'endpoint': '',
      'model': '',
      'api_key': '',
    },
    'daemon': {'enabled': true},
    'updates': {'check_interval_hours': 1},
  };
}

class _MemoryConfigRepository extends ConfigRepository {
  _MemoryConfigRepository({
    required Map<String, dynamic> initialConfig,
    this.saveSucceeds = true,
  }) : storedConfig = _copyConfig(initialConfig),
       super.test();

  Map<String, dynamic> storedConfig;
  bool saveSucceeds;

  @override
  Future<Map<String, dynamic>> loadConfig({
    bool forceRefresh = false,
  }) async {
    return _copyConfig(storedConfig);
  }

  @override
  Future<bool> saveConfig(Map<String, dynamic> config) async {
    if (!saveSucceeds) return false;
    storedConfig = _copyConfig(config);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await PythonBridge.deleteApiKey();
  });

  tearDown(() async {
    await PythonBridge.deleteApiKey();
  });

  test('clearing the API key clears secure storage and daemon state', () async {
    await PythonBridge.saveApiKey('old-secret');

    final repository = _MemoryConfigRepository(
      initialConfig: _initialConfig(),
    );
    final daemonUpdates = <Map<String, String>>[];
    var refreshCount = 0;
    final controller = SettingsController(
      repository,
      updateDaemonEnvironment: (environment) async {
        daemonUpdates.add(Map<String, String>.from(environment));
        return true;
      },
      refreshUpdateService: () async {
        refreshCount++;
      },
    );
    addTearDown(controller.dispose);

    await controller.loadConfig();
    final updated = _copyConfig(controller.config);
    (updated['ai'] as Map<String, dynamic>)['api_key'] = '';

    expect(await controller.updateConfig(updated), isTrue);
    expect(await PythonBridge.getApiKey(), isNull);
    expect(
      (repository.storedConfig['ai'] as Map<String, dynamic>)['api_key'],
      isEmpty,
    );
    expect(daemonUpdates, hasLength(1));
    expect(daemonUpdates.single['OMNISTORE_AI_API_KEY'], isEmpty);
    expect(refreshCount, 1);
  });

  test('restores the previous key when config persistence fails', () async {
    await PythonBridge.saveApiKey('old-secret');

    final repository = _MemoryConfigRepository(
      initialConfig: _initialConfig(),
      saveSucceeds: false,
    );
    final daemonUpdates = <Map<String, String>>[];
    var refreshCount = 0;
    final controller = SettingsController(
      repository,
      updateDaemonEnvironment: (environment) async {
        daemonUpdates.add(Map<String, String>.from(environment));
        return true;
      },
      refreshUpdateService: () async {
        refreshCount++;
      },
    );
    addTearDown(controller.dispose);

    await controller.loadConfig();
    final updated = _copyConfig(controller.config);
    (updated['ai'] as Map<String, dynamic>)['api_key'] = 'new-secret';

    expect(await controller.updateConfig(updated), isFalse);
    expect(await PythonBridge.getApiKey(), 'old-secret');
    expect(daemonUpdates, isEmpty);
    expect(refreshCount, 0);
  });
}
