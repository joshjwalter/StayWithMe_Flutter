import 'dart:async';
import 'package:flutter/material.dart';

class CountDownTimer extends StatefulWidget {
  const CountDownTimer({super.key});

  @override
  State<CountDownTimer> createState() => _CountDownTimerState();
}

class _CountDownTimerState extends State<CountDownTimer> {
  final DateTime targetTime = DateTime.now().add(const Duration(minutes: 1));
  Timer? timer;
  int secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    updateCountdown(); 
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      updateCountdown();
    });
  }

  void updateCountdown() {
    final diff = targetTime.difference(DateTime.now()).inSeconds;

    setState(() {
      secondsLeft = diff > 0 ? diff : 0;
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
      style: TextStyle(
        color: Colors.white,
        fontSize: 50,
      ),
    );
  }
}