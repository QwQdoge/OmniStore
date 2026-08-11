import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    if (email.isEmpty || password.isEmpty) {
      Toast.show(context, 'Please enter email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        Toast.show(context, 'Sign in failed: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Sign in error: $e');
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
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final authService = AuthService();
        final isAuthenticated = authService.isAuthenticated;

        return Scaffold(
          appBar: AppBar(
            title: const Text('MeoArch Account'),
            actions: [
              if (isAuthenticated)
                IconButton(
                  tooltip: 'Sign Out',
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
                  const ListTile(
                    leading: Icon(Icons.sync_rounded),
                    title: Text('Sync Status'),
                    subtitle: Text('Apps and settings are backed up'),
                    trailing: Icon(Icons.check_circle_rounded, color: Colors.green),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_rounded),
                    title: const Text('Manage Account'),
                    subtitle: const Text('Security, MFA, and sessions'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: _openAccountUrl,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign Out'),
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
              'Sign In to MeoArch',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync your apps, settings, and favorites across devices.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Email/Password Form
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
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
                duration: const Duration(milliseconds: 300),
                child: _isLoading
                  ? const SizedBox(key: ValueKey('loading'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign In', key: ValueKey('idle')),
              ),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: _openAccountUrl,
              child: const Text('Create MeoArch Account'),
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
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => AuthService().signInWithGitHub(),
              icon: const Icon(Icons.code_rounded),
              label: const Text('Continue with GitHub'),
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
