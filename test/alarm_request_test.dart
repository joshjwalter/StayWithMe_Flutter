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

  test('AlarmApiClient sends start request with expected payload', () async {
    final fixedNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final apiClient = AlarmApiClient(
      baseUrl: fixture.baseUrl,
      nowProvider: () => fixedNow,
    );

    final result = await apiClient.sendStartAlarm(
      duration: const Duration(seconds: 75),
      timerId: 'TEST-001',
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
    expect(payload['timerId'], 'TEST-001');

    apiClient.dispose();
  });

  test('AlarmApiClient sends cancel request with expected payload', () async {
    final fixedNow = DateTime.utc(2026, 1, 1, 13, 0, 0);
    final apiClient = AlarmApiClient(
      baseUrl: fixture.baseUrl,
      nowProvider: () => fixedNow,
    );

    final result = await apiClient.sendCancelAlarm(timerId: 'TEST-002');

    expect(result.sent, isTrue);
    expect(result.isSuccess, isTrue);

    final events = await fixture.fetchEvents();
    expect(events.length, 1);

    final event = events.single;
    expect(event['method'], 'POST');
    expect(event['path'], '/alarm/cancel');

    final payload = jsonDecode(event['body'] as String) as Map<String, dynamic>;
    expect(payload['event'], 'alarm_cancel');
    expect(payload['timerId'], 'TEST-002');
    expect(payload['requestedAt'], fixedNow.toIso8601String());

    apiClient.dispose();
  });

  test('AlarmApiClient start and cancel sequence is logged in order', () async {
    final fixedNow = DateTime.utc(2026, 1, 1, 14, 0, 0);
    final apiClient = AlarmApiClient(
      baseUrl: fixture.baseUrl,
      nowProvider: () => fixedNow,
    );

    await apiClient.sendStartAlarm(
      duration: const Duration(minutes: 30),
      timerId: 'SEQ-001',
    );
    await apiClient.sendCancelAlarm(timerId: 'SEQ-001');

    final events = await fixture.fetchEvents();
    expect(events.length, 2);
    expect(events[0]['path'], '/alarm/start');
    expect(events[1]['path'], '/alarm/cancel');

    final startPayload =
        jsonDecode(events[0]['body'] as String) as Map<String, dynamic>;
    final cancelPayload =
        jsonDecode(events[1]['body'] as String) as Map<String, dynamic>;

    expect(startPayload['timerId'], 'SEQ-001');
    expect(cancelPayload['timerId'], 'SEQ-001');

    apiClient.dispose();
  });

  test('AlarmApiClient checkConnectivity returns true when server is running',
      () async {
    final apiClient = AlarmApiClient(baseUrl: fixture.baseUrl);
    final isOnline = await apiClient.checkConnectivity();
    expect(isOnline, isTrue);
    apiClient.dispose();
  });

  test(
      'AlarmApiClient checkConnectivity returns false when server is unreachable',
      () async {
    final apiClient = AlarmApiClient(baseUrl: 'http://127.0.0.1:1');
    final isOnline = await apiClient.checkConnectivity();
    expect(isOnline, isFalse);
    apiClient.dispose();
  });

  test('AlarmApiClient returns not-sent result when base URL is empty', () async {
    final apiClient = AlarmApiClient(baseUrl: '');
    final startResult = await apiClient.sendStartAlarm(
      duration: const Duration(minutes: 15),
      timerId: 'UNCONFIGURED',
    );
    expect(startResult.sent, isFalse);
    expect(startResult.isSuccess, isFalse);

    final cancelResult =
        await apiClient.sendCancelAlarm(timerId: 'UNCONFIGURED');
    expect(cancelResult.sent, isFalse);
    expect(cancelResult.isSuccess, isFalse);

    apiClient.dispose();
  });
}
