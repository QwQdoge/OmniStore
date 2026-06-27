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
import 'package:frontend/core/widgets/skeleton.dart';

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
    return Selector<
      SettingsController,
      ({
        ThemeMode themeMode,
        Locale? locale,
        String fontFamily,
        double fontScale,
      })
    >(
      selector: (context, settings) => (
        themeMode: settings.themeMode,
        locale: settings.locale,
        fontFamily: settings.fontFamily,
        fontScale: settings.fontScale,
      ),
      builder: (context, data, _) {
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
          themeMode: data.themeMode,
          locale: data.locale,
          theme: OmnistoreTheme.light(fontFamily: data.fontFamily),
          darkTheme: OmnistoreTheme.dark(fontFamily: data.fontFamily),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(data.fontScale)),
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
            if (routeSettings.name != null &&
                routeSettings.name!.startsWith('/app/')) {
              final appId = Uri.decodeComponent(
                routeSettings.name!.substring(5),
              );
              final app = routeSettings.arguments as AppPackage?;
              if (app != null) {
                return MaterialPageRoute(
                  settings: routeSettings,
                  builder: (context) => AppDetailsPage(app: app),
                );
              } else {
                return MaterialPageRoute(
                  settings: routeSettings,
                  builder: (context) => _AppDetailsRouteLoader(appId: appId),
                );
              }
            }
            return null;
          },
        );
      },
    );
  }
}

class _AppDetailsRouteLoader extends StatefulWidget {
  final String appId;
  const _AppDetailsRouteLoader({required this.appId});

  @override
  State<_AppDetailsRouteLoader> createState() => _AppDetailsRouteLoaderState();
}

class _AppDetailsRouteLoaderState extends State<_AppDetailsRouteLoader> {
  late final Future<Map<String, dynamic>> _appDetailsFuture;

  @override
  void initState() {
    super.initState();
    _appDetailsFuture = PackageRepository().getAppDetails(widget.appId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _appDetailsFuture,
      builder: (context, snapshot) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.fastOutSlowIn,
          child: snapshot.connectionState == ConnectionState.waiting
              ? const Scaffold(
                  key: ValueKey('loading'),
                  body: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 80, height: 80, borderRadius: 28),
                        SizedBox(height: 16),
                        Skeleton(width: 200, height: 24),
                        SizedBox(height: 8),
                        Skeleton(width: double.infinity, height: 16),
                        SizedBox(height: 8),
                        Skeleton(width: 150, height: 16),
                      ],
                    ),
                  ),
                )
              : snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty
              ? Scaffold(
                  key: const ValueKey('error'),
                  appBar: AppBar(
                    title: Text(AppLocalizations.of(context)!.errorTitle),
                  ),
                  body: Center(
                    child: Text(
                      AppLocalizations.of(context)!.appDetailsNotFound,
                    ),
                  ),
                )
              : AppDetailsPage(
                  key: const ValueKey('loaded'),
                  app: AppPackage.fromJson(snapshot.data!),
                ),
        );
      },
    );
  }
}
