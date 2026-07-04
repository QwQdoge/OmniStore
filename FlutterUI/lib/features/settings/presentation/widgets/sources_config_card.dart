import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/source_plugin_info.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:frontend/core/widgets/app_card.dart';
import '../controllers/settings_controller.dart';

class SourcesConfigCard extends StatefulWidget {
  const SourcesConfigCard({super.key});

  @override
  State<SourcesConfigCard> createState() => _SourcesConfigCardState();
}

class _SourcesConfigCardState extends State<SourcesConfigCard> {
  List<SourcePluginInfo> _plugins = const [];
  bool _loadingPlugins = false;

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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final success = await BackendService.instance.setPluginEnabled(
      plugin.id,
      enabled,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? l10n.pluginUpdated : l10n.pluginUpdateFailed),
      ),
    );
    await _loadPlugins();
  }

  Future<void> _removePlugin(SourcePluginInfo plugin) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final success = await BackendService.instance.removePlugin(plugin.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? l10n.pluginRemoved : l10n.pluginRemovalFailed),
      ),
    );
    await _loadPlugins();
  }

  void _updateSourceConfig(String key, dynamic value) {
    final settings = context.read<SettingsController>();
    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(
      config['search']['sources'] ?? {},
    );
    config['search']['sources'][key] = value;
    settings.updateConfig(config);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.autoDetectingSources)));

    final settings = context.read<SettingsController>();
    final success = await settings.autoDetectSources();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.autoDetectSuccess : l10n.autoDetectFailed,
          ),
        ),
      );
    }
  }

  void _showAddSourceDialog(AppLocalizations l10n) {
    String type = "github";
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addCustomSource),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: InputDecoration(labelText: l10n.sourceType),
                      items: [
                        DropdownMenuItem(
                          value: "github",
                          child: Text(l10n.githubRepoType),
                        ),
                        DropdownMenuItem(
                          value: "bitu",
                          child: Text(l10n.bituRepoType),
                        ),
                        DropdownMenuItem(
                          value: "flatpak",
                          child: Text(l10n.flatpakRemoteType),
                        ),
                        DropdownMenuItem(
                          value: "appimage",
                          child: Text(l10n.appImageFeedType),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => type = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.sourceName,
                        hintText: l10n.hintCustomAppName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: type == "github" || type == "bitu"
                            ? l10n.repoOwnerRepo
                            : l10n.sourceUrl,
                        hintText: type == "github" || type == "bitu"
                            ? l10n.hintRepoFormat
                            : l10n.hintFeedUrl,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final url = urlController.text.trim();
                    if (name.isEmpty || url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorNameUrlRequired)),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final settings = context.read<SettingsController>();
                    Navigator.pop(context);

                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.addingCustomSource)),
                    );

                    bool success = false;
                    if (kIsWeb) {
                      final config = Map<String, dynamic>.from(
                        settings.config,
                      );
                      config['custom_repos'] = Map<String, dynamic>.from(
                        config['custom_repos'] ?? {},
                      );
                      config['custom_repos'][type] = List<dynamic>.from(
                        config['custom_repos'][type] ?? [],
                      );
                      config['custom_repos'][type].add({
                        "name": name,
                        "url": url,
                      });
                      success = await settings.updateConfig(config);
                    } else {
                      final result = await BackendService.instance
                          .addCustomRepo(type, name, url);
                      success = result;
                    }

                    if (!mounted) return;

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? l10n.sourceAddSuccess
                              : l10n.sourceAddFailed,
                        ),
                      ),
                    );
                  },
                  child: Text(l10n.add),
                ),
              ],
            );
          },
        );
      },
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
      selector: (context, s) => s.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {},
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
                    TextButton.icon(
                      onPressed: () => _autoDetectSources(l10n),
                      icon: const Icon(Icons.radar_rounded, size: 18),
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
                      onSelected: (val) => _updateSourceConfig(src, val),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (!kIsWeb) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.pluginsAndSources,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: l10n.refreshPlugins,
                        onPressed: _loadingPlugins ? null : _loadPlugins,
                      ),
                    ],
                  ),
                  if (_loadingPlugins)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_plugins.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.noPluginsFound),
                    )
                  else
                    ..._plugins.map((p) => _buildPluginTile(p, l10n)),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.addCustomSource),
                  subtitle: Text(l10n.addCustomSourceDesc),
                  trailing: Semantics(
                    label: l10n.addCustomSource,
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      tooltip: l10n.addCustomSource,
                      onPressed: () => _showAddSourceDialog(l10n),
                    ),
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
