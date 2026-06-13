import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:frontend/services/backend_service.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showAdvanced = false;
  final Map<String, Timer?> _debounces = {};
  String? _tempError;

  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late TextEditingController _tempController;

  final FocusNode _endpointFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();
  final FocusNode _tempFocus = FocusNode();

  Map<String, dynamic>? _storageInfo;
  bool _loadingStorage = false;

  Future<void> _fetchStorageInfo() async {
    if (!mounted) return;
    setState(() => _loadingStorage = true);
    try {
      final info = await BackendService.instance.getStorageInfo();
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _loadingStorage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStorage = false);
      }
    }
  }

  Future<void> _triggerCleanup(BuildContext context, AppLocalizations l10n) async {
    final taskController = context.read<TaskController>();
    if (taskController.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.taskInProgress)),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AnimatedBuilder(
          animation: taskController,
          builder: (context, child) {
            return AlertDialog(
              title: Text(l10n.systemCleaning),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(taskController.status),
                  const SizedBox(height: 16),
                  if (taskController.progress != null)
                    LinearProgressIndicator(value: taskController.progress)
                  else
                    const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Container(
                    height: 150,
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        taskController.logs.join('\n'),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!taskController.isBusy)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.confirm),
                  ),
              ],
            );
          },
        );
      },
    );

    await taskController.runCleanSystem(l10n);
    await _fetchStorageInfo();
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _endpointController = TextEditingController(
      text: settings.config['ai']?['endpoint'] ?? '',
    );
    _modelController = TextEditingController(
      text: settings.config['ai']?['model'] ?? '',
    );
    _apiKeyController = TextEditingController(
      text: settings.config['ai']?['api_key'] ?? '',
    );
    _tempController = TextEditingController(
      text: (settings.config['ai']?['temperature'] ?? 0.7).toString(),
    );
    _fetchStorageInfo();
  }

  SettingsController? _settingsController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<SettingsController>(context);
    if (_settingsController != newController) {
      _settingsController?.removeListener(_onSettingsChanged);
      _settingsController = newController;
      _settingsController?.addListener(_onSettingsChanged);
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      _syncControllers();
    }
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final settings = context.read<SettingsController>();
    _updateIfChanged(
      _endpointController,
      settings.config['ai']?['endpoint'] ?? '',
      _endpointFocus,
    );
    _updateIfChanged(
      _modelController,
      settings.config['ai']?['model'] ?? '',
      _modelFocus,
    );
    _updateIfChanged(
      _apiKeyController,
      settings.config['ai']?['api_key'] ?? '',
      _apiKeyFocus,
    );
    _updateIfChanged(
      _tempController,
      (settings.config['ai']?['temperature'] ?? 0.7).toString(),
      _tempFocus,
    );
  }

  void _updateIfChanged(
    TextEditingController controller,
    String value,
    FocusNode focus,
  ) {
    if (controller.text != value && !focus.hasFocus) {
      final selection = controller.selection;
      controller.text = value;
      // Maintain cursor position if it was within bounds (just in case)
      if (selection.baseOffset <= value.length &&
          selection.extentOffset <= value.length) {
        controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _settingsController?.removeListener(_onSettingsChanged);
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<SettingsController>(
        builder: (context, settings, child) {
          return ListView(
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
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(settings.language == 'zh-CN'
                ? l10n.langSimplifiedChinese
                : settings.language == 'zh-TW'
                    ? l10n.langTraditionalChinese
                    : settings.language == 'ja-JP'
                        ? l10n.langJapanese
                        : settings.language == 'es-ES' || settings.language == 'es'
                            ? l10n.langSpanish
                            : l10n.langEnglish),
            trailing: DropdownButton<String>(
              value: settings.language,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(value: 'zh-CN', child: Text(l10n.langSimplifiedChinese)),
                DropdownMenuItem(value: 'zh-TW', child: Text(l10n.langTraditionalChinese)),
                DropdownMenuItem(value: 'en-US', child: Text(l10n.langEnglish)),
                DropdownMenuItem(value: 'ja-JP', child: Text(l10n.langJapanese)),
                DropdownMenuItem(value: 'es-ES', child: Text(l10n.langSpanish)),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.setLanguage(val);
                }
              },
            ),
          ),
          SwitchListTile(
            title: Text(l10n.closeToTray),
            value: settings.closeToTray,
            onChanged: (val) {
              settings.setCloseToTray(val);
            },
          ),
          SwitchListTile(
            title: Text(l10n.useSystemTitleBar),
            subtitle: Text(l10n.configSaved),
            value: settings.useSystemTitleBar,
            onChanged: (val) {
              settings.setUseSystemTitleBar(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.configSaved),
                ),
              );
            },
          ),
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
          // Storage & Cleanup Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.systemCleaning,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _fetchStorageInfo,
                        tooltip: l10n.refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadingStorage)
                    const LinearProgressIndicator()
                  else if (_storageInfo != null) ...[
                    // Disk Space
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.diskSpaceInfo(
                            ((_storageInfo!['disk_free'] ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1),
                            ((_storageInfo!['disk_total'] ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((_storageInfo!['disk_used'] ?? 0) /
                            ((_storageInfo!['disk_total'] ?? 1) == 0 ? 1 : (_storageInfo!['disk_total'] ?? 1))),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cache Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${l10n.systemCleaningSubtitle}: ${((_storageInfo!['total_cache'] ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.cacheTypeInfo(
                                  ((_storageInfo!['pacman_cache'] ?? 0) / (1024 * 1024)).toStringAsFixed(1),
                                  ((_storageInfo!['flatpak_cache'] ?? 0) / (1024 * 1024)).toStringAsFixed(1),
                                  ((_storageInfo!['omnistore_cache'] ?? 0) / (1024 * 1024)).toStringAsFixed(1),
                                ),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _triggerCleanup(context, l10n),
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: Text(l10n.systemCleaning),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      l10n.systemCleaningSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildSection(l10n.repositories),
          _buildSourcesConfig(settings, l10n),

          const SizedBox(height: 24),
          _buildSection(l10n.updates),
          SwitchListTile(
            title: Text(l10n.enableDaemon),
            subtitle: Text(l10n.enableDaemonDesc),
            value: settings.daemonEnabled,
            onChanged: (val) {
              settings.setDaemonEnabled(val);
            },
          ),
          SwitchListTile(
            title: Text(l10n.autoUpdate),
            subtitle: Text(l10n.autoUpdateDesc),
            value: settings.autoUpdate,
            onChanged: (val) {
              settings.setAutoUpdate(val);
            },
          ),
          ListTile(
            title: Text(l10n.checkIntervalTitle),
            subtitle: Text(l10n.checkIntervalSubtitle(settings.checkIntervalHours)),
            trailing: DropdownButton<int>(
              value: settings.checkIntervalHours,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [1, 2, 4, 8, 12, 24].map((h) {
                return DropdownMenuItem(
                  value: h,
                  child: Text(l10n.hourValue(h)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  settings.setCheckIntervalHours(val);
                }
              },
            ),
          ),

          const SizedBox(height: 24),
          _buildSection(l10n.typography),
          ListTile(
            title: Text(l10n.fontFamily),
            subtitle: Text(settings.fontFamily == 'System' ? l10n.systemDefault : settings.fontFamily),
            trailing: DropdownButton<String>(
              value: settings.fontFamily,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(value: 'System', child: Text(l10n.systemDefault)),
                const DropdownMenuItem(value: 'Inter', child: Text('Inter')),
                const DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                const DropdownMenuItem(value: 'Outfit', child: Text('Outfit')),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.setFontFamily(val);
                }
              },
            ),
          ),
          ListTile(
            title: Text(l10n.fontScale),
            subtitle: Text("${(settings.fontScale * 100).toInt()}%"),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.fontScale,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: "${(settings.fontScale * 100).toInt()}%",
                onChanged: (val) {
                  settings.setFontScale(double.parse(val.toStringAsFixed(2)));
                },
              ),
            ),
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
                if (d == null) {
                  setState(() => _tempError = l10n.failed);
                } else if (d < 0.0 || d > 2.0) {
                  setState(() => _tempError = l10n.temperatureRangeError);
                } else {
                  setState(() => _tempError = null);
                  _debounceUpdateAIConfig('temperature', d, settings);
                }
              },
              errorText: _tempError,
            ),
          ],
        ],
          );
        },
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    Function(String) onChanged, {
    bool isPassword = false,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: errorText,
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

  void _debounceUpdateAIConfig(
    String key,
    dynamic value,
    SettingsController settings,
  ) {
    if (_debounces[key]?.isActive ?? false) _debounces[key]?.cancel();
    _debounces[key] = Timer(const Duration(milliseconds: 500), () {
      _updateAIConfig(key, value, settings);
    });
  }

  void _updateSourceConfig(
    String key,
    dynamic value,
    SettingsController settings,
  ) {
    final config = Map<String, dynamic>.from(settings.config);
    config['search'] = Map<String, dynamic>.from(config['search'] ?? {});
    config['search']['sources'] = Map<String, dynamic>.from(
      config['search']['sources'] ?? {},
    );
    config['search']['sources'][key] = value;
    settings.updateConfig(config);
  }

  Widget _buildSourcesConfig(
    SettingsController settings,
    AppLocalizations l10n,
  ) {
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
        settings.config['search']?['sources'] as Map<dynamic, dynamic>? ?? {};

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
                final bool isEnabled =
                    sourcesMap[src] ?? (src == 'github' || src == 'bitu');
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
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
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

  Future<void> _autoDetectSources(
    SettingsController settings,
    AppLocalizations l10n,
  ) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.autoDetectingSources)));

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

  void _showAddSourceDialog(
    SettingsController settings,
    AppLocalizations l10n,
  ) {
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
                      final config = Map<String, dynamic>.from(settings.config);
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
}
