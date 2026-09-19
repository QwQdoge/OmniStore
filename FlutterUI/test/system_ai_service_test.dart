import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/system_ai_service.dart';

void main() {
  const connectionId = '4e3ec70d-bcd4-4cd0-bc7c-a1ff307e13ab';
  const requestId = '6f45e0ac-28dd-4ebf-9a19-871f5b006f52';
  const hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test(
    'system broker invocation requires and forwards payload consent',
    () async {
      final actions = <String>[];
      late Map<String, DBusValue> preparedArguments;
      late Map<String, DBusValue> invokedArguments;
      final service = SystemAiService(
        consentPresenter: (summary) async {
          expect(summary.payloadSha256, hash);
          expect(summary.promptCharacters, 12);
          expect(summary.dataCategories, ['synthetic_test']);
          return true;
        },
        operationRunner: (action, arguments) async {
          actions.add(action);
          if (action == 'prepare_inference') {
            preparedArguments = arguments;
            return {
              'consent': {
                'requestId': requestId,
                'payloadSha256': hash,
                'confirmationVersion': 1,
                'expiresAt': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 2))
                    .toIso8601String(),
                'connectionId': connectionId,
                'providerName': 'Test provider',
                'destination': 'https://example.test/v1/chat/completions',
                'model': 'tiny-model',
                'purpose': 'Connection test',
                'dataCategories': ['synthetic_test'],
                'promptCharacters': 12,
                'clientId': 'org.meo.OmniStore',
              },
            };
          }
          invokedArguments = arguments;
          return {'text': 'OK'};
        },
      );

      final result = await service.invokeWithConsent(
        connectionId: connectionId,
        model: 'tiny-model',
        purpose: 'Connection test',
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'Reply OK.',
        userPrompt: 'OK?',
        maxOutputTokens: 8,
      );

      expect(result, 'OK');
      expect(actions, ['prepare_inference', 'invoke']);
      expect(invokedArguments['userPrompt'], preparedArguments['userPrompt']);
      final consent = invokedArguments['consent']! as DBusDict;
      final nativeConsent = consent.toNative() as Map<Object?, Object?>;
      expect(nativeConsent['requestId'], requestId);
      expect(nativeConsent['payloadSha256'], hash);
      expect(nativeConsent['approved'], isTrue);
    },
  );

  test('invalid consent summary never reaches invoke', () async {
    final actions = <String>[];
    final service = SystemAiService(
      consentPresenter: (_) async => true,
      operationRunner: (action, arguments) async {
        actions.add(action);
        return {
          'consent': {
            'requestId': requestId,
            'payloadSha256': hash,
            'confirmationVersion': 1,
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 2))
                .toIso8601String(),
            'connectionId': connectionId,
            'providerName': 'Test provider',
            'destination': 'https://example.test/v1/chat/completions',
            'model': 'different-model',
            'purpose': 'Connection test',
            'dataCategories': ['synthetic_test'],
            'promptCharacters': 12,
            'clientId': 'org.meo.OmniStore',
          },
        };
      },
    );

    await expectLater(
      service.invokeWithConsent(
        connectionId: connectionId,
        model: 'tiny-model',
        purpose: 'Connection test',
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'Reply OK.',
        userPrompt: 'OK?',
      ),
      throwsA(isA<SystemAiException>()),
    );
    expect(actions, ['prepare_inference']);
  });
}
