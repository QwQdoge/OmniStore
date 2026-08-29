import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:http/http.dart' as http;

/// The application-owned OAuth session returned after a system-account flow.
/// System account tokens never cross D-Bus.
class SystemAuthExchangeResult {
  const SystemAuthExchangeResult({
    required this.tokens,
    required this.requestId,
    required this.logoutEpoch,
  });

  final Map<String, dynamic> tokens;
  final String requestId;
  final int logoutEpoch;
}

class SystemAccountException implements Exception {
  const SystemAccountException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class _PendingAuthorization {
  const _PendingAuthorization({
    required this.state,
    required this.verifier,
    required this.oauthClientId,
    required this.requestId,
    required this.createdAt,
    required this.logoutEpoch,
  });

  factory _PendingAuthorization.fromJson(Map<String, dynamic> json) {
    return _PendingAuthorization(
      state: json['state'] as String? ?? '',
      verifier: json['verifier'] as String? ?? '',
      oauthClientId: json['oauthClientId'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      logoutEpoch: json['logoutEpoch'] as int? ?? 0,
    );
  }

  final String state;
  final String verifier;
  final String oauthClientId;
  final String requestId;
  final DateTime createdAt;
  final int logoutEpoch;

  Map<String, dynamic> toJson() => {
    'state': state,
    'verifier': verifier,
    'oauthClientId': oauthClientId,
    'requestId': requestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'logoutEpoch': logoutEpoch,
  };
}

/// Talks to the MeoArch per-user account broker. The broker opens the trusted
/// browser flow; OmniStore persists only its own one-shot PKCE request and
/// exchanges the resulting code for its own Supabase session.
class SystemAccountService extends ChangeNotifier {
  SystemAccountService._();
  static final SystemAccountService instance = SystemAccountService._();

  static const _interface = 'org.meo.Accounts1';
  static const _clientId = 'org.meo.OmniStore';
  static const _pendingKey = 'omnistore_system_account_pending_v1';
  static const _logoutEpochKey = 'omnistore_system_account_logout_epoch_v1';
  static const _requestLifetime = Duration(minutes: 5);

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final StreamController<int> _signOutController =
      StreamController<int>.broadcast();
  DBusClient? _bus;
  DBusRemoteObject? _broker;
  StreamSubscription<DBusSignal>? _signOutSubscription;
  StreamSubscription<DBusSignal>? _accountSubscription;
  bool _initialized = false;
  bool _available = false;
  bool _systemSignedIn = false;
  int _logoutEpoch = 0;
  String? _accountName;
  String? _accountId;
  String? _avatarUrl;
  String? _lastError;

  bool get supported => !kIsWeb && Platform.isLinux;
  bool get available => _available;
  bool get systemSignedIn => _systemSignedIn;
  int get logoutEpoch => _logoutEpoch;
  String? get accountName => _accountName;
  String? get accountId => _accountId;
  String? get avatarUrl => _avatarUrl;
  String? get lastError => _lastError;
  Stream<int> get signOutRequests => _signOutController.stream;

  DBusRemoteObject _object() {
    _bus ??= DBusClient.session();
    return _broker ??= DBusRemoteObject(
      _bus!,
      name: _interface,
      path: DBusObjectPath('/org/meo/Accounts1'),
    );
  }

  Future<void> initialize() async {
    if (_initialized || !supported) return;
    _initialized = true;
    final object = _object();
    _signOutSubscription = DBusRemoteObjectSignalStream(
      object: object,
      interface: _interface,
      name: 'clientSignOutRequested',
      signature: DBusSignature('sts'),
    ).listen(_handleSignOutSignal, onError: _handleSignalError);
    _accountSubscription = DBusRemoteObjectSignalStream(
      object: object,
      interface: _interface,
      name: 'accountChanged',
      signature: DBusSignature(''),
    ).listen((_) => refreshStatus(), onError: _handleSignalError);
    await refreshStatus();
    await _discardExpiredPending();
  }

  Future<bool> isAvailable() async {
    await initialize();
    await refreshStatus();
    return _available;
  }

  Future<void> refreshStatus() async {
    if (!supported) return;
    try {
      final result = await _object().callMethod(
        _interface,
        'GetStatus',
        const [],
        replySignature: DBusSignature('a{sv}'),
      );
      final status = result.returnValues.single.asStringVariantDict();
      _available = status['oauthConfigured']?.toNative() == true;
      _systemSignedIn = status['signedIn']?.toNative() == true;
      _accountName = _safeString(status['name']?.toNative());
      _avatarUrl = _safeHttpsUrl(status['avatarUrl']?.toNative());
      _logoutEpoch = status['logoutEpoch']?.toNative() as int? ?? 0;
      if (_systemSignedIn) {
        final identityResult = await _object().callMethod(
          _interface,
          'GetIdentity',
          const [DBusString(_clientId)],
          replySignature: DBusSignature('a{sv}'),
        );
        final identity = identityResult.returnValues.single
            .asStringVariantDict();
        _accountId = _safeString(identity['id']?.toNative());
      } else {
        _accountId = null;
      }
      _lastError = null;
    } catch (error) {
      _available = false;
      _systemSignedIn = false;
      _lastError = 'system_account_unavailable';
      debugPrint('Meo Account broker status failed: $error');
    }
    notifyListeners();
  }

  Future<bool> beginAuthorization() async {
    if (!supported || !MeoArchEnvironment.isConfigured) {
      _lastError = 'system_account_not_configured';
      notifyListeners();
      return false;
    }
    await initialize();
    final random = Random.secure();
    String secret(int length) => base64Url
        .encode(List<int>.generate(length, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final state = secret(32);
    final verifier = secret(48);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    try {
      final result = await _object().callMethod(
        _interface,
        'RequestAuthentication',
        [
          const DBusString(_clientId),
          const DBusString('authorize_client'),
          DBusDict.stringVariant({
            'state': DBusString(state),
            'codeChallenge': DBusString(challenge),
          }),
        ],
        replySignature: DBusSignature('s'),
      );
      final requestId = result.returnValues.single.asString();
      if (requestId.isEmpty) {
        throw const SystemAccountException(
          'request_failed',
          'The system account request could not be created.',
        );
      }
      final requestResult = await _object().callMethod(
        _interface,
        'GetRequest',
        [DBusString(requestId)],
        replySignature: DBusSignature('a{sv}'),
      );
      final request = requestResult.returnValues.single.asStringVariantDict();
      final oauthClientId = _safeString(request['oauthClientId']?.toNative());
      if (oauthClientId == null) {
        throw const SystemAccountException(
          'invalid_broker_response',
          'The system account broker returned an incomplete request.',
        );
      }
      await _writePending(
        _PendingAuthorization(
          state: state,
          verifier: verifier,
          oauthClientId: oauthClientId,
          requestId: requestId,
          createdAt: DateTime.now().toUtc(),
          logoutEpoch: _logoutEpoch,
        ),
      );
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = error is SystemAccountException
          ? error.code
          : 'system_account_request_failed';
      debugPrint('Meo Account broker authorization failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<SystemAuthExchangeResult?> exchangeCallback(Uri uri) async {
    if (uri.scheme != 'omnistore' ||
        uri.host != 'auth' ||
        uri.path != '/callback') {
      return null;
    }
    final pending = await _readPending();
    if (pending == null) {
      _lastError = 'missing_authentication_request';
      notifyListeners();
      return null;
    }
    if (DateTime.now().toUtc().difference(pending.createdAt) >
        _requestLifetime) {
      await _clearPending();
      _lastError = 'authentication_request_expired';
      notifyListeners();
      return null;
    }
    final callbackState = uri.queryParameters['state'];
    if (callbackState == null ||
        !_constantTimeEquals(callbackState, pending.state)) {
      _lastError = 'invalid_authentication_state';
      notifyListeners();
      return null;
    }

    // Consume before code exchange so duplicate/replayed callbacks fail closed.
    await _clearPending();
    final oauthError = uri.queryParameters['error'];
    if (oauthError != null) {
      final outcome = oauthError == 'access_denied' ? 'denied' : 'failed';
      await completeAuthorization(
        requestId: pending.requestId,
        outcome: outcome,
      );
      _lastError = outcome == 'denied'
          ? 'authentication_denied'
          : 'authentication_failed';
      notifyListeners();
      return null;
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      await completeAuthorization(
        requestId: pending.requestId,
        outcome: 'failed',
      );
      _lastError = 'missing_authorization_code';
      notifyListeners();
      return null;
    }
    try {
      final response = await http
          .post(
            Uri.parse('${MeoArchEnvironment.supabaseUrl}/auth/v1/oauth/token'),
            headers: {
              'apikey': MeoArchEnvironment.supabasePublishableKey,
              'content-type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': MeoArchEnvironment.authCallback,
              'client_id': pending.oauthClientId,
              'code_verifier': pending.verifier,
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = 'token_exchange_failed';
        await completeAuthorization(
          requestId: pending.requestId,
          outcome: 'failed',
        );
        notifyListeners();
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('OAuth token response is not an object');
      }
      _lastError = null;
      notifyListeners();
      return SystemAuthExchangeResult(
        tokens: decoded,
        requestId: pending.requestId,
        logoutEpoch: pending.logoutEpoch,
      );
    } catch (error) {
      _lastError = 'token_exchange_failed';
      debugPrint('Meo Account code exchange failed: $error');
      await completeAuthorization(
        requestId: pending.requestId,
        outcome: 'failed',
      );
      notifyListeners();
      return null;
    }
  }

  Future<bool> completeAuthorization({
    required String requestId,
    required String outcome,
    String sessionId = '',
    String accountId = '',
  }) async {
    if (!supported || requestId.isEmpty) return false;
    try {
      final response = await _object()
          .callMethod(_interface, 'CompleteClientAuthorization', [
            DBusString(requestId),
            DBusString(outcome),
            DBusString(sessionId),
            DBusString(accountId),
          ], replySignature: DBusSignature('b'));
      return response.returnValues.single.asBoolean();
    } catch (error) {
      debugPrint('Completing Meo Account request failed: $error');
      return false;
    }
  }

  Future<bool> registerClientSession({
    required String sessionId,
    required String accountId,
    int? logoutEpoch,
  }) async {
    if (!supported || sessionId.isEmpty || accountId.isEmpty) return false;
    try {
      await initialize();
      final epoch = logoutEpoch ?? _logoutEpoch;
      final response = await _object()
          .callMethod(_interface, 'RegisterClientSession', [
            const DBusString(_clientId),
            DBusString(sessionId),
            DBusString(accountId),
            DBusUint64(epoch),
          ], replySignature: DBusSignature('b'));
      final registered = response.returnValues.single.asBoolean();
      if (registered) {
        _accountId = accountId;
        await _storage.write(key: _logoutEpochKey, value: '$epoch');
        notifyListeners();
      }
      return registered;
    } catch (error) {
      debugPrint('Meo Account session registration failed: $error');
      return false;
    }
  }

  Future<void> _handleSignOutSignal(DBusSignal signal) async {
    if (signal.values.length != 3 || signal.values[0].asString() != _clientId) {
      return;
    }
    final epoch = signal.values[1].asUint64();
    final reason = signal.values[2].asString();
    final stored =
        int.tryParse(await _storage.read(key: _logoutEpochKey) ?? '') ?? 0;
    if (reason != 'client_access_revoked' && epoch <= stored) return;
    if (epoch > stored) {
      _logoutEpoch = epoch;
      await _storage.write(key: _logoutEpochKey, value: '$epoch');
    }
    _signOutController.add(epoch);
    notifyListeners();
  }

  void _handleSignalError(Object error, StackTrace stackTrace) {
    debugPrint('Meo Account signal error: $error');
  }

  Future<_PendingAuthorization?> _readPending() async {
    final value = await _storage.read(key: _pendingKey);
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      final pending = _PendingAuthorization.fromJson(decoded);
      if (pending.state.isEmpty ||
          pending.verifier.isEmpty ||
          pending.oauthClientId.isEmpty ||
          pending.requestId.isEmpty) {
        return null;
      }
      return pending;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePending(_PendingAuthorization pending) =>
      _storage.write(key: _pendingKey, value: jsonEncode(pending.toJson()));

  Future<void> _clearPending() => _storage.delete(key: _pendingKey);

  Future<void> _discardExpiredPending() async {
    final pending = await _readPending();
    if (pending != null &&
        DateTime.now().toUtc().difference(pending.createdAt) >
            _requestLifetime) {
      await _clearPending();
    }
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index++) {
      difference |= left[index % left.length] ^ right[index % right.length];
    }
    return difference == 0;
  }

  String? _safeString(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 512) {
      return null;
    }
    return value.trim();
  }

  String? _safeHttpsUrl(Object? value) {
    final text = _safeString(value);
    final uri = text == null ? null : Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' ? uri.toString() : null;
  }

  @override
  void dispose() {
    _signOutSubscription?.cancel();
    _accountSubscription?.cancel();
    _signOutController.close();
    _bus?.close();
    super.dispose();
  }
}
