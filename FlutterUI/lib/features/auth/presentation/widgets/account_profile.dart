import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/features/auth/auth_service.dart';

class AccountProfile extends StatelessWidget {
  final User user;
  final VoidCallback onOpenAccountUrl;

  const AccountProfile({
    super.key,
    required this.user,
    required this.onOpenAccountUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayName =
        user.userMetadata?['full_name'] as String? ?? user.email ?? 'User';
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
                    trailing: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_rounded),
                    title: const Text('Manage Account'),
                    subtitle: const Text('Security, MFA, and sessions'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: onOpenAccountUrl,
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
}
