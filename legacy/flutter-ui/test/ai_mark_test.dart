import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';

void main() {
  testWidgets('AI mark stays icon sized in a wide dialog slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 560, child: AiMark(size: 32)),
        ),
      ),
    );

    final paint = find.descendant(
      of: find.byType(AiMark),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(paint), const Size(32, 32));
  });
}
