import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
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
    final state = await BackendService.instance.getMeoChannel();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _switch(String channel, {bool confirm = false}) async {
    setState(() => _busy = true);
    final result = await BackendService.instance.setMeoChannel(
      channel,
      confirmStableDowngrades: confirm,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = result;
    });
    if (result['status'] == 'confirmation_required') {
      final packages = (result['downgrades'] as List? ?? const [])
          .map((item) => '${item['name']}: ${item['installed']} → ${item['stable']}')
          .join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch to Stable'),
          content: Text(
            'Only official Meo packages would be downgraded. Arch and third-party packages will not be changed.\n\n$packages',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Switch to Stable')),
          ],
        ),
      );
      if (confirmed == true && mounted) await _switch('stable', confirm: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = _state?['channel']?.toString() ?? 'Checking…';
    final error = _state?['status'] == 'error' ? _state?['error']?.toString() : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alt_route_rounded),
            title: const Text('Meo update channel'),
            subtitle: Text(
              channel == 'beta'
                  ? 'Beta receives newer Meo components before Stable. Arch system packages stay on their normal repositories.'
                  : 'Stable receives fully tested MeoArch release trains.',
            ),
            trailing: Chip(label: Text(channel)),
          ),
          if (error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy || channel == 'stable' ? null : () => _switch('stable'),
                child: const Text('Stable'),
              ),
              FilledButton.tonal(
                onPressed: _busy || channel == 'beta' ? null : () => _switch('beta'),
                child: const Text('Beta'),
              ),
              IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ],
      ),
    );
  }
}
