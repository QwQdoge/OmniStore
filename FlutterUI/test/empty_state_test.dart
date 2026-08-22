import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders icon, title, subtitle, and child correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Items',
            subtitle: 'Check back later',
            child: Text('Action Button Placeholder'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('No Items'), findsOneWidget);
    expect(find.text('Check back later'), findsOneWidget);
    expect(find.text('Action Button Placeholder'), findsOneWidget);
  });

  testWidgets('EmptyState exposes consolidated Semantics node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No Results Found',
            subtitle: 'Try searching with different keywords',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('No Results Found. Try searching with different keywords'),
      findsOneWidget,
    );

    handle.dispose();
  });
}
