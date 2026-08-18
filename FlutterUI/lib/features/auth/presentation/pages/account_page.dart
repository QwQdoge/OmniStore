import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/features/auth/auth_service.dart';
import 'package:frontend/core/config/meoarch_environment.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'package:frontend/features/auth/presentation/widgets/account_profile.dart';
import 'package:frontend/features/auth/presentation/widgets/sign_in_form.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
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
                ? AccountProfile(
                    user: authService.currentUser!,
                    onOpenAccountUrl: _openAccountUrl,
                  )
                : SignInForm(onOpenAccountUrl: _openAccountUrl),
          ),
        );
      },
    );
  }
}
