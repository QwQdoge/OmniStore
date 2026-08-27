import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders title, subtitle, icon, and optional child correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off,
            title: 'No Results Found',
            subtitle: 'Try searching for something else.',
            child: Text('Custom Action'),
          ),
        ),
      ),
    );

    expect(find.text('No Results Found'), findsOneWidget);
    expect(find.text('Try searching for something else.'), findsOneWidget);
    expect(find.text('Custom Action'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });
}
