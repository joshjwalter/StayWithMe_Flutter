import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/api/alarm_api_client.dart';
import 'package:stay_with_me_flutter/countdown_timer.dart';

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
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
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
      await tester.pump(Duration(minutes: 61));
      await tester.pumpAndSettle();

      // Verify expired phase displayed
      expect(find.text('Timer Expired'), findsOneWidget);
      expect(find.text('Alert sent to emergency contacts'), findsOneWidget);
    });
  });
}
