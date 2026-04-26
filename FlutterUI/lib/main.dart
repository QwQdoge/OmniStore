import 'package:flutter/material.dart';
import 'pages/homepage.dart';
import 'pages/searchpage.dart';
import 'pages/settingpage.dart';
import 'pages/download_page.dart';
import 'services/backend_service.dart';

void main() => runApp(const OmnistoreApp());

class OmnistoreApp extends StatelessWidget {
  const OmnistoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 按照用户要求，主色调改为经典的 Material 3 Blue
    const seedColor = Color(0xFF0B57D0);

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
    const DownloadPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // 背景使用最底层的 surface 颜色
      backgroundColor: colorScheme.surface,
      // Chrome OS 风格的全局顶部标题栏
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        // 左侧 Logo
        leadingWidth: 90,
        leading: Center(
          child: Icon(
            Icons.shop_two_rounded, // 类似 Play Store 的图标
            color: colorScheme.primary,
            size: 32,
          ),
        ),
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GestureDetector(
              onTap: () {
                if (_selectedIndex != 1) {
                  setState(() => _selectedIndex = 1);
                }
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Search apps & games',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.mic_none_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              'U',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // 左侧导航列：Google Play 宽屏布局风格
          _buildSideBar(colorScheme),

          // 右侧内容区：Google Play 招牌的大圆角容器
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              decoration: BoxDecoration(
                // 纯净背景，类似于 Google Play 的平铺感
                color: theme.brightness == Brightness.light
                    ? Colors.white
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
          // 中间导航项
          Expanded(
            child: NavigationRail(
              selectedIndex: _selectedIndex > 2 ? null : _selectedIndex,
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
    return ValueListenableBuilder<bool>(
      valueListenable: BackendService.isDownloading,
      builder: (context, isDownloading, child) {
        return ValueListenableBuilder<double?>(
          valueListenable: BackendService.globalProgress,
          builder: (context, progress, child) {
            return Tooltip(
              message: isDownloading
                  ? "正在执行任务: ${BackendService.globalStatus.value}"
                  : "查看下载队列",
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _selectedIndex == 3
                      ? colorScheme.primary
                      : isDownloading
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isDownloading)
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    IconButton(
                      onPressed: () {
                        setState(() => _selectedIndex = 3);
                      },
                      icon: Icon(
                        isDownloading
                            ? Icons.downloading_rounded
                            : Icons.download_for_offline_rounded,
                        color: _selectedIndex == 3
                            ? colorScheme.onPrimary
                            : isDownloading
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
