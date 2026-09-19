import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/local_ai_service.dart';

/// Opt-in live contract check for an OpenAI-compatible provider.
///
/// The credential is read only from the test process environment and is never
/// printed or persisted. Normal `flutter test` runs skip this paid/networked
/// check. Run it explicitly with MEO_TEST_AI_KEY after reviewing the endpoint
/// and low-cost model overrides.
void main() {
  final key = Platform.environment['MEO_TEST_AI_KEY'] ?? '';
  final endpoint =
      Platform.environment['MEO_TEST_AI_ENDPOINT'] ?? 'https://yunwu.ai/v1';
  final model = Platform.environment['MEO_TEST_AI_MODEL'] ?? 'gpt-4.1-nano';

  test(
    'live compatible provider lists models and completes a tiny prompt',
    () async {
      final service = LocalAiService(
        keyReader: (_) async => key,
        consentPresenter: (_) async => true,
      );

      final models = await service.discoverModels(
        provider: 'openai_compatible',
        endpoint: endpoint,
      );
      expect(models, contains(model));

      final response = await service.invokeWithConsent(
        provider: 'openai_compatible',
        endpoint: endpoint,
        model: model,
        purpose: 'OmniStore opt-in live provider contract test',
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'Reply with exactly OK.',
        userPrompt: 'OK?',
        temperature: 0,
        maxOutputTokens: 8,
      );
      expect(response.trim().toUpperCase(), contains('OK'));
    },
    skip: key.isEmpty
        ? 'Set MEO_TEST_AI_KEY to run the live provider test.'
        : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
