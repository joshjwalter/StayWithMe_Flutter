import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

void main() {
  group('AlarmApiClient unit', () {
    group('checkConnectivity', () {
      test('returns true for 2xx response', () async {
        final mock = MockClient((request) async {
          return http.Response('{"ok":true}', 200);
        });
        final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(await client.checkConnectivity(), isTrue);
      });

      test('returns true for other 2xx status codes (e.g. 201, 204, 299)', () async {
        for (final status in [201, 204, 299]) {
          final mock = MockClient((request) async {
            return http.Response('', status);
          });
          final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
          expect(await client.checkConnectivity(), isTrue, reason: 'status $status should be true');
        }
      });

      test('returns false when base URL is not configured', () async {
        final client = AlarmApiClient(baseUrl: '');
        expect(await client.checkConnectivity(), isFalse);
      });

      test('returns false for non-2xx response (4xx)', () async {
        for (final status in [400, 404, 500, 503]) {
          final mock = MockClient((request) async {
            return http.Response('error', status);
          });
          final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
          expect(await client.checkConnectivity(), isFalse, reason: 'status $status should be false');
        }
      });

      test('requests /health endpoint on configured base URL', () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response('', 200);
        });
        final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:9999', client: mock);
        await client.checkConnectivity();
        expect(captured, isNotNull);
        expect(captured!.method, 'GET');
        expect(captured!.url.toString(), 'http://127.0.0.1:9999/health');
      });

      test('returns false on network error (SocketException)', () async {
        final mock = MockClient((request) async {
          throw const SocketException('connection refused');
        });
        final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(await client.checkConnectivity(), isFalse);
      });

      test('returns false on timeout', () async {
        final mock = MockClient((request) async {
          throw TimeoutException('request timed out', const Duration(seconds: 3));
        });
        final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(await client.checkConnectivity(), isFalse);
      });

      test('returns false on client error (ClientException)', () async {
        final mock = MockClient((request) async {
          throw http.ClientException('failed to send');
        });
        final client = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(await client.checkConnectivity(), isFalse);
      });

      test('returns false on malformed URL', () async {
        final client = AlarmApiClient(baseUrl: 'not-a-valid-url', client: http.Client());
        expect(await client.checkConnectivity(), isFalse);
      });
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

    group('sendStartAlarm error scenarios', () {
      test('returns non-2xx status code on server error (500)', () async {
        final mock = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendStartAlarm(
          duration: const Duration(minutes: 5),
          timerId: 'ERR-500',
        );
        expect(res.sent, isTrue);
        expect(res.statusCode, 500);
        expect(res.isSuccess, isFalse);
        expect(res.responseBody, contains('Internal Server Error'));
      });

      test('returns non-2xx status code on client error (400)', () async {
        final mock = MockClient((request) async {
          return http.Response('Bad Request', 400);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendStartAlarm(
          duration: const Duration(minutes: 5),
          timerId: 'ERR-400',
        );
        expect(res.sent, isTrue);
        expect(res.statusCode, 400);
        expect(res.isSuccess, isFalse);
        expect(res.responseBody, contains('Bad Request'));
      });

      test('returns non-2xx status code on not found (404)', () async {
        final mock = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendStartAlarm(
          duration: const Duration(minutes: 5),
          timerId: 'ERR-404',
        );
        expect(res.sent, isTrue);
        expect(res.statusCode, 404);
        expect(res.isSuccess, isFalse);
      });

      test('propagates SocketException on network failure', () async {
        final mock = MockClient((request) async {
          throw const SocketException('connection refused');
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendStartAlarm(
            duration: const Duration(minutes: 5),
            timerId: 'NET-FAIL',
          ),
          throwsA(isA<SocketException>()),
        );
      });

      test('propagates TimeoutException when request times out', () async {
        final mock = MockClient((request) async {
          throw TimeoutException('request timed out', const Duration(seconds: 5));
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendStartAlarm(
            duration: const Duration(minutes: 5),
            timerId: 'TIMEOUT',
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('propagates ClientException on HTTP client error', () async {
        final mock = MockClient((request) async {
          throw http.ClientException('failed to send');
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendStartAlarm(
            duration: const Duration(minutes: 5),
            timerId: 'CLIENT-ERR',
          ),
          throwsA(isA<http.ClientException>()),
        );
      });
    });

    group('sendCancelAlarm', () {
      test('posts correct body and returns 2xx status', () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        });
        final api = AlarmApiClient(
          baseUrl: 'http://127.0.0.1:54010',
          client: mock,
          nowProvider: () => DateTime.utc(2020, 1, 1),
        );
        final res = await api.sendCancelAlarm(timerId: 'CANCEL-001');
        expect(res.sent, isTrue);
        expect(res.statusCode, 200);
        expect(res.isSuccess, isTrue);
        expect(captured, isNotNull);
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/alarm/cancel');
        final body = jsonDecode(captured!.body) as Map;
        expect(body['event'], 'alarm_cancel');
        expect(body['timerId'], 'CANCEL-001');
      });

      test('returns non-2xx status code on server error (500)', () async {
        final mock = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendCancelAlarm(timerId: 'CANCEL-ERR-500');
        expect(res.sent, isTrue);
        expect(res.statusCode, 500);
        expect(res.isSuccess, isFalse);
        expect(res.responseBody, contains('Internal Server Error'));
      });

      test('returns non-2xx status code on client error (400)', () async {
        final mock = MockClient((request) async {
          return http.Response('Bad Request', 400);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendCancelAlarm(timerId: 'CANCEL-ERR-400');
        expect(res.sent, isTrue);
        expect(res.statusCode, 400);
        expect(res.isSuccess, isFalse);
        expect(res.responseBody, contains('Bad Request'));
      });

      test('returns non-2xx status code on not found (404)', () async {
        final mock = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        final res = await api.sendCancelAlarm(timerId: 'CANCEL-ERR-404');
        expect(res.sent, isTrue);
        expect(res.statusCode, 404);
        expect(res.isSuccess, isFalse);
      });

      test('returns sent false when base URL is not configured', () async {
        final api = AlarmApiClient(baseUrl: '');
        final res = await api.sendCancelAlarm(timerId: 'CANCEL-UNCONFIG');
        expect(res.sent, isFalse);
        expect(res.isSuccess, isFalse);
        expect(res.responseBody, contains('API_BASE_URL not configured'));
      });

      test('propagates SocketException on network failure', () async {
        final mock = MockClient((request) async {
          throw const SocketException('connection refused');
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendCancelAlarm(timerId: 'CANCEL-NET-FAIL'),
          throwsA(isA<SocketException>()),
        );
      });

      test('propagates TimeoutException when request times out', () async {
        final mock = MockClient((request) async {
          throw TimeoutException('request timed out', const Duration(seconds: 5));
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendCancelAlarm(timerId: 'CANCEL-TIMEOUT'),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('propagates ClientException on HTTP client error', () async {
        final mock = MockClient((request) async {
          throw http.ClientException('failed to send');
        });
        final api = AlarmApiClient(baseUrl: 'http://127.0.0.1:54010', client: mock);
        expect(
          () => api.sendCancelAlarm(timerId: 'CANCEL-CLIENT-ERR'),
          throwsA(isA<http.ClientException>()),
        );
      });
    });
  });
}
