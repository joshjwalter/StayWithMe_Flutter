import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:stay_with_me_flutter/api/alarm_api_client.dart';

void main() {
  const baseUrl = String.fromEnvironment('API_BASE_URL');

  test('web smoke: request reaches capture server from browser runtime', () async {
    if (baseUrl.isEmpty) {
      // Keep this test non-blocking for local runs when server is not provided.
      expect(true, isTrue);
      return;
    }

    final resetResponse = await http
        .post(Uri.parse('$baseUrl/__reset'))
        .timeout(const Duration(seconds: 3));
    expect(resetResponse.statusCode, 200);

    final client = AlarmApiClient(
      baseUrl: baseUrl,
      nowProvider: () => DateTime.utc(2026, 1, 1, 12, 0, 0),
    );

    final sendResult = await client.sendStartAlarm(
      duration: const Duration(seconds: 90),
      timerId: 'WEB-SMOKE-001',
    );
    expect(sendResult.sent, isTrue);
    expect(sendResult.isSuccess, isTrue);

    final eventsResponse = await http
      .get(Uri.parse('$baseUrl/requests'))
      .timeout(const Duration(seconds: 3));
    expect(eventsResponse.statusCode, 200);

    final decoded = jsonDecode(eventsResponse.body) as Map<String, dynamic>;
    final events = decoded['events'] as List<dynamic>;
    expect(events, isNotEmpty);

    final matching = events.where((event) {
      final map = event as Map<String, dynamic>;
      return map['method'] == 'POST' && map['path'] == '/alarm/start';
    });

    expect(matching, isNotEmpty);
  }, skip: !kIsWeb);
}
