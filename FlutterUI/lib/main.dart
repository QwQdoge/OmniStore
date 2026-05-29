import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/homepage.dart';
import 'pages/category_page.dart';
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
    wm.windowManager.ensureInitialized().timeout(const Duration(seconds: 5)),
    BackendService.instance.loadConfig().timeout(const Duration(seconds: 10)),
  ]).catchError((e) {
    debugPrint("Initialization error: $e");
    return [null, <String, dynamic>{}];
  });

  final Map<String, dynamic> config = (results[1] as Map<String, dynamic>?) ?? {};

  // 初始化语言服务（依赖配置）
  await L10nService.init(config);

  wm.WindowOptions windowOptions = const wm.WindowOptions(
    size: Size(1150, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: wm.TitleBarStyle.normal,
    title: 'OmniStore',
  );

  wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
    await wm.windowManager.setTitle('OmniStore');
    await wm.windowManager.setSkipTaskbar(false);
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
        Locale('ja'),
        Locale('es'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
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
          ? WelcomePage(
              onFinish: () async {
                await BackendService.instance.loadConfig();
                setState(() {
                  _isFirstRun = false;
                });
              },
            )
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

    // 监听全局导航状态
    BackendService.navigationIndex.addListener(_onNavigationRequested);

    // 延迟初始化更新服务与系统托盘，确保 UI 已渲染且环境检查更安全
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _initUpdateService();
      });
    });

    _subPages = [
      const HomePage(),
      const CategoryPage(),
      const SearchPage(autoFocus: false),
      const SettingsPage(),
      const DownloadPage(),
    ];
  }

  void _onNavigationRequested() {
    if (mounted) {
      setState(() {
        _selectedIndex = BackendService.navigationIndex.value;
      });
    }
  }

  Future<void> _initUpdateService() async {
    try {
      await UpdateService().init().timeout(const Duration(seconds: 10));
      await UpdateService().updateConfig().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("UpdateService initialization failed: $e");
    }
  }

  @override
  void dispose() {
    wm.windowManager.removeListener(this);
    BackendService.navigationIndex.removeListener(_onNavigationRequested);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 动态检查配置中的“关闭至托盘”设置
    final config = await BackendService.instance.loadConfig();
    final bool closeToTray = config['ui']?['close_to_tray'] ?? true;

    if (closeToTray) {
      await wm.windowManager.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OmniStore 正在后台运行，可通过托盘图标打开"),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(colorScheme),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: theme.brightness == Brightness.light
                          ? colorScheme.surface
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28.0),
                      clipBehavior: Clip.antiAlias,
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
          ),
        ],
      ),
    );
  }


  // 侧边栏布局：探索 + 左下角下载
  Widget _buildSideBar(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Tooltip(
            message: l10n.explore,
            child: _buildSideBarItem(0, Icons.explore_outlined, Icons.explore, l10n.explore, colorScheme),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: l10n.category,
            child: _buildSideBarItem(1, Icons.grid_view_outlined, Icons.grid_view_rounded, l10n.category, colorScheme),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: l10n.settings,
            child: _buildSideBarItem(3, Icons.settings_outlined, Icons.settings, l10n.settings, colorScheme),
          ),
          const Spacer(),
          _buildDownloadButton(colorScheme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSideBarItem(int index, IconData icon, IconData selectedIcon, String label, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        BackendService.navigationIndex.value = index;
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 标题栏下方的顶栏布局：标题 + 搜索 + 头像
  Widget _buildTopBar(ColorScheme colorScheme) {
    String pageTitle = "";
    if (_selectedIndex == 0) {
      pageTitle = AppLocalizations.of(context)!.explore;
    } else if (_selectedIndex == 1) {
      pageTitle = AppLocalizations.of(context)!.category;
    } else if (_selectedIndex == 2) {
      pageTitle = AppLocalizations.of(context)!.search;
    } else if (_selectedIndex == 3) {
      pageTitle = AppLocalizations.of(context)!.settings;
    } else if (_selectedIndex == 4) {
      pageTitle = AppLocalizations.of(context)!.downloads;
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: [
          Text(
            pageTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // 搜索按钮 (若不在搜索页则显示，点击切换到搜索页)
          if (_selectedIndex != 2)
            IconButton(
              onPressed: () => BackendService.navigationIndex.value = 2,
              icon: Icon(
                Icons.search_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
              tooltip: AppLocalizations.of(context)!.search,
            ),
          if (_selectedIndex != 1) const SizedBox(width: 12),
          // 用户头像
          _buildUserAvatar(colorScheme),
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
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              const Icon(Icons.login_rounded, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)?.explore ?? "Login"),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        // Only login handled here for now, settings is in sidebar
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          "M",
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
                  color: _selectedIndex == 4
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
                        BackendService.navigationIndex.value = 4;
                      },
                      icon: Icon(
                        isDownloading
                            ? Icons.downloading_rounded
                            : Icons.download_for_offline_rounded,
                        color: _selectedIndex == 4
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
