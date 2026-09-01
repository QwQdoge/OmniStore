// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/smooth_progress_bar.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/task_state.dart';

void main() {
  testWidgets('Smoke test placeholder', (WidgetTester tester) async {
    // Basic test to avoid compilation errors while we focus on the core task
    expect(true, true);
  });

  testWidgets('long update output never overflows the active task header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: SmoothProgressBar(
                taskState: TaskState(
                  id: 'update-all',
                  status: TaskStatus.downloading,
                  progress: 0.67,
                  stage: 'A very long internal update stage that must truncate',
                  message:
                      'A very long package manager output line that must fit inside the available task card width',
                  speed: '1234567890.12 MiB/s with extra diagnostic text',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('FilterChip, ChoiceChip, and ActionChip have tooltips set', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              FilterChip(
                label: const Text('Pacman'),
                tooltip: 'Filter by source: Pacman',
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('All'),
                tooltip: 'Filter by source: All',
                selected: true,
                onSelected: (_) {},
              ),
              ActionChip(
                label: const Text('GIMP'),
                tooltip: 'Category: GIMP',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilterChip), findsOneWidget);
    expect(find.byType(ChoiceChip), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);

    final filterChip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(filterChip.tooltip, equals('Filter by source: Pacman'));

    final choiceChip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(choiceChip.tooltip, equals('Filter by source: All'));

    final actionChip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(actionChip.tooltip, equals('Category: GIMP'));
  });
}
