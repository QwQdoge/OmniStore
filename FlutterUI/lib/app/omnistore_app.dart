import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/app/main_navigation.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/onboarding/welcome_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:frontend/data/repositories/package_repository.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

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
    // Watch SettingsController for reactive theme changes
    final settings = context.watch<SettingsController>();

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
      themeMode: settings.themeMode,
      locale: settings.locale,
      theme: OmnistoreTheme.light(fontFamily: settings.fontFamily),
      darkTheme: OmnistoreTheme.dark(fontFamily: settings.fontFamily),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child!,
        );
      },
      initialRoute: _isFirstRun ? '/welcome' : '/home',
      routes: {
        '/welcome': (context) => WelcomePage(
              onFinish: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
        '/home': (context) => const MainNavigationEntry(),
      },
      onGenerateRoute: (routeSettings) {
        if (routeSettings.name != null && routeSettings.name!.startsWith('/app/')) {
          final appId = Uri.decodeComponent(routeSettings.name!.substring(5));
          final app = routeSettings.arguments as AppPackage?;
          if (app != null) {
            return MaterialPageRoute(
              settings: routeSettings,
              builder: (context) => AppDetailsPage(app: app),
            );
          } else {
            return MaterialPageRoute(
              settings: routeSettings,
              builder: (context) => FutureBuilder<Map<String, dynamic>>(
                future: PackageRepository().getAppDetails(appId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Error')),
                      body: const Center(child: Text('App details not found')),
                    );
                  }
                  final appDetails = snapshot.data!;
                  final appPackage = AppPackage.fromJson(appDetails);
                  return AppDetailsPage(app: appPackage);
                },
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
