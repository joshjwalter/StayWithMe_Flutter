import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/api/alarm_api_client.dart';

import 'test_harness/request_capture_fixture.dart';

void main() {
  final fixture = RequestCaptureFixture();

  setUpAll(() async {
    await fixture.start();
  });

  tearDownAll(() async {
    await fixture.stop();
  });

  setUp(() async {
    await fixture.reset();
  });

  test('AlarmApiClient sends request with expected payload', () async {
    final fixedNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final apiClient = AlarmApiClient(
      baseUrl: fixture.baseUrl,
      nowProvider: () => fixedNow,
    );

    final result = await apiClient.sendStartAlarm(
      duration: const Duration(seconds: 75),
    );

    expect(result.sent, isTrue);
    expect(result.isSuccess, isTrue);

    final events = await fixture.fetchEvents();
    expect(events.length, 1);

    final event = events.single;
    expect(event['method'], 'POST');
    expect(event['path'], '/alarm/start');

    final payload = jsonDecode(event['body'] as String) as Map<String, dynamic>;
    expect(payload['event'], 'alarm_start');
    expect(payload['durationSeconds'], 75);
    expect(payload['requestedAt'], fixedNow.toIso8601String());

    apiClient.dispose();
  });
}
