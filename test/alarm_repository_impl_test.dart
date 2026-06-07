import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/data/repositories/alarm_repository_impl.dart';
import 'package:stay_with_me_flutter/domain/entities/connectivity_status.dart';
import 'package:stay_with_me_flutter/domain/repositories/alarm_repository.dart';
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

/// Fake [AlarmApiClient] that allows controlling all method results.
///
/// Wraps the [AlarmApiClient] interface so tests can configure exact
/// return values without relying on real HTTP or the class constructor.
class FakeAlarmApiClient extends Fake implements AlarmApiClient {
  bool connectivityResult = true;
  bool disposed = false;

  /// Configurable result for [sendStartAlarm].
  AlarmRequestResult? startAlarmResult;

  /// Configurable result for [sendCancelAlarm].
  AlarmRequestResult? cancelAlarmResult;

  /// Records method call names for verification.
  final List<String> callLog = [];

  @override
  Future<bool> checkConnectivity() async {
    callLog.add('checkConnectivity');
    return connectivityResult;
  }

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
  }) async {
    callLog.add('sendStartAlarm');
    return startAlarmResult ??
        const AlarmRequestResult(
          sent: true,
          statusCode: 202,
          responseBody: '{}',
        );
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({required String timerId}) async {
    callLog.add('sendCancelAlarm');
    return cancelAlarmResult ??
        const AlarmRequestResult(
          sent: true,
          statusCode: 200,
          responseBody: '{}',
        );
  }

  @override
  void dispose() {
    disposed = true;
  }

  /// Reset all state between tests.
  void reset() {
    connectivityResult = true;
    disposed = false;
    startAlarmResult = null;
    cancelAlarmResult = null;
    callLog.clear();
  }
}

/// Collects stream events into a list, completing a [Future] once the
/// expected number of events has been received.
///
/// This works around broadcast streams delivering events asynchronously
/// via microtasks — callers simply await [received] to get all events.
class StreamCollector<T> {
  StreamCollector(this.expectedCount);

  final int expectedCount;
  final List<T> events = [];
  final Completer<void> _completer = Completer<void>();
  bool _done = false;

  void add(T event) {
    events.add(event);
    if (!_done && events.length >= expectedCount) {
      _done = true;
      _completer.complete();
    }
  }

  /// Future that completes once [expectedCount] events have been collected.
  Future<void> get received => _completer.future;
}

void main() {
  late FakeAlarmApiClient fakeApiClient;
  late AlarmRepositoryImpl repository;

  setUp(() {
    fakeApiClient = FakeAlarmApiClient();
    repository = AlarmRepositoryImpl(apiClient: fakeApiClient);
  });

  tearDown(() {
    fakeApiClient.reset();
  });

  tearDown(() {
    repository.dispose();
  });

  group('connectivityStream', () {
    test('emits checking then connected status on successful check', () async {
      final collector = StreamCollector<ConnectivityStatus>(2);
      repository.connectivityStream.listen(collector.add);

      await repository.checkConnectivity();
      await collector.received;

      expect(collector.events[0].isChecking, isTrue);
      expect(collector.events[0].isConnected, isFalse);
      expect(collector.events[1].isConnected, isTrue);
      expect(collector.events[1].isChecking, isFalse);
    });

    test('emits checking then disconnected status on failed check', () async {
      fakeApiClient.connectivityResult = false;

      final collector = StreamCollector<ConnectivityStatus>(2);
      repository.connectivityStream.listen(collector.add);

      await repository.checkConnectivity();
      await collector.received;

      expect(collector.events[0].isChecking, isTrue);
      expect(collector.events[0].isConnected, isFalse);
      expect(collector.events[1].isConnected, isFalse);
      expect(collector.events[1].isChecking, isFalse);
    });

    test('supports multiple simultaneous listeners (broadcast)', () async {
      final collector1 = StreamCollector<ConnectivityStatus>(2);
      final collector2 = StreamCollector<ConnectivityStatus>(2);
      repository.connectivityStream.listen(collector1.add);
      repository.connectivityStream.listen(collector2.add);

      await repository.checkConnectivity();
      await Future.wait([collector1.received, collector2.received]);

      expect(collector1.events.length, 2);
      expect(collector2.events.length, 2);
      expect(collector1.events[1].isConnected, isTrue);
      expect(collector2.events[1].isConnected, isTrue);
    });

    test('late listener does not receive past events', () async {
      final earlyCollector = StreamCollector<ConnectivityStatus>(2);
      repository.connectivityStream.listen(earlyCollector.add);

      await repository.checkConnectivity();
      await earlyCollector.received;
      expect(earlyCollector.events.length, 2);

      final lateCollector = StreamCollector<ConnectivityStatus>(2);
      repository.connectivityStream.listen(lateCollector.add);

      await repository.checkConnectivity();
      await lateCollector.received;

      // Late listener only gets the second check's events.
      expect(lateCollector.events.length, 2);
    });

    test('stream emits new events on subsequent checks', () async {
      final collector = StreamCollector<ConnectivityStatus>(4);
      repository.connectivityStream.listen(collector.add);

      fakeApiClient.connectivityResult = true;
      await repository.checkConnectivity();

      fakeApiClient.connectivityResult = false;
      await repository.checkConnectivity();
      await collector.received;

      expect(collector.events[1].isConnected, isTrue);
      expect(collector.events[3].isConnected, isFalse);
      expect(collector.events.length, 4);
    });

    test('stream done after dispose', () async {
      final doneCompleter = Completer<bool>();
      repository.connectivityStream.listen(
        (_) {},
        onDone: () => doneCompleter.complete(true),
      );

      repository.dispose();

      expect(await doneCompleter.future, isTrue);
    });
  });

  group('dispose', () {
    test('closes the stream controller', () async {
      // Avoid tearDown's dispose to isolate this test.
      final doneCompleter = Completer<bool>();
      repository.connectivityStream.listen(
        (_) {},
        onDone: () => doneCompleter.complete(true),
      );

      repository.dispose();

      expect(await doneCompleter.future, isTrue);
    });

    test('checkConnectivity returns disconnected stub after dispose', () async {
      repository.dispose();

      final status = await repository.checkConnectivity();

      expect(status.isConnected, isFalse);
      expect(status.isChecking, isFalse);
    });

    test('is safe to call multiple times', () async {
      repository.dispose();
      repository.dispose();

      // Should not throw. Verify by calling checkConnectivity which
      // checks isClosed internally.
      final status = await repository.checkConnectivity();
      expect(status.isConnected, isFalse);
    });

    test('new listeners after dispose receive done event immediately', () async {
      repository.dispose();

      final events = <ConnectivityStatus>[];
      final doneCompleter = Completer<bool>();
      repository.connectivityStream.listen(
        events.add,
        onDone: () => doneCompleter.complete(true),
      );

      expect(events, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(doneCompleter.isCompleted, isTrue);
    });
  });

  // --- startAlarm ---

  group('startAlarm', () {
    test('returns success when API returns 2xx', () async {
      fakeApiClient.startAlarmResult = const AlarmRequestResult(
        sent: true,
        statusCode: 202,
        responseBody: '{}',
      );

      final target = DateTime.utc(2026, 1, 1, 0, 5, 0);
      final result = await repository.startAlarm(
        duration: const Duration(minutes: 5),
        timerId: 'ABC123',
        targetTime: target,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('ABC123'));
      expect(result.message, contains('300s'));
    });

    test('returns failure when API was not sent (not configured)', () async {
      fakeApiClient.startAlarmResult = const AlarmRequestResult(
        sent: false,
        statusCode: null,
        responseBody: 'API_BASE_URL not configured',
      );

      final result = await repository.startAlarm(
        duration: const Duration(minutes: 1),
        timerId: 'DEF456',
        targetTime: DateTime.utc(2026, 1, 1, 0, 1, 0),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('not configured'));
    });

    test('returns failure with status code when API returns non-2xx', () async {
      fakeApiClient.startAlarmResult = const AlarmRequestResult(
        sent: true,
        statusCode: 500,
        responseBody: 'Internal Server Error',
      );

      final result = await repository.startAlarm(
        duration: const Duration(minutes: 1),
        timerId: 'FAIL01',
        targetTime: DateTime.utc(2026, 1, 1, 0, 1, 0),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('500'));
    });

    test('delegates to API client sendStartAlarm', () async {
      await repository.startAlarm(
        duration: const Duration(seconds: 30),
        timerId: 'T1',
        targetTime: DateTime.utc(2026, 6, 7),
      );

      expect(fakeApiClient.callLog, contains('sendStartAlarm'));
    });
  });

  // --- cancelAlarm ---

  group('cancelAlarm', () {
    test('returns success when API returns 2xx', () async {
      fakeApiClient.cancelAlarmResult = const AlarmRequestResult(
        sent: true,
        statusCode: 200,
        responseBody: '{}',
      );

      final result = await repository.cancelAlarm(timerId: 'ABC123');

      expect(result.success, isTrue);
      expect(result.message, contains('200'));
    });

    test('returns failure with status code on non-2xx', () async {
      fakeApiClient.cancelAlarmResult = const AlarmRequestResult(
        sent: true,
        statusCode: 503,
        responseBody: 'Service Unavailable',
      );

      final result = await repository.cancelAlarm(timerId: 'ABC123');

      expect(result.success, isFalse);
      expect(result.message, contains('503'));
    });

    test('returns failure when not sent (not configured)', () async {
      fakeApiClient.cancelAlarmResult = const AlarmRequestResult(
        sent: false,
        statusCode: null,
        responseBody: 'API_BASE_URL not configured',
      );

      final result = await repository.cancelAlarm(timerId: 'NOPE');

      expect(result.success, isFalse);
      expect(result.message, contains('not sent'));
    });

    test('delegates to API client sendCancelAlarm', () async {
      await repository.cancelAlarm(timerId: 'T1');

      expect(fakeApiClient.callLog, contains('sendCancelAlarm'));
    });
  });

  // --- AlarmRepository interface contract ---

  group('AlarmRepository interface contract', () {
    test('AlarmRepositoryImpl implements AlarmRepository', () {
      expect(repository, isA<AlarmRepository>());
    });
  });
}
