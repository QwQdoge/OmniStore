import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/l10n_service.dart';

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

      final log = config['logging'] ?? {};
      logLevel = log['level'] ?? 'INFO';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(L10nService.s('settings')),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.done_all),
                  label: Text(L10nService.s('save_apply')),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle(L10nService.s('language')),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: Text(L10nService.s('language')),
                    trailing: DropdownButton<Language>(
                      value: L10nService.language.value,
                      underline: const SizedBox(),
                      onChanged: (Language? v) {
                        if (v != null) {
                          setState(() => L10nService.setLanguage(v));
                        }
                      },
                      items: [
                        DropdownMenuItem(value: Language.zh, child: Text(L10nService.s('chinese'))),
                        DropdownMenuItem(value: Language.en, child: Text(L10nService.s('english'))),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(L10nService.s('package_manager')),
                _buildGroupCard([
                  _buildSwitchTile(
                    'Pacman（官方库）',
                    pacmanEnabled,
                    (v) => setState(() => pacmanEnabled = v),
                  ),
                  _buildSwitchTile(
                    'AUR（用户库）',
                    aurEnabled,
                    (v) => setState(() => aurEnabled = v),
                  ),
                  _buildSwitchTile(
                    'Flatpak',
                    flatpakEnabled,
                    (v) => setState(() => flatpakEnabled = v),
                  ),
                  _buildSwitchTile(
                    'AppImage',
                    appimageEnabled,
                    (v) => setState(() => appimageEnabled = v),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('结果源优先级 (拖动排序)'),
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
                            label = 'Pacman (官方)';
                            break;
                          case 'aur':
                            icon = Icons.cloud_outlined;
                            label = 'AUR (用户)';
                            break;
                          case 'flatpak':
                            icon = Icons.inventory_2_outlined;
                            label = 'Flatpak';
                            break;
                          default:
                            icon = Icons.insert_drive_file_outlined;
                            label = 'AppImage';
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
                _buildSectionTitle('搜索设置'),
                _buildGroupCard([
                  _buildSliderTile(
                    '最大显示结果数',
                    maxResults,
                    (v) => setState(() => maxResults = v),
                    max: 500,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(L10nService.s('appearance')),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(L10nService.s('theme_color')),
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
                    title: Text(L10nService.s('appearance_mode')),
                    trailing: DropdownButton<String>(
                      value: appearance,
                      underline: const SizedBox(),
                      onChanged: (v) => setState(() => appearance = v!),
                      items: [
                        DropdownMenuItem(value: 'system', child: Text(L10nService.s('system_mode'))),
                        DropdownMenuItem(value: 'light', child: Text(L10nService.s('light_mode'))),
                        DropdownMenuItem(value: 'dark', child: Text(L10nService.s('dark_mode'))),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle(L10nService.s('logging')),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(L10nService.s('log_level')),
                    subtitle: const Text('较低等级会显示更多详细信息'),
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
            max: max,
            divisions: max.toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
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
        'language': L10nService.languageCode,
      },
      'logging': {'level': logLevel},
    };

    BackendService().saveConfig(config).then((success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? L10nService.s('save_success') : L10nService.s('save_fail')),
          backgroundColor: success ? null : Theme.of(context).colorScheme.error,
        ),
      );
    });
  }
}
