import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

class TimerCapturingApiClient extends AlarmApiClient {
  TimerCapturingApiClient({
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

  final AlarmRequestResult startResult;
  final AlarmRequestResult cancelResult;

  String? startTimerId;
  String? cancelTimerId;

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
  }) async {
    startTimerId = timerId;
    return startResult;
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({required String timerId}) async {
    cancelTimerId = timerId;
    return cancelResult;
  }

  @override
  Future<bool> checkConnectivity() async => true;
}

void main() {
  group('AlarmPage Cancel Operation', () {
    testWidgets('Cancel uses same timerId as start', (tester) async {
      final apiClient = TimerCapturingApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: apiClient,
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
          ),
        ),
      );

      // Start timer
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Timer'));
      await tester.pumpAndSettle();

      // Verify timerId was captured
      expect(apiClient.startTimerId, isNotNull);
      expect(apiClient.startTimerId, isNotEmpty);

      // Cancel timer
      final cancelButton = find.widgetWithText(ElevatedButton, 'Cancel Timer');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Verify timerId correlation
      expect(apiClient.cancelTimerId, equals(apiClient.startTimerId));

      // Verify cancelled phase
      expect(find.text('Timer cancelled'), findsOneWidget);
    });

    testWidgets('timerId format is correct', (tester) async {
      final apiClient = TimerCapturingApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: apiClient,
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Timer'));
      await tester.pumpAndSettle();

      final timerId = apiClient.startTimerId;

      // Verify hex format
      expect(timerId, matches(RegExp(r'^[0-9A-F]+$')));
      // Verify uppercase
      expect(timerId, equals(timerId!.toUpperCase()));
      // Verify non-empty
      expect(timerId.isNotEmpty, isTrue);
    });
  });
}
