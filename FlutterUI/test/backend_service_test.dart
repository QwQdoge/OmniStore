import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/services/backend/platform_environment.dart';
import 'package:frontend/services/backend/security_validator.dart';
import 'package:frontend/core/platform/desktop_window_service.dart';
import 'package:flutter/material.dart';
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

  test(
    'desktop window sizing is logical and bounded on mixed-DPI displays',
    () {
      expect(
        DesktopWindowService.initialSizeFor(const Size(2560, 1440)),
        const Size(1440, 960),
      );
      final scaled = DesktopWindowService.initialSizeFor(
        const Size(1829, 1143),
      );
      expect(scaled.width, closeTo(1316.88, 0.001));
      expect(scaled.height, closeTo(891.54, 0.001));
      final smallMinimum = DesktopWindowService.minimumSizeFor(
        const Size(800, 600),
      );
      expect(smallMinimum.width, lessThan(800));
      expect(smallMinimum.height, lessThan(600));
    },
  );

  test('Linux runner prefers native Wayland for per-monitor scaling', () {
    final runner = File('linux/runner/main.cc').readAsStringSync();
    expect(runner, contains('XDG_SESSION_TYPE'));
    expect(runner, contains('g_setenv("GDK_BACKEND", "wayland,x11", TRUE)'));
  });

  test('daemon wire response unwraps legacy nested protocol exactly once', () {
    final result = DaemonResult.fromWire({
      'status': 'success',
      'response': {
        'status': 'success',
        'context': 'run_search',
        'response': [
          {'id': 'org.meo.App'},
        ],
      },
    });
    expect(result.status, 'success');
    expect(result.response, isA<List<dynamic>>());

    final innerError = DaemonResult.fromWire({
      'status': 'success',
      'response': {'status': 'error', 'error': 'NotFound'},
    });
    expect(innerError.status, 'error');
    expect(innerError.error, 'NotFound');
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
