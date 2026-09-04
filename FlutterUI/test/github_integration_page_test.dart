import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/features/settings/presentation/pages/github_integration_page.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('GitHubIntegrationPage renders correctly and toggles PAT visibility', (
    WidgetTester tester,
  ) async {
    final configRepo = ConfigRepository.test(
      saveDebounce: Duration.zero,
      desktopWriter: (_) async => true,
    );

    await tester.pumpWidget(
      Provider<ConfigRepository>.value(
        value: configRepo,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GitHubIntegrationPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Initial state: obscureText is true
    TextField textField = tester.widget(find.byType(TextField));
    expect(textField.obscureText, isTrue);

    // Find visibility toggle button
    final toggleFinder = find.byTooltip('Show password');
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 300));

    textField = tester.widget(find.byType(TextField));
    expect(textField.obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
