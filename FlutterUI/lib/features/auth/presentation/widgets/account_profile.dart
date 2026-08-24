import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/auth/auth_service.dart';

class AccountProfile extends StatelessWidget {
  final User user;
  final bool isSyncing;
  final bool? lastSyncSucceeded;
  final VoidCallback onSync;
  final VoidCallback onOpenAccount;

  const AccountProfile({
    super.key,
    required this.user,
    required this.isSyncing,
    required this.lastSyncSucceeded,
    required this.onSync,
    required this.onOpenAccount,
  });

    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final displayName =
        user.userMetadata?['full_name'] as String? ??
        user.email ??
        l10n.defaultUser;
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;

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
                      Icons.sync_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      l10n.syncStatus,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(l10n.syncStatusSubtitle),
                    trailing: isSyncing
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(
                            lastSyncSucceeded == false
                                ? Icons.error_rounded
                                : lastSyncSucceeded == true
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_rounded,
                            color: lastSyncSucceeded == false
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                    onTap: isSyncing ? null : onSync,
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
                    onTap: onOpenAccount,
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
