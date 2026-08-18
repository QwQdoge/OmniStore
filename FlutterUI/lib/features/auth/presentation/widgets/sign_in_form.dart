import 'package:flutter/material.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/utils/toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class SignInForm extends StatefulWidget {
  final VoidCallback onOpenAccountUrl;

  const SignInForm({super.key, required this.onOpenAccountUrl});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
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

  @override
  Widget build(BuildContext context) {
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
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                  ),
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
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In', key: ValueKey('idle')),
              ),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onOpenAccountUrl,
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
              onPressed: _isLoading
                  ? null
                  : () => AuthService().signInWithGoogle(),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => AuthService().signInWithGitHub(),
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
