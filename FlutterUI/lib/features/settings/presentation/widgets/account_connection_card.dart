import 'package:flutter/material.dart';
import 'package:frontend/features/ai/account_ai_service.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';

class AccountConnectionCard extends StatelessWidget {
  final Map<dynamic, dynamic> aiConfig;
  final bool isAuthenticated;
  final bool isLoadingAccountCredentials;
  final String? accountCredentialError;
  final List<AccountAiCredential> accountCredentials;
  final VoidCallback onOpenAccountSignIn;
  final VoidCallback onOpenAccountAiSettings;
  final VoidCallback onLoadAccountCredentials;
  final ValueChanged<String?> onSelectAccountCredential;

  const AccountConnectionCard({
    super.key,
    required this.aiConfig,
    required this.isAuthenticated,
    required this.isLoadingAccountCredentials,
    required this.accountCredentialError,
    required this.accountCredentials,
    required this.onOpenAccountSignIn,
    required this.onOpenAccountAiSettings,
    required this.onLoadAccountCredentials,
    required this.onSelectAccountCredential,
  });

  Widget _buildAccountCallout({
    required Color background,
    required String title,
    required String detail,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final detailColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(detail),
            ],
          );
          final action = FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiMark(size: 48),
                    const SizedBox(width: 14),
                    Expanded(child: detailColumn),
                  ],
                ),
                const SizedBox(height: 12),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiMark(size: 48),
              const SizedBox(width: 14),
              Expanded(child: detailColumn),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!isAuthenticated) {
      return _buildAccountCallout(
        background: colors.secondaryContainer.withValues(alpha: 0.55),
        title: '先登录 Meo Account',
        detail: '登录后即可选择账号中加密保存的 AI 连接；API 密钥不会下发到 OmniStore。',
        actionLabel: '登录账号',
        actionIcon: Icons.login_rounded,
        onPressed: onOpenAccountSignIn,
      );
    }

    if (isLoadingAccountCredentials) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: Text('正在读取账号 AI 连接'),
        subtitle: Text('只读取名称、服务商和密钥掩码。'),
      );
    }

    if (accountCredentialError != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_off_rounded, color: colors.error),
        title: const Text('无法读取账号 AI 连接'),
        subtitle: Text(accountCredentialError!),
        trailing: IconButton(
          tooltip: '重试',
          onPressed: () => onLoadAccountCredentials(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    if (accountCredentials.isEmpty) {
      return _buildAccountCallout(
        background: colors.surfaceContainerHigh,
        title: '账号中还没有 AI 连接',
        detail: '前往 Account 填写你自己的 API 密钥并安全保存，然后回到这里刷新。',
        actionLabel: '去连接',
        actionIcon: Icons.open_in_new_rounded,
        onPressed: onOpenAccountAiSettings,
      );
    }

    final configuredId = '${aiConfig['account_credential_id'] ?? ''}';
    final selectedId =
        accountCredentials.any((credential) => credential.id == configuredId)
        ? configuredId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: '账号 AI 连接',
            helperText: '密钥只在 Account Edge broker 内解密，OmniStore 不可读取。',
            prefixIcon: Icon(Icons.account_circle_outlined),
          ),
          items: [
            for (final credential in accountCredentials)
              DropdownMenuItem(
                value: credential.id,
                child: Text(
                  '${credential.displayName} · ${credential.secretHint}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onSelectAccountCredential,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: onOpenAccountAiSettings,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('管理 AI 连接'),
            ),
            TextButton.icon(
              onPressed: () => onLoadAccountCredentials(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '每次发送前，OmniStore 都会显示服务商、模型、用途、数据类别、完整内容和请求指纹，并要求“仅同意这一次”。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

}
