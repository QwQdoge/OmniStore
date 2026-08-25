import 'dart:convert';

import 'package:frontend/core/app_navigator.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountAiException implements Exception {
  const AccountAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountAiConsentDenied extends AccountAiException {
  const AccountAiConsentDenied() : super('用户取消了这次 AI 调用。');
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

  Future<List<AccountAiCredential>> listCredentials({
    bool forceRefresh = false,
  }) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) {
      _credentialCache = null;
      _credentialCacheTime = null;
      _credentialCacheUserId = null;
      throw const AccountAiException('请先登录 Meo Account。');
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
      throw const AccountAiException('这个 AI 连接没有默认模型，请先在设置中填写模型。');
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
      throw const AccountAiException('账号服务没有返回有效的授权摘要。');
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
      throw const AccountAiException('AI 授权摘要无效或已经过期。');
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
      throw const AccountAiConsentDenied();
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
      throw const AccountAiException('AI 服务没有返回有效内容。');
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
        purpose: '测试 OmniStore 的 AI 连接',
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
      throw const AccountAiException('账号 AI 连接的目标地址无效。');
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
    throw const AccountAiException('找不到所选 AI 连接，请在设置中重新选择。');
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (!_auth.isInitialized || !_auth.isAuthenticated) {
      throw const AccountAiException('请先登录 Meo Account。');
    }
    try {
      final response = await _auth.client.functions.invoke(
        'ai-provider-broker',
        body: body,
      );
      if (response.data is! Map) {
        throw const AccountAiException('账号 AI 服务返回了无效数据。');
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
        error.status >= 500 ? '账号 AI 服务暂时不可用。' : '账号 AI 请求被拒绝，请重新登录后再试。',
      );
    } catch (_) {
      throw const AccountAiException('无法连接账号 AI 服务。');
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
