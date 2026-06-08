import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/app/main_navigation.dart';
import 'package:frontend/core/theme/omnistore_theme.dart';
import 'package:frontend/features/onboarding/welcome_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

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
      theme: OmnistoreTheme.light(),
      darkTheme: OmnistoreTheme.dark(),
      home: _isFirstRun
          ? WelcomePage(
              onFinish: () => setState(() => _isFirstRun = false),
            )
          : const MainNavigationEntry(),
    );
  }
}
