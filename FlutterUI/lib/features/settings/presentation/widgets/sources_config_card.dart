import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/source_plugin_info.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';
import "add_source_dialog.dart";
import '../pages/github_integration_page.dart';
import '../controllers/settings_controller.dart';
import 'package:frontend/core/utils/toast.dart';

class SourcesConfigCard extends StatefulWidget {
  const SourcesConfigCard({super.key});

  @override
  State<SourcesConfigCard> createState() => _SourcesConfigCardState();
}

class _SourcesConfigCardState extends State<SourcesConfigCard> {
  List<SourcePluginInfo> _plugins = const [];
  bool _loadingPlugins = false;
  bool _detectingSources = false;
  final Set<String> _updatingSources = <String>{};
  final Set<String> _updatingPlugins = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    if (kIsWeb) return;
    setState(() => _loadingPlugins = true);
    try {
      final raw = await BackendService.instance.listPlugins();
      if (!mounted) return;
      setState(() {
        _plugins = raw
            .whereType<Map>()
            .map(
              (item) =>
                  SourcePluginInfo.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      });
    } catch (e) {
      debugPrint("Failed to load source plugins: $e");
    } finally {
      if (mounted) setState(() => _loadingPlugins = false);
    }
  }

  Future<void> _togglePlugin(SourcePluginInfo plugin, bool enabled) async {
    if (!_updatingPlugins.add(plugin.id)) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final success = await BackendService.instance.setPluginEnabled(
        plugin.id,
        enabled,
      );
      if (!mounted) return;
      Toast.show(
        context,
        success ? l10n.pluginUpdated : l10n.pluginUpdateFailed,
      );
      await _loadPlugins();
    } finally {
      _updatingPlugins.remove(plugin.id);
    }
  }

  Future<void> _removePlugin(SourcePluginInfo plugin) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await BackendService.instance.removePlugin(plugin.id);
    if (!mounted) return;
    Toast.show(
      context,
      success ? l10n.pluginRemoved : l10n.pluginRemovalFailed,
    );
    await _loadPlugins();
  }

  Future<void> _updateSourceConfig(String key, bool value) async {
    if (!_updatingSources.add(key)) return;
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(
      config['search']['sources'] ?? {},
    );
    config['search']['sources'][key] = value;
    try {
      final saved = await settings.updateConfig(config);
      if (!saved && mounted) {
        Toast.show(context, AppLocalizations.of(context)!.failed);
      }
    } finally {
      _updatingSources.remove(key);
    }
  }

  String _displayName(String key) {
    final mapping = {
      'pacman': 'Pacman',
      'aur': 'AUR',
      'flatpak': 'Flatpak',
      'appimage': 'AppImage',
      'snap': 'Snap',
      'github': 'GitHub',
      'bitu': 'Bitu',
      'winget': 'Winget',
      'scoop': 'Scoop',
      'brew': 'Homebrew',
    };
    return mapping[key.toLowerCase()] ?? key;
  }

  Future<void> _autoDetectSources(AppLocalizations l10n) async {
    if (_detectingSources) return;
    setState(() => _detectingSources = true);
    Toast.show(context, l10n.autoDetectingSources);

    try {
      final settings = context.read<SettingsController>();
      final success = await settings.autoDetectSources();
      if (mounted) {
        Toast.show(
          context,
          success ? l10n.autoDetectSuccess : l10n.autoDetectFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _detectingSources = false);
    }
  }

  void _showAddSourceDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AddSourceDialog(l10n: l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sources = [
      'github',
      'bitu',
      'pacman',
      'aur',
      'flatpak',
      'appimage',
      'snap',
      'winget',
      'scoop',
      'brew',
    ];

    return Selector<SettingsController, Map<dynamic, dynamic>>(
      selector: (context, s) =>
          s.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {},
      shouldRebuild: (prev, next) => !const MapEquality().equals(prev, next),
      builder: (context, sourcesMap, child) {
        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _detectingSources
                          ? null
                          : () => _autoDetectSources(l10n),
                      icon: SmoothSizeSwitcher(
                        child: _detectingSources
                            ? const SizedBox.square(
                                key: ValueKey('loading'),
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.radar_rounded, size: 18, key: ValueKey('idle')),
                      ),
                      label: Text(l10n.autoDetect),
                    ),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sources.map((src) {
                    final bool isEnabled =
                        sourcesMap[src] ?? (src == 'github' || src == 'bitu');
                    return FilterChip(
                      label: Text(_displayName(src)),
                      selected: isEnabled,
                      onSelected: _updatingSources.contains(src)
                          ? null
                          : (val) => _updateSourceConfig(src, val),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.pacmanBrowsingNoAuthorization,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.code_rounded),
                  title: Text(l10n.githubIntegration),
                  subtitle: Text(l10n.configurePat),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GitHubIntegrationPage(),
                      ),
                    );
                  },
                ),
                if (!kIsWeb) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.pluginsAndSources,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: l10n.refreshPlugins,
                        onPressed: _loadingPlugins ? null : _loadPlugins,
                      ),
                    ],
                  ),
                  SmoothSizeSwitcher(
                    alignment: Alignment.topCenter,
                    child: _loadingPlugins
                        ? const LinearProgressIndicator(
                            minHeight: 2,
                            key: ValueKey('loading'),
                          )
                        : _plugins.isEmpty
                        ? Padding(
                            key: const ValueKey('empty'),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l10n.noPluginsFound),
                          )
                        : Column(
                            key: const ValueKey('plugins'),
                            children: _plugins
                                .map((p) => _buildPluginTile(p, l10n))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.addCustomSource),
                  subtitle: Text(l10n.addCustomSourceDesc),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    tooltip: l10n.addCustomSource,
                    onPressed: () => _showAddSourceDialog(l10n),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPluginTile(SourcePluginInfo plugin, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final statusColor = plugin.error != null
        ? theme.colorScheme.error
        : plugin.available
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    final subtitle = [
      plugin.id,
      if (plugin.platforms.isNotEmpty) plugin.platforms.join(', '),
      if (plugin.capabilities.isNotEmpty)
        '${plugin.capabilities.length} capabilities',
      if (plugin.error != null) plugin.error!,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.12),
        foregroundColor: statusColor,
        child: Icon(
          plugin.legacy ? Icons.extension_off_rounded : Icons.extension_rounded,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(plugin.name)),
          if (plugin.builtin)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(l10n.builtin),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (plugin.legacy)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(l10n.legacy),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: plugin.enabled,
            onChanged: plugin.available && !plugin.legacy
                ? (value) => _togglePlugin(plugin, value)
                : null,
          ),
          if (!plugin.builtin && !plugin.legacy)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.removePlugin,
              onPressed: () => _removePlugin(plugin),
            ),
        ],
      ),
    );
  }
}
