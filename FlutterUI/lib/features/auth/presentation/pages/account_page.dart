import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/auth/presentation/widgets/sign_in_form.dart';
import 'package:frontend/features/auth/presentation/widgets/account_profile.dart';
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
    SystemAccountService.instance.isAvailable().then((available) {
      if (mounted) setState(() => _systemAccountAvailable = available);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                ? AccountProfile(
                    user: authService.currentUser!,
                    isSyncing: _isSyncing,
                    lastSyncSucceeded: _lastSyncSucceeded,
                    onSync: _syncNow,
                    onOpenAccount: _openAccountUrl,
                  )
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
                        ? () => AuthService().signInWithSystemAccount()
                        : null,
                  ),
          ),
        );
      },
    );
  }

}
