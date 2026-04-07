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
  Widget buildTimer({
    DateTime? targetTime,
    Duration? totalDuration,
    required DateTime Function() nowProvider,
    Duration tickInterval = const Duration(seconds: 1),
    VoidCallback? onEightyPercentWarning,
    VoidCallback? onNinetyFivePercentWarning,
    VoidCallback? onExpired,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CountDownTimer(
        targetTime: targetTime,
        totalDuration: totalDuration,
        nowProvider: nowProvider,
        tickInterval: tickInterval,
        onEightyPercentWarning: onEightyPercentWarning,
        onNinetyFivePercentWarning: onNinetyFivePercentWarning,
        onExpired: onExpired,
      ),
    );
  }

  testWidgets('CountDownTimer counts down to zero (MM:SS format)', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 3));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      buildTimer(targetTime: targetTime, nowProvider: nowProvider),
    );

    expect(find.text('00:03'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('CountDownTimer clamps past target to zero', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 10);
    final targetTime = now.subtract(const Duration(seconds: 5));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      buildTimer(targetTime: targetTime, nowProvider: nowProvider),
    );

    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('CountDownTimer uses default target when null', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      buildTimer(nowProvider: nowProvider),
    );

    // Default is 1 minute = 60 seconds = "01:00"
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('CountDownTimer respects tickInterval', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 5));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      buildTimer(
        targetTime: targetTime,
        nowProvider: nowProvider,
        tickInterval: const Duration(seconds: 2),
      ),
    );

    expect(find.text('00:05'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:05'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:03'), findsOneWidget);
  });

  testWidgets('CountDownTimer can be disposed safely', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 2));
    DateTime nowProvider() => now;
    await tester.pumpWidget(
      buildTimer(targetTime: targetTime, nowProvider: nowProvider),
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('onEightyPercentWarning fires once at 20% remaining', (
    WidgetTester tester,
  ) async {
    // 100-second timer; 80 % = 80 s elapsed = 20 s remaining.
    int warningCount = 0;
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 100));
    DateTime nowProvider() => now;

    await tester.pumpWidget(
      buildTimer(
        targetTime: targetTime,
        totalDuration: const Duration(seconds: 100),
        nowProvider: nowProvider,
        tickInterval: const Duration(seconds: 1),
        onEightyPercentWarning: () => warningCount++,
      ),
    );

    // Advance to 79 s elapsed (21 s remaining) — no warning yet.
    now = now.add(const Duration(seconds: 79));
    await tester.pump(const Duration(seconds: 79));
    expect(warningCount, 0);

    // Advance to 80 s elapsed (20 s remaining) — warning should fire.
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(); // flush post-frame callbacks
    expect(warningCount, 1);

    // Advance further — should not fire again.
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(warningCount, 1);
  });

  testWidgets('onNinetyFivePercentWarning fires once at 5% remaining', (
    WidgetTester tester,
  ) async {
    // 100-second timer; 95% = 95 s elapsed = 5 s remaining.
    int warningCount = 0;
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 100));
    DateTime nowProvider() => now;

    await tester.pumpWidget(
      buildTimer(
        targetTime: targetTime,
        totalDuration: const Duration(seconds: 100),
        nowProvider: nowProvider,
        tickInterval: const Duration(seconds: 1),
        onNinetyFivePercentWarning: () => warningCount++,
      ),
    );

    // Advance to 94 s elapsed (6 s remaining) — no warning yet.
    now = now.add(const Duration(seconds: 94));
    await tester.pump(const Duration(seconds: 94));
    expect(warningCount, 0);

    // Advance to 95 s elapsed (5 s remaining) — warning fires.
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(warningCount, 1);

    // Should not fire again.
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(warningCount, 1);
  });

  testWidgets('onExpired fires when countdown reaches zero', (
    WidgetTester tester,
  ) async {
    int expiredCount = 0;
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final targetTime = now.add(const Duration(seconds: 2));
    DateTime nowProvider() => now;

    await tester.pumpWidget(
      buildTimer(
        targetTime: targetTime,
        totalDuration: const Duration(seconds: 2),
        nowProvider: nowProvider,
        tickInterval: const Duration(seconds: 1),
        onExpired: () => expiredCount++,
      ),
    );

    expect(expiredCount, 0);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(expiredCount, 1);

    // Should not fire again.
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(expiredCount, 1);
  });

  testWidgets('80% warning does not fire when 95% already fired', (
    WidgetTester tester,
  ) async {
    // If a timer starts already past 95%, the 80% callback should not fire —
    // only the 95% one should.
    int eightyCount = 0;
    int ninetyFiveCount = 0;
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    // Start the clock 96 seconds in for a 100-second timer → 4 s remaining.
    final targetTime = now.add(const Duration(seconds: 4));
    DateTime nowProvider() => now;

    await tester.pumpWidget(
      buildTimer(
        targetTime: targetTime,
        totalDuration: const Duration(seconds: 100),
        nowProvider: nowProvider,
        tickInterval: const Duration(seconds: 1),
        onEightyPercentWarning: () => eightyCount++,
        onNinetyFivePercentWarning: () => ninetyFiveCount++,
      ),
    );

    await tester.pump(); // flush post-frame callbacks from initState
    expect(eightyCount, 0);
    expect(ninetyFiveCount, 1);
  });
}
