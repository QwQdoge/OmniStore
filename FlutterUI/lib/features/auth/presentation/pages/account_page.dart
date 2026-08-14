import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/l10n/app_localizations.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context)!;

    if (email.isEmpty || password.isEmpty) {
      Toast.show(context, l10n.enterEmailPassword);
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
            title: Text(l10n.meoArchAccount),
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
                : _buildSignInForm(),
          ),
        );
      },
    );
  }

  Widget _buildAccountProfile(User user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final displayName = user.userMetadata?['full_name'] as String? ?? user.email ?? 'User';
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;

    return Center(
      key: const ValueKey('profile'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                  ? Icon(Icons.person_rounded, size: 48, color: colorScheme.onPrimaryContainer)
                  : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: Text(l10n.syncStatus),
                    subtitle: Text(l10n.syncStatusSubtitle),
                    trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_rounded),
                    title: Text(l10n.manageAccount),
                    subtitle: Text(l10n.manageAccountSubtitle),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: _openAccountUrl,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(l10n.signOut),
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

  Widget _buildSignInForm() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      key: const ValueKey('signin'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const Icon(Icons.account_circle_rounded, size: 64),
            const SizedBox(height: 24),
            Text(
              l10n.signInToMeoArch,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.signInSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Email/Password Form
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _handleEmailSignIn(),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isLoading ? null : _handleEmailSignIn,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: SmoothSizeSwitcher(
                child: _isLoading
                  ? const SizedBox(key: ValueKey('loading'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.signIn, key: const ValueKey('idle')),
              ),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: _openAccountUrl,
              child: Text(l10n.createAccount),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => AuthService().signInWithGoogle(),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(l10n.continueWithGoogle),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => AuthService().signInWithGitHub(),
              icon: const Icon(Icons.code_rounded),
              label: Text(l10n.continueWithGitHub),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
