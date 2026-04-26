import 'package:flutter/material.dart';
import 'package:frontend/services/backend_service.dart';

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
            title: const Text('设置'),
            centerTitle: false,
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.done_all),
                  label: const Text('保存并应用'),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('包管理器'),
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
                _buildSectionTitle('结果优先级（权重）'),
                _buildGroupCard([
                  _buildSliderTile(
                    'Pacman',
                    pacmanPriority,
                    (v) => setState(() => pacmanPriority = v),
                  ),
                  _buildSliderTile(
                    'AUR',
                    aurPriority,
                    (v) => setState(() => aurPriority = v),
                  ),
                  _buildSliderTile(
                    'Flatpak',
                    flatpakPriority,
                    (v) => setState(() => flatpakPriority = v),
                  ),
                  _buildSliderTile(
                    'AppImage',
                    appimagePriority,
                    (v) => setState(() => appimagePriority = v),
                  ),
                  _buildSliderTile(
                    '最大结果数',
                    maxResults,
                    (v) => setState(() => maxResults = v),
                    max: 500,
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('界面个性化'),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('主题色种子'),
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
                    title: const Text('外观模式'),
                    trailing: DropdownButton<String>(
                      value: appearance,
                      underline: const SizedBox(),
                      onChanged: (v) => setState(() => appearance = v!),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                        DropdownMenuItem(value: 'light', child: Text('浅色模式')),
                        DropdownMenuItem(value: 'dark', child: Text('深色模式')),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionTitle('系统与日志'),
                _buildGroupCard([
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('日志记录等级'),
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
      'ui': {'appearance': appearance, 'color_seed': colorSeed},
      'logging': {'level': logLevel},
    };

    BackendService().saveConfig(config).then((success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '配置已保存，部分设置重启生效' : '保存配置失败'),
          backgroundColor: success ? null : Theme.of(context).colorScheme.error,
        ),
      );
    });
  }
}
