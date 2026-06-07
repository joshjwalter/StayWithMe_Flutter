import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';
import 'package:stay_with_me_flutter/countdown_timer.dart';

/// Mutable clock for testing time-dependent behavior.
class TestClock {
  DateTime _currentTime;

  TestClock(this._currentTime);

  DateTime now() => _currentTime;

  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }
}

/// Mock API client that simulates server responses for testing.
class ScriptedAlarmApiClient extends AlarmApiClient {
  ScriptedAlarmApiClient({
    this.connectivityResponses = const [],
    this.startResult = const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'ok',
    ),
    this.cancelResult = const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'ok',
    ),
  }) : super(baseUrl: '');

  final List<Future<bool>> connectivityResponses;
  final AlarmRequestResult startResult;
  final AlarmRequestResult cancelResult;

  int connectivityCallCount = 0;

  @override
  Future<bool> checkConnectivity() {
    final index = connectivityCallCount;
    connectivityCallCount += 1;

    if (index < connectivityResponses.length) {
      return connectivityResponses[index];
    }
    // Return connected by default if no more responses
    return Future.value(true);
  }

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
  }) async {
    return startResult;
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({required String timerId}) async {
    return cancelResult;
  }
}

void main() {
  group('AlarmPage Timer Expiration', () {
    testWidgets('Timer expiration transitions to expired phase', (tester) async {
      // Create mutable clock for testing
      final clock = TestClock(DateTime(2025, 1, 1, 12, 0, 0));

      // Build widget with scripted API client that stays connected
      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: ScriptedAlarmApiClient(
              connectivityResponses: [
                Future.value(true), // Initial check
                Future.value(true), // Active polling
              ],
            ),
            nowProvider: clock.now,
          ),
        ),
      );

      // Start timer using the key
      final startButton = find.byKey(const Key('start_button'));
      expect(startButton, findsOneWidget);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Verify active phase started
      expect(find.byType(CountDownTimer), findsOneWidget);

      // Advance time past expiration (60 minutes + 1 second)
      clock.advance(const Duration(minutes: 61));

      // Trigger timer ticks to check for expiration
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify expired phase displayed
      expect(find.text('Timer expired'), findsOneWidget);
      expect(find.text('Alert sent to your emergency contacts.'), findsOneWidget);
    });

    testWidgets('Reset button returns to idle after expiration', (tester) async {
      // Create mutable clock for testing
      final clock = TestClock(DateTime(2025, 1, 1, 12, 0, 0));

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: ScriptedAlarmApiClient(
              connectivityResponses: [
                Future.value(true), // Initial check
                Future.value(true), // Active polling
              ],
            ),
            nowProvider: clock.now,
          ),
        ),
      );

      // Start and expire timer
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();

      // Advance time past expiration
      clock.advance(const Duration(minutes: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify expired phase
      expect(find.text('Timer expired'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('Back to start'));
      await tester.pumpAndSettle();

      // Verify returned to idle phase
      expect(find.text('Select timer duration'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget); // Default duration
      expect(find.byKey(const Key('start_button')), findsOneWidget);
    });

    testWidgets('Reset button returns to idle after cancellation', (tester) async {
      // Create mutable clock for testing
      final clock = TestClock(DateTime(2025, 1, 1, 12, 0, 0));

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: ScriptedAlarmApiClient(
              connectivityResponses: [
                Future.value(true), // Initial check
                Future.value(true), // Active polling
              ],
              startResult: const AlarmRequestResult(
                sent: true,
                statusCode: 200,
                responseBody: 'ok',
              ),
              cancelResult: const AlarmRequestResult(
                sent: true,
                statusCode: 200,
                responseBody: 'ok',
              ),
            ),
            nowProvider: clock.now,
          ),
        ),
      );

      // Start and cancel timer
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pumpAndSettle();

      // Verify cancelled phase
      expect(find.text('Timer cancelled'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('Back to start'));
      await tester.pumpAndSettle();

      // Verify returned to idle phase
      expect(find.text('Select timer duration'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.byKey(const Key('start_button')), findsOneWidget);
    });
  });
}
