import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

void main() {
  group('AlarmApiClient unit', () {
    test('checkConnectivity returns true for 2xx', () async {
      final mock = MockClient((request) async {
        return http.Response('{"ok":true}', 200);
      });
      final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
      expect(await client.checkConnectivity(), isTrue);
    });

    test('sendStartAlarm posts correct body and returns status', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 202);
      });
      final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock, nowProvider: () => DateTime.utc(2020,1,1));
      final res = await api.sendStartAlarm(duration: Duration(minutes: 5), timerId: 'ABC');
      expect(res.sent, isTrue);
      expect(res.statusCode, 202);
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/alarm/start');
      final body = jsonDecode(captured!.body) as Map;
      expect(body['timerId'], 'ABC');
      expect(body['durationSeconds'], 300);
    });

    test('not configured returns sent false', () async {
      final api = AlarmApiClient(baseUrl: '');
      final res = await api.sendStartAlarm(duration: Duration(seconds:1), timerId:'x');
      expect(res.sent, isFalse);
      expect(res.responseBody, contains('API_BASE_URL not configured'));
    });
  });
}
