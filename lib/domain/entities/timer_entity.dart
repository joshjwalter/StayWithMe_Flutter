import 'package:meta/meta.dart';

/// Lifecycle phases of a safety timer.
///
/// Matches the four phases used throughout the application UI and logic.
enum TimerPhase {
  /// User has not started a timer yet.
  idle,

  /// Timer is running, device is showing countdown.
  active,

  /// Timer hit zero without being cancelled.
  expired,

  /// User cancelled before expiry.
  cancelled,
}

/// Immutable domain entity representing a safety timer.
///
/// Encapsulates the core timer state: a unique [timerId] generated from epoch
/// milliseconds, the wall-clock [targetTime] the countdown is heading toward,
/// the [totalDuration] chosen by the user, and the current lifecycle [phase].
///
/// Computed getters ([remainingSeconds], [progress]) derive from the current
/// wall-clock time rather than elapsed duration, consistent with the app's
/// wall-clock-based countdown approach.
@immutable
class TimerEntity {
  /// Creates an immutable timer entity.
  ///
  /// [timerId] is a hex string from epoch milliseconds, used to correlate
  /// start/cancel pairs on the backend.
  const TimerEntity({
    required this.timerId,
    required this.targetTime,
    required this.totalDuration,
    this.phase = TimerPhase.idle,
  });

  /// Unique identifier for this timer instance, generated as a hex string
  /// from epoch milliseconds (e.g. `"1A2B3C4D"`).
  final String timerId;

  /// The wall-clock time at which the timer expires.
  final DateTime targetTime;

  /// The full duration the user selected for this timer.
  final Duration totalDuration;

  /// Current lifecycle phase of the timer.
  final TimerPhase phase;

  /// Remaining seconds until [targetTime], clamped to zero if expired.
  ///
  /// Uses the current wall-clock time to avoid drift, consistent with the
  /// [CountDownTimer] widget approach.
  int get remainingSeconds {
    final diff = targetTime.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Progress of the timer as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 when [totalDuration] is zero or [phase] is [TimerPhase.idle].
  /// Returns 1.0 when the timer has expired (no time remaining).
  /// Otherwise returns the fraction of [totalDuration] that has elapsed.
  double get progress {
    if (totalDuration.inSeconds <= 0) return 0.0;
    if (phase == TimerPhase.idle) return 0.0;

    final remaining = remainingSeconds;
    final elapsed = totalDuration.inSeconds - remaining;

    if (elapsed >= totalDuration.inSeconds) return 1.0;
    if (elapsed <= 0) return 0.0;

    return elapsed / totalDuration.inSeconds;
  }

  /// Creates a copy of this entity with the given fields replaced.
  TimerEntity copyWith({
    String? timerId,
    DateTime? targetTime,
    Duration? totalDuration,
    TimerPhase? phase,
  }) {
    return TimerEntity(
      timerId: timerId ?? this.timerId,
      targetTime: targetTime ?? this.targetTime,
      totalDuration: totalDuration ?? this.totalDuration,
      phase: phase ?? this.phase,
    );
  }
}
