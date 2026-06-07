import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showAdvanced = false;
  final Map<String, Timer?> _debounces = {};
  
  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late TextEditingController _tempController;

  final FocusNode _endpointFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();
  final FocusNode _tempFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _endpointController = TextEditingController(text: settings.config['ai']?['endpoint'] ?? '');
    _modelController = TextEditingController(text: settings.config['ai']?['model'] ?? '');
    _apiKeyController = TextEditingController(text: settings.config['ai']?['api_key'] ?? '');
    _tempController = TextEditingController(text: (settings.config['ai']?['temperature'] ?? 0.7).toString());
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final settings = context.read<SettingsController>();
    _updateIfChanged(_endpointController, settings.config['ai']?['endpoint'] ?? '', _endpointFocus);
    _updateIfChanged(_modelController, settings.config['ai']?['model'] ?? '', _modelFocus);
    _updateIfChanged(_apiKeyController, settings.config['ai']?['api_key'] ?? '', _apiKeyFocus);
    _updateIfChanged(_tempController, (settings.config['ai']?['temperature'] ?? 0.7).toString(), _tempFocus);
  }

  void _updateIfChanged(TextEditingController controller, String value, FocusNode focus) {
    if (controller.text != value && !focus.hasFocus) {
      final selection = controller.selection;
      controller.text = value;
      // Maintain cursor position if it was within bounds (just in case)
      if (selection.baseOffset <= value.length && selection.extentOffset <= value.length) {
        controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _debounces.values) {
      timer?.cancel();
    }
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _tempController.dispose();
    _endpointFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    _tempFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    // We still call sync here in case of external config changes (like from another page)
    _syncControllers();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.settings,
                style: OmnistoreTheme.standardHeader(context),
              ),
              FilterChip(
                label: Text(l10n.advanced),
                selected: _showAdvanced,
                onSelected: (val) => setState(() => _showAdvanced = val),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Primary Settings
          _buildSection(l10n.general),
          SwitchListTile(
            title: Text(l10n.aiEnabled),
            subtitle: Text(l10n.aiAssistantDesc),
            value: settings.isAIEnabled,
            onChanged: (val) {
              final config = Map<String, dynamic>.from(settings.config);
              config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
              config['ai']['enabled'] = val;
              settings.updateConfig(config);
            },
          ),
          ListTile(
            title: Text(l10n.systemCleaning),
            subtitle: Text(l10n.systemCleaningSubtitle),
            trailing: const Icon(Icons.delete_sweep_rounded),
            onTap: () {
              context.read<TaskRepository>().cleanSystem().listen((_) {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.processing)),
              );
            },
          ),

          if (_showAdvanced) ...[
            const SizedBox(height: 32),
            _buildSection(l10n.aiProvider),
            _buildTextField(
              l10n.aiEndpoint,
              _endpointController,
              _endpointFocus,
              (val) => _debounceUpdateAIConfig('endpoint', val, settings),
            ),
            _buildTextField(
              l10n.aiModel,
              _modelController,
              _modelFocus,
              (val) => _debounceUpdateAIConfig('model', val, settings),
            ),
            _buildTextField(
              l10n.aiApiKey,
              _apiKeyController,
              _apiKeyFocus,
              (val) => _debounceUpdateAIConfig('api_key', val, settings),
              isPassword: true,
            ),
            _buildTextField(
              l10n.aiTemperature,
              _tempController,
              _tempFocus,
              (val) {
                final d = double.tryParse(val);
                if (d != null) {
                  _debounceUpdateAIConfig('temperature', d, settings);
                }
              },
            ),
            const SizedBox(height: 24),
            _buildSection(l10n.repositories),
            _buildSourcesConfig(settings, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, FocusNode focusNode, Function(String) onChanged, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        obscureText: isPassword,
        onChanged: onChanged,
      ),
    );
  }

  void _updateAIConfig(String key, dynamic value, SettingsController settings) {
    final config = Map<String, dynamic>.from(settings.config);
    config['ai'] = Map<String, dynamic>.from(config['ai'] ?? {});
    config['ai'][key] = value;
    settings.updateConfig(config);
  }

  void _debounceUpdateAIConfig(String key, dynamic value, SettingsController settings) {
    if (_debounces[key]?.isActive ?? false) _debounces[key]?.cancel();
    _debounces[key] = Timer(const Duration(milliseconds: 500), () {
      _updateAIConfig(key, value, settings);
    });
  }

  void _updateSourceConfig(String key, dynamic value, SettingsController settings) {
    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(config['search']['sources'] ?? {});
    config['search']['sources'][key] = value;
    settings.updateConfig(config);
  }

  Widget _buildSourcesConfig(SettingsController settings, AppLocalizations l10n) {
    final sources = ['github', 'bitu', 'pacman', 'aur', 'flatpak', 'appimage', 'snap', 'winget', 'scoop', 'brew'];
    final sourcesMap = settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};

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
                  onPressed: () => _autoDetectSources(settings, l10n),
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
                final bool isEnabled = sourcesMap[src] ?? (src == 'github' || src == 'bitu');
                return FilterChip(
                  label: Text(_displayName(src)),
                  selected: isEnabled,
                  onSelected: (val) {
                    _updateSourceConfig(src, val, settings);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addCustomSource),
              subtitle: Text(l10n.addCustomSourceDesc),
              trailing: IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                onPressed: () => _showAddSourceDialog(settings, l10n),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _autoDetectSources(SettingsController settings, AppLocalizations l10n) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.autoDetectingSources)),
    );

    final Map<String, bool> detectedSources = {
      "pacman": false,
      "aur": false,
      "flatpak": false,
      "appimage": false,
      "snap": false,
      "github": true,
      "bitu": true,
      "winget": false,
      "scoop": false,
      "brew": false,
    };

    if (kIsWeb) {
      // Browser: keep defaults (github, bitu)
    } else {
      if (Platform.isLinux) {
        detectedSources["pacman"] = File("/usr/bin/pacman").existsSync();
        detectedSources["aur"] = detectedSources["pacman"]! && (File("/usr/bin/yay").existsSync() || File("/usr/bin/paru").existsSync());
        detectedSources["flatpak"] = _isCommandAvailable("flatpak");
        detectedSources["appimage"] = true;
        detectedSources["snap"] = _isCommandAvailable("snap");
        detectedSources["brew"] = _isCommandAvailable("brew");
      } else if (Platform.isWindows) {
        detectedSources["winget"] = _isCommandAvailable("winget");
        detectedSources["scoop"] = _isCommandAvailable("scoop");
      } else if (Platform.isMacOS) {
        detectedSources["brew"] = _isCommandAvailable("brew");
      }
    }

    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(config['search']['sources'] ?? {});
    
    detectedSources.forEach((key, value) {
      config['search']['sources'][key] = value;
    });

    final success = await settings.updateConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? l10n.autoDetectSuccess
              : l10n.autoDetectFailed
          ),
        ),
      );
    }
  }

  bool _isCommandAvailable(String cmd) {
    try {
      final check = Platform.isWindows ? 'where' : 'which';
      final res = Process.runSync(check, [cmd]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _showAddSourceDialog(SettingsController settings, AppLocalizations l10n) {
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
                      value: type,
                      decoration: InputDecoration(labelText: l10n.sourceType),
                      items: [
                        DropdownMenuItem(value: "github", child: Text(l10n.githubRepoType)),
                        DropdownMenuItem(value: "bitu", child: Text(l10n.bituRepoType)),
                        DropdownMenuItem(value: "flatpak", child: Text(l10n.flatpakRemoteType)),
                        DropdownMenuItem(value: "appimage", child: Text(l10n.appImageFeedType)),
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
                        labelText: type == "github" || type == "bitu" ? l10n.repoOwnerRepo : l10n.sourceUrl,
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
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.addingCustomSource)),
                    );

                    bool success = false;
                    if (kIsWeb) {
                      final config = Map<String, dynamic>.from(settings.config);
                      config['custom_repos'] = Map<String, dynamic>.from(config['custom_repos'] ?? {});
                      config['custom_repos'][type] = List<dynamic>.from(config['custom_repos'][type] ?? []);
                      config['custom_repos'][type].add({"name": name, "url": url});
                      success = await settings.updateConfig(config);
                    } else {
                      final result = await BackendService.instance.addCustomRepo(type, name, url);
                      success = result;
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? l10n.sourceAddSuccess : l10n.sourceAddFailed)),
                      );
                    }
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
}
