import 'package:flutter/material.dart';
import 'countdown_timer.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle with countdown timer
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                shape: BoxShape.circle,
              ),
              child: Center(child: CountDownTimer()),
            ),
            SizedBox(height: 60), // Buffer for spacing
            // Grey button matching circle width
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
