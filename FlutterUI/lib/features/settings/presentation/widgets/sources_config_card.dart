import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/backend_service.dart';
import '../controllers/settings_controller.dart';

class SourcesConfigCard extends StatefulWidget {
  final SettingsController settings;

  const SourcesConfigCard({super.key, required this.settings});

  @override
  State<SourcesConfigCard> createState() => _SourcesConfigCardState();
}

class _SourcesConfigCardState extends State<SourcesConfigCard> {
  void _updateSourceConfig(String key, dynamic value) {
    final config = Map<String, dynamic>.from(widget.settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(
      config['search']['sources'] ?? {},
    );
    config['search']['sources'][key] = value;
    widget.settings.updateConfig(config);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.autoDetectingSources))
    );

    final success = await widget.settings.autoDetectSources();
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
                    Navigator.pop(context);

                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.addingCustomSource)),
                    );

                    bool success = false;
                    if (kIsWeb) {
                      final config = Map<String, dynamic>.from(widget.settings.config);
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
                      success = await widget.settings.updateConfig(config);
                    } else {
                      final result = await BackendService.instance
                          .addCustomRepo(type, name, url);
                      success = result;
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? l10n.sourceAddSuccess : l10n.sourceAddFailed,
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
    final sourcesMap =
        widget.settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.activeSources,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
  }
}
