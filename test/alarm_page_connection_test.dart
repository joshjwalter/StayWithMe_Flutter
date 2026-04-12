import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/api/alarm_api_client.dart';
import 'test_harness/fake_notification_service.dart';

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
    bool stealthMode = false,
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
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          notificationService: notificationService,
        ),
      ),
    );

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
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          notificationService: notificationService,
        ),
      ),
    );

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
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          notificationService: notificationService,
        ),
      ),
    );

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
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          nowProvider: nowProvider,
          notificationService: notificationService,
        ),
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

  testWidgets('95% warning uses in-page banner and countdown keeps ticking', (
    WidgetTester tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
    DateTime nowProvider() => now;
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          debugModeEnabled: true,
          nowProvider: nowProvider,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('2 min'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    now = now.add(const Duration(seconds: 114));
    await tester.pump(const Duration(seconds: 114));
    await tester.pump();

    expect(find.byKey(const Key('final_warning_banner')), findsOneWidget);
    expect(find.byKey(const Key('dismiss_overlay_button')), findsNothing);
    expect(find.byKey(const Key('final_cancel_button')), findsNothing);
    expect(find.text('00:06'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:05'), findsOneWidget);
  });

  testWidgets('shows queued-reminder diagnostics after timer starts', (
    WidgetTester tester,
  ) async {
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService(
      exactSchedulingSupported: false,
      pendingNotificationsForTimer: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          debugModeEnabled: true,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    expect(
      find.textContaining('reminders were not queued (using inexact schedule)'),
      findsOneWidget,
    );
  });

  testWidgets('debug OFF hides 2 min option', (WidgetTester tester) async {
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 min'), findsNothing);
  });

  testWidgets('debug ON shows 2 min option', (WidgetTester tester) async {
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          debugModeEnabled: true,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 min'), findsOneWidget);
  });

  testWidgets('debug OFF hides queued-reminder diagnostics after timer starts', (
    WidgetTester tester,
  ) async {
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService(
      exactSchedulingSupported: false,
      pendingNotificationsForTimer: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    expect(
      find.textContaining('reminders were not queued (using inexact schedule)'),
      findsNothing,
    );
  });

  testWidgets('debug ON shows queued-reminder diagnostics after timer starts', (
    WidgetTester tester,
  ) async {
    final apiClient = ScriptedAlarmApiClient(
      connectivityResponses: [() async => true],
    );
    final notificationService = FakeNotificationService(
      exactSchedulingSupported: false,
      pendingNotificationsForTimer: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmPage(
          apiClient: apiClient,
          debugModeEnabled: true,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pump();

    expect(
      find.textContaining('reminders were not queued (using inexact schedule)'),
      findsOneWidget,
    );
  });
}
