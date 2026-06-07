import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/countdown_timer.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

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
  group('AlarmPage Warning Thresholds', () {
    testWidgets('80% warning shows SnackBar with cancel action', (tester) async {
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

      // Start timer
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();

      // Advance to 80% (48 minutes elapsed, 12 remaining)
      clock.advance(const Duration(minutes: 48));

      // Trigger timer ticks to check for threshold
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Verify SnackBar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Timer ends in'), findsOneWidget);

      // Verify cancel action exists
      final cancelAction = find.widgetWithText(SnackBarAction, 'Cancel timer');
      expect(cancelAction, findsOneWidget);

      // Cancel using the main cancel button instead of SnackBar action
      final mainCancelButton = find.byKey(const Key('cancel_button'));
      expect(mainCancelButton, findsOneWidget);

      await tester.tap(mainCancelButton);
      await tester.pumpAndSettle();

      // Verify cancelled phase
      expect(find.text('Timer cancelled'), findsOneWidget);
    });

    testWidgets('95% overlay displays with cancel button', (tester) async {
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

      // Start timer
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pumpAndSettle();

      // Advance to 95% (57 minutes elapsed, 3 remaining)
      clock.advance(const Duration(minutes: 57));

      // Trigger timer ticks to check for threshold
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Verify overlay appears by finding the notification icon
      expect(find.byIcon(Icons.notification_important), findsOneWidget);
      expect(find.textContaining('Last chance to cancel'), findsOneWidget);

      // Verify dismiss button exists
      final dismissButton = find.byKey(const Key('dismiss_overlay_button'));
      expect(dismissButton, findsOneWidget);

      // Verify cancel button exists in overlay
      final cancelButton = find.byKey(const Key('final_cancel_button'));
      expect(cancelButton, findsOneWidget);

      // Tap dismiss to verify overlay hides but timer continues
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      // Verify overlay hidden but timer still active
      expect(find.byIcon(Icons.notification_important), findsNothing);
      expect(find.byType(CountDownTimer), findsOneWidget);

      // Tap cancel from main view
      final mainCancelButton = find.byKey(const Key('cancel_button'));
      await tester.tap(mainCancelButton);
      await tester.pumpAndSettle();

      // Verify cancelled phase
      expect(find.text('Timer cancelled'), findsOneWidget);
    });
  });
}
