import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/features/auth/secure_auth_storage.dart';
import 'package:frontend/features/auth/system_account_service.dart';

/// Linux forwards custom-scheme activations as Dart entrypoint arguments.
/// Only the exact OmniStore account callback is accepted.
Uri? meoAccountCallbackFromArguments(Iterable<String> arguments) {
  for (final argument in arguments) {
    final uri = Uri.tryParse(argument);
    if (uri != null &&
        uri.scheme == 'omnistore' &&
        uri.host == 'auth' &&
        uri.path == '/callback') {
      return uri;
    }
  }
  return null;
}

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
  StreamSubscription<int>? _systemSignOutSubscription;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isBusy = false;
  bool _disposed = false;
  User? _currentUser;
  String? _lastError;
  DateTime? _lastSyncedAt;
  String? _authenticationSource;

  bool get isAuthenticated => _currentUser != null;
  bool get isSignedIn => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String get authenticationSource =>
      _authenticationSource ??
      (_currentUser?.appMetadata['provider'] as String? ?? 'email');
  bool get systemAccountAvailable => SystemAccountService.instance.available;
  bool get systemIdentityMatches =>
      _currentUser != null &&
      SystemAccountService.instance.accountId == _currentUser!.id;

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
  Future<void> initialize({Uri? initialDeepLink}) async {
    if (_disposed) return;
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      if (!MeoArchEnvironment.isConfigured) {
        debugPrint(
          'Warning: Supabase environment variables not configured. Auth will not work.',
        );
      } else {
        final projectRef = Uri.parse(
          MeoArchEnvironment.supabaseUrl,
        ).host.split('.').first;
        final secureStorage = SecureAuthStorage(
          sessionKey: 'sb-$projectRef-auth-token',
        );
        await Supabase.initialize(
          url: MeoArchEnvironment.supabaseUrl,
          publishableKey: MeoArchEnvironment.supabasePublishableKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            localStorage: secureStorage,
            pkceAsyncStorage: secureStorage,
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
                if (session != null) {
                  unawaited(_registerClientSession(session));
                }
                notifyListeners();

                debugPrint('Auth event: $event, User: ${_currentUser?.id}');
              },
              onError: (err) {
                debugPrint('Auth state subscription encountered error: $err');
              },
            );
      }

      await SystemAccountService.instance.initialize();
      _systemSignOutSubscription = SystemAccountService.instance.signOutRequests
          .listen((_) => _handleSystemSignOut());
      final restoredSession = MeoArchEnvironment.isConfigured
          ? Supabase.instance.client.auth.currentSession
          : null;
      if (restoredSession != null) {
        await _registerClientSession(restoredSession);
      }
      await _initDeepLinks(initialDeepLink);
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
  Future<void> _initDeepLinks(Uri? nativeInitialLink) async {
    if (_disposed) return;
    try {
      if (nativeInitialLink != null) {
        await _handleDeepLink(nativeInitialLink);
      }
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null && initialLink != nativeInitialLink) {
        await _handleDeepLink(initialLink);
      }
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          if (_disposed) return;
          await _handleDeepLink(uri);
        },
        onError: (err) {
          debugPrint('Deep link listener error: $err');
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Error initializing deep links listener: $e\n$stackTrace');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (_disposed ||
        uri.scheme != 'omnistore' ||
        uri.host != 'auth' ||
        uri.path != '/callback' ||
        !MeoArchEnvironment.isConfigured) {
      return;
    }
    debugPrint('Meo Account callback received');
    final exchange = await SystemAccountService.instance.exchangeCallback(uri);
    if (exchange == null) {
      _lastError = SystemAccountService.instance.lastError;
      notifyListeners();
      return;
    }
    final refreshToken = exchange.tokens['refresh_token'] as String?;
    final accessToken = exchange.tokens['access_token'] as String?;
    if (refreshToken == null || accessToken == null) {
      _lastError = 'invalid_token_response';
      await SystemAccountService.instance.completeAuthorization(
        requestId: exchange.requestId,
        outcome: 'failed',
      );
      notifyListeners();
      return;
    }
    try {
      final response = await client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
      final session = response.session ?? client.auth.currentSession;
      final user = response.user ?? session?.user;
      final sessionId = _jwtStringClaim(accessToken, 'session_id');
      if (session == null || user == null || sessionId == null) {
        throw const FormatException('Session identity is incomplete');
      }
      final completed = await SystemAccountService.instance
          .completeAuthorization(
            requestId: exchange.requestId,
            outcome: 'approved',
            sessionId: sessionId,
            accountId: user.id,
          );
      _currentUser = user;
      _authenticationSource = 'system';
      _lastSyncedAt = DateTime.now();
      _lastError = completed ? null : 'system_session_registration_failed';
      notifyListeners();
    } catch (error, stackTrace) {
      _lastError = 'authentication_callback_failed';
      await SystemAccountService.instance.completeAuthorization(
        requestId: exchange.requestId,
        outcome: 'failed',
      );
      debugPrint('Meo Account callback failed: $error\n$stackTrace');
      notifyListeners();
    }
  }

  Future<void> signInWithGitHub() async {
    await _signInWithOAuth(OAuthProvider.github);
  }

  Future<void> signInWithGoogle() async {
    await _signInWithOAuth(OAuthProvider.google);
  }

  Future<bool> signInWithSystemAccount() async {
    if (_disposed || _isBusy || !_isInitialized) return false;
    _isBusy = true;
    _lastError = null;
    notifyListeners();
    try {
      final started = await SystemAccountService.instance.beginAuthorization();
      if (!started) {
        _lastError = SystemAccountService.instance.lastError;
      }
      return started;
    } catch (error) {
      _lastError = 'system_account_request_failed';
      debugPrint('System account sign in failed: $error');
      return false;
    } finally {
      if (!_disposed) {
        _isBusy = false;
        notifyListeners();
      }
    }
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
      _authenticationSource = provider.name;
      _lastError = null;
    } catch (e, stackTrace) {
      _lastError = 'oauth_sign_in_failed';
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
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _authenticationSource = 'email';
      _lastError = null;
      return response;
    } catch (e, stackTrace) {
      _lastError = 'password_sign_in_failed';
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
      _lastSyncedAt = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = 'session_refresh_failed';
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
      _authenticationSource = null;
      _lastError = null;
    } catch (e, stackTrace) {
      debugPrint('Error signing out via Supabase: $e\n$stackTrace');
    } finally {
      if (!_disposed) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _handleSystemSignOut() async {
    if (_disposed || !MeoArchEnvironment.isConfigured) return;
    try {
      await client.auth.signOut(scope: SignOutScope.local);
      _currentUser = null;
      _authenticationSource = null;
      _lastError = null;
    } catch (error) {
      // Clear the in-memory projection immediately even if credential storage
      // is temporarily unavailable; a later refresh cannot resurrect it.
      _currentUser = null;
      _authenticationSource = null;
      _lastError = 'local_sign_out_failed';
      debugPrint('Linked system sign out failed locally: $error');
    }
    notifyListeners();
  }

  Future<void> _registerClientSession(Session session) async {
    final sessionId = _jwtStringClaim(session.accessToken, 'session_id');
    if (sessionId == null) return;
    final registered = await SystemAccountService.instance
        .registerClientSession(
          sessionId: sessionId,
          accountId: session.user.id,
        );
    if (registered) {
      _lastSyncedAt = DateTime.now();
      notifyListeners();
    }
  }

  String? _jwtStringClaim(String token, String name) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      final value = decoded is Map<String, dynamic> ? decoded[name] : null;
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
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
    try {
      _systemSignOutSubscription?.cancel();
      _systemSignOutSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling system account subscription: $e');
    }
    super.dispose();
  }
}
