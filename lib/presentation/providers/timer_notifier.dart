import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/timer_entity.dart';

part 'timer_notifier.g.dart';

@riverpod
class TimerNotifier extends _$TimerNotifier {
  // Mutable UI/request state (not part of immutable TimerEntity)
  bool requestInFlight = false;
  String statusMessage = '';
  bool showFinalWarningOverlay = false;
  int overlayRemainingSeconds = 0;

  @override
  TimerEntity build() {
    return TimerEntity(
      timerId: '',
      targetTime: DateTime(2025),
      totalDuration: Duration(minutes: 60),
      phase: TimerPhase.idle,
    );
  }

  void selectDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);
  }

  void startTimer({
    required String timerId,
    required DateTime targetTime,
    Duration? duration,
  }) {
    state = state.copyWith(
      timerId: timerId,
      targetTime: targetTime,
      totalDuration: duration ?? state.totalDuration,
      phase: TimerPhase.active,
    );
    showFinalWarningOverlay = false;
  }

  void cancelTimer() {
    state = state.copyWith(phase: TimerPhase.cancelled);
    showFinalWarningOverlay = false;
  }

  void expireTimer() {
    state = state.copyWith(phase: TimerPhase.expired);
    showFinalWarningOverlay = false;
  }

  void resetToIdle() {
    state = TimerEntity(
      timerId: '',
      targetTime: DateTime(2025),
      totalDuration: Duration(minutes: 60),
      phase: TimerPhase.idle,
    );
    requestInFlight = false;
    statusMessage = '';
    showFinalWarningOverlay = false;
  }

  void setRequestInFlight(bool value) {
    requestInFlight = value;
  }

  void setStatusMessage(String value) {
    statusMessage = value;
  }

  void showOverlay(int remainingSeconds) {
    overlayRemainingSeconds = remainingSeconds;
    showFinalWarningOverlay = true;
  }

  void dismissOverlay() {
    showFinalWarningOverlay = false;
  }
}
