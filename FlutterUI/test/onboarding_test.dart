import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/onboarding/welcome_page.dart';
import 'package:frontend/features/settings/presentation/controllers/settings_controller.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets('Onboarding WelcomePage renders intro correctly and navigates steps',  (WidgetTester tester) async {
    final configRepo = ConfigRepository();
    final settingsController = SettingsController(configRepo);

    // Initial mock load of config
    await settingsController.loadConfig();

    bool finished = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settingsController),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
          ],
          home: Scaffold(
            body: WelcomePage(
              onFinish: () {
                finished = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Page 1 renders intro with title and subtitle
    expect(find.text('Welcome to OmniStore'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Click "Get Started" to navigate to page 2 (Env Check)
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify Page 2 is shown
    expect(find.text('Step 2 of 4'), findsOneWidget);

    // Click "Next" to navigate to page 3 (Sources Config)
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 4'), findsOneWidget);

    // Click "Next" to navigate to page 4 (AI Config)
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Step 4 of 4'), findsOneWidget);

    // Click "Enter Store" to finish onboarding
    await tester.tap(find.byIcon(Icons.login_rounded));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });
}
