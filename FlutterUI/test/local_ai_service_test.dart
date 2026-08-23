import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/features/ai/local_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseRequest = (
    provider: 'openai',
    endpoint: 'https://attacker.invalid/v1',
    model: 'gpt-5',
    purpose: 'Explain a package',
    categories: <String>['package_metadata'],
    system: 'Be concise.',
    user: 'Explain test.',
  );

  test('denial happens before keychain read or provider request', () async {
    var keyReads = 0;
    var requests = 0;
    final service = LocalAiService(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      keyReader: (_) async {
        keyReads++;
        return 'secret-key';
      },
      consentPresenter: (_) async => false,
    );

    await expectLater(
      service.invokeWithConsent(
        provider: baseRequest.provider,
        endpoint: baseRequest.endpoint,
        model: baseRequest.model,
        purpose: baseRequest.purpose,
        dataCategories: baseRequest.categories,
        systemPrompt: baseRequest.system,
        userPrompt: baseRequest.user,
      ),
      throwsA(isA<LocalAiConsentDenied>()),
    );
    expect(keyReads, 0);
    expect(requests, 0);
  });

  test(
    'OpenAI uses fixed HTTPS endpoint and disables provider storage',
    () async {
      AiConsentSummary? summary;
      late http.Request captured;
      final service = LocalAiService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'output': [
                {
                  'content': [
                    {'type': 'output_text', 'text': 'safe answer'},
                  ],
                },
              ],
            }),
            200,
          );
        }),
        keyReader: (provider) async {
          expect(provider, 'openai');
          return 'sk-test-secret';
        },
        consentPresenter: (value) async {
          summary = value;
          return true;
        },
      );

      final text = await service.invokeWithConsent(
        provider: baseRequest.provider,
        endpoint: baseRequest.endpoint,
        model: baseRequest.model,
        purpose: baseRequest.purpose,
        dataCategories: baseRequest.categories,
        systemPrompt: baseRequest.system,
        userPrompt: baseRequest.user,
      );

      expect(text, 'safe answer');
      expect(captured.url.toString(), 'https://api.openai.com/v1/responses');
      expect(captured.headers['authorization'], 'Bearer sk-test-secret');
      expect(jsonDecode(captured.body)['store'], isFalse);
      expect(summary?.destination, 'https://api.openai.com/v1/responses');
      expect(summary?.userPrompt, baseRequest.user);
      expect(summary?.payloadSha256, hasLength(64));
    },
  );

  test(
    'custom compatible endpoint rejects local and private destinations',
    () async {
      final service = LocalAiService(
        client: MockClient((_) async => http.Response('{}', 200)),
        keyReader: (_) async => 'secret-key',
        consentPresenter: (_) async => true,
      );

      await expectLater(
        service.invokeWithConsent(
          provider: 'openai_compatible',
          endpoint: 'https://192.168.1.20/v1',
          model: 'model',
          purpose: baseRequest.purpose,
          dataCategories: baseRequest.categories,
          systemPrompt: baseRequest.system,
          userPrompt: baseRequest.user,
        ),
        throwsA(isA<LocalAiException>()),
      );
    },
  );

  test('Ollama loopback calls never read an API key', () async {
    var keyReads = 0;
    final service = LocalAiService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:11434/api/chat');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'message': {'role': 'assistant', 'content': 'local answer'},
          }),
          200,
        );
      }),
      keyReader: (_) async {
        keyReads++;
        return null;
      },
      consentPresenter: (_) async => true,
    );

    final text = await service.invokeWithConsent(
      provider: 'ollama',
      endpoint: 'http://localhost:11434',
      model: 'qwen2.5:1.5b',
      purpose: baseRequest.purpose,
      dataCategories: baseRequest.categories,
      systemPrompt: baseRequest.system,
      userPrompt: baseRequest.user,
    );
    expect(text, 'local answer');
    expect(keyReads, 0);
  });

  test('Ollama HTTPS endpoints are also restricted to loopback', () async {
    final service = LocalAiService(
      client: MockClient((_) async => http.Response('{}', 200)),
      keyReader: (_) async => null,
      consentPresenter: (_) async => true,
    );

    await expectLater(
      service.invokeWithConsent(
        provider: 'ollama',
        endpoint: 'https://remote-ollama.example',
        model: 'qwen2.5:1.5b',
        purpose: baseRequest.purpose,
        dataCategories: baseRequest.categories,
        systemPrompt: baseRequest.system,
        userPrompt: baseRequest.user,
      ),
      throwsA(isA<LocalAiException>()),
    );
  });
}
