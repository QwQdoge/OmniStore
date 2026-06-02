import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/features/package_browse/home_page.dart';
import 'package:frontend/features/package_browse/category_page.dart';
import 'package:frontend/features/package_browse/search_page.dart';
import 'package:frontend/features/package_browse/apps_page.dart';
import 'package:frontend/features/package_browse/github_store_page.dart';
import 'package:frontend/features/package_browse/flatpak_store_page.dart';
import 'package:frontend/features/settings/tweaks_page.dart';
import 'package:frontend/features/settings/settings_controller.dart';
import 'package:frontend/features/task_manager/download_page.dart';
import 'package:frontend/features/task_manager/task_controller.dart';
import 'package:frontend/features/package_browse/browse_controller.dart';
import 'package:frontend/features/onboarding/welcome_page.dart';
import 'package:frontend/backend/repositories/config_repository.dart';
import 'package:frontend/backend/repositories/package_repository.dart';
import 'package:frontend/backend/repositories/task_repository.dart';
import 'package:frontend/backend/repositories/ai_repository.dart';
import 'package:frontend/services/l10n_service.dart';
import 'package:frontend/services/update_service.dart';
import 'package:window_manager/window_manager.dart' as wm;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configRepo = ConfigRepository();
  final packageRepo = PackageRepository();
  final taskRepo = TaskRepository();
  final aiRepo = AIRepository();

  final results =
      await Future.wait([
        wm.windowManager.ensureInitialized().timeout(
          const Duration(seconds: 5),
        ),
        configRepo.loadConfig().timeout(const Duration(seconds: 10)),
      ]).catchError((e) {
        debugPrint("Initialization error: $e");
        return [null, <String, dynamic>{}];
      });

  final Map<String, dynamic> config =
      (results[1] as Map<String, dynamic>?) ?? {};
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

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: configRepo),
        Provider.value(value: packageRepo),
        Provider.value(value: taskRepo),
        Provider.value(value: aiRepo),
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
    const seedColor = Color(0xFF6750A4);

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.light,
        iconTheme: const IconThemeData(size: 24),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
        iconTheme: const IconThemeData(size: 24),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isFirstRun
          ? WelcomePage(
              onFinish: () {
                setState(() {
                  _isFirstRun = false;
                });
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
  late final List<Widget> _subPages;

  @override
  void initState() {
    super.initState();
    wm.windowManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          _initUpdateService(l10n);
        }
      });
    });

    _subPages = [
      const HomePage(),
      const CategoryPage(),
      const SearchPage(autoFocus: false),
      const TweaksPage(),
      const DownloadPage(),
      const AppsPage(),
      const GitHubStorePage(),
      const FlatpakStorePage(),
    ];
  }

  Future<void> _initUpdateService(AppLocalizations l10n) async {
    try {
      await UpdateService().init().timeout(const Duration(seconds: 10));
      await UpdateService()
          .updateConfig(l10n)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("UpdateService initialization failed: $e");
    }
  }

  @override
  void dispose() {
    wm.windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final settings = context.read<SettingsController>();
    final bool closeToTray = settings.config['ui']?['close_to_tray'] ?? true;

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
      debugPrint("Process cleanup error: $e");
    }

    await wm.windowManager.setPreventClose(false);
    await wm.windowManager.close();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nav = context.watch<NavigationController>();
    final task = context.watch<TaskController>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      bottomNavigationBar: task.isBusy
          ? Container(
              height: 32,
              color: colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${AppLocalizations.of(context)!.processing} ${task.status} ${task.speed}",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.progress != null)
                    Text(
                      "${(task.progress! * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
      body: Row(
        children: [
          _buildSideBar(context, colorScheme, nav),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context, colorScheme, nav),
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
                          key: ValueKey<int>(nav.selectedIndex),
                          child: _subPages[nav.selectedIndex],
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

  Widget _buildSideBar(
    BuildContext context,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    final items = [
      {'title': 'Explore', 'icon': Icons.apps_rounded, 'index': 0},
      {'title': 'Categories', 'icon': Icons.grid_view_rounded, 'index': 1},
      {'title': 'Installed', 'icon': Icons.inventory_2_rounded, 'index': 5},
      {'title': 'GitHub Store', 'icon': Icons.code_rounded, 'index': 6},
      {
        'title': 'Flatpak Store',
        'icon': Icons.shopping_bag_rounded,
        'index': 7,
      },
    ];

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildSideBarItem(
                context,
                item['index'] as int,
                item['icon'] as IconData,
                item['icon'] as IconData,
                item['title'] as String,
                colorScheme,
                nav,
              ),
            );
          }),
          const Spacer(),
          _buildSideBarItem(
            context,
            3,
            Icons.settings_rounded,
            Icons.settings_rounded,
            AppLocalizations.of(context)!.settings,
            colorScheme,
            nav,
          ),
          const SizedBox(height: 12),
          _buildDownloadButton(context, colorScheme, nav),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSideBarItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    final isSelected = nav.selectedIndex == index;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => nav.setIndex(index),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    String pageTitle = "";
    final titles = {
      0: AppLocalizations.of(context)!.explore,
      1: AppLocalizations.of(context)!.category,
      2: AppLocalizations.of(context)!.search,
      3: AppLocalizations.of(context)!.settings,
      4: AppLocalizations.of(context)!.downloads,
      5: "Installed Apps",
      6: "GitHub Store",
      7: "Flatpak Store",
    };
    pageTitle = titles[nav.selectedIndex] ?? "";

    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            pageTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -1.0,
            ),
          ),
          const Spacer(),
          if (nav.selectedIndex != 2)
            FilledButton.tonalIcon(
              onPressed: () => nav.setIndex(2),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(AppLocalizations.of(context)!.search),
            ),
          const SizedBox(width: 16),
          _buildUserAvatar(context, colorScheme, nav),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    return ListenableBuilder(
      listenable: UpdateService().availableUpdates,
      builder: (context, _) {
        final updates = UpdateService().availableUpdates.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildDownloadButtonBase(context, colorScheme, nav),
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
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    updates.length.toString(),
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadButtonBase(
    BuildContext context,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    final task = context.watch<TaskController>();
    return Tooltip(
      message: AppLocalizations.of(context)!.downloads,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: nav.selectedIndex == 4
              ? colorScheme.primary
              : task.isBusy
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (task.isBusy)
              CircularProgressIndicator(
                value: task.progress,
                strokeWidth: 3,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            IconButton(
              onPressed: () => nav.setIndex(4),
              icon: Icon(
                task.isBusy
                    ? Icons.downloading_rounded
                    : Icons.download_for_offline_rounded,
                color: nav.selectedIndex == 4
                    ? colorScheme.onPrimary
                    : task.isBusy
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(
    BuildContext context,
    ColorScheme colorScheme,
    NavigationController nav,
  ) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.settings),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 0) nav.setIndex(3);
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
}
