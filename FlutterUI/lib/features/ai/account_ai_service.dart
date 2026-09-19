import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/app_navigator.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountAiException implements Exception {
  const AccountAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountAiConsentDenied extends AccountAiException {
  const AccountAiConsentDenied([
    super.message = 'You cancelled this AI request.',
  ]);
}

class AccountAiCredential {
  const AccountAiCredential({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.endpoint,
    required this.defaultModel,
    required this.secretHint,
    required this.enabled,
  });

  final String id;
  final String provider;
  final String displayName;
  final String endpoint;
  final String defaultModel;
  final String secretHint;
  final bool enabled;

  factory AccountAiCredential.fromJson(Map<String, dynamic> json) {
    return AccountAiCredential(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'AI',
      endpoint: json['endpoint'] as String? ?? '',
      defaultModel: json['defaultModel'] as String? ?? '',
      secretHint: json['secretHint'] as String? ?? '••••',
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

typedef AiConsentPresenter = Future<bool> Function(AiConsentSummary summary);

class AccountAiService {
  AccountAiService({
    AuthService? authService,
    AiConsentPresenter? consentPresenter,
  }) : _auth = authService ?? AuthService(),
       _consentPresenter = consentPresenter ?? _presentConsent;

  static final AccountAiService instance = AccountAiService();
  static const applicationId = 'org.meo.OmniStore';

  final AuthService _auth;
  final AiConsentPresenter _consentPresenter;
  List<AccountAiCredential>? _credentialCache;
  DateTime? _credentialCacheTime;
  String? _credentialCacheUserId;

  bool get isSignedIn => _auth.isAuthenticated;

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

  Future<List<AccountAiCredential>> listCredentials({
    bool forceRefresh = false,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      _credentialCache = null;
      _credentialCacheTime = null;
      _credentialCacheUserId = null;
      throw AccountAiException(
        _localized(
          (value) => value.accountAiSignInRequired,
          'Sign in to Meo Account before using Account AI.',
        ),
      );
    }
    final cached = _credentialCache;
    final cachedAt = _credentialCacheTime;
    if (!forceRefresh &&
        _credentialCacheUserId == userId &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 30)) {
      return cached;
    }

    final data = await _invoke(const {'action': 'list_credentials'});
    final credentials = (data['credentials'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              AccountAiCredential.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id.isNotEmpty && item.enabled)
        .toList(growable: false);
    _credentialCache = credentials;
    _credentialCacheTime = DateTime.now();
    _credentialCacheUserId = userId;
    return credentials;
  }

  Future<String> invokeWithConsent({
    required String credentialId,
    required String purpose,
    required List<String> dataCategories,
    required String systemPrompt,
    required String userPrompt,
    String model = '',
    double temperature = 0.3,
    int maxOutputTokens = 2048,
  }) async {
    final credential = await _credential(credentialId);
    final selectedModel = model.trim().isNotEmpty
        ? model.trim()
        : credential.defaultModel.trim();
    if (selectedModel.isEmpty) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiNoDefaultModel,
          'This AI connection has no default model. Choose a model in Settings first.',
        ),
      );
    }
    final expectedDestination = _providerDestination(credential, selectedModel);

    final request = <String, dynamic>{
      'credentialId': credential.id,
      'clientId': _effectiveClientId(),
      'purpose': purpose.trim(),
      'dataCategories': dataCategories,
      'model': selectedModel,
      'systemPrompt': systemPrompt,
      'userPrompt': userPrompt,
      'temperature': temperature.clamp(0, 2),
      'maxOutputTokens': maxOutputTokens.clamp(1, 4096),
    };
    final prepared = await _invoke({'action': 'prepare_inference', ...request});
    final rawConsent = prepared['consent'];
    if (rawConsent is! Map) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiInvalidConsent,
          'The account AI service did not return a valid consent summary.',
        ),
      );
    }
    final consent = Map<String, dynamic>.from(rawConsent);
    final requestId = consent['requestId'] as String? ?? '';
    final payloadSha256 = consent['payloadSha256'] as String? ?? '';
    final confirmationVersion = consent['confirmationVersion'] as int? ?? 0;
    final consentDestination = consent['destination'] as String? ?? '';
    final expiresAt = DateTime.tryParse(consent['expiresAt'] as String? ?? '');
    final now = DateTime.now().toUtc();
    final consentCategories = (consent['dataCategories'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final requestedCategories = dataCategories.toSet();
    if (requestId.isEmpty ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(requestId) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(payloadSha256) ||
        payloadSha256.length != 64 ||
        confirmationVersion != 1 ||
        expiresAt == null ||
        expiresAt.isBefore(now) ||
        expiresAt.isAfter(now.add(const Duration(minutes: 6))) ||
        consent['model'] != selectedModel ||
        consent['credentialId'] != credential.id ||
        consent['provider'] != credential.provider ||
        consentDestination != expectedDestination ||
        consent['purpose'] != purpose.trim() ||
        consent['clientId'] != request['clientId'] ||
        consentCategories.length != requestedCategories.length ||
        !consentCategories.containsAll(requestedCategories) ||
        consent['promptCharacters'] !=
            systemPrompt.length + userPrompt.length) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiConsentExpired,
          'The AI consent summary is invalid or expired.',
        ),
      );
    }

    final approved = await _consentPresenter(
      AiConsentSummary(
        providerName:
            consent['providerName'] as String? ?? credential.displayName,
        destination: 'Meo Account broker → $consentDestination',
        model: consent['model'] as String? ?? selectedModel,
        purpose: consent['purpose'] as String? ?? purpose,
        dataCategories: consentCategories.toList(growable: false)..sort(),
        promptCharacters:
            consent['promptCharacters'] as int? ??
            systemPrompt.length + userPrompt.length,
        payloadSha256: payloadSha256,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      ),
    );

    if (!approved) {
      try {
        await _invoke({
          'action': 'deny_inference',
          ...request,
          'consent': {
            'approved': false,
            'confirmationVersion': confirmationVersion,
            'requestId': requestId,
            'payloadSha256': payloadSha256,
          },
        });
      } catch (_) {
        // The user decision remains denial even if the metadata audit is down.
      }
      throw AccountAiConsentDenied(
        _localized(
          (value) => value.aiConsentCancelled,
          'You cancelled this AI request.',
        ),
      );
    }

    final result = await _invoke({
      'action': 'invoke',
      ...request,
      'consent': {
        'approved': true,
        'confirmationVersion': confirmationVersion,
        'requestId': requestId,
        'payloadSha256': payloadSha256,
        'confirmedAt': DateTime.now().toUtc().toIso8601String(),
      },
    });
    final text = result['text'];
    if (text is! String || text.trim().isEmpty) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiInvalidResponse,
          'The AI service did not return valid content.',
        ),
      );
    }
    return text.trim();
  }

  Future<Map<String, dynamic>> testConnection({
    required String credentialId,
    String model = '',
  }) async {
    final started = DateTime.now();
    try {
      final response = await invokeWithConsent(
        credentialId: credentialId,
        purpose: _localized(
          (value) => value.accountAiTestPurpose,
          'Test the OmniStore account AI connection',
        ),
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'This is a connection test. Reply with a short OK.',
        userPrompt: 'OmniStore connection test.',
        model: model,
        temperature: 0,
        maxOutputTokens: 32,
      );
      return {
        'status': 'success',
        'response': response,
        'diagnostics': {
          'provider': 'meo_account',
          'credential_id': credentialId,
          'model': model,
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
          'consent': 'approved_once',
          'credential_location': 'account_edge_broker',
        },
      };
    } on AccountAiException catch (error) {
      return {
        'status': 'error',
        'response': error.message,
        'diagnostics': {
          'provider': 'meo_account',
          'credential_id': credentialId,
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
          'consent': error is AccountAiConsentDenied ? 'denied' : 'not_invoked',
        },
      };
    }
  }

  String _providerDestination(AccountAiCredential credential, String model) {
    final endpoint = Uri.tryParse(credential.endpoint);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        !endpoint.hasAuthority ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.query.isNotEmpty ||
        endpoint.fragment.isNotEmpty) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiInvalidDestination,
          'The account AI connection has an invalid destination.',
        ),
      );
    }
    String suffix;
    if (credential.provider == 'openai') {
      suffix = '/responses';
    } else if (credential.provider == 'gemini') {
      suffix = '/models/${Uri.encodeComponent(model)}:generateContent';
    } else {
      suffix = '/chat/completions';
    }
    final base = endpoint.path.replaceFirst(RegExp(r'/$'), '');
    return (base.endsWith(suffix)
            ? endpoint
            : endpoint.replace(path: '$base$suffix'))
        .toString();
  }

  Future<AccountAiCredential> _credential(String id) async {
    final credentials = await listCredentials();
    for (final credential in credentials) {
      if (credential.id == id) return credential;
    }
    throw AccountAiException(
      _localized(
        (value) => value.accountAiConnectionNotFound,
        'The selected AI connection is unavailable. Choose it again in Settings.',
      ),
    );
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (!_auth.isInitialized || !_auth.isAuthenticated) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiSignInRequired,
          'Sign in to Meo Account before using Account AI.',
        ),
      );
    }
    try {
      final response = await _auth.client.functions.invoke(
        'ai-provider-broker',
        body: body,
      );
      if (response.data is! Map) {
        throw AccountAiException(
          _localized(
            (value) => value.accountAiInvalidData,
            'The account AI service returned invalid data.',
          ),
        );
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw AccountAiException(error);
      }
      return data;
    } on AccountAiException {
      rethrow;
    } on FunctionException catch (error) {
      throw AccountAiException(
        error.status >= 500
            ? _localized(
                (value) => value.accountAiUnavailable,
                'The account AI service is temporarily unavailable.',
              )
            : _localized(
                (value) => value.accountAiRequestDenied,
                'The account AI request was denied. Sign in again and try once more.',
              ),
      );
    } catch (_) {
      throw AccountAiException(
        _localized(
          (value) => value.accountAiConnectionFailed,
          'Unable to connect to the account AI service.',
        ),
      );
    }
  }

  String _effectiveClientId() {
    final token = _auth.accessToken;
    if (token == null) return applicationId;
    try {
      final part = token.split('.')[1];
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(part))),
      );
      if (claims is Map && claims['client_id'] is String) {
        final oauthClientId = claims['client_id'] as String;
        if (oauthClientId.isNotEmpty) return oauthClientId;
      }
    } catch (_) {
      // Authentication is still verified by Supabase in the Edge Function.
    }
    return applicationId;
  }

  static Future<bool> _presentConsent(AiConsentSummary summary) async {
    final context = omnistoreNavigatorKey.currentContext;
    if (context == null) return false;
    return showAiConsentDialog(context, summary);
  }
}
