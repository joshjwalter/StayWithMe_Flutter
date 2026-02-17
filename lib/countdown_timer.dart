import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown widget that targets a specific wall-clock time.
///
/// The widget computes remaining time by subtracting the current time from
/// [targetTime] and clamping to zero. It recomputes on every [tickInterval]
/// using [nowProvider] so it stays aligned with the clock and avoids drift.
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
/// CountDownTimer(targetTime: target);
/// ```
class CountDownTimer extends StatefulWidget {
  const CountDownTimer({
    super.key,
    this.targetTime,
    this.nowProvider = DateTime.now,
    this.tickInterval = const Duration(seconds: 1),
  });

  /// Target DateTime the countdown should reach.
  final DateTime? targetTime;

  /// Clock source used to compute remaining time.
  final DateTime Function() nowProvider;

  /// How often the countdown recomputes remaining time.
  final Duration tickInterval;

  @override
  State<CountDownTimer> createState() => _CountDownTimerState();
}

class _CountDownTimerState extends State<CountDownTimer> {
  Timer? timer;
  int secondsLeft = 0;
  // Cached target used for the lifetime of this widget instance.
  late final DateTime targetTime;

  @override
  void initState() {
    super.initState();
    // Use provided target time or default to one minute from "now".
    targetTime =
        widget.targetTime ??
        widget.nowProvider().add(const Duration(minutes: 1));
    // Initial render uses the computed remaining seconds.
    secondsLeft = computeSecondsLeft();
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

  /// Recomputes remaining time and cancels the timer when it reaches zero.
  void updateCountdown() {
    setState(() {
      // Always derive the display from the current clock to avoid drift.
      secondsLeft = computeSecondsLeft();
    });

    if (secondsLeft == 0) {
      timer?.cancel();
      // Notify the user that the text has been sent and the alarms have been set off
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
      "$secondsLeft",
      style: TextStyle(color: Colors.white, fontSize: 50),
    );
  }
}
