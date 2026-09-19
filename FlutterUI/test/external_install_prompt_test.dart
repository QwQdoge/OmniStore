import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/external_install_request.dart';
import 'package:frontend/features/external_install/external_install_prompt.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  testWidgets('external install stays behind OmniStore confirmation', (
    tester,
  ) async {
    const request = ExternalInstallRequest(
      packageId: 'wireplumber',
      source: 'Native',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showExternalInstallPrompt(context, request),
              child: const Text('Open request'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open request'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Install'), findsOneWidget);
    expect(find.textContaining('wireplumber'), findsOneWidget);
    expect(find.text('Native'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Install'), findsNothing);
  });
}
