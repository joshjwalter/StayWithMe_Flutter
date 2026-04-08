import 'dart:async';

import 'package:flutter/material.dart';

import 'api/alarm_api_client.dart';
import 'countdown_timer.dart';
import 'services/notification_service.dart';

// ---------------------------------------------------------------------------
// Available timer preset durations (v1 — four fixed options).
// ---------------------------------------------------------------------------
const List<Duration> kTimerPresets = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
];



// ---------------------------------------------------------------------------
// AlarmPage
// ---------------------------------------------------------------------------
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, this.apiClient, this.nowProvider});

  final AlarmApiClient? apiClient;

  /// Clock source forwarded to the countdown widget and API client.
  final DateTime Function()? nowProvider;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

enum _ConnectivityStatus { checking, connected, disconnected }

// ---------------------------------------------------------------------------
// Timer lifecycle states
// ---------------------------------------------------------------------------
enum _TimerPhase {
  /// Idle: user has not started a timer yet.
  idle,

  /// Active: timer is running, device is showing countdown.
  active,

  /// Expired: timer hit zero without being cancelled.
  expired,

  /// Cancelled: user cancelled before expiry.
  cancelled,
}

class _AlarmPageState extends State<AlarmPage> with WidgetsBindingObserver {
  late final AlarmApiClient _apiClient;
  late final bool _ownsApiClient;
  late final NotificationService _notificationService;
  bool _notificationPermissionRequested = false;

  // --- selection state (idle phase) ---
  Duration _selectedDuration = kTimerPresets.last; // default 60 min
  bool _isStealthMode = false;

  // --- active-timer state ---
  _TimerPhase _phase = _TimerPhase.idle;
  String? _activeTimerId;
  DateTime? _targetTime;

  // --- connectivity ---
  _ConnectivityStatus _connectivityStatus = _ConnectivityStatus.checking;
  bool _connectivityCheckInFlight = false;
  DateTime? _lastConnectivityCheckAt;
  Timer? _connectivityTimer;

  // --- warning overlay ---
  bool _showFinalWarningOverlay = false;
  // Remaining seconds captured when the 95% overlay is triggered.  Displayed
  // in the overlay so the value stays consistent between timer ticks.
  int _overlayRemainingSeconds = 0;

  // --- request state ---
  bool _requestInFlight = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AlarmApiClient();
    _ownsApiClient = widget.apiClient == null;
    _notificationService = NotificationService();
    _notificationService.initialize();
    WidgetsBinding.instance.addObserver(this);
    _scheduleConnectivityCheck(delay: Duration.zero, showChecking: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final lastCheckAt = _lastConnectivityCheckAt;
    if (lastCheckAt == null) {
      return;
    }

    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    if (now.difference(lastCheckAt) > const Duration(seconds: 15)) {
      _scheduleConnectivityCheck(delay: Duration.zero, showChecking: true);
    }
  }

  // -------------------------------------------------------------------------
  // Connectivity polling
  // -------------------------------------------------------------------------

  Duration get _connectivityPollingInterval {
    switch (_phase) {
      case _TimerPhase.active:
        return _connectivityStatus == _ConnectivityStatus.disconnected
            ? const Duration(seconds: 5)
            : const Duration(seconds: 10);
      case _TimerPhase.idle:
      case _TimerPhase.expired:
      case _TimerPhase.cancelled:
        return const Duration(seconds: 30);
    }
  }

  void _scheduleConnectivityCheck({
    bool showChecking = false,
    Duration? delay,
  }) {
    _connectivityTimer?.cancel();
    final nextDelay = delay ?? _connectivityPollingInterval;
    final shouldPulse =
        showChecking || _connectivityStatus == _ConnectivityStatus.disconnected;
    if (nextDelay == Duration.zero) {
      _connectivityTimer = null;
      unawaited(_pollConnectivity(showChecking: shouldPulse));
      return;
    }

    _connectivityTimer = Timer(
      nextDelay,
      () => unawaited(_pollConnectivity(showChecking: shouldPulse)),
    );
  }

  Future<void> _pollConnectivity({required bool showChecking}) async {
    if (_connectivityCheckInFlight) {
      return;
    }

    _connectivityCheckInFlight = true;
    if (showChecking && mounted) {
      setState(() => _connectivityStatus = _ConnectivityStatus.checking);
    }

    final online = await _apiClient.checkConnectivity();
    if (!mounted) {
      _connectivityCheckInFlight = false;
      return;
    }

    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    setState(() {
      _connectivityStatus = online
          ? _ConnectivityStatus.connected
          : _ConnectivityStatus.disconnected;
      _lastConnectivityCheckAt = now;
    });
    _connectivityCheckInFlight = false;
    _scheduleConnectivityCheck();
  }

  void _stopConnectivityPolling() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  // -------------------------------------------------------------------------
  // Remaining-time helpers
  // -------------------------------------------------------------------------

  int get _remainingSeconds {
    if (_targetTime == null) return 0;
    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    final diff = _targetTime!.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  // -------------------------------------------------------------------------
  // Timer control
  // -------------------------------------------------------------------------

  Future<void> _startAlarm() async {
    if (_requestInFlight || _phase != _TimerPhase.idle) return;

    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    final timerId = now.millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    final target = now.add(_selectedDuration);

    setState(() {
      _requestInFlight = true;
      _statusMessage = 'Starting timer…';
    });

    // Request notification permissions on first timer start
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      await _notificationService.requestPermissions();
    }

    try {
      final result = await _apiClient.sendStartAlarm(
        duration: _selectedDuration,
        timerId: timerId,
        stealthMode: _isStealthMode,
      );
      if (!mounted) return;

      if (result.sent && !result.isSuccess) {
        setState(() {
          _statusMessage = 'Server error (${result.statusCode})';
          _requestInFlight = false;
        });
        return;
      }

      setState(() {
        _activeTimerId = timerId;
        _targetTime = target;
        _phase = _TimerPhase.active;
        _showFinalWarningOverlay = false;
        _statusMessage = result.sent
            ? 'Timer started (${result.statusCode})'
            : 'Timer started (offline — server unreachable)';
        _requestInFlight = false;
      });

      // Schedule background notifications
      await _notificationService.scheduleTimerNotifications(
        targetTime: target,
        totalDuration: _selectedDuration,
        timerId: timerId,
        isStealthMode: _isStealthMode,
      );

      _scheduleConnectivityCheck();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to start timer (network error)';
        _requestInFlight = false;
      });
    }
  }

  Future<void> _cancelAlarm() async {
    if (_requestInFlight || _phase != _TimerPhase.active) return;
    final timerId = _activeTimerId;
    if (timerId == null) return;

    setState(() {
      _requestInFlight = true;
      _statusMessage = 'Cancelling…';
    });

    try {
      final result = await _apiClient.sendCancelAlarm(timerId: timerId);
      if (!mounted) return;

      setState(() {
        _phase = _TimerPhase.cancelled;
        _showFinalWarningOverlay = false;
        _statusMessage = result.sent
            ? 'Timer cancelled (${result.statusCode})'
            : 'Cancelled (offline — server not reached)';
        _requestInFlight = false;
      });

      // Cancel scheduled notifications
      await _notificationService.cancelNotifications(timerId);

      _scheduleConnectivityCheck();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Cancel failed (network error)';
        _requestInFlight = false;
      });
    }
  }

  void _onEightyPercentWarning() {
    // Shoulder-tap: show a non-dismissable SnackBar notification.
    final remaining = _remainingSeconds;
    final minutes = (remaining / 60).ceil();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Timer ends in $minutes minute${minutes == 1 ? '' : 's'} — tap to cancel.',
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Cancel timer', onPressed: _cancelAlarm),
      ),
    );
  }

  void _onNinetyFivePercentWarning() {
    setState(() {
      _overlayRemainingSeconds = _remainingSeconds;
      _showFinalWarningOverlay = true;
    });
  }

  void _onExpired() {
    final timerId = _activeTimerId;
    setState(() {
      _phase = _TimerPhase.expired;
      _showFinalWarningOverlay = false;
      _statusMessage = 'Timer expired — alert sent to emergency contacts.';
    });

    // Cancel any remaining scheduled notifications
    if (timerId != null) {
      _notificationService.cancelNotifications(timerId);
    }

    _scheduleConnectivityCheck();
  }

  void _resetToIdle() {
    setState(() {
      _phase = _TimerPhase.idle;
      _activeTimerId = null;
      _targetTime = null;
      _showFinalWarningOverlay = false;
      _statusMessage = '';
      _isStealthMode = false; // Reset stealth mode
    });
    _scheduleConnectivityCheck();
  }

  @override
  void dispose() {
    _stopConnectivityPolling();
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsApiClient) {
      _apiClient.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Timer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _ServerConnectionPill(status: _connectivityStatus),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(context),
          if (_showFinalWarningOverlay) _buildFinalWarningOverlay(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _TimerPhase.idle:
        return _buildIdleView(context);
      case _TimerPhase.active:
        return _buildActiveView(context);
      case _TimerPhase.expired:
        return _buildExpiredView(context);
      case _TimerPhase.cancelled:
        return _buildCancelledView(context);
    }
  }

  // --- Idle view: duration selector + Start button ---

  Widget _buildIdleView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select timer duration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: kTimerPresets.map((d) {
              final isSelected = d == _selectedDuration;
              final label = '${d.inMinutes} min';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedDuration = d),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            key: const Key('stealth_mode_toggle'),
            title: const Text('Stealth Mode'),
            subtitle: const Text('Silent notifications (no sound or vibration)'),
            value: _isStealthMode,
            onChanged: (value) => setState(() => _isStealthMode = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 40),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 250,
            height: 60,
            child: ElevatedButton(
              key: const Key('start_button'),
              onPressed: _requestInFlight ? null : _startAlarm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              child: _requestInFlight
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Start Timer', style: TextStyle(fontSize: 18)),
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_statusMessage, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  // --- Active view: countdown + offline banner + cancel button ---

  Widget _buildActiveView(BuildContext context) {
    final showOfflineBanner =
        _connectivityStatus == _ConnectivityStatus.disconnected;
    final isCancelEnabled =
        !_requestInFlight &&
        _connectivityStatus == _ConnectivityStatus.connected;

    return Column(
      children: [
        if (showOfflineBanner)
          Material(
            key: const Key('offline_banner'),
            color: Colors.red.shade700,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline timer cannot be stopped until connection is restored',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    color: Colors.blueGrey,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CountDownTimer(
                      key: ValueKey(_activeTimerId),
                      targetTime: _targetTime,
                      totalDuration: _selectedDuration,
                      nowProvider: widget.nowProvider ?? DateTime.now,
                      onEightyPercentWarning: _onEightyPercentWarning,
                      onNinetyFivePercentWarning: _onNinetyFivePercentWarning,
                      onExpired: _onExpired,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton(
                    key: const Key('cancel_button'),
                    onPressed: isCancelEnabled ? _cancelAlarm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.red.shade200,
                      disabledForegroundColor: Colors.white70,
                    ),
                    child: _requestInFlight
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Cancel Timer',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Expired view ---

  Widget _buildExpiredView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Timer expired',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Alert sent to your emergency contacts.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              key: const Key('reset_button'),
              onPressed: _resetToIdle,
              child: const Text('Back to start'),
            ),
          ),
        ],
      ),
    );
  }

  // --- Cancelled view ---

  Widget _buildCancelledView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Timer cancelled',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_statusMessage, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              key: const Key('reset_button'),
              onPressed: _resetToIdle,
              child: const Text('Back to start'),
            ),
          ),
        ],
      ),
    );
  }

  // --- 95 % full-screen overlay ---

  Widget _buildFinalWarningOverlay(BuildContext context) {
    final isCancelEnabled =
        !_requestInFlight &&
        _connectivityStatus == _ConnectivityStatus.connected;

    return Positioned.fill(
      child: Material(
        color: Colors.red.shade900.withValues(alpha: 0.95),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notification_important,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  // Show the exact remaining time (MM:SS) consistent with the
                  // countdown widget, snapped to when the overlay was triggered.
                  '${CountDownTimer.formatMmSs(_overlayRemainingSeconds)} remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Last chance to cancel.\nIf you are offline you cannot stop this timer.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    key: const Key('final_cancel_button'),
                    onPressed: isCancelEnabled ? _cancelAlarm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      disabledBackgroundColor: Colors.white70,
                      disabledForegroundColor: Colors.red.shade300,
                    ),
                    child: const Text(
                      'Cancel Timer Now',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  key: const Key('dismiss_overlay_button'),
                  onPressed: () =>
                      setState(() => _showFinalWarningOverlay = false),
                  child: const Text(
                    'Dismiss (timer continues)',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerConnectionPill extends StatefulWidget {
  const _ServerConnectionPill({required this.status});

  final _ConnectivityStatus status;

  @override
  State<_ServerConnectionPill> createState() => _ServerConnectionPillState();
}

class _ServerConnectionPillState extends State<_ServerConnectionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.status),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ServerConnectionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.duration = _durationFor(widget.status);
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _durationFor(_ConnectivityStatus status) {
    switch (status) {
      case _ConnectivityStatus.checking:
        return const Duration(milliseconds: 1800);
      case _ConnectivityStatus.disconnected:
        return const Duration(milliseconds: 2800);
      case _ConnectivityStatus.connected:
        return const Duration(milliseconds: 1);
    }
  }

  bool get _isPulsing =>
      widget.status == _ConnectivityStatus.checking ||
      widget.status == _ConnectivityStatus.disconnected;

  Color get _dotColor {
    switch (widget.status) {
      case _ConnectivityStatus.checking:
        return Colors.amber.shade700;
      case _ConnectivityStatus.connected:
        return Colors.green.shade600;
      case _ConnectivityStatus.disconnected:
        return Colors.red.shade600;
    }
  }

  Color get _foregroundColor {
    switch (widget.status) {
      case _ConnectivityStatus.checking:
        return Colors.amber.shade900;
      case _ConnectivityStatus.connected:
        return Colors.green.shade800;
      case _ConnectivityStatus.disconnected:
        return Colors.red.shade800;
    }
  }

  String get _label {
    switch (widget.status) {
      case _ConnectivityStatus.checking:
        return 'Checking';
      case _ConnectivityStatus.connected:
        return 'Connected';
      case _ConnectivityStatus.disconnected:
        return 'No connection';
    }
  }

  String get _semanticLabel => 'Server connection status: $_label';

  void _syncAnimation() {
    if (_isPulsing) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animatedDot = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        final scale = _isPulsing ? 1.0 + (pulse * 0.25) : 1.0;
        final opacity = _isPulsing ? 0.55 + (pulse * 0.45) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
      ),
    );

    return Semantics(
      label: _semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _foregroundColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _foregroundColor.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            animatedDot,
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: _foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
