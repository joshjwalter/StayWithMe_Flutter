import 'package:flutter/material.dart';

import 'api/alarm_api_client.dart';
import 'countdown_timer.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({
    super.key,
    this.apiClient,
    this.countdownDuration = const Duration(minutes: 1),
    this.showCountdown = true,
  });

  final AlarmApiClient? apiClient;
  final Duration countdownDuration;
  final bool showCountdown;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  late final AlarmApiClient _apiClient;
  late final bool _ownsApiClient;
  bool _requestInFlight = false;
  String _statusMessage = 'Ready';

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AlarmApiClient();
    _ownsApiClient = widget.apiClient == null;
  }

  Future<void> _startAlarm() async {
    if (_requestInFlight) {
      return;
    }

    setState(() {
      _requestInFlight = true;
      _statusMessage = 'Sending request...';
    });

    try {
      final result = await _apiClient.sendStartAlarm(duration: widget.countdownDuration);
      if (!mounted) {
        return;
      }

      setState(() {
        if (!result.sent) {
          _statusMessage = 'Request skipped: configure API_BASE_URL';
        } else if (result.isSuccess) {
          _statusMessage = 'Request sent (${result.statusCode})';
        } else {
          _statusMessage = 'Request failed (${result.statusCode})';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Request failed (network error)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _requestInFlight = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_ownsApiClient) {
      _apiClient.dispose();
    }
    super.dispose();
  }

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
              child: Center(
                child: widget.showCountdown ? const CountDownTimer() : const SizedBox.shrink(),
              ),
            ),
            SizedBox(height: 60), // Buffer for spacing
            // Grey button matching circle width
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: _requestInFlight ? null : _startAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: Text('Start'),
              ),
            ),
            SizedBox(height: 20), //Buffer for spacing
            Text(_statusMessage),
            SizedBox(height: 20), //Buffer for spacing
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: Text('Stop'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
