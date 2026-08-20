import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders title, subtitle, icon and child correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No Items Found',
            subtitle: 'Try searching for something else.',
            child: Text('Extra Child Content'),
          ),
        ),
      ),
    );

    expect(find.text('No Items Found'), findsOneWidget);
    expect(find.text('Try searching for something else.'), findsOneWidget);
    expect(find.text('Extra Child Content'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
  });

  testWidgets('EmptyState applies semantic label correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.task_alt,
            title: 'No Active Tasks',
          ),
        ),
      ),
    );

    expect(find.text('No Active Tasks'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(EmptyState));
    expect(semantics.label, 'No Active Tasks');
  });
}
