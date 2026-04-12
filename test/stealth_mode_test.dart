import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/alarm.dart';
import 'package:stay_with_me_flutter/api/alarm_api_client.dart';
import 'test_harness/fake_notification_service.dart';

class AlwaysOnlineAlarmApiClient extends AlarmApiClient {
  AlwaysOnlineAlarmApiClient() : super(baseUrl: '');

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
  group('Stealth Mode UI', () {
    testWidgets('Stealth mode toggle is visible in idle state', (tester) async {
      final apiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: apiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );

      // Wait for initial connectivity check
      await tester.pump();

      // Find the stealth mode toggle
      final toggleFinder = find.byKey(const Key('stealth_mode_toggle'));
      expect(toggleFinder, findsOneWidget);

      // Verify it's a SwitchListTile
      final toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.title, isA<Text>());
      expect(toggle.subtitle, isA<Text>());

      // Verify initial state is OFF
      expect(toggle.value, isFalse);
    });

    testWidgets('Stealth mode toggle can be turned on', (tester) async {
      final apiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: apiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the stealth mode toggle
      await tester.tap(find.byKey(const Key('stealth_mode_toggle')));
      await tester.pump();

      // Verify toggle is now ON
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('stealth_mode_toggle')),
      );
      expect(toggle.value, isTrue);
    });

    testWidgets('Stealth mode toggle can be toggled multiple times', (
      tester,
    ) async {
      final apiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: apiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      final toggleFinder = find.byKey(const Key('stealth_mode_toggle'));

      // Initial state: OFF
      var toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isFalse);

      // Toggle ON
      await tester.tap(toggleFinder);
      await tester.pump();
      toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isTrue);

      // Toggle OFF
      await tester.tap(toggleFinder);
      await tester.pump();
      toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isFalse);

      // Toggle ON again
      await tester.tap(toggleFinder);
      await tester.pump();
      toggle = tester.widget<SwitchListTile>(toggleFinder);
      expect(toggle.value, isTrue);
    });

    testWidgets('Stealth mode toggle is only visible in idle state', (
      tester,
    ) async {
      // Create a mock API client that returns offline
      final mockApiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: mockApiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Stealth mode toggle should be visible in idle state
      expect(find.byKey(const Key('stealth_mode_toggle')), findsOneWidget);

      // Start a timer (will be offline but timer starts anyway)
      await tester.tap(find.text('60 min'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pump();

      // Stealth mode toggle should NOT be visible when timer is active
      expect(find.byKey(const Key('stealth_mode_toggle')), findsNothing);
    });

    testWidgets('Stealth mode resets to OFF after cancel and reset', (
      tester,
    ) async {
      final mockApiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: mockApiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Turn stealth mode ON
      await tester.tap(find.byKey(const Key('stealth_mode_toggle')));
      await tester.pump();
      var toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('stealth_mode_toggle')),
      );
      expect(toggle.value, isTrue);

      // Start and immediately cancel timer
      await tester.tap(find.byKey(const Key('start_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pump();

      // Go back to idle state
      await tester.tap(find.byKey(const Key('reset_button')));
      await tester.pump();

      // Stealth mode should be reset to OFF
      toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('stealth_mode_toggle')),
      );
      expect(toggle.value, isFalse);
    });

    testWidgets('Duration selection and stealth toggle can both be changed', (
      tester,
    ) async {
      final apiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: apiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Select 15 min duration
      await tester.tap(find.text('15 min'));
      await tester.pump();

      // Turn stealth mode ON
      await tester.tap(find.byKey(const Key('stealth_mode_toggle')));
      await tester.pump();

      // Change to 30 min duration
      await tester.tap(find.text('30 min'));
      await tester.pump();

      // Stealth mode should still be ON (independent state)
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('stealth_mode_toggle')),
      );
      expect(toggle.value, isTrue);
    });
  });

  group('Stealth Mode Integration', () {
    testWidgets('Start button is enabled with stealth mode on', (tester) async {
      final apiClient = AlwaysOnlineAlarmApiClient();
      final notificationService = FakeNotificationService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlarmPage(
              apiClient: apiClient,
              notificationService: notificationService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Turn stealth mode ON
      await tester.tap(find.byKey(const Key('stealth_mode_toggle')));
      await tester.pump();

      // Start button should still be enabled
      final startButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('start_button')),
      );
      expect(startButton.onPressed, isNotNull);
    });

    testWidgets('All timer durations work with stealth mode', (tester) async {
      final durations = ['2 min', '15 min', '30 min', '45 min', '60 min'];

      for (final duration in durations) {
        final apiClient = AlwaysOnlineAlarmApiClient();
        final notificationService = FakeNotificationService();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlarmPage(
                apiClient: apiClient,
                debugModeEnabled: true,
                notificationService: notificationService,
              ),
            ),
          ),
        );
        await tester.pump();

        // Select duration
        await tester.tap(find.text(duration));
        await tester.pump();

        // Turn stealth mode ON
        final switchTile = tester.widget<SwitchListTile>(
          find.byKey(const Key('stealth_mode_toggle')),
        );
        switchTile.onChanged?.call(true);
        await tester.pump();

        // Verify both are selected
        final toggle = tester.widget<SwitchListTile>(
          find.byKey(const Key('stealth_mode_toggle')),
        );
        expect(
          toggle.value,
          isTrue,
          reason: 'Stealth mode should be ON for $duration',
        );
      }
    });
  });
}
