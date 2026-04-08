import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown widget that targets a specific wall-clock time.
///
/// The widget computes remaining time by subtracting the current time from
/// [targetTime] and clamping to zero. It recomputes on every [tickInterval]
/// using [nowProvider] so it stays aligned with the clock and avoids drift.
///
/// Threshold callbacks ([onEightyPercentWarning], [onNinetyFivePercentWarning],
/// [onExpired]) fire exactly once when the corresponding point in the
/// countdown is first crossed. Supply [totalDuration] (the full timer length)
/// to enable percentage-based thresholds.
///
/// Defaults:
/// - If [targetTime] is null, the widget sets it to `nowProvider() + 1 minute`.
/// - [tickInterval] defaults to 1 second.
///
/// Testing:
/// - Inject a deterministic clock with [nowProvider] so tests can advance time
///   without waiting in real time.
/// - Use [tickInterval] to control how often the countdown updates in tests.
///
/// Example:
/// ```dart
/// final target = DateTime.now().add(const Duration(seconds: 10));
/// CountDownTimer(targetTime: target, totalDuration: Duration(seconds: 10));
/// ```
class CountDownTimer extends StatefulWidget {
  const CountDownTimer({
    super.key,
    this.targetTime,
    this.totalDuration,
    this.nowProvider = DateTime.now,
    this.tickInterval = const Duration(seconds: 1),
    this.onEightyPercentWarning,
    this.onNinetyFivePercentWarning,
    this.onExpired,
  });

  /// Target DateTime the countdown should reach.
  final DateTime? targetTime;

  /// Full duration of the timer used for percentage-based threshold callbacks.
  /// Required for [onEightyPercentWarning] and [onNinetyFivePercentWarning].
  final Duration? totalDuration;

  /// Clock source used to compute remaining time.
  final DateTime Function() nowProvider;

  /// How often the countdown recomputes remaining time.
  final Duration tickInterval;

  /// Called once when remaining time falls to ≤ 20 % of [totalDuration].
  final VoidCallback? onEightyPercentWarning;

  /// Called once when remaining time falls to ≤ 5 % of [totalDuration].
  final VoidCallback? onNinetyFivePercentWarning;

  /// Called once when the countdown reaches zero.
  final VoidCallback? onExpired;

  /// Formats [seconds] as MM:SS.
  static String formatMmSs(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  State<CountDownTimer> createState() => _CountDownTimerState();
}

class _CountDownTimerState extends State<CountDownTimer> {
  Timer? timer;
  int secondsLeft = 0;
  // Cached target used for the lifetime of this widget instance.
  late final DateTime targetTime;

  bool _eightyPercentFired = false;
  bool _ninetyFivePercentFired = false;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    // Use provided target time or default to one minute from "now".
    targetTime =
        widget.targetTime ??
        widget.nowProvider().add(const Duration(minutes: 1));
    // Initial render uses the computed remaining seconds.
    secondsLeft = computeSecondsLeft();
    _checkThresholds();
    // Tick at a fixed interval and recompute remaining time from the clock.
    timer = Timer.periodic(widget.tickInterval, (_) {
      updateCountdown();
    });
  }

  /// Returns remaining seconds until [targetTime] based on [nowProvider].
  int computeSecondsLeft() {
    final diff = targetTime.difference(widget.nowProvider()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Fires threshold callbacks if warranted.  Callbacks are guarded so they
  /// each fire at most once per widget lifetime.
  void _checkThresholds() {
    final total = widget.totalDuration;
    if (total == null || total.inSeconds <= 0) {
      return;
    }
    final totalSecs = total.inSeconds;

    // 95 % elapsed → 5 % remaining
    if (!_ninetyFivePercentFired &&
        secondsLeft <= totalSecs * 0.05) {
      _ninetyFivePercentFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onNinetyFivePercentWarning?.call();
      });
    }

    // 80 % elapsed → 20 % remaining (only if 95% not yet fired)
    if (!_eightyPercentFired &&
        !_ninetyFivePercentFired &&
        secondsLeft <= totalSecs * 0.20) {
      _eightyPercentFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEightyPercentWarning?.call();
      });
    }

    // Expired
    if (!_expiredFired && secondsLeft == 0) {
      _expiredFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired?.call();
      });
    }
  }

  /// Recomputes remaining time and cancels the timer when it reaches zero.
  void updateCountdown() {
    setState(() {
      // Always derive the display from the current clock to avoid drift.
      secondsLeft = computeSecondsLeft();
    });

    _checkThresholds();

    if (secondsLeft == 0) {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      CountDownTimer.formatMmSs(secondsLeft),
      style: const TextStyle(color: Colors.white, fontSize: 50),
    );
  }
}
