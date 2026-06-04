import 'package:flutter/material.dart';
import 'package:frontend/app/omnistore_app.dart';
import 'package:frontend/data/repositories/ai_repository.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/data/repositories/package_repository.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/core/navigation_controller.dart';
import 'package:frontend/core/network/github_client.dart';
import 'package:frontend/core/platform/desktop_window_service.dart';
import 'package:frontend/features/explore/presentation/controllers/browse_controller.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';
import 'package:frontend/services/l10n_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wires global providers and launches [OmnistoreApp].
Future<void> bootstrapOmniStore() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configRepo = ConfigRepository();
  final packageRepo = PackageRepository();
  final taskRepo = TaskRepository();
  final aiRepo = AIRepository();

  Map<String, dynamic> config = {};
  late final SharedPreferences prefs;

  try {
    // ⚡ Load config first to know window style
    config = await configRepo.loadConfig();
    final useSystemTitleBar = config['ui']?['use_system_title_bar'] ?? false;

    final results = await Future.wait([
      DesktopWindowService.initialize(useSystemTitleBar: useSystemTitleBar).timeout(const Duration(seconds: 5)),
      SharedPreferences.getInstance(),
    ]);
    prefs = results[2] as SharedPreferences;
  } catch (e) {
    debugPrint('Initialization error: $e');
    prefs = await SharedPreferences.getInstance();
  }

  await L10nService.init(config);
  final githubToken = config['github']?['pat'] as String?;

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: configRepo),
        Provider.value(value: packageRepo),
        Provider.value(value: taskRepo),
        Provider.value(value: aiRepo),
        Provider(
          create: (_) => GitHubClient(prefs: prefs, token: githubToken),
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
