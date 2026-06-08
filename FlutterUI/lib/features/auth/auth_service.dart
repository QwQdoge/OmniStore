import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _isInitialized = false;
  User? _currentUser;

  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;

  Future<void> initialize(String supabaseUrl, String supabaseAnonKey) async {
    if (_isInitialized) return;

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _currentUser = Supabase.instance.client.auth.currentUser;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      _currentUser = session?.user;
      notifyListeners();

      debugPrint('Auth event: $event, User: ${_currentUser?.id}');
    });

    _initDeepLinks();
    _isInitialized = true;
  }

  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      debugPrint('Deep link received: $uri');
      if (uri.scheme == 'omnistore' && uri.host == 'auth' && uri.path == '/callback') {
        // The Supabase SDK automatically intercepts PKCE callbacks if configured correctly.
        // However, we can manually ensure the session is extracted if needed.
        // The supabase_flutter plugin intercepts links that match the App/Activity intent.
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  /// Initiates the login flow.
  /// This will open the default browser to account.meoarch.org
  Future<void> signIn() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github, // Configured provider in Supabase linked to account.meoarch.org
        redirectTo: 'omnistore://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error signing in: $e');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}
