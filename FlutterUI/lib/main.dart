import 'package:flutter/material.dart';
import 'pages/homepage.dart';
import 'pages/searchpage.dart';
import 'pages/settingpage.dart';

void main() => runApp(const OmnistoreApp());

class OmnistoreApp extends StatelessWidget {
  const OmnistoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 定义统一的种子颜色
    const seedColor = Color(0xFF005FB8);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omnistore',

      // 1. 实现“跟随系统亮暗”的关键：
      themeMode: ThemeMode.system,

      // 亮色模式配置
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.light, // 修复：这里只能是 light
      ),

      // 暗色模式配置
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark, // 修复：这里只能是 dark
      ),

      home: const MainNavigationEntry(),
    );
  }
}

class MainNavigationEntry extends StatefulWidget {
  const MainNavigationEntry({super.key});

  @override
  State<MainNavigationEntry> createState() => _MainNavigationEntryState();
}

class _MainNavigationEntryState extends State<MainNavigationEntry> {
  int _selectedIndex = 0;

  final List<Widget> _subPages = [
    const HomePage(),
    const SearchPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // 背景使用最底层的 surface 颜色
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          // 左侧导航列：Google Play 宽屏布局风格
          _buildSideBar(colorScheme),

          // 右侧内容区：Google Play 招牌的大圆角容器
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              decoration: BoxDecoration(
                // 使用 surfaceContainer 营造出 M3 的分层感
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  // 使用这种曲线让切换更有 Google Play 的灵动感
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: _subPages[_selectedIndex],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 侧边栏布局：Logo + 导航 + 左下角图标
  Widget _buildSideBar(ColorScheme colorScheme) {
    return Container(
      width: 90, // 固定宽度
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // 顶部 Logo
          _buildLogo(colorScheme),

          // 中间导航项
          Expanded(
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.selected,
              backgroundColor: Colors.transparent,
              indicatorColor: colorScheme.secondaryContainer,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.apps_outlined),
                  selectedIcon: Icon(Icons.apps_rounded),
                  label: Text('Discover'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.manage_search_rounded),
                  label: Text('Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),

          // 2. 左下角下载图标（Google Play 管理入口风格）
          _buildDownloadButton(colorScheme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(ColorScheme colorScheme) {
    return Tooltip(
      message: "查看下载队列",
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () {
            // 这里以后可以弹出下载进度对话框
          },
          icon: Icon(
            Icons.download_for_offline_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_mosaic,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
