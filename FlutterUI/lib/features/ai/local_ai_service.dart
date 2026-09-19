import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/data/python_bridge.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/core/app_navigator.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

typedef LocalAiConsentPresenter =
    Future<bool> Function(AiConsentSummary summary);
typedef LocalAiKeyReader = Future<String?> Function(String provider);

class LocalAiException implements Exception {
  const LocalAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalAiConsentDenied extends LocalAiException {
  const LocalAiConsentDenied([
    super.message = 'You cancelled this AI request.',
  ]);
}

/// Direct, consent-gated AI calls for users who do not sign in to Meo Account.
///
/// Provider credentials are read from the platform credential store only after
/// the user approves the exact prompt fingerprint. On Linux,
/// [PythonBridge.getApiKey] is backed by flutter_secure_storage and therefore
/// Secret Service/KWallet. No API key is copied into OmniStore's config file.
class LocalAiService {
  LocalAiService({
    http.Client? client,
    LocalAiKeyReader? keyReader,
    LocalAiConsentPresenter? consentPresenter,
  }) : _client = client,
       _keyReader = keyReader ?? _readApiKey,
       _consentPresenter = consentPresenter ?? _presentConsent;

  static final LocalAiService instance = LocalAiService();

  final http.Client? _client;
  final LocalAiKeyReader _keyReader;
  final LocalAiConsentPresenter _consentPresenter;

  String _localized(
    String Function(AppLocalizations value) message,
    String fallback,
  ) {
    try {
      final context = omnistoreNavigatorKey.currentContext;
      if (context == null) return fallback;
      final value = AppLocalizations.of(context);
      return value == null ? fallback : message(value);
    } on FlutterError {
      return fallback;
    }
  }

  /// Reads provider metadata only. No prompt or user data is sent.
  ///
  /// Ollama discovery is restricted to the same loopback policy as inference.
  /// Cloud discovery reads the provider key lazily from the platform credential
  /// store and never returns it to the caller.
  Future<List<String>> discoverModels({
    required String provider,
    required String endpoint,
  }) async {
    final normalizedProvider = provider == 'custom'
        ? 'openai_compatible'
        : provider.trim().toLowerCase();
    if (!_providerNames.containsKey(normalizedProvider) ||
        normalizedProvider == 'account') {
      throw LocalAiException(
        _localized(
          (value) => value.localAiUnsupportedModelDiscovery,
          'This connection does not support local model discovery.',
        ),
      );
    }
    final selectedEndpoint = _endpointFor(normalizedProvider, endpoint);
    final isOllama = normalizedProvider == 'ollama';
    final url = _appendPath(
      selectedEndpoint,
      isOllama ? '/api/tags' : '/models',
    );
    final headers = <String, String>{'Accept': 'application/json'};
    String apiKey = '';
    if (!isOllama) {
      try {
        apiKey = (await _keyReader(normalizedProvider))?.trim() ?? '';
      } catch (_) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiCredentialStoreUnavailable,
            'Unable to open the secure credential store. Unlock KWallet and try again.',
          ),
        );
      }
      if (apiKey.length < 8 || apiKey.contains(RegExp(r'[\r\n\x00]'))) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiApiKeyRequired,
            'Securely save an API key for this provider first.',
          ),
        );
      }
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final ownClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.bodyBytes.length > 2 * 1024 * 1024) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiCatalogTooLarge,
            'The model catalog response is too large.',
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LocalAiException(_providerError(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiInvalidCatalog,
            'The model catalog returned invalid data.',
          ),
        );
      }
      final raw = isOllama ? decoded['models'] : decoded['data'];
      if (raw is! List) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiInvalidCatalog,
            'The model catalog returned invalid data.',
          ),
        );
      }
      final models =
          raw
              .whereType<Map>()
              .map(
                (item) =>
                    (item[isOllama ? 'name' : 'id'] as String? ?? '').trim(),
              )
              .where(
                (id) =>
                    id.isNotEmpty &&
                    id.length <= 160 &&
                    !id.contains(RegExp(r'[\r\n\x00]')),
              )
              .toSet()
              .toList(growable: false)
            ..sort();
      return models;
    } on LocalAiException {
      rethrow;
    } on FormatException {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidCatalog,
          'The model catalog returned invalid data.',
        ),
      );
    } catch (_) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiCatalogUnavailable,
          'Unable to read the model catalog. Check that the service is running.',
        ),
      );
    } finally {
      if (ownClient) client.close();
      apiKey = '';
    }
  }

  static const Map<String, String> _fixedEndpoints = {
    'openai': 'https://api.openai.com/v1',
    'gemini': 'https://generativelanguage.googleapis.com/v1beta',
    'deepseek': 'https://api.deepseek.com',
    'openrouter': 'https://openrouter.ai/api/v1',
  };

  static const Map<String, String> _providerNames = {
    'ollama': 'Ollama',
    'openai': 'OpenAI',
    'gemini': 'Google Gemini',
    'deepseek': 'DeepSeek',
    'openrouter': 'OpenRouter',
    'openai_compatible': 'OpenAI Compatible',
  };

  Future<String> invokeWithConsent({
    required String provider,
    required String endpoint,
    required String model,
    required String purpose,
    required List<String> dataCategories,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
    int maxOutputTokens = 2048,
  }) async {
    final normalizedProvider = provider == 'custom'
        ? 'openai_compatible'
        : provider.trim().toLowerCase();
    if (!_providerNames.containsKey(normalizedProvider)) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiUnsupportedConnection,
          'This local AI connection type is not supported.',
        ),
      );
    }
    final selectedModel = model.trim();
    if (selectedModel.isEmpty || selectedModel.length > 160) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidModel,
          'Enter a valid model name.',
        ),
      );
    }
    final normalizedPurpose = purpose.trim();
    if (normalizedPurpose.isEmpty || normalizedPurpose.length > 240) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidPurpose,
          'The AI request purpose is invalid.',
        ),
      );
    }
    if (systemPrompt.length > 12000 ||
        userPrompt.trim().isEmpty ||
        userPrompt.length > 40000 ||
        systemPrompt.length + userPrompt.length > 48000) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidInput,
          'The AI input is empty or too large.',
        ),
      );
    }
    final categories = dataCategories.toSet().toList()..sort();
    if (categories.isEmpty ||
        categories.length > 12 ||
        categories.any(
          (item) => !RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$').hasMatch(item),
        )) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidDataCategories,
          'The AI data categories are invalid.',
        ),
      );
    }
    final selectedEndpoint = _endpointFor(normalizedProvider, endpoint);
    final selectedTemperature = temperature.clamp(0, 2).toDouble();
    final selectedMaxTokens = maxOutputTokens.clamp(1, 4096);
    final requestPreview = _providerRequest(
      provider: normalizedProvider,
      endpoint: selectedEndpoint,
      model: selectedModel,
      apiKey: '',
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: selectedTemperature,
      maxOutputTokens: selectedMaxTokens,
    );
    final approvedDestination = requestPreview.url;
    final canonical = jsonEncode({
      'schema': 'org.meo.local-ai-consent/v1',
      'provider': normalizedProvider,
      'destination': approvedDestination.toString(),
      'model': selectedModel,
      'purpose': normalizedPurpose,
      'dataCategories': categories,
      'systemPrompt': systemPrompt,
      'userPrompt': userPrompt,
      'temperature': selectedTemperature,
      'maxOutputTokens': selectedMaxTokens,
    });
    final payloadSha256 = sha256.convert(utf8.encode(canonical)).toString();
    final providerName = _providerDisplayName(normalizedProvider);
    final approved = await _consentPresenter(
      AiConsentSummary(
        providerName: providerName,
        destination: approvedDestination.toString(),
        model: selectedModel,
        purpose: normalizedPurpose,
        dataCategories: categories,
        promptCharacters: systemPrompt.length + userPrompt.length,
        payloadSha256: payloadSha256,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      ),
    );
    if (!approved) {
      throw LocalAiConsentDenied(
        _localized(
          (value) => value.aiConsentCancelled,
          'You cancelled this AI request.',
        ),
      );
    }

    String apiKey = '';
    if (normalizedProvider != 'ollama') {
      try {
        apiKey = (await _keyReader(normalizedProvider))?.trim() ?? '';
      } catch (_) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiCredentialStoreUnavailable,
            'Unable to open the secure credential store. Unlock KWallet and try again.',
          ),
        );
      }
      if (apiKey.length < 8 || apiKey.contains(RegExp(r'[\r\n\x00]'))) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiApiKeyInvalid,
            'The secure credential store has no valid API key for this provider.',
          ),
        );
      }
    }

    final request = _providerRequest(
      provider: normalizedProvider,
      endpoint: selectedEndpoint,
      model: selectedModel,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: selectedTemperature,
      maxOutputTokens: selectedMaxTokens,
    );
    if (request.url != approvedDestination) {
      apiKey = '';
      throw LocalAiException(
        _localized(
          (value) => value.localAiDestinationChanged,
          'The AI destination changed after consent, so the request was blocked.',
        ),
      );
    }
    final ownClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            request.url,
            headers: request.headers,
            body: jsonEncode(request.payload),
          )
          .timeout(const Duration(seconds: 45));
      if (response.bodyBytes.length > 2 * 1024 * 1024) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiResponseTooLarge,
            'The AI service response is too large.',
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LocalAiException(_providerError(response.statusCode));
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiInvalidResponse,
            'The AI service returned invalid data.',
          ),
        );
      }
      if (decoded is! Map) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiInvalidResponse,
            'The AI service returned invalid data.',
          ),
        );
      }
      final data = Map<String, dynamic>.from(decoded);
      final text = _responseText(normalizedProvider, data).trim();
      if (text.isEmpty) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiNoResponseText,
            'The AI service did not return text.',
          ),
        );
      }
      return text;
    } on LocalAiException {
      rethrow;
    } catch (_) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiConnectionFailed,
          'Unable to connect to the AI service, or the request timed out.',
        ),
      );
    } finally {
      if (ownClient) client.close();
      apiKey = '';
    }
  }

  Future<Map<String, dynamic>> testConnection({
    required String provider,
    required String endpoint,
    required String model,
  }) async {
    final started = DateTime.now();
    try {
      final response = await invokeWithConsent(
        provider: provider,
        endpoint: endpoint,
        model: model,
        purpose: _localized(
          (value) => value.localAiTestPurpose,
          'Test the OmniStore local secure AI connection',
        ),
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'This is a connection test. Reply with a short OK.',
        userPrompt: 'OmniStore connection test.',
        temperature: 0,
        maxOutputTokens: 32,
      );
      return {
        'status': 'success',
        'response': response,
        'diagnostics': {
          'provider': provider,
          'credential_location': provider == 'ollama'
              ? 'none_local_model'
              : 'platform_credential_store',
          'consent': 'approved_once',
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
        },
      };
    } on LocalAiException catch (error) {
      return {
        'status': 'error',
        'response': error.message,
        'diagnostics': {
          'provider': provider,
          'consent': error is LocalAiConsentDenied ? 'denied' : 'not_invoked',
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
        },
      };
    }
  }

  Uri _endpointFor(String provider, String submitted) {
    final fixed = _fixedEndpoints[provider];
    final raw = (fixed ?? submitted).trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiInvalidEndpoint,
          'The AI service address is invalid.',
        ),
      );
    }
    final host = uri.host.toLowerCase();
    if (provider == 'ollama') {
      final loopback =
          host == 'localhost' || host == '127.0.0.1' || host == '::1';
      if (!loopback || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw LocalAiException(
          _localized(
            (value) => value.localAiOllamaLoopbackRequired,
            'The Ollama address must use local HTTP(S) loopback.',
          ),
        );
      }
    } else if (uri.scheme != 'https') {
      throw LocalAiException(
        _localized(
          (value) => value.localAiHttpsRequired,
          'Cloud AI services must use HTTPS.',
        ),
      );
    }
    if (provider == 'openai_compatible' && _isPrivateOrLocalHost(host)) {
      throw LocalAiException(
        _localized(
          (value) => value.localAiPrivateEndpointBlocked,
          'A compatible API cannot point to a local or private network. Use Ollama for local models.',
        ),
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), ''));
  }

  bool _isPrivateOrLocalHost(String host) {
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host == '::1' ||
        host.startsWith('fc') ||
        host.startsWith('fd') ||
        host.startsWith('fe80:')) {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return !host.contains('.');
    }
    final first = parts[0]!;
    final second = parts[1]!;
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        first >= 224;
  }

  _LocalProviderRequest _providerRequest({
    required String provider,
    required Uri endpoint,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxOutputTokens,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    Uri url;
    Map<String, dynamic> payload;
    if (provider == 'openai') {
      url = _appendPath(endpoint, '/responses');
      headers['Authorization'] = 'Bearer $apiKey';
      payload = {
        'model': model,
        'input': userPrompt,
        if (systemPrompt.isNotEmpty) 'instructions': systemPrompt,
        'temperature': temperature,
        'max_output_tokens': maxOutputTokens,
        'store': false,
      };
    } else if (provider == 'gemini') {
      url = _appendPath(
        endpoint,
        '/models/${Uri.encodeComponent(model)}:generateContent',
      );
      headers['x-goog-api-key'] = apiKey;
      headers['x-goog-api-client'] = 'omnistore/1.0';
      payload = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt},
            ],
          },
        ],
        if (systemPrompt.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
        },
      };
    } else if (provider == 'ollama') {
      url = _appendPath(endpoint, '/api/chat');
      payload = {
        'model': model,
        'messages': [
          if (systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'stream': false,
        'options': {'temperature': temperature, 'num_predict': maxOutputTokens},
      };
    } else {
      url = _appendPath(endpoint, '/chat/completions');
      headers['Authorization'] = 'Bearer $apiKey';
      if (provider == 'openrouter') {
        headers['HTTP-Referer'] = 'https://omnistore.meoarch.org';
        headers['X-OpenRouter-Title'] = 'OmniStore';
      }
      payload = {
        'model': model,
        'messages': [
          if (systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
        'max_tokens': maxOutputTokens,
        'stream': false,
      };
    }
    return _LocalProviderRequest(url: url, headers: headers, payload: payload);
  }

  Uri _appendPath(Uri endpoint, String suffix) {
    final base = endpoint.path.replaceFirst(RegExp(r'/$'), '');
    if (base.endsWith(suffix)) return endpoint;
    return endpoint.replace(path: '$base$suffix');
  }

  String _responseText(String provider, Map<String, dynamic> data) {
    if (provider == 'openai') {
      final direct = data['output_text'];
      if (direct is String) return direct;
      final lines = <String>[];
      for (final item
          in data['output'] is List ? data['output'] as List : const []) {
        if (item is! Map || item['content'] is! List) {
          continue;
        }
        for (final part in item['content'] as List) {
          if (part is Map && part['text'] is String) {
            lines.add(part['text'] as String);
          }
        }
      }
      return lines.join('\n');
    }
    if (provider == 'gemini') {
      final candidates = data['candidates'];
      if (candidates is! List ||
          candidates.isEmpty ||
          candidates.first is! Map) {
        return '';
      }
      final content = (candidates.first as Map)['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List) return '';
      return parts
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n');
    }
    if (provider == 'ollama') {
      final message = data['message'];
      return message is Map && message['content'] is String
          ? message['content'] as String
          : '';
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return '';
    final message = (choices.first as Map)['message'];
    return message is Map && message['content'] is String
        ? message['content'] as String
        : '';
  }

  String _providerDisplayName(String provider) {
    if (provider == 'ollama') {
      return _localized(
        (value) => value.localAiOllama,
        'Ollama (on this device)',
      );
    }
    return _providerNames[provider] ?? 'AI';
  }

  String _providerError(int status) {
    if (status == 401 || status == 403) {
      return _localized(
        (value) => value.localAiApiKeyRejected,
        'The AI service rejected the API key.',
      );
    }
    if (status == 404) {
      return _localized(
        (value) => value.localAiModelOrEndpointNotFound,
        'The requested AI model or service address was not found.',
      );
    }
    if (status == 429) {
      return _localized(
        (value) => value.localAiRateLimited,
        'The AI service is out of quota or receiving requests too quickly.',
      );
    }
    if (status >= 500) {
      return _localized(
        (value) => value.localAiUnavailable,
        'The AI service is temporarily unavailable.',
      );
    }
    return _localized(
      (value) => value.localAiRequestRejected(status),
      'The AI service rejected the request (HTTP $status).',
    );
  }

  static Future<String?> _readApiKey(String provider) =>
      PythonBridge.getApiKey(provider: provider, throwOnError: true);

  static Future<bool> _presentConsent(AiConsentSummary summary) async {
    final context = omnistoreNavigatorKey.currentContext;
    if (context == null) return false;
    return showAiConsentDialog(context, summary);
  }
}

class _LocalProviderRequest {
  const _LocalProviderRequest({
    required this.url,
    required this.headers,
    required this.payload,
  });

  final Uri url;
  final Map<String, String> headers;
  final Map<String, dynamic> payload;
}
