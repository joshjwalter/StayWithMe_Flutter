import 'package:flutter_test/flutter_test.dart';

import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';
import 'test_harness/request_capture_fixture.dart';

void main() {
  test('integration: start alarm captured by request server', () async {
    final fixture = RequestCaptureFixture();
    await fixture.start();
    try {
      final api = AlarmApiClient(baseUrl: fixture.baseUrl);
      final res = await api.sendStartAlarm(duration: Duration(minutes: 1), timerId: 'TEST123');
      expect(res.sent, isTrue);
      final events = await fixture.fetchEvents();
      expect(events.any((e) => (e['body'] as String).contains('TEST123')), isTrue);
    } finally {
      await fixture.stop();
    }
  }, timeout: Timeout(Duration(seconds: 20)));
}
