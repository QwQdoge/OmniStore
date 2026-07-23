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
  bool _isBusy = false;
  bool _disposed = false;

  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isBusy => _isBusy;

  /// Murphy-proof: Overridden notifyListeners() with disposal guard to prevent late-lifecycle crashes.
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Murphy-proof: Initializer wrapped in strict try-catch block for isolated execution.
  /// Any dependency or initialization failure is captured and degraded gracefully.
  Future<void> initialize(String supabaseUrl, String supabaseAnonKey) async {
    if (_isInitialized) return;

    try {
      // Extreme Input Validation to block null-equivalent/empty strings and invalid formats.
      final trimmedUrl = supabaseUrl.trim();
      final trimmedKey = supabaseAnonKey.trim();

      if (trimmedUrl.isEmpty || !Uri.parse(trimmedUrl).isAbsolute) {
        throw ArgumentError("AuthService initialize: Invalid or empty Supabase URL provided.");
      }
      if (trimmedKey.isEmpty) {
        throw ArgumentError("AuthService initialize: Empty Supabase Anon Key provided.");
      }

      await Supabase.initialize(
        url: trimmedUrl,
        publishableKey: trimmedKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      _currentUser = Supabase.instance.client.auth.currentUser;

      // Murphy-proof: Register subscription with error catching and proper future disposal binding.
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          try {
            final AuthChangeEvent event = data.event;
            final Session? session = data.session;

            _currentUser = session?.user;
            notifyListeners();

            debugPrint('Auth event: $event, User: ${_currentUser?.id}');
          } catch (e) {
            debugPrint('Murphy-proof Error: Exception inside onAuthStateChange callback: $e');
          }
        },
        onError: (error) {
          debugPrint('Murphy-proof Error: Auth state change stream encountered an error: $error');
        },
      );

      _initDeepLinks();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Murphy-proof Fatal: AuthService initialization failed (isolated and degraded): $e');
      _currentUser = null;
      _isInitialized = false;
    }
  }

  /// Murphy-proof: Deep link stream initialization wrapped in try-catch with safe callbacks.
  void _initDeepLinks() {
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          try {
            debugPrint('Deep link received: $uri');
            if (uri.scheme == 'omnistore' &&
                uri.host == 'auth' &&
                uri.path == '/callback') {
              // The Supabase SDK automatically intercepts PKCE callbacks if configured correctly.
              // However, we can manually ensure the session is extracted if needed.
              // The supabase_flutter plugin intercepts links that match the App/Activity intent.
            }
          } catch (e) {
            debugPrint('Murphy-proof Error: Deep link callback execution failed: $e');
          }
        },
        onError: (err) {
          debugPrint('Deep link stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Murphy-proof Error: Failed to subscribe to deep links stream: $e');
    }
  }

  /// Initiates the login flow.
  /// This will open the default browser to account.meoarch.org
  /// Murphy-proof: Wrapped with mutual exclusion isBusy state locks to prevent duplicate calls.
  Future<void> signIn() async {
    if (_isBusy) {
      debugPrint('AuthService: Already busy, ignoring duplicate signIn trigger.');
      return;
    }
    _isBusy = true;
    notifyListeners();

    try {
      if (!_isInitialized) {
        throw StateError("AuthService is not initialized. Call initialize() first.");
      }
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github, // Configured provider in Supabase linked to account.meoarch.org
        redirectTo: 'omnistore://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Murphy-proof Error: Exception signing in: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Murphy-proof: Wrapped with mutual exclusion isBusy state locks to prevent duplicate calls.
  Future<void> signOut() async {
    if (_isBusy) {
      debugPrint('AuthService: Already busy, ignoring duplicate signOut trigger.');
      return;
    }
    _isBusy = true;
    notifyListeners();

    try {
      if (!_isInitialized) {
        throw StateError("AuthService is not initialized. Call initialize() first.");
      }
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Murphy-proof Error: Exception signing out: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Murphy-proof: Proper release of all registered StreamSubscriptions to prevent memory leaks.
  @override
  void dispose() {
    _disposed = true;
    try {
      _linkSubscription?.cancel();
    } catch (e) {
      debugPrint('Error disposing _linkSubscription: $e');
    }
    try {
      _authSubscription?.cancel();
    } catch (e) {
      debugPrint('Error disposing _authSubscription: $e');
    }
    super.dispose();
  }
}
