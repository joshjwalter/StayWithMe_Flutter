import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for scheduling and managing background notifications.
///
/// Schedules notifications at 80% and 95% timer thresholds that fire even
/// when the app is backgrounded or force-quit. Supports both normal mode
/// (high-priority with sound) and stealth mode (silent notifications).
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Initializes the notification plugin with platform-specific settings.
  ///
  /// Must be called before scheduling notifications. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('ic_notification');
    // Do not request permissions during initialization; they are requested
    // explicitly via requestPermissions() to avoid unexpected prompts.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Requests notification permissions from the user.
  ///
  /// Returns true if permissions granted, false otherwise.
  /// On Android 12 and below, permissions are granted by default.
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final implementation = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // If implementation is null (e.g. web, test env without plugin) treat as
      // "not granted".  On pre-Android-13 devices the plugin itself returns true
      // because no runtime permission is required, so the fallback is not needed.
      final result = await implementation?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  /// Schedules notifications for the 80% and 95% timer thresholds.
  ///
  /// [targetTime] - When the timer expires
  /// [totalDuration] - Full timer duration (used to calculate thresholds)
  /// [timerId] - Unique timer identifier (used for notification IDs)
  /// [isStealthMode] - If true, notifications are silent (no sound/vibration)
  Future<void> scheduleTimerNotifications({
    required DateTime targetTime,
    required Duration totalDuration,
    required String timerId,
    required bool isStealthMode,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final now = DateTime.now();
    final startTime = targetTime.subtract(totalDuration);

    // Calculate threshold times
    final eightyPercentTime = startTime.add(totalDuration * 0.8);
    final ninetyFivePercentTime = startTime.add(totalDuration * 0.95);

    // Schedule 80% notification (shoulder-tap warning)
    if (eightyPercentTime.isAfter(now)) {
      final remainingMinutes = (totalDuration.inSeconds * 0.2 / 60).ceil();
      await _scheduleNotification(
        id: _getNotificationId(timerId, '80'),
        scheduledDate: eightyPercentTime,
        title: isStealthMode ? 'Reminder' : 'Safety Timer Warning',
        body: '$remainingMinutes minutes remaining on your timer',
        isStealthMode: isStealthMode,
      );
    }

    // Schedule 95% notification (final warning)
    if (ninetyFivePercentTime.isAfter(now)) {
      final remainingSeconds = (totalDuration.inSeconds * 0.05).round();
      final remainingDisplay = remainingSeconds >= 60
          ? '${(remainingSeconds / 60).ceil()} minute${remainingSeconds >= 120 ? 's' : ''}'
          : '$remainingSeconds second${remainingSeconds == 1 ? '' : 's'}';
      await _scheduleNotification(
        id: _getNotificationId(timerId, '95'),
        scheduledDate: ninetyFivePercentTime,
        title: isStealthMode ? 'Reminder' : 'Final Warning',
        body: isStealthMode
            ? 'Time is almost up'
            : 'Final warning: $remainingDisplay remaining',
        isStealthMode: isStealthMode,
      );
    }
  }

  /// Cancels all scheduled notifications for a given timer.
  Future<void> cancelNotifications(String timerId) async {
    await _plugin.cancel(_getNotificationId(timerId, '80'));
    await _plugin.cancel(_getNotificationId(timerId, '95'));
  }

  /// Cancels all pending notifications.
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// Schedules a single notification.
  Future<void> _scheduleNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required bool isStealthMode,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      isStealthMode ? 'timer_stealth' : 'timer_alerts',
      isStealthMode ? 'Timer (Silent)' : 'Timer Alerts',
      channelDescription: isStealthMode
          ? 'Silent timer notifications'
          : 'Important timer notifications',
      importance: isStealthMode ? Importance.low : Importance.high,
      priority: isStealthMode ? Priority.low : Priority.high,
      playSound: !isStealthMode,
      enableVibration: !isStealthMode,
      showWhen: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !isStealthMode,
      sound: isStealthMode ? null : 'default',
      interruptionLevel: isStealthMode
          ? InterruptionLevel.passive
          : InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _toTZDateTime(scheduledDate),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Handles notification tap - opens app to timer screen.
  void _onNotificationTapped(NotificationResponse response) {
    // Navigation logic will be handled by the app's navigation setup
    // This callback just ensures the app knows a notification was tapped
    debugPrint('Notification tapped: ${response.id} ${response.payload}');
  }

  /// Generates a deterministic notification ID from timer ID and threshold.
  int _getNotificationId(String timerId, String threshold) {
    final input = '${timerId}_$threshold';
    const int fnvOffsetBasis = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffsetBasis;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Converts DateTime to TZDateTime for scheduling.
  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    final location = tz.local;
    return tz.TZDateTime.from(dateTime, location);
  }
}
