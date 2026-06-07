import 'dart:async';

import '../../domain/entities/alarm_result.dart';
import '../../domain/entities/connectivity_status.dart';
import '../../domain/repositories/alarm_repository.dart';
import '../../infrastructure/api/alarm_api_client.dart';

/// Implementation of [AlarmRepository] backed by [AlarmApiClient].
///
/// Wraps the HTTP-based API client and translates its raw
/// [AlarmRequestResult] responses into domain [AlarmResult] objects.
/// Manages a broadcast [StreamController] so multiple listeners can
/// observe connectivity status changes.
class AlarmRepositoryImpl implements AlarmRepository {
  /// Creates an [AlarmRepositoryImpl] wrapping the given [apiClient].
  AlarmRepositoryImpl({required AlarmApiClient apiClient})
      : _apiClient = apiClient,
        _connectivityController = StreamController<ConnectivityStatus>.broadcast();

  final AlarmApiClient _apiClient;
  final StreamController<ConnectivityStatus> _connectivityController;

  @override
  Future<ConnectivityStatus> checkConnectivity() async {
    if (_connectivityController.isClosed) {
      return ConnectivityStatus(
        isConnected: false,
        isChecking: false,
        lastChecked: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    final checking = ConnectivityStatus.checking();
    _connectivityController.add(checking);

    final connected = await _apiClient.checkConnectivity();
    final status =
        connected ? ConnectivityStatus.connected() : ConnectivityStatus.disconnected();
    _connectivityController.add(status);

    return status;
  }

  @override
  Future<AlarmResult> startAlarm({
    required Duration duration,
    required String timerId,
    required DateTime targetTime,
  }) async {
    final result = await _apiClient.sendStartAlarm(
      duration: duration,
      timerId: timerId,
    );

    if (result.isSuccess) {
      return AlarmResult.success(
        message: 'Alarm started (timerId=$timerId, '
            'duration=${duration.inSeconds}s)',
      );
    }

    if (!result.sent) {
      return AlarmResult.failure(
        message: 'Alarm start failed: ${result.responseBody}',
      );
    }

    return AlarmResult.failure(
      message: 'Alarm start failed: server returned ${result.statusCode}',
    );
  }

  @override
  Future<AlarmResult> cancelAlarm({required String timerId}) async {
    final result = await _apiClient.sendCancelAlarm(timerId: timerId);
    if (result.isSuccess) {
      return AlarmResult.success(
        message: 'Cancel sent (HTTP ${result.statusCode})',
      );
    }
    return AlarmResult.failure(
      message: result.sent
          ? 'Cancel failed (HTTP ${result.statusCode})'
          : 'Cancel not sent: server not configured',
    );
  }

  @override
  Stream<ConnectivityStatus> get connectivityStream =>
      _connectivityController.stream;

  @override
  void dispose() {
    _connectivityController.close();
  }
}
