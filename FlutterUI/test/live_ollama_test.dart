import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/local_ai_service.dart';

/// Opt-in end-to-end check for the user's local Ollama service.
///
/// This test never downloads a model and never reads a credential. Set
/// MEO_TEST_OLLAMA=1 only after the user has installed Ollama and a small model.
void main() {
  final enabled = Platform.environment['MEO_TEST_OLLAMA'] == '1';
  final endpoint =
      Platform.environment['MEO_TEST_OLLAMA_ENDPOINT'] ??
      'http://127.0.0.1:11434';
  final requestedModel = Platform.environment['MEO_TEST_OLLAMA_MODEL'] ?? '';

  test(
    'live Ollama discovery and tiny inference stay on loopback',
    () async {
      var keyRead = false;
      final service = LocalAiService(
        keyReader: (_) async {
          keyRead = true;
          return null;
        },
        consentPresenter: (_) async => true,
      );
      final models = await service.discoverModels(
        provider: 'ollama',
        endpoint: endpoint,
      );
      expect(models, isNotEmpty);
      final model = requestedModel.isEmpty ? models.first : requestedModel;
      expect(models, contains(model));

      final response = await service.invokeWithConsent(
        provider: 'ollama',
        endpoint: endpoint,
        model: model,
        purpose: 'OmniStore opt-in local Ollama contract test',
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'Reply with exactly OK.',
        userPrompt: 'OK?',
        temperature: 0,
        maxOutputTokens: 8,
      );
      expect(response.trim(), isNotEmpty);
      expect(keyRead, isFalse);
    },
    skip: enabled
        ? false
        : 'Set MEO_TEST_OLLAMA=1 to test a running local Ollama.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
