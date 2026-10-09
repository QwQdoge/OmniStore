import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _configKey = 'omnistore_config';

Map<String, dynamic> _copyConfig(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('serializes desktop writes so an older save cannot finish last', () async {
    final firstWriteStarted = Completer<void>();
    final releaseFirstWrite = Completer<void>();
    final writes = <Map<String, dynamic>>[];
    var callCount = 0;

    final repository = ConfigRepository.test(
      saveDebounce: Duration.zero,
      desktopWriter: (config) async {
        writes.add(_copyConfig(config));
        callCount++;
        if (callCount == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
        }
        return true;
      },
    );

    final firstSave = repository.saveConfig({'version': 1});
    await firstWriteStarted.future;

    final secondSave = repository.saveConfig({'version': 2});
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(writes.map((config) => config['version']), [1]);

    releaseFirstWrite.complete();
    expect(await firstSave, isTrue);
    expect(await secondSave, isTrue);
    expect(writes.map((config) => config['version']), [1, 2]);

    final loaded = await repository.loadConfig();
    expect(loaded['version'], 2);

    final prefs = await SharedPreferences.getInstance();
    final backup = jsonDecode(prefs.getString(_configKey)!) as Map<String, dynamic>;
    expect(backup['version'], 2);
  });

  test('failed durable save leaves the previous cache and backup intact', () async {
    final initialConfig = <String, dynamic>{'version': 1};
    SharedPreferences.setMockInitialValues({
      _configKey: jsonEncode(initialConfig),
    });

    final repository = ConfigRepository.test(
      saveDebounce: Duration.zero,
      desktopWriter: (_) async => false,
    );

    expect((await repository.loadConfig())['version'], 1);
    expect(await repository.saveConfig({'version': 2}), isFalse);
    expect((await repository.loadConfig())['version'], 1);

    final prefs = await SharedPreferences.getInstance();
    final backup = jsonDecode(prefs.getString(_configKey)!) as Map<String, dynamic>;
    expect(backup['version'], 1);
  });

  test('configuration snapshots cannot be mutated through caller-owned maps', () async {
    final repository = ConfigRepository.test();
    final original = <String, dynamic>{
      'nested': <String, dynamic>{'value': 1},
    };

    expect(await repository.saveConfig(original), isTrue);

    (original['nested'] as Map<String, dynamic>)['value'] = 2;
    final firstLoad = await repository.loadConfig();
    expect((firstLoad['nested'] as Map<String, dynamic>)['value'], 1);

    (firstLoad['nested'] as Map<String, dynamic>)['value'] = 3;
    final secondLoad = await repository.loadConfig();
    expect((secondLoad['nested'] as Map<String, dynamic>)['value'], 1);
  });

  test('debounced callers share the result of the newest snapshot', () async {
    final writes = <Map<String, dynamic>>[];
    final repository = ConfigRepository.test(
      saveDebounce: const Duration(milliseconds: 20),
      desktopWriter: (config) async {
        writes.add(_copyConfig(config));
        return true;
      },
    );

    final firstSave = repository.saveConfig({'version': 1});
    final secondSave = repository.saveConfig({'version': 2});

    expect(await firstSave, isTrue);
    expect(await secondSave, isTrue);
    expect(writes, hasLength(1));
    expect(writes.single['version'], 2);
  });
}
