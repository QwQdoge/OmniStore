import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/account_ai_prompts.dart';
import 'package:frontend/features/ai/account_ai_service.dart';

void main() {
  test('account credential metadata contains no provider key field', () {
    final credential = AccountAiCredential.fromJson(const {
      'id': 'credential-id',
      'provider': 'openai',
      'displayName': 'Personal OpenAI',
      'endpoint': 'https://api.openai.com/v1',
      'defaultModel': 'gpt-5',
      'secretHint': '••••abcd',
      'enabled': true,
      'apiKey': 'must-not-be-consumed',
    });

    expect(credential.id, 'credential-id');
    expect(credential.endpoint, 'https://api.openai.com/v1');
    expect(credential.secretHint, '••••abcd');
    expect(credential.toString(), isNot(contains('must-not-be-consumed')));
  });

  test('account consent is bound to credential, provider, and destination', () {
    final source = File(
      'lib/features/ai/account_ai_service.dart',
    ).readAsStringSync();

    expect(source, contains("consent['credentialId'] != credential.id"));
    expect(source, contains("consent['provider'] != credential.provider"));
    expect(source, contains('consentDestination != expectedDestination'));
    expect(source, contains('Meo Account broker → \$consentDestination'));
  });

  test('all OmniStore account prompts mark user content as untrusted', () {
    final prompts = [
      OmniStoreAiPrompts.explain('App', 'Description', 'English'),
      OmniStoreAiPrompts.summarizeUpdate('App', '1', '2', 'English'),
      OmniStoreAiPrompts.cli('App', 'Flatpak', 'English'),
      OmniStoreAiPrompts.conflicts('App', 'English'),
      OmniStoreAiPrompts.pick('English'),
      OmniStoreAiPrompts.correction('query', 'English'),
      OmniStoreAiPrompts.compare('App', 'English'),
      OmniStoreAiPrompts.health(const {'os': 'MeoArch'}, 'English'),
      OmniStoreAiPrompts.analyzeError('sample log', 'English'),
      OmniStoreAiPrompts.recommend('drawing app', 'English'),
      OmniStoreAiPrompts.installationDecision('App', const [
        {'source': 'Flatpak'},
      ], 'English'),
    ];

    for (final prompt in prompts) {
      expect(prompt.purpose, isNotEmpty);
      expect(prompt.dataCategories, isNotEmpty);
      expect(prompt.systemPrompt, contains('untrusted data'));
      expect(prompt.systemPrompt, contains('Do not claim that you executed'));
      expect(prompt.userPrompt, isNotEmpty);
    }
  });

  test('installation decision prompt sends only supplied variants', () {
    final prompt = OmniStoreAiPrompts.installationDecision('Example', const [
      {'source': 'Flatpak', 'publisher': 'Example'},
      {'source': 'AUR', 'publisher': 'Community'},
    ], 'English');
    final payload = jsonDecode(prompt.userPrompt) as Map<String, dynamic>;

    expect(payload['app'], 'Example');
    expect(payload['variants'], hasLength(2));
    expect(prompt.systemPrompt, contains('Return only one JSON object'));
    expect(prompt.systemPrompt, contains('Recommend only a source present'));
  });
}
