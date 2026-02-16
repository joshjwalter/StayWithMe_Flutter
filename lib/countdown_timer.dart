import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown widget that targets a specific wall-clock time.
///
/// Production uses real time via [nowProvider]. Tests can inject a fake clock.
/// If [targetTime] is null, the default is `now + 1 minute`.
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
