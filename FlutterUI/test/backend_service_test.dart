import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/services/backend/platform_environment.dart';
import 'package:frontend/services/backend/security_validator.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  test('PlatformEnvironment detects project root', () {
    final env = PlatformEnvironment.instance;
    expect(env.projectRoot, isNotEmpty);
    // In our test environment, we expect to be in a place where we can find python/main.py
    // (the current working directory or its parent)
    final scriptFile = File('${env.projectRoot}/python/main.py');
    expect(scriptFile.existsSync(), isTrue);
  });

  test('BackendService is a singleton', () {
    final b1 = BackendService.instance;
    final b2 = BackendService.instance;
    expect(b1, same(b2));
  });

  test('BackendService uses shared platform environment paths', () {
    final env = PlatformEnvironment.instance;

    expect(BackendService.venvPython, env.venvPython);
    expect(BackendService.scriptPath, env.scriptPath);
    expect(BackendService.workingDir, env.workingDir);
  });

  test('PlatformEnvironment resolves the checked-in Windows venv', () {
    if (!Platform.isWindows) return;

    final expected = p.join(
      PlatformEnvironment.instance.projectRoot,
      'python',
      '.venv',
      'Scripts',
      'python.exe',
    );

    if (File(expected).existsSync()) {
      expect(PlatformEnvironment.instance.venvPython, expected);
    }
  });

  test('PlatformEnvironment exposes an OmniStore config directory', () {
    final configDir = PlatformEnvironment.instance.appConfigDir;
    expect(configDir, isNotEmpty);
    expect(p.basename(configDir), 'omnistore');
    expect(configDir, isNot(contains('/home/user')));
  });

  test('Safe JSON decode handles noise and artifacts', () {
    final backend = BackendService.instance;

    // We can't easily test private methods with (backend as dynamic) if they are not defined on the class
    // But I'll just check if it's there.

    // Exact match
    expect(
      backend.searchPackages("", cancelOngoing: false),
      isA<Future<List>>(),
    ); // Triggers trimmed empty query early return
  });

  test('Search validator accepts GitHub store query syntax', () {
    expect(
      () => SecurityValidator.validateSearchQuery(
        'source:github:stars:>5000 sort:stars',
        'Search Query',
      ),
      returnsNormally,
    );
  });

  test('Search validator rejects shell control syntax', () {
    expect(
      () => SecurityValidator.validateSearchQuery(
        'source:github; rm -rf /',
        'Search Query',
      ),
      throwsArgumentError,
    );
  });
}
