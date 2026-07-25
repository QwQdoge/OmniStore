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
  StreamSubscription<AuthState>? _authSubscription;

  bool _isInitialized = false;
  User? _currentUser;
  bool _isBusy = false; // State-mutex flag to prevent duplicate execution of sensitive methods (login/logout)
  bool _disposed = false; // Lifecycle flag to prevent notifyListeners() memory leaks and crashes after dispose

  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isBusy => _isBusy;

  Future<void> initialize(String supabaseUrl, String supabaseAnonKey) async {
    if (_isInitialized) return;

    // Fail-safe: Wrap external third-party initialization to prevent initialization avalanche failures
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      _currentUser = Supabase.instance.client.auth.currentUser;

      // Fail-safe: Safely capture subscription to cancel upon dispose and protect notifyListeners
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (_disposed) return;
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          _currentUser = session?.user;
          _safeNotifyListeners();

          debugPrint('Auth event: $event, User: ${_currentUser?.id}');
        },
        onError: (err) {
          debugPrint('Auth subscription error: $err');
        },
      );

      _initDeepLinks();
      _isInitialized = true;
    } catch (e) {
      // Graceful degradation: log the error and allow app features to work silently without crashing
      debugPrint('Murphy-proof Error: Supabase initialization failed: $e');
      _isInitialized = false;
    }
  }

  void _initDeepLinks() {
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          debugPrint('Deep link received: $uri');
          if (uri.scheme == 'omnistore' &&
              uri.host == 'auth' &&
              uri.path == '/callback') {
            // PKCE callback matches standard supabase_flutter filters.
          }
        },
        onError: (err) {
          debugPrint('Deep link error: $err');
        },
      );
    } catch (e) {
      // Graceful degradation: AppLinks failures are captured and do not propagate to cause startup crash
      debugPrint('Murphy-proof Error: AppLinks initialization failed: $e');
    }
  }

  /// Initiates the login flow.
  /// This will open the default browser to account.meoarch.org
  Future<void> signIn() async {
    if (_disposed) return;
    if (_isBusy) {
      debugPrint('Murphy-proof Warning: signIn already in progress. Ignoring duplicate request.');
      return;
    }

    _isBusy = true;
    _safeNotifyListeners();

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github, // Configured provider in Supabase linked to account.meoarch.org
        redirectTo: 'omnistore://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error signing in: $e');
    } finally {
      _isBusy = false;
      _safeNotifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_disposed) return;
    if (_isBusy) {
      debugPrint('Murphy-proof Warning: signOut already in progress. Ignoring duplicate request.');
      return;
    }

    _isBusy = true;
    _safeNotifyListeners();

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      _isBusy = false;
      _safeNotifyListeners();
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    _linkSubscription = null;
    _authSubscription = null;
    super.dispose();
  }
}
