import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/external_install_request.dart';

void main() {
  group('ExternalInstallRequest', () {
    test('parses the public native install command', () {
      final request = ExternalInstallRequest.fromArguments([
        'install',
        'alsa-utils',
        '--source',
        'pacman',
      ]);

      expect(request, isNotNull);
      expect(request!.packageId, 'alsa-utils');
      expect(request.source, 'Native');
    });

    test('defaults to the native source', () {
      final request = ExternalInstallRequest.fromArguments([
        'install',
        'wireplumber',
      ]);

      expect(request!.source, 'Native');
    });

    test('ignores unrelated startup arguments', () {
      expect(
        ExternalInstallRequest.fromArguments(['omnistore://auth/callback']),
        isNull,
      );
    });

    test('rejects shell-like package identifiers', () {
      expect(
        () => ExternalInstallRequest.fromArguments([
          'install',
          r'alsa-utils; rm -rf /',
        ]),
        throwsFormatException,
      );
    });

    test('rejects unknown options and sources', () {
      expect(
        () => ExternalInstallRequest.fromArguments([
          'install',
          'alsa-utils',
          '--execute',
          'anything',
        ]),
        throwsFormatException,
      );
      expect(
        () => ExternalInstallRequest.fromArguments([
          'install',
          'alsa-utils',
          '--source',
          'unknown',
        ]),
        throwsFormatException,
      );
    });
  });
}
