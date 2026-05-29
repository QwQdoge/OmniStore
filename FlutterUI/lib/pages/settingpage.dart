import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:file_picker/file_picker.dart';
import '../widgets/magic_pulse_icon.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_service.dart';
import '../services/l10n_service.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // General settings
  bool pacmanEnabled = true;
  bool aurEnabled = true;
  bool flatpakEnabled = true;
  bool appimageEnabled = true;

  double maxResults = 100;
  double pacmanPriority = 100;
  double aurPriority = 80;
  double flatpakPriority = 60;
  double appimagePriority = 40;

  List<String> sourceOrder = ['pacman', 'aur', 'flatpak', 'appimage'];

  String appearance = 'system';
  String colorSeed = '#CA6ECF';
  String logLevel = 'INFO';
  bool closeToTray = true;
  bool enableSystemTray = true;
  bool useSystemTitleBar = false;
  bool includeAurUpdates = true;

  bool notificationsEnabled = true;
  bool progressNotifications = true;
  bool completionNotifications = true;
  double updateCheckInterval = 1;
  bool remindUpdates = true;

  // AI Settings
  bool aiEnabled = false;
  String aiProvider = 'ollama';
  double aiTemperature = 0.7;
  double aiMaxTokens = 2048;

  // Persistent Controllers to avoid rebuild issues
  final TextEditingController _aiEndpointController = TextEditingController();
  final TextEditingController _aiModelController = TextEditingController();
  final TextEditingController _aiApiKeyController = TextEditingController();
  final TextEditingController _aiProxyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _aiEndpointController.dispose();
    _aiModelController.dispose();
    _aiApiKeyController.dispose();
    _aiProxyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await BackendService.instance.loadConfig().timeout(const Duration(seconds: 5));
      if (config.isEmpty) return;

      if (mounted) {
        setState(() {
          final s = config['search'] as Map<String, dynamic>? ?? {};
          final src = (s['sources'] as Map<String, dynamic>?) ?? {};
          pacmanEnabled = src['pacman'] ?? true;
          aurEnabled = src['aur'] ?? true;
          flatpakEnabled = src['flatpak'] ?? true;
          appimageEnabled = src['appimage'] ?? true;
          maxResults = (s['max_results'] ?? 100).toDouble();

          final p = config['priority'] as Map<String, dynamic>? ?? {};
          pacmanPriority = (p['pacman'] ?? 100).toDouble();
          aurPriority = (p['aur'] ?? 80).toDouble();
          flatpakPriority = (p['flatpak'] ?? 60).toDouble();
          appimagePriority = (p['appimage'] ?? 40).toDouble();

          var entries = p.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          sourceOrder =
              entries.map((e) => e.key.toString()).cast<String>().toList();
          for (var s in ['pacman', 'aur', 'flatpak', 'appimage']) {
            if (!sourceOrder.contains(s)) sourceOrder.add(s);
          }

          final ui = config['ui'] as Map<String, dynamic>? ?? {};
          appearance = ui['appearance'] ?? 'system';
          colorSeed = ui['color_seed'] ?? '#CA6ECF';
          closeToTray = ui['close_to_tray'] ?? true;
          enableSystemTray = ui['enable_system_tray'] ?? (Platform.isLinux ? false : true);
          useSystemTitleBar = ui['use_system_title_bar'] ?? false;

          final log = config['logging'] as Map<String, dynamic>? ?? {};
          logLevel = log['level'] ?? 'INFO';

          final notify = config['notifications'] as Map<String, dynamic>? ?? {};
          notificationsEnabled = notify['enabled'] ?? true;
          progressNotifications = notify['progress'] ?? true;
          completionNotifications = notify['completion'] ?? true;

          final upConfig = config['updates'] as Map<String, dynamic>? ?? {};
          updateCheckInterval = (upConfig['check_interval_hours'] ?? 1).toDouble();
          remindUpdates = upConfig['remind_updates'] ?? true;
          includeAurUpdates = upConfig['include_aur_in_update_all'] ?? true;

          final ai = config['ai'] as Map<String, dynamic>? ?? {};
          aiEnabled = ai['enabled'] ?? false;
          aiProvider = ai['provider'] ?? 'ollama';
          _aiEndpointController.text = ai['endpoint'] ?? '';
          _aiModelController.text = ai['model'] ?? '';
          _aiApiKeyController.text = ai['api_key'] ?? '';
          _aiProxyController.text = ai['proxy'] ?? '';
          aiTemperature = (ai['temperature'] ?? 0.7).toDouble();
          aiMaxTokens = (ai['max_tokens'] ?? 2048).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Settings load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context)!.settings,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: () => _saveAll(),
                  icon: const Icon(Icons.done_all),
                  label: Text(AppLocalizations.of(context)!.saveAndApply),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle(AppLocalizations.of(context)!.packageManager),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.pacmanOfficial,
                    pacmanEnabled,
                    (v) => setState(() => pacmanEnabled = v),
                  ),
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.aurUser,
                    aurEnabled,
                    (v) => setState(() => aurEnabled = v),
                  ),
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.flatpak,
                    flatpakEnabled,
                    (v) => setState(() => flatpakEnabled = v),
                  ),
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.appImage,
                    appimageEnabled,
                    (v) => setState(() => appimageEnabled = v),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.sourcePriority),
                _buildGroupCard([
                  SizedBox(
                    height: 220,
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = sourceOrder.removeAt(oldIndex);
                          sourceOrder.insert(newIndex, item);

                          for (int i = 0; i < sourceOrder.length; i++) {
                            double weight = 100.0 - (i * 20);
                            switch (sourceOrder[i]) {
                              case 'pacman':
                                pacmanPriority = weight;
                                break;
                              case 'aur':
                                aurPriority = weight;
                                break;
                              case 'flatpak':
                                flatpakPriority = weight;
                                break;
                              case 'appimage':
                                appimagePriority = weight;
                                break;
                            }
                          }
                        });
                      },
                      children: sourceOrder.map((s) {
                        IconData icon;
                        String label;
                        switch (s) {
                          case 'pacman':
                            icon = Icons.apps;
                            label = AppLocalizations.of(context)!.pacmanOfficial;
                            break;
                          case 'aur':
                            icon = Icons.cloud_outlined;
                            label = AppLocalizations.of(context)!.aurUser;
                            break;
                          case 'flatpak':
                            icon = Icons.inventory_2_outlined;
                            label = AppLocalizations.of(context)!.flatpak;
                            break;
                          default:
                            icon = Icons.insert_drive_file_outlined;
                            label = AppLocalizations.of(context)!.appImage;
                        }
                        return ListTile(
                          key: ValueKey(s),
                          leading: Icon(icon),
                          title: Text(label),
                          trailing: const Icon(Icons.drag_handle),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.search),
                _buildGroupCard([
                  _buildSliderTile(
                    AppLocalizations.of(context)!.maxResults,
                    maxResults,
                    (v) => setState(() => maxResults = v),
                    max: 500,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.appearance),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(AppLocalizations.of(context)!.themeColor),
                    subtitle: Text(colorSeed),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(colorSeed.replaceAll('#', '0xFF')),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      _showColorPicker();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.brightness_medium_outlined),
                    title: Text(AppLocalizations.of(context)!.appearance),
                    trailing: DropdownButton<String>(
                      value: appearance,
                      underline: const SizedBox(),
                      onChanged: (v) => setState(() => appearance = v!),
                      items: [
                        DropdownMenuItem(value: 'system', child: Text(AppLocalizations.of(context)!.followSystem)),
                        DropdownMenuItem(value: 'light', child: Text(AppLocalizations.of(context)!.lightMode)),
                        DropdownMenuItem(value: 'dark', child: Text(AppLocalizations.of(context)!.darkMode)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.notifications),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.enableNotifications,
                    notificationsEnabled,
                    (v) => setState(() => notificationsEnabled = v),
                  ),
                  if (notificationsEnabled) ...[
                    _buildSwitchTile(
                      AppLocalizations.of(context)!.progressNotifications,
                      progressNotifications,
                      (v) => setState(() => progressNotifications = v),
                    ),
                    _buildSwitchTile(
                      AppLocalizations.of(context)!.completionNotifications,
                      completionNotifications,
                      (v) => setState(() => completionNotifications = v),
                    ),
                  ],
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.systemAndWindow),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.closeToTray,
                    closeToTray,
                    (v) => setState(() => closeToTray = v),
                  ),
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.enableSystemTray,
                    enableSystemTray,
                    (v) => setState(() => enableSystemTray = v),
                  ),
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.useSystemTitleBar,
                    useSystemTitleBar,
                    (v) => _toggleTitleBar(v),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.aiSettings),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.aiEnabled,
                    aiEnabled,
                    (v) => setState(() => aiEnabled = v),
                  ),
                  if (aiEnabled) ...[
                    ListTile(
                      leading: const MagicPulseIcon(icon: Icons.smart_toy_outlined),
                      title: Text(AppLocalizations.of(context)!.aiProvider),
                      subtitle: const Text("Select your AI model source (Local or Cloud)"),
                      trailing: DropdownButton<String>(
                        value: aiProvider,
                        underline: const SizedBox(),
                        onChanged: (v) => setState(() => aiProvider = v!),
                        items: const [
                          DropdownMenuItem(value: 'ollama', child: Text('Ollama (Local)')),
                          DropdownMenuItem(value: 'openai', child: Text('OpenAI Compatible')),
                          DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                        ],
                      ),
                    ),
                    _buildTextTile(
                      AppLocalizations.of(context)!.aiEndpoint,
                      _aiEndpointController,
                      hint: 'http://localhost:11434',
                    ),
                    _buildTextTile(
                      AppLocalizations.of(context)!.aiModel,
                      _aiModelController,
                      hint: 'qwen2.5:7b',
                    ),
                    _buildTextTile(
                      AppLocalizations.of(context)!.aiApiKey,
                      _aiApiKeyController,
                      hint: 'sk-xxxxxxxx',
                      isPassword: true,
                    ),
                    _buildTextTile(
                      AppLocalizations.of(context)!.aiProxy,
                      _aiProxyController,
                      hint: 'http://127.0.0.1:7890',
                    ),
                    _buildSliderTile(
                      AppLocalizations.of(context)!.aiTemperature,
                      aiTemperature,
                      (v) => setState(() => aiTemperature = v),
                      min: 0,
                      max: 1,
                    ),
                    _buildSliderTile(
                      AppLocalizations.of(context)!.aiMaxTokens,
                      aiMaxTokens,
                      (v) => setState(() => aiMaxTokens = v),
                      min: 256,
                      max: 8192,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testAIConnection,
                              icon: const MagicPulseIcon(icon: Icons.bolt_rounded),
                              label: Text(AppLocalizations.of(context)!.aiTestButton),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.updateReminders),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.remindMeOfUpdates,
                    remindUpdates,
                    (v) => setState(() => remindUpdates = v),
                  ),
                  _buildSliderTile(
                    AppLocalizations.of(context)!.checkInterval,
                    updateCheckInterval,
                    (v) => setState(() => updateCheckInterval = v),
                    min: 1,
                    max: 24,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.maintenance),
                _buildGroupCard([
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.includeAurUpdates,
                    includeAurUpdates,
                    (v) => setState(() => includeAurUpdates = v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.system_update_rounded),
                    title: Text(AppLocalizations.of(context)!.updateAllPackages),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.searching)),
                      );
                      await UpdateService().checkNow();
                      if (UpdateService().availableUpdates.value.isNotEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.foundUpdates(UpdateService().availableUpdates.value.length))),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: Text(AppLocalizations.of(context)!.resetOnboarding),
                    onTap: _resetOnboarding,
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded),
                    title: Text(AppLocalizations.of(context)!.systemCleaning),
                    subtitle: Text(AppLocalizations.of(context)!.systemCleaningSubtitle),
                    onTap: () {
                      BackendService.instance.cleanSystem().listen((event) {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.systemCleaningStarted)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
                    title: Text(AppLocalizations.of(context)!.aiHealthTitle),
                    subtitle: Text(AppLocalizations.of(context)!.aiHealthSubtitle),
                    onTap: _showAIHealthReport,
                  ),
                  ListTile(
                    leading: const Icon(Icons.backup_rounded),
                    title: Text(AppLocalizations.of(context)!.backupAndExport),
                    subtitle: Text(AppLocalizations.of(context)!.backupAndExportSubtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                            onPressed: _exportBackup,
                            icon: const Icon(Icons.upload_rounded),
                            label: Text(AppLocalizations.of(context)!.export)),
                        TextButton.icon(
                            onPressed: _importBackup,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(AppLocalizations.of(context)!.import)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(AppLocalizations.of(context)!.help),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(AppLocalizations.of(context)!.loggingLevel),
                    subtitle: Text(AppLocalizations.of(context)!.help),
                    trailing: DropdownButton<String>(
                      value: logLevel,
                      underline: const SizedBox(),
                      onChanged: (v) => setState(() => logLevel = v!),
                      items: const [
                        DropdownMenuItem(value: 'DEBUG', child: Text('DEBUG')),
                        DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                        DropdownMenuItem(value: 'WARNING', child: Text('WARNING')),
                        DropdownMenuItem(value: 'ERROR', child: Text('ERROR')),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

  Widget _buildGroupCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(children: children),
    );
  }

  Widget _buildTextTile(String title, TextEditingController controller,
      {String? hint, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildSliderTile(
    String title,
    double value,
    Function(double) onChanged, {
    double min = 0,
    double max = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(
                value.toInt().toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt() == 0 ? 1 : (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context)!.selectExportLocation,
      fileName: 'omnistore_backup.json',
    );

    if (outputFile != null) {
      final res = await BackendService.instance.exportPackages(outputFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['status'] == 'success'
                  ? AppLocalizations.of(context)!.exportSuccess(res['count'])
                  : AppLocalizations.of(context)!.exportFailed(res['message']))),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      final packages = await BackendService.instance.importPackages(path);
      if (mounted && packages.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.importBackup),
            content: Text(AppLocalizations.of(context)!.importBackupConfirm(packages.length)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel)),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  for (var pkg in packages) {
                    BackendService.instance
                        .executeAction("-I", pkg['name'], pkg['source'] ?? 'Native')
                        .listen((_) {});
                  }
                },
                child: Text(AppLocalizations.of(context)!.startRecovery),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _resetOnboarding() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetOnboarding),
        content: Text(AppLocalizations.of(context)!.resetOnboardingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final config = await BackendService.instance.loadConfig();
      config['first_run'] = true;
      final success = await BackendService.instance.saveConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? AppLocalizations.of(context)!.configSaved : AppLocalizations.of(context)!.configSaveFailed),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.themeColor),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              '#CA6ECF', '#0B57D0', '#1A73E8', '#34A853', '#FBBC04', '#EA4335',
              '#673AB7', '#3F51B5', '#00BCD4', '#009688', '#FF5722', '#795548',
            ].map((hex) => InkWell(
              onTap: () {
                setState(() => colorSeed = hex);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(int.parse(hex.replaceAll('#', '0xFF'))),
                  shape: BoxShape.circle,
                  border: colorSeed == hex ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: colorSeed == hex ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.confirm)),
        ],
      ),
    );
  }

  Future<void> _toggleTitleBar(bool useSystem) async {
    setState(() => useSystemTitleBar = useSystem);
    try {
      final wm.TitleBarStyle style = useSystem
          ? wm.TitleBarStyle.normal
          : wm.TitleBarStyle.hidden;
      await wm.windowManager.setTitleBarStyle(style);
    } catch (e) {
      debugPrint("TitleBar Error: $e");
    }
  }

  Future<void> _testAIConnection() async {
    _saveAll(silent: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.searching)),
    );

    try {
      final result = await Process.run(
        BackendService.venvPython,
        [BackendService.scriptPath, "--ai-summary", "--json"],
        workingDirectory: BackendService.workingDir,
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (result.exitCode == 0) {
        final data = jsonDecode(result.stdout);
        if (data['response'] != null && !data['response'].toString().startsWith('Error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.aiTestSuccess),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiTestFailed(result.stdout + result.stderr)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiTestFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAIHealthReport() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const MagicPulseIcon(icon: Icons.auto_awesome_rounded),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.aiHealthTitle),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: FutureBuilder<String>(
            future: BackendService.instance.aiSystemHealth(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: MarkdownBody(
                  data: snapshot.data ?? "AI failed to respond.",
                  selectable: true,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  void _saveAll({bool silent = false}) {
    final config = {
      'search': {
        'sources': {
          'pacman': pacmanEnabled,
          'aur': aurEnabled,
          'flatpak': flatpakEnabled,
          'appimage': appimageEnabled,
        },
        'max_results': maxResults.toInt(),
      },
      'priority': {
        'pacman': pacmanPriority.toInt(),
        'aur': aurPriority.toInt(),
        'flatpak': flatpakPriority.toInt(),
        'appimage': appimagePriority.toInt(),
      },
      'ui': {
        'appearance': appearance, 
        'color_seed': colorSeed,
        'close_to_tray': closeToTray,
        'enable_system_tray': enableSystemTray,
        'use_system_title_bar': useSystemTitleBar,
        'language': L10nService.languageCode,
      },
      'logging': {'level': logLevel},
      'notifications': {
        'enabled': notificationsEnabled,
        'progress': progressNotifications,
        'completion': completionNotifications,
      },
      'updates': {
        'check_interval_hours': updateCheckInterval.toInt(),
        'remind_updates': remindUpdates,
        'include_aur_in_update_all': includeAurUpdates,
      },
      'ai': {
        'enabled': aiEnabled,
        'provider': aiProvider,
        'endpoint': _aiEndpointController.text,
        'model': _aiModelController.text,
        'api_key': _aiApiKeyController.text,
        'proxy': _aiProxyController.text,
        'temperature': aiTemperature,
        'max_tokens': aiMaxTokens.toInt(),
      },
    };

    BackendService.instance.saveConfig(config).then((success) {
      if (success) {
        UpdateService().updateConfig();
      }
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? AppLocalizations.of(context)!.configSaved : AppLocalizations.of(context)!.configSaveFailed),
          backgroundColor: success ? null : Theme.of(context).colorScheme.error,
        ),
      );
    });
  }
}
