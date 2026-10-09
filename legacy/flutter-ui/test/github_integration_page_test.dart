import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/config_repository.dart';
import 'package:frontend/features/settings/presentation/pages/github_integration_page.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _MemoryConfig extends ConfigRepository {
  _MemoryConfig() : super.test();

  @override
  Future<Map<String, dynamic>> loadConfig({bool forceRefresh = false}) async =>
      {
        'github': {'pat': ''},
      };
}

Future<void> render(WidgetTester tester, {double scale = 1}) async {
  final repository = _MemoryConfig();
  await tester.pumpWidget(
    Provider<ConfigRepository>.value(
      value: repository,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const GitHubIntegrationPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'PAT stays obscured until explicitly revealed and can be hidden again',
    (tester) async {
      await render(tester);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.enterText(field, 'fixture-only-token');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'fixture-only-token',
      );
      expect(tester.widget<TextField>(field).enableSuggestions, isFalse);
      expect(tester.widget<TextField>(field).autocorrect, isFalse);
    },
  );

  testWidgets(
    'small-window PAT editor keeps Save reachable at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(tester, scale: 2);
      expect(tester.takeException(), isNull);
      final save = find.byType(FilledButton);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
