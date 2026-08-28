import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/auth_service.dart';

void main() {
  test('accepts only the exact cold-start system account callback', () {
    final callback = meoAccountCallbackFromArguments([
      '--verbose',
      'omnistore://auth/callback?code=one&state=two',
    ]);
    expect(callback?.scheme, 'omnistore');
    expect(callback?.host, 'auth');
    expect(callback?.path, '/callback');

    expect(
      meoAccountCallbackFromArguments([
        'omnistore://attacker/callback?code=one',
      ]),
      isNull,
    );
    expect(
      meoAccountCallbackFromArguments([
        'https://account.meoarch.org/auth/callback',
      ]),
      isNull,
    );
  });

  test('system flow persists one-shot proof and fails replay closed', () {
    final source = File(
      'lib/features/auth/system_account_service.dart',
    ).readAsStringSync();

    expect(source, contains('FlutterSecureStorage'));
    expect(source, contains("'state': state"));
    expect(source, contains("'verifier': verifier"));
    expect(source, contains("'requestId': requestId"));
    expect(source, contains("'createdAt': createdAt.toUtc()"));
    expect(source, contains('Duration(minutes: 5)'));
    expect(source, contains('_constantTimeEquals'));
    expect(source, contains('Consume before code exchange'));
    expect(source, contains('clientSignOutRequested'));
    expect(source, contains('client_access_revoked'));
    expect(source, contains('RegisterClientSession'));
    expect(source, isNot(contains("'access_token': DBus")));
    expect(source, isNot(contains("'refresh_token': DBus")));
  });
}
