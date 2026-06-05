import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';
import 'package:stay_with_me_flutter/countdown_timer.dart';

class ScriptedAlarmApiClient extends AlarmApiClient {
  ScriptedAlarmApiClient({
    required this.connectivityResponses,
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

  final List<Future<bool> Function()> connectivityResponses;
  final AlarmRequestResult startResult;
  final AlarmRequestResult cancelResult;

  int connectivityCallCount = 0;

  @override
  Future<bool> checkConnectivity() {
    final index = connectivityCallCount;
    connectivityCallCount += 1;

    final handler = index < connectivityResponses.length
        ? connectivityResponses[index]
        : connectivityResponses.last;
    return handler();
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
  testWidgets('AlarmPage polls on open', (WidgetTester tester) async {
    final initialCheck = Completer<bool>();
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() => initialCheck.future],
    );

    await tester.pumpWidget(MaterialApp(home: AlarmPage(apiClient: apiClient)));

    initialCheck.complete(true);
    await tester.pump();
    await tester.pump();

    expect(apiClient.connectivityCallCount, 1);
  });

  testWidgets('AlarmPage shows offline banner and disables cancel button', (
    WidgetTester tester,
  ) async {
    final initialCheck = Completer<bool>();
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() => initialCheck.future, () async => false],
    );

    await tester.pumpWidget(MaterialApp(home: AlarmPage(apiClient: apiClient)));

    await tester.pump();

    initialCheck.complete(true);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(
      find.text('Offline timer cannot be stopped until connection is restored'),
      findsOneWidget,
    );

    final cancelButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('cancel_button')),
    );
    expect(cancelButton.onPressed, isNull);
  });

  testWidgets('AlarmPage retries disconnected timers and re-enables cancel', (
    WidgetTester tester,
  ) async {
    final initialCheck = Completer<bool>();
    final reconnectCompleter = Completer<bool>();
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [
        () => initialCheck.future,
        () async => false,
        () => reconnectCompleter.future,
      ],
    );

    await tester.pumpWidget(MaterialApp(home: AlarmPage(apiClient: apiClient)));

    await tester.pump();

    initialCheck.complete(true);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(find.byKey(const Key('offline_banner')), findsOneWidget);

    final disabledCancelButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('cancel_button')),
    );
    expect(disabledCancelButton.onPressed, isNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    reconnectCompleter.complete(true);
    await tester.pump();
    await tester.pump();

    final enabledCancelButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('cancel_button')),
    );
    expect(enabledCancelButton.onPressed, isNotNull);
  });

  testWidgets('AlarmPage refreshes on resume when the last check is stale', (
    WidgetTester tester,
  ) async {
    final initialCheck = Completer<bool>();
    var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
    DateTime nowProvider() => now;

    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() => initialCheck.future, () async => true],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(apiClient: apiClient, nowProvider: nowProvider),
      ),
    );

    await tester.pump();

    initialCheck.complete(true);
    await tester.pump();
    await tester.pump();

    expect(apiClient.connectivityCallCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    now = now.add(const Duration(seconds: 16));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(apiClient.connectivityCallCount, 2);
  });

  testWidgets('Cancel button disabled when offline with visual feedback', (
    WidgetTester tester,
  ) async {
    final initialCheck = Completer<bool>();
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() => initialCheck.future, () async => false],
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

    // Complete initial check as connected
    initialCheck.complete(true);
    await tester.pump();
    await tester.pump();

    // Start timer
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();
    await tester.pump();

    // Wait for connectivity check to show offline (10 second poll interval)
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    // Verify cancel button is disabled
    final cancelButton = find.byKey(const Key('cancel_button'));
    expect(cancelButton, findsOneWidget);

    final ElevatedButton button = tester.widget<ElevatedButton>(cancelButton);
    expect(button.onPressed, isNull);

    // Verify disabled visual feedback
    expect(
      find.text('Offline timer cannot be stopped until connection is restored'),
      findsOneWidget,
    );

    // Verify tapping disabled button does nothing
    await tester.tap(cancelButton);
    await tester.pump();
    await tester.pump();

    // Verify still in active phase (not cancelled)
    expect(find.byType(CountDownTimer), findsOneWidget);
    expect(find.text('Timer cancelled'), findsNothing);
  });
}
