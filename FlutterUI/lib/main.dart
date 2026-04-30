import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/homepage.dart';
import 'pages/searchpage.dart';
import 'pages/settingpage.dart';
import 'pages/download_page.dart';
import 'services/backend_service.dart';
import 'services/l10n_service.dart';
import 'services/update_service.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 750),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
  });

  // 初始化配置和语言
  final config = await BackendService().loadConfig();
  await L10nService.init(config);

  // 初始化更新服务
  await UpdateService().init();
  
  runApp(const OmnistoreApp());
}

class OmnistoreApp extends StatelessWidget {
  const OmnistoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 按照用户要求，主色调改为经典的 Material 3 Blue
    const seedColor = Color(0xFF0B57D0);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omnistore',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],

          // 1. 实现“跟随系统亮暗”的关键：
          themeMode: ThemeMode.system,

          // 亮色模式配置
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seedColor,
            brightness: Brightness.light, 
          ),

          // 暗色模式配置
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seedColor,
            brightness: Brightness.dark, 
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

class _MainNavigationEntryState extends State<MainNavigationEntry> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 这里可以处理关闭逻辑，比如隐藏到托盘
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
  int _selectedIndex = 0;

  final List<Widget> _subPages = [
    const HomePage(),
    const SearchPage(autoFocus: false),
    const SettingsPage(),
    const DownloadPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // 自定义标题栏
          _buildChromeTitleBar(colorScheme, theme),
          Expanded(
            child: Row(
              children: [
                // 左侧导航列
                _buildSideBar(colorScheme),
                // 右侧内容区
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                    decoration: BoxDecoration(
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
          ),
        ],
      ),
    );
  }

  Widget _buildChromeTitleBar(ColorScheme colorScheme, ThemeData theme) {
    return DragToMoveArea(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: colorScheme.surface,
        child: Row(
          children: [
            // Logo
            const SizedBox(width: 8),
            Icon(
              Icons.shop_two_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            // Title
            Text(
              "OmniStore",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            // Search Bar (Middle)
            Center(
              child: SizedBox(
                height: 32,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => setState(() => _selectedIndex = 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.searchHint,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Window Controls
            Row(
              children: [
                _buildWindowButton(
                  icon: Icons.minimize_rounded,
                  onPressed: () => windowManager.minimize(),
                  colorScheme: colorScheme,
                ),
                _buildWindowButton(
                  icon: Icons.crop_square_rounded,
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                  colorScheme: colorScheme,
                ),
                _buildWindowButton(
                  icon: Icons.close_rounded,
                  onPressed: () => windowManager.close(),
                  isClose: true,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isClose = false,
  }) {
    return Container(
      width: 46,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red.withValues(alpha: 0.8) : colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
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
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.apps_outlined),
                  selectedIcon: const Icon(Icons.apps_rounded),
                  label: Text(AppLocalizations.of(context)!.explore),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.search_rounded),
                  selectedIcon: const Icon(Icons.manage_search_rounded),
                  label: Text(AppLocalizations.of(context)!.search),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: Text(AppLocalizations.of(context)!.settings),
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
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: UpdateService().availableUpdates,
      builder: (context, updates, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildDownloadButtonBase(colorScheme),
            if (updates.isNotEmpty)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 2),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    updates.length.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadButtonBase(ColorScheme colorScheme) {
    return ValueListenableBuilder<bool>(
      valueListenable: BackendService.isDownloading,
      builder: (context, isDownloading, child) {
        return ValueListenableBuilder<double?>(
          valueListenable: BackendService.globalProgress,
          builder: (context, progress, child) {
            return Tooltip(
              message: isDownloading
                  ? "${AppLocalizations.of(context)!.searching} ${BackendService.globalStatus.value}"
                  : AppLocalizations.of(context)!.downloads,
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
