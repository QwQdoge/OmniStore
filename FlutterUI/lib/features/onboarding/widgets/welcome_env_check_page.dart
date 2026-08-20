import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import 'welcome_config_card.dart';

class WelcomeEnvCheckPage extends StatelessWidget {
  final Map<String, dynamic>? envData;
  final bool isCheckingEnv;
  final String level;
  final VoidCallback onCheckEnvironment;
  final bool isBootstrapping;
  final String bootstrapLogs;
  final VoidCallback onStartBootstrap;
  final ScrollController terminalScrollController;

  const WelcomeEnvCheckPage({
    super.key,
    required this.envData,
    required this.isCheckingEnv,
    required this.level,
    required this.onCheckEnvironment,
    required this.isBootstrapping,
    required this.bootstrapLogs,
    required this.onStartBootstrap,
    required this.terminalScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.envCheckTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.envCheckSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SmoothSizeSwitcher(
            alignment: Alignment.topCenter,
            child: isCheckingEnv
                ? Center(
                    key: const ValueKey('checking'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Checking environment status...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : envData == null
                    ? Center(
                        key: const ValueKey('error'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to fetch environment details.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: onCheckEnvironment,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        key: const ValueKey('content'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEnvStatusHeader(level, l10n, theme),
                          const SizedBox(height: 20),
                          if (level == 'warning') ...[
                            WelcomeConfigCard(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.bootstrapNote,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: isBootstrapping ? null : onStartBootstrap,
                                        icon: SmoothSizeSwitcher(
                                          child: isBootstrapping
                                              ? const SizedBox(
                                                  key: ValueKey('loading'),
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.build_rounded, key: ValueKey('idle')),
                                        ),
                                        label: Text(l10n.fixProblems),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (isBootstrapping || bootstrapLogs.isNotEmpty) ...[
                            Text(
                              'Bootstrap progress:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isBootstrapping) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                            ],
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: SingleChildScrollView(
                                controller: terminalScrollController,
                                child: SelectableText(
                                  bootstrapLogs,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'System details:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildEnvDetailsGrid(envData!, theme),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvStatusHeader(String level, AppLocalizations l10n, ThemeData theme) {
    final IconData icon;
    final Color color;
    final String text;

    if (level == 'ok') {
      icon = Icons.check_circle_rounded;
      color = theme.colorScheme.primary;
      text = l10n.envOkDesc;
    } else if (level == 'warning') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
      text = l10n.envWarningDesc;
    } else {
      icon = Icons.error_outline_rounded;
      color = theme.colorScheme.error;
      text = l10n.envFatalDesc;
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvDetailsGrid(Map<String, dynamic> env, ThemeData theme) {
    return Column(
      children: env.entries.map((entry) {
        final key = entry.key;
        final val = entry.value;
        if (val is! Map) return const SizedBox.shrink();

        final String message = val['message']?.toString() ?? key;
        final String status = val['status']?.toString() ?? 'unknown';

        final IconData icon;
        final Color color;

        if (status == 'ok') {
          icon = Icons.check_rounded;
          color = theme.colorScheme.primary;
        } else if (status == 'warning') {
          icon = Icons.info_outline_rounded;
          color = Colors.orange;
        } else {
          icon = Icons.close_rounded;
          color = theme.colorScheme.error;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
