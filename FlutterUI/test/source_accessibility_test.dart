import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/features/task_manager/presentation/widgets/installed_tab.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'empty state announces one header and preserves actionable child',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.search_off,
                title: 'No matching packages',
                subtitle: 'Try another source',
                child: TextButton(onPressed: null, child: Text('Search again')),
              ),
            ),
          ),
        );
        final heading = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'No matching packages\nTry another source',
        );
        final node = tester.getSemantics(heading);
        expect(node.label, 'No matching packages\nTry another source');
        expect(node.flagsCollection.isHeader, isTrue);
        expect(find.text('Search again'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'source filters expose localized hints and activate the actual source',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InstalledTab(
              isLoading: false,
              selectedSourceFilter: 'all',
              filteredApps: const [],
              filterScrollController: controller,
              onSourceFilterSelected: (source) => selected = source,
              availableFilters: const ['all', 'apt'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(ChoiceChip, 'apt');
      expect(chip, findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(chip))!;
      expect(
        tester.widget<ChoiceChip>(chip).tooltip,
        l10n.sourceFilterSemantics('apt'),
      );
      await tester.tap(chip);
      expect(selected, 'apt');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'many source filters stay lazy and selectable at large text scale',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: InstalledTab(
                  isLoading: false,
                  selectedSourceFilter: 'source-0',
                  filteredApps: const [],
                  filterScrollController: controller,
                  onSourceFilterSelected: (source) => selected = source,
                  availableFilters: List.generate(
                    30,
                    (index) => 'source-$index',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('source-29'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('source-29'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(Scrollbar),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 30,
      );
      await tester.tap(find.text('source-29'));
      expect(selected, 'source-29');
      expect(tester.takeException(), isNull);
    },
  );
}
