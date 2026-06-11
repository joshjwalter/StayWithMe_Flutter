import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/domain/entities/timer_entity.dart';
import 'package:stay_with_me_flutter/presentation/providers/timer_notifier.dart';

void main() {
  group('TimerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle with empty timerId', () {
      final state = container.read(timerNotifierProvider);

      expect(state.phase, TimerPhase.idle);
      expect(state.timerId, isEmpty);
      expect(state.totalDuration, const Duration(minutes: 60));
    });

    test('selectDuration updates totalDuration', () {
      container
          .read(timerNotifierProvider.notifier)
          .selectDuration(const Duration(minutes: 30));

      final state = container.read(timerNotifierProvider);
      expect(state.totalDuration, const Duration(minutes: 30));
    });

    test('startTimer transitions to active phase', () {
      final targetTime = DateTime(2025, 1, 1, 12, 30);

      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: targetTime,
      );

      final state = container.read(timerNotifierProvider);
      expect(state.phase, TimerPhase.active);
      expect(state.timerId, 'ABC123');
      expect(state.targetTime, targetTime);
    });

    test('startTimer preserves duration when not specified', () {
      container
          .read(timerNotifierProvider.notifier)
          .selectDuration(const Duration(minutes: 15));
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 15),
      );

      final state = container.read(timerNotifierProvider);
      expect(state.totalDuration, const Duration(minutes: 15));
    });

    test('startTimer with duration overrides existing duration', () {
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 45),
        duration: const Duration(minutes: 45),
      );

      final state = container.read(timerNotifierProvider);
      expect(state.totalDuration, const Duration(minutes: 45));
    });

    test('cancelTimer transitions to cancelled phase', () {
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 30),
      );
      container.read(timerNotifierProvider.notifier).cancelTimer();

      final state = container.read(timerNotifierProvider);
      expect(state.phase, TimerPhase.cancelled);
    });

    test('expireTimer transitions to expired phase', () {
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 30),
      );
      container.read(timerNotifierProvider.notifier).expireTimer();

      final state = container.read(timerNotifierProvider);
      expect(state.phase, TimerPhase.expired);
    });

    test('resetToIdle returns to initial state', () {
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 30),
      );
      final notifier = container.read(timerNotifierProvider.notifier);
      notifier.setRequestInFlight(true);
      notifier.setStatusMessage('Test message');
      notifier.resetToIdle();

      final state = container.read(timerNotifierProvider);
      expect(state.phase, TimerPhase.idle);
      expect(state.timerId, isEmpty);
      expect(notifier.requestInFlight, false);
      expect(notifier.statusMessage, '');
      expect(notifier.showFinalWarningOverlay, false);
    });

    test('requestInFlight tracks request state', () {
      final notifier = container.read(timerNotifierProvider.notifier);

      expect(notifier.requestInFlight, false);
      notifier.setRequestInFlight(true);
      expect(notifier.requestInFlight, true);
      notifier.setRequestInFlight(false);
      expect(notifier.requestInFlight, false);
    });

    test('statusMessage tracks status text', () {
      final notifier = container.read(timerNotifierProvider.notifier);

      expect(notifier.statusMessage, '');
      notifier.setStatusMessage('Starting timer…');
      expect(notifier.statusMessage, 'Starting timer…');
    });

    test('showOverlay sets overlay state with remaining seconds', () {
      final notifier = container.read(timerNotifierProvider.notifier);

      expect(notifier.showFinalWarningOverlay, false);
      notifier.showOverlay(180);
      expect(notifier.showFinalWarningOverlay, true);
      expect(notifier.overlayRemainingSeconds, 180);
    });

    test('dismissOverlay clears overlay state', () {
      final notifier = container.read(timerNotifierProvider.notifier);
      notifier.showOverlay(60);
      notifier.dismissOverlay();

      expect(notifier.showFinalWarningOverlay, false);
    });

    test('cancelTimer dismisses overlay', () {
      final notifier = container.read(timerNotifierProvider.notifier);
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 30),
      );
      notifier.showOverlay(60);
      container.read(timerNotifierProvider.notifier).cancelTimer();

      expect(notifier.showFinalWarningOverlay, false);
    });

    test('expireTimer dismisses overlay', () {
      final notifier = container.read(timerNotifierProvider.notifier);
      container.read(timerNotifierProvider.notifier).startTimer(
        timerId: 'ABC123',
        targetTime: DateTime(2025, 1, 1, 12, 30),
      );
      notifier.showOverlay(60);
      container.read(timerNotifierProvider.notifier).expireTimer();

      expect(notifier.showFinalWarningOverlay, false);
    });
  });
}
