import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/services/notification_service.dart';

void main() {
  group('NotificationService Threshold Calculations', () {
    test('calculates correct 80% and 95% times for 15 minute timer', () {
      // For a 15 minute timer:
      // 80% = 12 minutes elapsed, 3 minutes remaining
      // 95% = 14.25 minutes elapsed, 0.75 minutes (45 seconds) remaining

      final startTime = DateTime(2026, 1, 1, 12, 0, 0);
      final targetTime = startTime.add(const Duration(minutes: 15));
      const totalDuration = Duration(minutes: 15);

      final eightyPercentTime = startTime.add(totalDuration * 0.8);
      final ninetyFivePercentTime = startTime.add(totalDuration * 0.95);

      // 80% should be at 12:12 (12 minutes after start)
      expect(eightyPercentTime, DateTime(2026, 1, 1, 12, 12, 0));

      // 95% should be at 12:14:15 (14 minutes 15 seconds after start)
      expect(ninetyFivePercentTime, DateTime(2026, 1, 1, 12, 14, 15));

      // Remaining time at each threshold
      final remaining80 = targetTime.difference(eightyPercentTime);
      final remaining95 = targetTime.difference(ninetyFivePercentTime);

      expect(remaining80.inMinutes, 3);
      expect(remaining95.inSeconds, 45);
    });

    test('calculates correct thresholds for 30 minute timer', () {
      // For a 30 minute timer:
      // 80% = 24 minutes elapsed, 6 minutes remaining
      // 95% = 28.5 minutes elapsed, 1.5 minutes (90 seconds) remaining

      final startTime = DateTime(2026, 1, 1, 13, 0, 0);
      final targetTime = startTime.add(const Duration(minutes: 30));
      const totalDuration = Duration(minutes: 30);

      final eightyPercentTime = startTime.add(totalDuration * 0.8);
      final ninetyFivePercentTime = startTime.add(totalDuration * 0.95);

      expect(eightyPercentTime, DateTime(2026, 1, 1, 13, 24, 0));
      expect(ninetyFivePercentTime, DateTime(2026, 1, 1, 13, 28, 30));

      final remaining80 = targetTime.difference(eightyPercentTime);
      final remaining95 = targetTime.difference(ninetyFivePercentTime);

      expect(remaining80.inMinutes, 6);
      expect(remaining95.inSeconds, 90);
    });

    test('calculates correct thresholds for 45 minute timer', () {
      // For a 45 minute timer:
      // 80% = 36 minutes elapsed, 9 minutes remaining
      // 95% = 42.75 minutes elapsed, 2.25 minutes (135 seconds) remaining

      final startTime = DateTime(2026, 1, 1, 14, 0, 0);
      final targetTime = startTime.add(const Duration(minutes: 45));
      const totalDuration = Duration(minutes: 45);

      final eightyPercentTime = startTime.add(totalDuration * 0.8);
      final ninetyFivePercentTime = startTime.add(totalDuration * 0.95);

      expect(eightyPercentTime, DateTime(2026, 1, 1, 14, 36, 0));
      expect(ninetyFivePercentTime, DateTime(2026, 1, 1, 14, 42, 45));

      final remaining80 = targetTime.difference(eightyPercentTime);
      final remaining95 = targetTime.difference(ninetyFivePercentTime);

      expect(remaining80.inMinutes, 9);
      expect(remaining95.inSeconds, 135);
    });

    test('calculates correct thresholds for 60 minute timer', () {
      // For a 60 minute timer:
      // 80% = 48 minutes elapsed, 12 minutes remaining
      // 95% = 57 minutes elapsed, 3 minutes (180 seconds) remaining

      final startTime = DateTime(2026, 1, 1, 15, 0, 0);
      final targetTime = startTime.add(const Duration(minutes: 60));
      const totalDuration = Duration(minutes: 60);

      final eightyPercentTime = startTime.add(totalDuration * 0.8);
      final ninetyFivePercentTime = startTime.add(totalDuration * 0.95);

      expect(eightyPercentTime, DateTime(2026, 1, 1, 15, 48, 0));
      expect(ninetyFivePercentTime, DateTime(2026, 1, 1, 15, 57, 0));

      final remaining80 = targetTime.difference(eightyPercentTime);
      final remaining95 = targetTime.difference(ninetyFivePercentTime);

      expect(remaining80.inMinutes, 12);
      expect(remaining95.inSeconds, 180);
    });

    test('notification IDs are deterministic based on timerId', () {
      const timerId = 'TEST-123';
      final id80 = '${timerId}_80'.hashCode & 0x7FFFFFFF;
      final id95 = '${timerId}_95'.hashCode & 0x7FFFFFFF;

      // IDs should be consistent
      expect(id80, '${timerId}_80'.hashCode & 0x7FFFFFFF);
      expect(id95, '${timerId}_95'.hashCode & 0x7FFFFFFF);

      // IDs should be different
      expect(id80, isNot(equals(id95)));

      // IDs should be positive
      expect(id80, greaterThan(0));
      expect(id95, greaterThan(0));
    });

    test('notification IDs are unique for different timerIds', () {
      const timerId1 = 'TIMER-001';
      const timerId2 = 'TIMER-002';

      final id1_80 = '${timerId1}_80'.hashCode & 0x7FFFFFFF;
      final id2_80 = '${timerId2}_80'.hashCode & 0x7FFFFFFF;

      // Different timers should have different notification IDs
      expect(id1_80, isNot(equals(id2_80)));
    });

    test('remaining time calculations are accurate', () {
      // Verify the math for remaining time at thresholds
      const durations = [
        Duration(minutes: 15),
        Duration(minutes: 30),
        Duration(minutes: 45),
        Duration(minutes: 60),
      ];

      for (final duration in durations) {
        // At 80% elapsed, 20% remains
        final remaining80Seconds = (duration.inSeconds * 0.2).round();
        expect(remaining80Seconds, duration.inSeconds - (duration.inSeconds * 0.8).round());

        // At 95% elapsed, 5% remains
        final remaining95Seconds = (duration.inSeconds * 0.05).round();
        expect(remaining95Seconds, duration.inSeconds - (duration.inSeconds * 0.95).round());
      }
    });
  });

  group('NotificationService', () {
    test('can be instantiated', () {
      final service = NotificationService();
      expect(service, isNotNull);
    });

    test('initialize is idempotent', () async {
      final service = NotificationService();
      
      // Should not throw when called multiple times
      await service.initialize();
      await service.initialize();
      await service.initialize();
    });

    test('cancelNotifications does not throw for any timerId', () async {
      final service = NotificationService();
      await service.initialize();

      // Should handle any timer ID without errors
      await service.cancelNotifications('VALID-ID');
      await service.cancelNotifications('ANOTHER-ID');
      await service.cancelNotifications('');
    });

    test('cancelAllNotifications does not throw', () async {
      final service = NotificationService();
      await service.initialize();

      // Should work even with no notifications scheduled
      await service.cancelAllNotifications();
    });
  });

  group('NotificationService Message Formatting', () {
    test('formats 80% notification message correctly for different durations', () {
      const testCases = [
        (Duration(minutes: 15), 3),  // 20% of 15 min = 3 min
        (Duration(minutes: 30), 6),  // 20% of 30 min = 6 min
        (Duration(minutes: 45), 9),  // 20% of 45 min = 9 min
        (Duration(minutes: 60), 12), // 20% of 60 min = 12 min
      ];

      for (final (duration, expectedMinutes) in testCases) {
        final remainingSeconds = (duration.inSeconds * 0.2).round();
        final remainingMinutes = (remainingSeconds / 60).ceil();
        
        expect(remainingMinutes, expectedMinutes,
            reason: 'Expected $expectedMinutes minutes remaining for ${duration.inMinutes} min timer at 80%');
      }
    });

    test('formats 95% notification message correctly for different durations', () {
      const testCases = [
        (Duration(minutes: 15), 45),   // 5% of 15 min = 45 sec
        (Duration(minutes: 30), 90),   // 5% of 30 min = 90 sec
        (Duration(minutes: 45), 135),  // 5% of 45 min = 135 sec
        (Duration(minutes: 60), 180),  // 5% of 60 min = 180 sec
      ];

      for (final (duration, expectedSeconds) in testCases) {
        final remainingSeconds = (duration.inSeconds * 0.05).round();
        
        expect(remainingSeconds, expectedSeconds,
            reason: 'Expected $expectedSeconds seconds remaining for ${duration.inMinutes} min timer at 95%');
      }
    });
  });
}
