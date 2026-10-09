import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/secure_auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sessionKey = 'sb-test-auth-token';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      sessionKey: 'plaintext-session-that-must-be-removed',
      'supabase.auth.token-code-verifier': 'plaintext-verifier',
    });
  });

  test('stores session and PKCE material only in secure storage', () async {
    final storage = SecureAuthStorage(sessionKey: sessionKey);
    await storage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(sessionKey), isFalse);
    expect(
      preferences.containsKey('supabase.auth.token-code-verifier'),
      isFalse,
    );

    await storage.persistSession('secure-session');
    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), 'secure-session');

    await storage.setItem(key: 'pkce', value: 'secure-verifier');
    expect(await storage.getItem(key: 'pkce'), 'secure-verifier');

    await storage.removeItem(key: 'pkce');
    await storage.removePersistedSession();
    expect(await storage.getItem(key: 'pkce'), isNull);
    expect(await storage.hasAccessToken(), isFalse);
  });
}
