import 'package:http/http.dart' as http;
import 'package:stay_with_me_flutter/infrastructure/api/alarm_api_client.dart';

/// Simple mock implementation of AlarmApiClient for testing.
/// This provides a way to simulate API responses in widget tests.
class MockAlarmApiClient extends AlarmApiClient {
  bool _shouldSucceed = true;
  String _errorMessage = '';

  MockAlarmApiClient() : super(client: http.Client());

  // Configure the mock to return success or failure
  void configureSuccess({bool succeed = true, String errorMessage = ''}) {
    _shouldSucceed = succeed;
    _errorMessage = errorMessage;
  }

  @override
  Future<AlarmRequestResult> sendStartAlarm({
    required Duration duration,
    required String timerId,
    DateTime? targetTime,
  }) async {
    if (!_shouldSucceed) {
      throw Exception(_errorMessage);
    }
    return const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'success',
    );
  }

  @override
  Future<AlarmRequestResult> sendCancelAlarm({
    required String timerId,
  }) async {
    if (!_shouldSucceed) {
      throw Exception(_errorMessage);
    }
    return const AlarmRequestResult(
      sent: true,
      statusCode: 200,
      responseBody: 'success',
    );
  }

  @override
  Future<bool> checkConnectivity() async {
    return _shouldSucceed;
  }
}
