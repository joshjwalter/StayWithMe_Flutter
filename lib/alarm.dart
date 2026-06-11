import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/entities/connectivity_status.dart';
import 'domain/entities/timer_entity.dart';
import 'infrastructure/api/alarm_api_client.dart';
import 'presentation/providers/connectivity_notifier.dart';
import 'presentation/providers/timer_notifier.dart';
import 'countdown_timer.dart';

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
class AlarmPage extends ConsumerStatefulWidget {
  const AlarmPage({super.key, this.apiClient, this.nowProvider});

  final AlarmApiClient? apiClient;

  /// Clock source forwarded to the countdown widget and API client.
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends ConsumerState<AlarmPage> with WidgetsBindingObserver {
  late final AlarmApiClient _apiClient;
  late final bool _ownsApiClient;

  // --- widget-local connectivity lifecycle (not managed by Riverpod) ---
  bool _connectivityCheckInFlight = false;
  DateTime? _lastConnectivityCheckAt;
  Timer? _connectivityTimer;

  // --- convenience accessors (read from Riverpod) ---
  TimerNotifier get _timerNotifier => ref.read(timerNotifierProvider.notifier);
  TimerEntity get _timerState => ref.watch(timerNotifierProvider);
  ConnectivityStatus get _connectivityState =>
      ref.watch(connectivityNotifierProvider);

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AlarmApiClient();
    _ownsApiClient = widget.apiClient == null;
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
    if (_timerState.phase == TimerPhase.active) {
      return _connectivityState.isConnected
          ? const Duration(seconds: 10)
          : const Duration(seconds: 5);
    }
    return const Duration(seconds: 30);
  }

  void _scheduleConnectivityCheck({
    bool showChecking = false,
    Duration? delay,
  }) {
    _connectivityTimer?.cancel();
    final nextDelay = delay ?? _connectivityPollingInterval;
    final shouldPulse = showChecking || !_connectivityState.isConnected;
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
    final connNotifier = ref.read(connectivityNotifierProvider.notifier);
    if (showChecking && mounted) {
      connNotifier.setChecking();
    }

    final online = await _apiClient.checkConnectivity();
    if (!mounted) {
      _connectivityCheckInFlight = false;
      return;
    }

    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    connNotifier.updateFromCheck(online);
    _lastConnectivityCheckAt = now;
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
    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    final diff = _timerState.targetTime.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  // -------------------------------------------------------------------------
  // Timer control
  // -------------------------------------------------------------------------

  Future<void> _startAlarm() async {
    if (_timerNotifier.requestInFlight ||
        _timerState.phase != TimerPhase.idle) {
      return;
    }

    final now = widget.nowProvider != null
        ? widget.nowProvider!()
        : DateTime.now();
    final timerId = now.millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    final target = now.add(_timerState.totalDuration);

    _timerNotifier.setRequestInFlight(true);
    _timerNotifier.setStatusMessage('Starting timer…');

    try {
      final result = await _apiClient.sendStartAlarm(
        duration: _timerState.totalDuration,
        timerId: timerId,
      );
      if (!mounted) return;

      if (result.sent && !result.isSuccess) {
        _timerNotifier.setRequestInFlight(false);
        _timerNotifier
            .setStatusMessage('Server error (${result.statusCode})');
        return;
      }

      _timerNotifier.startTimer(
        timerId: timerId,
        targetTime: target,
      );
      _timerNotifier.setRequestInFlight(false);
      _timerNotifier.setStatusMessage(result.sent
          ? 'Timer started (${result.statusCode})'
          : 'Timer started (offline — server unreachable)');

      _scheduleConnectivityCheck();
    } catch (_) {
      if (!mounted) return;
      _timerNotifier.setRequestInFlight(false);
      _timerNotifier.setStatusMessage('Failed to start timer (network error)');
    }
  }

  Future<void> _cancelAlarm() async {
    if (_timerNotifier.requestInFlight ||
        _timerState.phase != TimerPhase.active) {
      return;
    }
    final timerId = _timerState.timerId;
    if (timerId.isEmpty) return;

    _timerNotifier.setRequestInFlight(true);
    _timerNotifier.setStatusMessage('Cancelling…');

    try {
      final result = await _apiClient.sendCancelAlarm(timerId: timerId);
      if (!mounted) return;

      _timerNotifier.cancelTimer();
      _timerNotifier.setRequestInFlight(false);
      _timerNotifier.setStatusMessage(result.sent
          ? 'Timer cancelled (${result.statusCode})'
          : 'Cancelled (offline — server not reached)');
      _scheduleConnectivityCheck();
    } catch (_) {
      if (!mounted) return;
      _timerNotifier.setRequestInFlight(false);
      _timerNotifier.setStatusMessage('Cancel failed (network error)');
    }
  }

  void _onEightyPercentWarning() {
    // Shoulder-tap: show a non-dismissable SnackBar notification.
    // Requires BuildContext, so it stays in the widget layer.
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
    _timerNotifier.showOverlay(_remainingSeconds);
  }

  void _onExpired() {
    _timerNotifier.expireTimer();
    _timerNotifier
        .setStatusMessage('Timer expired — alert sent to emergency contacts.');
    _scheduleConnectivityCheck();
  }

  void _resetToIdle() {
    _timerNotifier.resetToIdle();
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
              child: _ServerConnectionPill(status: _connectivityState),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(context),
          if (_timerNotifier.showFinalWarningOverlay)
            _buildFinalWarningOverlay(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_timerState.phase) {
      case TimerPhase.idle:
        return _buildIdleView(context);
      case TimerPhase.active:
        return _buildActiveView(context);
      case TimerPhase.expired:
        return _buildExpiredView(context);
      case TimerPhase.cancelled:
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
              final isSelected = d == _timerState.totalDuration;
              final label = '${d.inMinutes} min';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) =>
                    ref.read(timerNotifierProvider.notifier).selectDuration(d),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 250,
            height: 60,
            child: ElevatedButton(
              key: const Key('start_button'),
              onPressed: _timerNotifier.requestInFlight ? null : _startAlarm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              child: _timerNotifier.requestInFlight
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Start Timer', style: TextStyle(fontSize: 18)),
            ),
          ),
          if (_timerNotifier.statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_timerNotifier.statusMessage, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  // --- Active view: countdown + offline banner + cancel button ---

  Widget _buildActiveView(BuildContext context) {
    final showOfflineBanner = !_connectivityState.isConnected;
    final isCancelEnabled =
        !_timerNotifier.requestInFlight && _connectivityState.isConnected;

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
                      key: ValueKey(_timerState.timerId),
                      targetTime: _timerState.targetTime,
                      totalDuration: _timerState.totalDuration,
                      nowProvider: widget.nowProvider ?? DateTime.now,
                      onEightyPercentWarning: _onEightyPercentWarning,
                      onNinetyFivePercentWarning: _onNinetyFivePercentWarning,
                      onExpired: _onExpired,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _timerNotifier.statusMessage,
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
                    child: _timerNotifier.requestInFlight
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
          Text(_timerNotifier.statusMessage, textAlign: TextAlign.center),
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
        !_timerNotifier.requestInFlight && _connectivityState.isConnected;

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
                  '${CountDownTimer.formatMmSs(_timerNotifier.overlayRemainingSeconds)} remaining',
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
                  onPressed: () => _timerNotifier.dismissOverlay(),
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

  final ConnectivityStatus status;

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
    if (oldWidget.status.isConnected != widget.status.isConnected ||
        oldWidget.status.isChecking != widget.status.isChecking) {
      _controller.duration = _durationFor(widget.status);
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _durationFor(ConnectivityStatus status) {
    if (status.isChecking) return const Duration(milliseconds: 1800);
    if (!status.isConnected) return const Duration(milliseconds: 2800);
    return const Duration(milliseconds: 1);
  }

  bool get _isPulsing => widget.status.isChecking || !widget.status.isConnected;

  Color get _dotColor {
    if (widget.status.isChecking) return Colors.amber.shade700;
    if (widget.status.isConnected) return Colors.green.shade600;
    return Colors.red.shade600;
  }

  Color get _foregroundColor {
    if (widget.status.isChecking) return Colors.amber.shade900;
    if (widget.status.isConnected) return Colors.green.shade800;
    return Colors.red.shade800;
  }

  String get _label {
    if (widget.status.isChecking) return 'Checking';
    if (widget.status.isConnected) return 'Connected';
    return 'No connection';
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
