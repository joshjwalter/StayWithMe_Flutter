import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

class NetworkFailureApiClient extends AlarmApiClient {
  NetworkFailureApiClient({
    this.startShouldFail = false,
    this.cancelShouldFail = false,
    this.startShouldThrow = false,
    this.cancelShouldThrow = false,
    this.statusCode = 500,
  }) : super(baseUrl: '');

  final bool startShouldFail;
  final bool cancelShouldFail;
  final bool startShouldThrow;
  final bool cancelShouldThrow;
  final int statusCode;

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
  }) async {
    if (startShouldThrow) {
      throw Exception('Network unavailable');
    }
    if (startShouldFail) {
      return AlarmRequestResult(
        sent: true,
        statusCode: statusCode,
        responseBody: 'Server error: $statusCode',
      );
    }
    return const AlarmRequestResult(
      sent: true,
      statusCode: 202,
      responseBody: 'ok',
    );
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({required String timerId}) async {
    if (cancelShouldThrow) {
      throw Exception('Network unavailable during cancel');
    }
    if (cancelShouldFail) {
      return AlarmRequestResult(
        sent: true,
        statusCode: statusCode,
        responseBody: 'Server error: $statusCode',
      );
    }
    return const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'ok',
    );
  }
}

void main() {
  group('AlarmPage Network Failure Handling', () {
    testWidgets('Start request exception shows error message', (tester) async {
      final apiClient = NetworkFailureApiClient(startShouldThrow: true);

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: apiClient,
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
          ),
        ),
      );

      // Wait for initial connectivity check
      await tester.pump();
      await tester.pump();

      // Attempt to start timer
      final startButton = find.byKey(const Key('start_button'));
      expect(startButton, findsOneWidget);
      await tester.tap(startButton);
      await tester.pump();
      await tester.pump();

      // Verify error message displayed
      expect(find.textContaining('Failed to start timer'), findsOneWidget);
      expect(find.textContaining('network error'), findsOneWidget);
    });

    testWidgets('Cancel request exception shows error message', (tester) async {
      final apiClient = NetworkFailureApiClient(
        startShouldFail: false,
        cancelShouldThrow: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: apiClient,
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
          ),
        ),
      );

      // Wait for initial connectivity check
      await tester.pump();
      await tester.pump();

      // Start timer successfully
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pump();
      await tester.pump();

      // Attempt to cancel
      final cancelButton = find.byKey(const Key('cancel_button'));
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump();

      // Verify error message displayed
      expect(find.textContaining('Cancel failed'), findsOneWidget);
      expect(find.textContaining('network error'), findsOneWidget);
    });

    testWidgets('Server 500 error shows appropriate message', (tester) async {
      final apiClient = NetworkFailureApiClient(
        startShouldFail: true,
        statusCode: 500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmPage(
            apiClient: apiClient,
            nowProvider: () => DateTime(2025, 1, 1, 12, 0, 0),
          ),
        ),
      );

      // Wait for initial connectivity check
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pump();
      await tester.pump();

      // Verify error message shows server error
      expect(find.textContaining('Server error'), findsOneWidget);
      expect(find.textContaining('500'), findsOneWidget);
    });
  });
}
