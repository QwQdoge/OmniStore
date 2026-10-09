import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists Supabase sessions and PKCE verifiers in the platform credential
/// store. On Linux this is the Secret Service API provided by KWallet.
///
/// This deliberately fails closed if the credential store is unavailable. We
/// never fall back to plaintext SharedPreferences for refresh tokens.
class SecureAuthStorage extends LocalStorage implements GotrueAsyncStorage {
  SecureAuthStorage({FlutterSecureStorage? storage, required this.sessionKey})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pkcePrefix = 'omnistore_supabase_pkce_';
  static const _legacyPkceKey = 'supabase.auth.token-code-verifier';

  final FlutterSecureStorage _storage;
  final String sessionKey;

  @override
  Future<void> initialize() async {
    // Remove any session or verifier written by Supabase's historical default
    // SharedPreferences storage. A refresh token must not remain in plaintext.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(sessionKey);
    await preferences.remove(_legacyPkceKey);

    // Probe the credential store so initialization fails before auth starts if
    // KWallet/Secret Service is unavailable or locked.
    await _storage.containsKey(key: sessionKey);
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: sessionKey);

  String _pkceKey(String key) => '$_pkcePrefix$key';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _pkceKey(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _pkceKey(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _pkceKey(key));
}
