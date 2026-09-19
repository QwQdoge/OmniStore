import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/app_navigator.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SystemAiException implements Exception {
  const SystemAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SystemAiConsentDenied extends SystemAiException {
  const SystemAiConsentDenied([
    super.message = 'You cancelled this AI request.',
  ]);
}

class SystemAiConnection {
  const SystemAiConnection({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.endpoint,
    required this.defaultModel,
    required this.credentialStored,
  });

  final String id;
  final String provider;
  final String displayName;
  final String endpoint;
  final String defaultModel;
  final bool credentialStored;

  factory SystemAiConnection.fromNative(Map<Object?, Object?> value) {
    return SystemAiConnection(
      id: '${value['id'] ?? ''}',
      provider: '${value['provider'] ?? ''}',
      displayName: '${value['displayName'] ?? 'AI'}',
      endpoint: '${value['endpoint'] ?? ''}',
      defaultModel: '${value['defaultModel'] ?? ''}',
      credentialStored: value['credentialStored'] == true,
    );
  }
}

typedef SystemAiConsentPresenter = Future<bool> Function(
  AiConsentSummary summary,
);
typedef SystemAiOperationRunner = Future<Map<Object?, Object?>> Function(
  String action,
  Map<String, DBusValue> arguments,
);

/// Client for the Account-owned per-user AI broker.
///
/// The broker reads KWallet and performs the network request. OmniStore sees
/// connection metadata, a payload-bound consent summary, and the final text;
/// it never receives the stored provider credential.
class SystemAiService {
  SystemAiService({
    DBusClient? bus,
    SystemAiConsentPresenter? consentPresenter,
    SystemAiOperationRunner? operationRunner,
  }) : _bus = bus,
       _consentPresenter = consentPresenter ?? _presentConsent,
       _operationRunner = operationRunner;

  static final SystemAiService instance = SystemAiService();
  static const _interface = 'org.meo.Accounts1';
  static const _clientId = 'org.meo.OmniStore';

  final DBusClient? _bus;
  final SystemAiConsentPresenter _consentPresenter;
  final SystemAiOperationRunner? _operationRunner;
  DBusClient? _ownedBus;
  DBusRemoteObject? _broker;

  bool get supported => !kIsWeb && Platform.isLinux;

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

  DBusRemoteObject _object() {
    final bus = _bus ?? (_ownedBus ??= DBusClient.session());
    return _broker ??= DBusRemoteObject(
      bus,
      name: _interface,
      path: DBusObjectPath('/org/meo/Accounts1'),
    );
  }

  Future<List<SystemAiConnection>> listConnections() async {
    if (!supported) return const [];
    try {
      final response = await _object().callMethod(
        _interface,
        'ListAvailableLocalAiConnections',
        const [DBusString(_clientId)],
        replySignature: DBusSignature('av'),
      );
      final native = response.returnValues.single.toNative();
      if (native is! List) throw const FormatException();
      return native
          .whereType<Map>()
          .map(
            (item) =>
                SystemAiConnection.fromNative(Map<Object?, Object?>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiLoadFailed,
          'Unable to read system AI connections. Check Accounts & Security in Meo Settings.',
        ),
      );
    }
  }

  Future<bool> openSettings() async {
    if (!supported) return false;
    try {
      final response = await _object().callMethod(
        _interface,
        'OpenSettings',
        const [],
        replySignature: DBusSignature('b'),
      );
      return response.returnValues.single.asBoolean();
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> discoverModels(String connectionId) async {
    final result = await _runOperation('discover_models', {
      'connectionId': DBusString(connectionId),
    });
    final models = result['models'];
    if (models is! List) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiInvalidCatalog,
          'The system AI service returned an invalid model catalog.',
        ),
      );
    }
    return models.whereType<String>().toList(growable: false);
  }

  Future<String> invokeWithConsent({
    required String connectionId,
    required String model,
    required String purpose,
    required List<String> dataCategories,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
    int maxOutputTokens = 2048,
  }) async {
    final arguments = <String, DBusValue>{
      'connectionId': DBusString(connectionId),
      'model': DBusString(model),
      'purpose': DBusString(purpose),
      'dataCategories': DBusArray.string(dataCategories),
      'systemPrompt': DBusString(systemPrompt),
      'userPrompt': DBusString(userPrompt),
      'temperature': DBusDouble(temperature),
      'maxOutputTokens': DBusInt32(maxOutputTokens),
    };
    final prepared = await _runOperation('prepare_inference', arguments);
    final rawConsent = prepared['consent'];
    if (rawConsent is! Map) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiInvalidConsent,
          'The system AI service did not return a valid consent summary.',
        ),
      );
    }
    final consent = Map<Object?, Object?>.from(rawConsent);
    final requestId = '${consent['requestId'] ?? ''}';
    final hash = '${consent['payloadSha256'] ?? ''}';
    final expiresAt = DateTime.tryParse('${consent['expiresAt'] ?? ''}');
    final categories = (consent['dataCategories'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (requestId.isEmpty ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(requestId) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
        consent['confirmationVersion'] != 1 ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now().toUtc()) ||
        consent['connectionId'] != connectionId ||
        consent['model'] != model ||
        consent['purpose'] != purpose ||
        consent['clientId'] != _clientId ||
        consent['promptCharacters'] !=
            systemPrompt.length + userPrompt.length ||
        categories.toSet().length != dataCategories.toSet().length ||
        !categories.toSet().containsAll(dataCategories)) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiConsentExpired,
          'The system AI consent summary is invalid or expired.',
        ),
      );
    }

    final approved = await _consentPresenter(
      AiConsentSummary(
        providerName: '${consent['providerName'] ?? 'AI'}',
        destination: 'Meo Account broker → ${consent['destination'] ?? ''}',
        model: model,
        purpose: purpose,
        dataCategories: categories,
        promptCharacters: systemPrompt.length + userPrompt.length,
        payloadSha256: hash,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      ),
    );
    final consentValue = DBusDict.stringVariant({
      'requestId': DBusString(requestId),
      'payloadSha256': DBusString(hash),
      'confirmationVersion': const DBusInt32(1),
      'approved': DBusBoolean(approved),
    });
    if (!approved) {
      try {
        await _runOperation('deny_inference', {
          ...arguments,
          'consent': consentValue,
        });
      } catch (_) {
        // A local denial remains a denial if audit cleanup is unavailable.
      }
      throw SystemAiConsentDenied(
        _localized(
          (value) => value.aiConsentCancelled,
          'You cancelled this AI request.',
        ),
      );
    }

    final result = await _runOperation('invoke', {
      ...arguments,
      'consent': consentValue,
    });
    final text = result['text'];
    if (text is! String || text.trim().isEmpty) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiInvalidResponse,
          'The system AI service did not return valid text.',
        ),
      );
    }
    return text.trim();
  }

  Future<Map<Object?, Object?>> _operation(
    String action,
    Map<String, DBusValue> arguments,
  ) async {
    if (!supported) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiUnsupported,
          'System AI is not supported on this platform.',
        ),
      );
    }
    try {
      final started = await _object()
          .callMethod(_interface, 'StartLocalAiOperation', [
            const DBusString(_clientId),
            DBusString(action),
            DBusDict.stringVariant(arguments),
          ], replySignature: DBusSignature('s'));
      final requestId = started.returnValues.single.asString();
      if (requestId.isEmpty) throw const FormatException();
      for (var attempt = 0; attempt < 240; attempt++) {
        final response = await _object().callMethod(_interface, 'GetRequest', [
          DBusString(requestId),
        ], replySignature: DBusSignature('a{sv}'));
        final native = response.returnValues.single.toNative();
        if (native is! Map) throw const FormatException();
        final request = Map<Object?, Object?>.from(native);
        final state = '${request['state'] ?? ''}';
        if (state == 'completed') return request;
        if (state == 'denied') throw const SystemAiConsentDenied();
        if (state == 'failed' || state == 'expired') {
          final error = '${request['error'] ?? ''}'.trim();
          throw SystemAiException(
            error.isEmpty
                ? _localized(
                    (value) => value.systemAiOperationFailed,
                    'The system AI operation failed.',
                  )
                : error,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw SystemAiException(
        _localized(
          (value) => value.systemAiTimeout,
          'The system AI operation timed out.',
        ),
      );
    } on SystemAiException {
      rethrow;
    } catch (_) {
      throw SystemAiException(
        _localized(
          (value) => value.systemAiUnavailable,
          'Unable to connect to the Meo Account system AI service.',
        ),
      );
    }
  }

  Future<Map<Object?, Object?>> _runOperation(
    String action,
    Map<String, DBusValue> arguments,
  ) {
    return _operationRunner?.call(action, arguments) ??
        _operation(action, arguments);
  }

  Future<Map<String, dynamic>> testConnection({
    required String connectionId,
    required String model,
  }) async {
    final started = DateTime.now();
    try {
      final response = await invokeWithConsent(
        connectionId: connectionId,
        model: model,
        purpose: _localized(
          (value) => value.systemAiTestPurpose,
          'Test the OmniStore system AI connection',
        ),
        dataCategories: const ['synthetic_test'],
        systemPrompt: 'Reply with exactly OK.',
        userPrompt: 'OK?',
        temperature: 0,
        maxOutputTokens: 8,
      );
      return {
        'status': 'success',
        'response': response,
        'diagnostics': {
          'provider': 'system_ai_broker',
          'credential_location': 'meo_account_kwallet',
          'consent': 'approved_once',
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
        },
      };
    } on SystemAiException catch (error) {
      return {
        'status': 'error',
        'response': error.message,
        'diagnostics': {
          'provider': 'system_ai_broker',
          'consent': error is SystemAiConsentDenied ? 'denied' : 'not_invoked',
          'latency_ms': DateTime.now().difference(started).inMilliseconds,
        },
      };
    }
  }

  static Future<bool> _presentConsent(AiConsentSummary summary) async {
    final context = omnistoreNavigatorKey.currentContext;
    if (context == null) return false;
    return showAiConsentDialog(context, summary);
  }
}
