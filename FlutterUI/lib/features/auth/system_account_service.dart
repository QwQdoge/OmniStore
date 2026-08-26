import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:http/http.dart' as http;

/// Talks to the MeoArch per-user account broker. No system access or refresh
/// token crosses D-Bus: OmniStore receives and exchanges its own OAuth code.
class SystemAccountService {
  SystemAccountService._();
  static final SystemAccountService instance = SystemAccountService._();

  static const _interface = 'org.meo.Accounts1';
  static const _clientId = 'org.meo.OmniStore';
  DBusClient? _bus;
  DBusRemoteObject? _broker;
  String? _state;
  String? _verifier;
  String? _oauthClientId;

  bool get supported => !kIsWeb && Platform.isLinux;

  DBusRemoteObject _object() {
    _bus ??= DBusClient.session();
    return _broker ??= DBusRemoteObject(
      _bus!,
      name: _interface,
      path: DBusObjectPath('/org/meo/Accounts1'),
    );
  }

  Future<bool> isAvailable() async {
    if (!supported) return false;
    try {
      final result = await _object().callMethod(
        _interface,
        'GetStatus',
        const [],
        replySignature: DBusSignature('a{sv}'),
      );
      if (result.returnValues.isEmpty) return false;
      final status = result.returnValues.single.asStringVariantDict();
      return status['oauthConfigured']?.toNative() == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> beginAuthorization() async {
    if (!supported || !MeoArchEnvironment.isConfigured) return false;
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
      final result = await _object()
          .callMethod(_interface, 'BeginAuthorization', [
            const DBusString(_clientId),
            DBusString(state),
            DBusString(challenge),
            const DBusString('S256'),
          ], replySignature: DBusSignature('s'));
      final authorizationUrl = result.returnValues.single.asString();
      final oauthClientId = Uri.parse(
        authorizationUrl,
      ).queryParameters['client_id'];
      if (authorizationUrl.isEmpty || oauthClientId == null) return false;
      _state = state;
      _verifier = verifier;
      _oauthClientId = oauthClientId;
      return true;
    } catch (error) {
      debugPrint('Meo Account broker authorization failed: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>?> exchangeCallback(Uri uri) async {
    final expectedState = _state;
    final verifier = _verifier;
    final oauthClientId = _oauthClientId;
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (expectedState == null ||
        verifier == null ||
        oauthClientId == null ||
        code == null ||
        state == null ||
        !_constantTimeEquals(state, expectedState)) {
      _clearPending();
      return null;
    }
    _clearPending();
    final response = await http.post(
      Uri.parse('${MeoArchEnvironment.supabaseUrl}/auth/v1/oauth/token'),
      headers: {
        'apikey': MeoArchEnvironment.supabasePublishableKey,
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': MeoArchEnvironment.authCallback,
        'client_id': oauthClientId,
        'code_verifier': verifier,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Meo Account code exchange failed (${response.statusCode})');
      return null;
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
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

  void _clearPending() {
    _state = null;
    _verifier = null;
    _oauthClientId = null;
  }
}
