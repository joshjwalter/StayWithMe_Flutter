import 'package:stay_with_me_flutter/services/notification_service.dart';

class FakeNotificationService extends NotificationService {
  FakeNotificationService({
    this.permissionsGranted = true,
    this.failSchedule = false,
    this.failCancel = false,
  });

  bool permissionsGranted;
  bool failSchedule;
  bool failCancel;

  int initializeCalls = 0;
  int requestPermissionsCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCalls += 1;
    return permissionsGranted;
  }

  @override
  Future<void> scheduleTimerNotifications({
    required DateTime targetTime,
    required Duration totalDuration,
    required String timerId,
    required bool isStealthMode,
  }) async {
    scheduleCalls += 1;
    if (failSchedule) {
      throw Exception('schedule failed');
    }
  }

  @override
  Future<void> cancelNotifications(String timerId) async {
    cancelCalls += 1;
    if (failCancel) {
      throw Exception('cancel failed');
    }
  }

  @override
  Future<void> cancelAllNotifications() async {}
}
