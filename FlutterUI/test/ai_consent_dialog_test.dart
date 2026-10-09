import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/ai_consent_dialog.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';
import 'package:frontend/l10n/app_localizations.dart';

const _summary = AiConsentSummary(
  providerName: 'Example AI',
  destination: 'https://api.example.invalid/v1',
  model: 'example-model',
  purpose: "Explain an application's purpose and value",
  dataCategories: ['app_name', 'app_description'],
  promptCharacters: 42,
  payloadSha256:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  systemPrompt: 'Reply concisely.',
  userPrompt: 'Describe the application.',
);

Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showAiConsentDialog(context, _summary),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows concise Chinese consent copy and friendly categories', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Locale('zh')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('确认这一次 AI 请求'), findsOneWidget);
    final aiMark = find.descendant(
      of: find.byType(AiMark),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(aiMark), const Size(32, 32));
    expect(find.text('应用名称 · 应用描述'), findsOneWidget);
    expect(find.text('app_name'), findsNothing);
    expect(find.text('暂不发送'), findsOneWidget);

    final confirm = find.widgetWithText(FilledButton, '确认并发送一次');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('uses English consent copy when the UI locale is English', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Review this AI request'), findsOneWidget);
    expect(find.text('App name · App description'), findsOneWidget);
    expect(find.text('Confirm and send once'), findsOneWidget);
    expect(find.text('确认这一次 AI 请求'), findsNothing);
  });
}
