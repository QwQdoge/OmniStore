import 'package:flutter/material.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/auth/presentation/widgets/account_profile.dart';
import 'package:frontend/features/auth/presentation/widgets/sign_in_form.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

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
                ? AccountProfile(user: authService.currentUser!)
                : const SignInForm(),
          ),
        );
      },
    );
  }
}
