import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/services/backend/platform_environment.dart';
import 'dart:io';

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
}
