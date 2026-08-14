import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:frontend/core/config/meoarch_environment.dart';

/// [AuthService] manages the integration with Supabase for user authentication
/// and handles deep links. It is designed defensively to guarantee zero memory leaks,
/// prevent multiple concurrent initialization/login/logout requests, and guard against
/// unexpected failures using robust try-catch blocks and mutex flags.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isBusy = false;
  bool _disposed = false;
  User? _currentUser;

  bool get isAuthenticated => _currentUser != null;
  bool get isSignedIn => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;

  SupabaseClient get client => Supabase.instance.client;
  Session? get currentSession =>
      _isInitialized ? client.auth.currentSession : null;
  String? get accessToken => currentSession?.accessToken;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  @override
  void notifyListeners() {
    // Guards against notifying listeners after the controller has been disposed to avoid memory/lifecycle crashes.
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  /// Defensive initialization of Supabase and deep link listeners.
  /// Prevents duplicate execution and ensures any failures do not crash the main thread.
  Future<void> initialize() async {
    if (_disposed) return;
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      if (!MeoArchEnvironment.isConfigured) {
        debugPrint(
          'Warning: Supabase environment variables not configured. Auth will not work.',
        );
      } else {
        await Supabase.initialize(
          url: MeoArchEnvironment.supabaseUrl,
          publishableKey: MeoArchEnvironment.supabasePublishableKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );

        _currentUser = Supabase.instance.client.auth.currentUser;

        _authSubscription = Supabase.instance.client.auth.onAuthStateChange
            .listen(
              (data) {
                if (_disposed) return;
                final AuthChangeEvent event = data.event;
                final Session? session = data.session;

                _currentUser = session?.user;
                notifyListeners();

                debugPrint('Auth event: $event, User: ${_currentUser?.id}');
              },
              onError: (err) {
                debugPrint('Auth state subscription encountered error: $err');
              },
            );
      }

      _initDeepLinks();
      _isInitialized = true;
    } catch (e, stackTrace) {
      // Gracefully catches any initialization issues to prevent "initialization avalanche" failures.
      debugPrint('Error initializing Supabase: $e\n$stackTrace');
    } finally {
      if (!_disposed) {
        _isInitializing = false;
      }
    }
  }

  /// Safe deep links configuration with exception safety.
  void _initDeepLinks() {
    if (_disposed) return;
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          if (_disposed) return;
          debugPrint('Deep link received: $uri');
          if (uri.scheme == 'omnistore' &&
              uri.host == 'auth' &&
              uri.path == '/callback') {
            // Note: The supabase_flutter plugin generally intercepts link authentication automatically,
            // but we listen here for explicit state observation and recovery.
          }
        },
        onError: (err) {
          debugPrint('Deep link listener error: $err');
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Error initializing deep links listener: $e\n$stackTrace');
    }
  }

  Future<void> signInWithGitHub() async {
    await _signInWithOAuth(OAuthProvider.github);
  }

  Future<void> signInWithGoogle() async {
    await _signInWithOAuth(OAuthProvider.google);
  }

  /// Initiates the OAuth sign-in process with a state lock flag.
  /// This will open the default browser to complete authentication.
  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    if (_disposed) return;
    if (!_isInitialized || !MeoArchEnvironment.isConfigured) {
      debugPrint(
        'AuthService._signInWithOAuth: Supabase is not initialized. Operation ignored.',
      );
      return;
    }
    if (_isBusy) return;

    _isBusy = true;
    notifyListeners();
    try {
      await client.auth.signInWithOAuth(
        provider,
        redirectTo: MeoArchEnvironment.authCallback,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e, stackTrace) {
      debugPrint('Error signing in via $provider: $e\n$stackTrace');
    } finally {
      if (!_disposed) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<AuthResponse?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (_disposed) return null;
    if (!_isInitialized || !MeoArchEnvironment.isConfigured) {
      debugPrint(
        'AuthService.signInWithPassword: Supabase is not initialized. Operation ignored.',
      );
      return null;
    }
    if (_isBusy) return null;

    _isBusy = true;
    notifyListeners();
    try {
      return await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e, stackTrace) {
      debugPrint('Error signing in via password: $e\n$stackTrace');
      rethrow;
    } finally {
      if (!_disposed) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshSession() async {
    if (_disposed) return;
    if (!_isInitialized || !MeoArchEnvironment.isConfigured) {
      return;
    }
    try {
      await client.auth.refreshSession();
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
  }

  /// Standard signOut flow with safety guards.
  Future<void> signOut() async {
    if (_disposed) return;
    if (!_isInitialized || !MeoArchEnvironment.isConfigured) {
      debugPrint(
        'AuthService.signOut: Supabase is not initialized. Operation ignored.',
      );
      return;
    }
    if (_isBusy) return;

    _isBusy = true;
    notifyListeners();
    try {
      await client.auth.signOut();
    } catch (e, stackTrace) {
      debugPrint('Error signing out via Supabase: $e\n$stackTrace');
    } finally {
      if (!_disposed) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _authSubscription?.cancel();
      _authSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling auth subscription: $e');
    }
    try {
      _linkSubscription?.cancel();
      _linkSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling link subscription: $e');
    }
    super.dispose();
  }
}
