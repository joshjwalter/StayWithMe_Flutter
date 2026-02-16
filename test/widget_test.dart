// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

//THIS IS ALL AI WRITTEN, I DONT KNOW HOW TO WRITE TESTS YET

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/countdown_timer.dart';

void main() {
  testWidgets('CountDownTimer counts down to zero', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 3));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CountDownTimer(targetTime: targetTime, nowProvider: nowProvider),
      ),
    );

    expect(find.text('3'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('CountDownTimer can be disposed safely', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 2));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CountDownTimer(targetTime: targetTime, nowProvider: nowProvider),
      ),
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });
}
