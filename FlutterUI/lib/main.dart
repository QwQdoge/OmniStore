import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/backend/repositories/ai_repository.dart';
import 'package:frontend/backend/repositories/config_repository.dart';
import 'package:frontend/backend/repositories/package_repository.dart';
import 'package:frontend/backend/repositories/task_repository.dart';
import 'package:frontend/core/layout/adaptive_navigation_shell.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/core/platform/desktop_window_service.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/apps/apps_page.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/features/explore/presentation/pages/category_page.dart';
import 'package:frontend/features/explore/presentation/pages/flatpak_store_page.dart';
import 'package:frontend/features/explore/presentation/pages/github_store_page.dart';
import 'package:frontend/features/explore/presentation/pages/search_page.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:frontend/features/onboarding/welcome_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/settings/presentation/pages/tweaks_page.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/features/task_manager/presentation/pages/download_page.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/services/l10n_service.dart';
import 'package:frontend/services/update_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart' as wm;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configRepo = ConfigRepository();
  final packageRepo = PackageRepository();
  final taskRepo = TaskRepository();
  final aiRepo = AIRepository();

  Map<String, dynamic> config = {};
  late final SharedPreferences prefs;

  try {
    final results = await Future.wait([
      DesktopWindowService.initialize().timeout(const Duration(seconds: 5)),
      configRepo.loadConfig().timeout(const Duration(seconds: 10)),
      SharedPreferences.getInstance(),
    ]);
    config = (results[1] as Map<String, dynamic>?) ?? {};
    prefs = results[2] as SharedPreferences;
  } catch (e) {
    debugPrint('Initialization error: $e');
    prefs = await SharedPreferences.getInstance();
  }
  await L10nService.init(config);

  final githubToken = config['github']?['token'] as String?;

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: configRepo),
        Provider.value(value: packageRepo),
        Provider.value(value: taskRepo),
        Provider.value(value: aiRepo),
        Provider(
          create: (_) => GitHubClient(
            prefs: prefs,
            token: githubToken,
          ),
        ),
        ChangeNotifierProvider(create: (_) => NavigationController()),
        ChangeNotifierProvider(
          create: (_) => SettingsController(configRepo)..loadConfig(),
        ),
        ChangeNotifierProvider(
          create: (_) => BrowseController(packageRepo)..fetchRecommendations(),
        ),
        ChangeNotifierProvider(create: (_) => TaskController(taskRepo)),
      ],
      child: OmnistoreApp(initialConfig: config),
    ),
  );
}

class OmnistoreApp extends StatefulWidget {
  const OmnistoreApp({super.key, required this.initialConfig});

  final Map<String, dynamic> initialConfig;

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
      themeMode: ThemeMode.system,
      theme: OmnistoreTheme.light(),
      darkTheme: OmnistoreTheme.dark(),
      home: _isFirstRun
          ? WelcomePage(
              onFinish: () {
                setState(() => _isFirstRun = false);
              },
            )
          : const MainNavigationEntry(),
    );
  }
}

class MainNavigationEntry extends StatefulWidget {
  const MainNavigationEntry({super.key});

  @override
  State<MainNavigationEntry> createState() => _MainNavigationEntryState();
}

class _MainNavigationEntryState extends State<MainNavigationEntry>
    with wm.WindowListener {
  static const _pages = <Widget>[
    HomePage(),
    CategoryPage(),
    SearchPage(autoFocus: false),
    TweaksPage(),
    DownloadPage(),
    AppsPage(),
    GitHubStorePage(),
    FlatpakStorePage(),
  ];

  @override
  void initState() {
    super.initState();
    if (DesktopWindowService.isSupported) {
      wm.windowManager.addListener(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _initUpdateService(AppLocalizations.of(context)!);
        }
      });
    });
  }

  Future<void> _initUpdateService(AppLocalizations l10n) async {
    try {
      await UpdateService().init().timeout(const Duration(seconds: 10));
      await UpdateService().updateConfig(l10n).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('UpdateService initialization failed: $e');
    }
  }

  @override
  void dispose() {
    if (DesktopWindowService.isSupported) {
      wm.windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final settings = context.read<SettingsController>();
    final closeToTray = settings.config['ui']?['close_to_tray'] ?? true;

    if (closeToTray) {
      await wm.windowManager.hide();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.runningInBackground),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        UpdateService().showSimpleNotification(
          l10n.omnistore,
          l10n.runningInBackground,
        );
      }
    } else {
      await _handleFullExit();
    }
  }

  Future<void> _handleFullExit() async {
    try {
      await Process.run('pkill', ['omnistore-daemon']);
      await Process.run('pkill', ['-f', 'python/main.py']);
      await Process.run('pkill', ['python_server']);
    } catch (e) {
      debugPrint('Process cleanup error: $e');
    }

    await wm.windowManager.setPreventClose(false);
    await wm.windowManager.close();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final l10n = AppLocalizations.of(context)!;

    final primary = [
      NavDestination(
        index: 0,
        icon: Icons.apps_rounded,
        selectedIcon: Icons.apps,
        label: l10n.explore,
      ),
      NavDestination(
        index: 1,
        icon: Icons.grid_view_rounded,
        selectedIcon: Icons.grid_view,
        label: l10n.category,
      ),
      NavDestination(
        index: 6,
        icon: Icons.code_outlined,
        selectedIcon: Icons.code_rounded,
        label: l10n.githubStore,
      ),
      NavDestination(
        index: 5,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: l10n.installedApps,
      ),
      NavDestination(
        index: 3,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: l10n.settings,
      ),
    ];

    final secondary = [
      NavDestination(
        index: 7,
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag_rounded,
        label: l10n.flatpakStore,
      ),
    ];

    final titles = {
      0: l10n.explore,
      1: l10n.category,
      2: l10n.search,
      3: l10n.settings,
      4: l10n.downloads,
      5: l10n.installedApps,
      6: l10n.githubStore,
      7: l10n.flatpakStore,
    };

    return AdaptiveNavigationShell(
      destinations: primary,
      secondaryDestinations: secondary,
      pageTitle: titles[nav.selectedIndex] ?? '',
      pageChild: _pages[nav.selectedIndex],
      showSearch: nav.selectedIndex != 2,
      onSearch: () => nav.setIndex(2),
      useWindowTitleBar: DesktopWindowService.isSupported,
    );
  }
}
