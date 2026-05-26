import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/homepage.dart';
import 'pages/searchpage.dart';
import 'pages/settingpage.dart';
import 'pages/download_page.dart';
import 'pages/welcome_page.dart';
import 'services/backend_service.dart';
import 'services/l10n_service.dart';
import 'services/update_service.dart';
import 'package:window_manager/window_manager.dart' as wm;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 并行初始化核心服务以提升加载速度
  final results = await Future.wait([
    wm.windowManager.ensureInitialized(),
    BackendService.instance.loadConfig(),
    UpdateService().init(),
  ]);

  final Map<String, dynamic> config = results[1] as Map<String, dynamic>;

  // 初始化语言服务（依赖配置）
  await L10nService.init(config);
  
  // 更新服务同步最新配置
  await UpdateService().updateConfig();

  wm.WindowOptions windowOptions = const wm.WindowOptions(
    size: Size(1150, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: wm.TitleBarStyle.normal,
  );

  wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
    await wm.windowManager.show();
    await wm.windowManager.focus();
    await wm.windowManager.setPreventClose(true);
  });
  
  runApp(OmnistoreApp(initialConfig: config));
}

class OmnistoreApp extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  const OmnistoreApp({super.key, required this.initialConfig});

  @override
  State<OmnistoreApp> createState() => _OmnistoreAppState();
}

class _OmnistoreAppState extends State<OmnistoreApp> {
  late bool _isFirstRun;

  @override
  void initState() {
    super.initState();
    _isFirstRun = widget.initialConfig['first_run'] == true;
  }

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

      home: _isFirstRun
          ? WelcomePage(onFinish: () {
              setState(() => _isFirstRun = false);
            })
          : MainNavigationEntry(initialConfig: widget.initialConfig),
    );
  }
}

class MainNavigationEntry extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  const MainNavigationEntry({super.key, required this.initialConfig});

  @override
  State<MainNavigationEntry> createState() => _MainNavigationEntryState();
}

class _MainNavigationEntryState extends State<MainNavigationEntry> with wm.WindowListener {
  int _selectedIndex = 0;
  late final List<Widget> _subPages;

  @override
  void initState() {
    super.initState();
    wm.windowManager.addListener(this);
    _subPages = [
      const HomePage(),
      const SearchPage(autoFocus: false),
      const SettingsPage(),
      const DownloadPage(),
    ];
  }

  @override
  void dispose() {
    wm.windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 动态检查配置中的“关闭至托盘”设置
    final config = await BackendService.instance.loadConfig();
    final bool closeToTray = config['ui']?['close_to_tray'] ?? true;

    if (closeToTray) {
      await wm.windowManager.hide();
    } else {
      await wm.windowManager.setPreventClose(false);
      await wm.windowManager.close();
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: BackendService.isDownloading,
        builder: (context, isDownloading, _) {
          if (!isDownloading) return const SizedBox.shrink();
          return Container(
            height: 32,
            color: colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(
                    width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: BackendService.globalStatus,
                    builder: (context, status, _) => Text(
                      "正在处理: $status",
                      style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ValueListenableBuilder<double?>(
                  valueListenable: BackendService.globalProgress,
                  builder: (context, progress, _) => Text(
                    progress != null ? "${(progress * 100).toInt()}%" : "",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      body: Row(
        children: [
          // 左侧导航列
          _buildSideBar(colorScheme),
          // 右侧内容区
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOutExpo,
                  switchOutCurve: Curves.easeInOutExpo,
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
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // 顶部头像与搜索
          _buildUserAvatar(colorScheme),
          const SizedBox(height: 12),
          IconButton(
            onPressed: () => setState(() => _selectedIndex = 1),
            icon: Icon(Icons.search_rounded,
              color: _selectedIndex == 1 ? colorScheme.primary : colorScheme.onSurfaceVariant),
            tooltip: AppLocalizations.of(context)!.search,
          ),
          const SizedBox(height: 20),

          // 中间导航项 (移除设置，移入头像菜单)
          Expanded(
            child: NavigationRail(
              selectedIndex: _selectedIndex == 0 ? 0 : (_selectedIndex == 3 ? 1 : null),
              onDestinationSelected: (i) {
                if (i == 0) setState(() => _selectedIndex = 0);
                if (i == 1) setState(() => _selectedIndex = 3);
              },
              labelType: NavigationRailLabelType.none,
              backgroundColor: Colors.transparent,
              indicatorColor: colorScheme.secondaryContainer,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.apps_outlined),
                  selectedIcon: const Icon(Icons.apps_rounded),
                  label: Text(AppLocalizations.of(context)!.explore),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.download_done_rounded),
                  selectedIcon: const Icon(Icons.download_done_rounded),
                  label: Text(AppLocalizations.of(context)!.downloads),
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
                    style: TextStyle(color: colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserAvatar(ColorScheme colorScheme) {
    return PopupMenuButton<int>(
      offset: const Offset(40, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              const Icon(Icons.login_rounded, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)?.explore ?? "Login"), // 占位 Login
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              const Icon(Icons.settings_rounded, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.settings),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 1) setState(() => _selectedIndex = 2);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.purple, // 用户要求的紫色
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          "M", // 用户要求的M
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
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
