import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/api/alarm_api_client.dart';
import 'package:stay_with_me_flutter/main.dart';
import 'package:stay_with_me_flutter/settings.dart';

import 'test_harness/fake_notification_service.dart';

class _AlwaysOnlineAlarmApiClient extends AlarmApiClient {
  _AlwaysOnlineAlarmApiClient() : super(baseUrl: '');

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
    bool stealthMode = false,
  }) async {
    return const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'ok',
    );
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({required String timerId}) async {
    return const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'ok',
    );
  }
}

void main() {
  Future<void> pumpNavigationFrame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'should call settings callback when debug mode toggle is changed',
    (WidgetTester tester) async {
      bool? latestValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              debugMode: false,
              onDebugModeChanged: (bool value) {
                latestValue = value;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('debug_mode_toggle')));
      await tester.pump();

      expect(latestValue, isTrue);
    },
  );

  testWidgets(
    'should show 2 min preset in alarm after enabling debug mode in settings',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationBottom()));
      await pumpNavigationFrame(tester);

      await tester.tap(find.text('Settings').last);
      await pumpNavigationFrame(tester);
      await tester.tap(find.byKey(const Key('debug_mode_toggle')));
      await pumpNavigationFrame(tester);
      await tester.tap(find.text('Alarm').last);
      await pumpNavigationFrame(tester);

      expect(find.text('2 min'), findsOneWidget);
    },
  );

  testWidgets(
    'should hide 2 min preset in alarm after disabling debug mode in settings',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NavigationBottom()));
      await pumpNavigationFrame(tester);

      await tester.tap(find.text('Settings').last);
      await pumpNavigationFrame(tester);
      await tester.tap(find.byKey(const Key('debug_mode_toggle')));
      await pumpNavigationFrame(tester);
      await tester.tap(find.byKey(const Key('debug_mode_toggle')));
      await pumpNavigationFrame(tester);
      await tester.tap(find.text('Alarm').last);
      await pumpNavigationFrame(tester);

      expect(find.text('2 min'), findsNothing);
    },
  );

  testWidgets(
    'should coerce selected duration to 60 min when debug mode turns off',
    (WidgetTester tester) async {
      final apiClient = _AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      var debugMode = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('toggle_debug_mode'),
                      onPressed: () {
                        setState(() {
                          debugMode = false;
                        });
                      },
                      child: const Text('disable debug'),
                    ),
                    Expanded(
                      child: AlarmPage(
                        apiClient: apiClient,
                        notificationService: notificationService,
                        debugModeEnabled: debugMode,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('2 min'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('toggle_debug_mode')));
      await tester.pump();

      final sixtyMinuteChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '60 min'),
      );
      expect(sixtyMinuteChip.selected, isTrue);
    },
  );
}
