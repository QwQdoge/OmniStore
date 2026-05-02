import 'package:flutter/material.dart';
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
  bool includeAurUpdates = true;

  bool notificationsEnabled = true;
  bool progressNotifications = true;
  bool completionNotifications = true;
  double updateCheckInterval = 1;
  bool remindUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await BackendService().loadConfig();
    if (config.isEmpty) return;

    setState(() {
      final s = config['search'] ?? {};
      final src = s['sources'] ?? {};
      pacmanEnabled = src['pacman'] ?? true;
      aurEnabled = src['aur'] ?? true;
      flatpakEnabled = src['flatpak'] ?? true;
      appimageEnabled = src['appimage'] ?? true;
      maxResults = (s['max_results'] ?? 100).toDouble();

      final p = config['priority'] ?? {};
      pacmanPriority = (p['pacman'] ?? 100).toDouble();
      aurPriority = (p['aur'] ?? 80).toDouble();
      flatpakPriority = (p['flatpak'] ?? 60).toDouble();
      appimagePriority = (p['appimage'] ?? 40).toDouble();

      // 根据权重排序源
      var entries = p.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      sourceOrder =
          entries.map((e) => e.key.toString()).cast<String>().toList();
      // 补齐缺失的
      for (var s in ['pacman', 'aur', 'flatpak', 'appimage']) {
        if (!sourceOrder.contains(s)) sourceOrder.add(s);
      }

      final ui = config['ui'] ?? {};
      appearance = ui['appearance'] ?? 'system';
      colorSeed = ui['color_seed'] ?? '#CA6ECF';
      closeToTray = ui['close_to_tray'] ?? true;

      final log = config['logging'] ?? {};
      logLevel = log['level'] ?? 'INFO';

      final notify = config['notifications'] ?? {};
      notificationsEnabled = notify['enabled'] ?? true;
      progressNotifications = notify['progress'] ?? true;
      completionNotifications = notify['completion'] ?? true;

      final upConfig = config['updates'] ?? {};
      updateCheckInterval = (upConfig['check_interval_hours'] ?? 1).toDouble();
      remindUpdates = upConfig['remind_updates'] ?? true;
      includeAurUpdates = upConfig['include_aur_in_update_all'] ?? true;
    });
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
                  onPressed: _saveAll,
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
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = sourceOrder.removeAt(oldIndex);
                          sourceOrder.insert(newIndex, item);

                          // 根据新顺序重新分配权重 (100, 80, 60, 40)
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
                    onTap: () {}, // TODO: 颜色选择器
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
                  _buildSwitchTile(
                    AppLocalizations.of(context)!.closeToTray,
                    closeToTray,
                    (v) => setState(() => closeToTray = v),
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
                      // 触发更新所有
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.searching)),
                      );
                      await UpdateService().checkNow();
                      if (UpdateService().availableUpdates.value.isNotEmpty) {
                        // 如果有更新，跳转到下载页面
                        // 这里我们简单的通过通知用户或者直接开始逻辑
                        // 实际上用户通常希望看到进度，所以我们可以尝试开始更新第一个
                        // 或者在这里逻辑：UpdateService().startUpdate(...)
                        // 考虑到 UI 逻辑，跳转到索引 3 是最好的
                        // 我们需要访问 MainNavigationEntry 的状态，或者使用一个全局导航 key
                        // 在此 demo 中，我们先提示已检查到更新
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.foundUpdates(UpdateService().availableUpdates.value.length))),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: Text(AppLocalizations.of(context)!.resetOnboarding),
                    onTap: _resetOnboarding,
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
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
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
      final config = await BackendService().loadConfig();
      config['first_run'] = true;
      final success = await BackendService().saveConfig(config);
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

  void _saveAll() {
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
    };

    BackendService().saveConfig(config).then((success) {
      if (success) {
        UpdateService().updateConfig();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? AppLocalizations.of(context)!.configSaved : AppLocalizations.of(context)!.configSaveFailed),
          backgroundColor: success ? null : Theme.of(context).colorScheme.error,
        ),
      );
    });
  }
}
