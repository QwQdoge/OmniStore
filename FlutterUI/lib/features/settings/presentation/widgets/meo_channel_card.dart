import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';

/// A thin UI over the package-owned channel mechanism.  It deliberately has
/// no local preferences: every refresh asks pacman-conf through OmniStore.
class MeoChannelCard extends StatefulWidget {
  const MeoChannelCard({super.key});

  @override
  State<MeoChannelCard> createState() => _MeoChannelCardState();
}

class _MeoChannelCardState extends State<MeoChannelCard> {
  Map<String, dynamic>? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final state = await BackendService.instance.getMeoChannel();
      if (mounted) setState(() => _state = state);
    } catch (error) {
      if (mounted) {
        setState(() => _state = {
          ...?_state,
          'status': 'error',
          'error': error.toString(),
        });
      }
    }
  }

  Future<void> _switch(String channel, {bool confirm = false}) async {
    setState(() => _busy = true);
    try {
      final result = await BackendService.instance.setMeoChannel(
        channel,
        confirmStableDowngrades: confirm,
      );
      if (!mounted) return;
      setState(() => _state = {...?_state, ...result});
      if (result['status'] == 'confirmation_required') {
        await _confirmStableDowngrades(result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _state = {
          ...?_state,
          'status': 'error',
          'error': error.toString(),
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStableDowngrades(Map<String, dynamic> state) async {
    final l10n = AppLocalizations.of(context)!;
    final packages = (state['downgrades'] as List? ?? const [])
        .map((item) => '${item['name']}: ${item['installed']} → ${item['stable']}')
        .join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.security_update_good_rounded),
        title: Text(l10n.switchToStable),
        content: Text(
          l10n.meoDowngradeConfirmDialog(packages),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.switchToStable)),
        ],
      ),
    );
    if (confirmed == true && mounted) await _switch('stable', confirm: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = _state;
    final channel = state?['channel']?.toString() ?? 'Checking…';
    final error = state != null && state['status'] == 'error' ? state['error']?.toString() : null;
    final downgradePending = state?['downgrades'] is List && (state!['downgrades'] as List).isNotEmpty;
    final repositories = (state?['repositories'] as List? ?? const []).join(' → ');
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                  child: const Icon(Icons.alt_route_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.meoUpdateChannel, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        l10n.meoUpdateChannelDesc,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(channel)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              channel == 'beta'
                  ? l10n.meoBetaChannelDesc
                  : l10n.meoStableChannelDesc,
              style: theme.textTheme.bodyMedium,
            ),
            if (repositories.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.meoRepositoryPriority(repositories), style: theme.textTheme.bodySmall),
            ],
            if (channel == 'beta') ...[
              const SizedBox(height: 12),
              _StatusPanel(
                icon: Icons.science_outlined,
                color: theme.colorScheme.tertiary,
                text: l10n.meoBetaWarning,
              ),
            ],
            if (downgradePending) ...[
              const SizedBox(height: 12),
              _StatusPanel(
                icon: Icons.pending_actions_rounded,
                color: theme.colorScheme.primary,
                text: l10n.meoDowngradePending((state['downgrades'] as List).length),
                action: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _confirmStableDowngrades(state),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.meoReviewDowngrades),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              _StatusPanel(icon: Icons.error_outline_rounded, color: theme.colorScheme.error, text: error),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'stable', label: const Text('Stable'), icon: const Icon(Icons.verified_outlined), enabled: !_busy && channel != 'stable'),
                      ButtonSegment(value: 'beta', label: const Text('Beta'), icon: const Icon(Icons.science_outlined), enabled: !_busy && channel != 'beta'),
                    ],
                    selected: {'stable', 'beta'}.contains(channel) ? {channel} : const <String>{},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) _switch(selection.first);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: l10n.refresh,
                  onPressed: _busy ? null : _refresh,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.color, required this.text, this.action});

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}
