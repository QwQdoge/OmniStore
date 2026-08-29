import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/auth/presentation/widgets/sign_in_form.dart';
import 'package:frontend/services/sync_service.dart';
import 'package:frontend/features/auth/system_account_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool? _lastSyncSucceeded;
  bool _systemAccountAvailable = false;

  @override
  void initState() {
    super.initState();
    SystemAccountService.instance.addListener(_handleSystemAccountChanged);
    SystemAccountService.instance.isAvailable().then((available) {
      if (mounted) setState(() => _systemAccountAvailable = available);
    });
  }

  void _handleSystemAccountChanged() {
    if (!mounted) return;
    setState(() {
      _systemAccountAvailable = SystemAccountService.instance.available;
    });
  }

  @override
  void dispose() {
    SystemAccountService.instance.removeListener(_handleSystemAccountChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSystemSignIn() async {
    final started = await AuthService().signInWithSystemAccount();
    if (!started && mounted) {
      Toast.show(context, AppLocalizations.of(context)!.failed);
    }
  }

  Future<void> _handleEmailSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Toast.show(context, l10n.enterEmailAndPassword);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        Toast.show(context, l10n.signInFailed(e.message));
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, l10n.signInError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAccountUrl() async {
    final uri = Uri.parse(MeoArchEnvironment.accountUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final succeeded = await SyncService().syncInstalledApps();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncSucceeded = succeeded;
    });
    final l10n = AppLocalizations.of(context)!;
    Toast.show(context, succeeded ? l10n.syncStatusSubtitle : l10n.failed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final authService = AuthService();
        final isAuthenticated = authService.isAuthenticated;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.meoarchAccount),
            centerTitle: true,
            actions: [
              if (isAuthenticated)
                IconButton(
                  tooltip: l10n.signOut,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => authService.signOut(),
                ),
            ],
          ),
          body: SmoothSizeSwitcher(
            child: isAuthenticated
                ? _buildAccountProfile(authService.currentUser!)
                : SignInForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isObscure: _isObscure,
                    isLoading: _isLoading,
                    onToggleObscure: () =>
                        setState(() => _isObscure = !_isObscure),
                    onSignIn: _handleEmailSignIn,
                    onCreateAccount: _openAccountUrl,
                    onSignInWithGoogle: () => AuthService().signInWithGoogle(),
                    onSignInWithGitHub: () => AuthService().signInWithGitHub(),
                    onSignInWithSystemAccount: _systemAccountAvailable
                        ? _handleSystemSignIn
                        : null,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAccountProfile(User user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final displayName =
        user.userMetadata?['full_name'] as String? ??
        user.email ??
        l10n.defaultUser;
    final rawAvatarUrl = user.userMetadata?['avatar_url'] as String?;
    final avatarUri = rawAvatarUrl == null ? null : Uri.tryParse(rawAvatarUrl);
    final avatarUrl = avatarUri?.scheme == 'https'
        ? avatarUri.toString()
        : null;
    final authService = AuthService();
    final source = authService.authenticationSource == 'system'
        ? l10n.meoarchAccount
        : authService.authenticationSource == 'google'
        ? 'Google'
        : authService.authenticationSource == 'github'
        ? 'GitHub'
        : l10n.email;

    return Center(
      key: const ValueKey('profile'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            if (user.email != null) ...[
              const SizedBox(height: 6),
              Text(
                user.email!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (authService.lastError != null) ...[
              Card(
                color: colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                  title: Text(l10n.failed),
                  subtitle: Text(authService.lastError!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.badge_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(l10n.signIn),
                    subtitle: Text(source),
                    trailing: authService.systemAccountAvailable
                        ? Icon(
                            authService.systemIdentityMatches
                                ? Icons.verified_user_rounded
                                : Icons.person_search_rounded,
                            color: authService.systemIdentityMatches
                                ? colorScheme.primary
                                : colorScheme.tertiary,
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.sync_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      l10n.syncStatus,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      authService.lastSyncedAt == null
                          ? l10n.syncStatusSubtitle
                          : authService.lastSyncedAt!.toLocal().toString(),
                    ),
                    trailing: _isSyncing
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(
                            _lastSyncSucceeded == false
                                ? Icons.error_rounded
                                : _lastSyncSucceeded == true
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_rounded,
                            color: _lastSyncSucceeded == false
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                    onTap: _isSyncing ? null : _syncNow,
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.manage_accounts_rounded,
                      color: colorScheme.secondary,
                    ),
                    title: Text(
                      l10n.manageAccount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(l10n.manageAccountSubtitle),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                    onTap: _openAccountUrl,
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.logout_rounded,
                      color: colorScheme.error,
                    ),
                    title: Text(
                      l10n.signOut,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.error,
                      ),
                    ),
                    onTap: () => AuthService().signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
