import 'package:flutter/material.dart';
import 'package:frontend/bridges/search_bridge.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 本地配置状态（对应你的配置文件结构）
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent, // 背景由外层容器提供
      appBar: AppBar(
        title: const Text("设置"),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.done_all),
            label: const Text("保存并应用"),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // --- 搜索源设置 ---
          _buildSectionTitle("搜索源管理"),
          _buildGroupCard([
            _buildSwitchTile("Pacman (官方库)", pacmanEnabled, (v) => setState(() => pacmanEnabled = v)),
            _buildSwitchTile("AUR (用户库)", aurEnabled, (v) => setState(() => aurEnabled = v)),
            _buildSwitchTile("Flatpak", flatpakEnabled, (v) => setState(() => flatpakEnabled = v)),
            _buildSwitchTile("AppImage", appimageEnabled, (v) => setState(() => appimageEnabled = v)),
          ]),

          const SizedBox(height: 24),

          // --- 搜索优先级 ---
          _buildSectionTitle("结果优先级 (权重)"),
          _buildGroupCard([
            _buildSliderTile("Pacman", pacmanPriority, (v) => setState(() => pacmanPriority = v)),
            _buildSliderTile("AUR", aurPriority, (v) => setState(() => aurPriority = v)),
            _buildSliderTile("Flatpak", flatpakPriority, (v) => setState(() => flatpakPriority = v)),
            _buildSliderTile("AppImage", appimagePriority, (v) => setState(() => appimagePriority = v)),
            _buildSliderTile("最大结果数", maxResults, (v) => setState(() => maxResults = v), max: 500),
          ]),

          const SizedBox(height: 24),

          // --- UI 外观 ---
          _buildSectionTitle("界面个性化"),
          _buildGroupCard([
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text("主题色种子"),
              subtitle: Text(colorSeed),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(int.parse(colorSeed.replaceAll('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () {
                // 这里以后可以集成颜色选择器
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_medium_outlined),
              title: const Text("外观模式"),
              trailing: DropdownButton<String>(
                value: appearance,
                underline: const SizedBox(),
                onChanged: (String? newValue) {
                  setState(() => appearance = newValue!);
                },
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                  DropdownMenuItem(value: 'light', child: Text('浅色模式')),
                  DropdownMenuItem(value: 'dark', child: Text('深色模式')),
                ],
              ),
            ),
          ]),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI 构建组件 ---

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

  Widget _buildSliderTile(String title, double value, Function(double) onChanged, {double max = 100}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    // 构造最终的 JSON 并传给后端
    final config = {
      "search": {
        "sources": {
          "pacman": pacmanEnabled,
          "aur": aurEnabled,
          "flatpak": flatpakEnabled,
          "appimage": appimageEnabled,
        },
        "max_results": maxResults.toInt(),
      },
      "priority": {
        "pacman": pacmanPriority.toInt(),
        "aur": aurPriority.toInt(),
        "flatpak": flatpakPriority.toInt(),
        "appimage": appimagePriority.toInt(),
      },
      "ui": {
        "appearance": appearance,
        "color_seed": colorSeed,
      }
    };
    
    // 调用 BackendService.saveConfig(config)
    BackendService().saveConfig(config).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("配置已保存，部分设置重启生效")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("保存配置失败")),
        );
      }
    });
  }
}