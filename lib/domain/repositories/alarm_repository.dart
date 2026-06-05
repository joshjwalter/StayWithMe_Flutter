import '../entities/connectivity_status.dart';
import '../entities/alarm_result.dart';

/// Abstract repository interface for alarm-related operations.
///
/// Defines the contract between the domain layer and data sources,
/// encapsulating all alarm API interactions behind a single abstraction.
/// Implementations handle network communication, connectivity monitoring,
/// and resource lifecycle.
///
/// Consumers depend on this interface rather than concrete API clients,
/// enabling testability via mocks and flexibility to swap data sources.
abstract class AlarmRepository {
  /// Checks whether the backend server is reachable.
  ///
  /// Performs a lightweight health check against the server and returns
  /// a [ConnectivityStatus] reflecting the current connection state.
  /// Implementations should handle timeouts and network errors gracefully
  /// rather than propagating exceptions to callers.
  ///
  /// Returns a [ConnectivityStatus] indicating connected, disconnected, or
  /// checking state. Does not throw; network failures are represented as
  /// [ConnectivityStatus.disconnected].
  Future<ConnectivityStatus> checkConnectivity();

  /// Sends a start-alarm request to the backend server.
  ///
  /// Notifies the server that a safety timer has begun, providing the
  /// [duration] the user selected, the [timerId] for correlation with a
  /// future cancel request, and the [targetTime] wall-clock moment when
  /// the timer will expire.
  ///
  /// [duration] is the full countdown duration the user chose.
  /// [timerId] is the hex-encoded epoch-millisecond identifier that
  /// correlates this start with its corresponding cancel.
  /// [targetTime] is the wall-clock DateTime at which the timer expires.
  ///
  /// Returns an [AlarmResult] indicating success or failure with a
  /// human-readable message. May throw [StateError] if the repository
  /// has already been disposed.
  Future<AlarmResult> startAlarm({
    required Duration duration,
    required String timerId,
    required DateTime targetTime,
  });

  /// Sends a cancel-alarm request to the backend server.
  ///
  /// Informs the server that the user cancelled the timer before it
  /// expired, using [timerId] to correlate with the original start request.
  /// Implementations should prevent cancellation when the device is offline,
  /// as the server cannot receive the cancel notification.
  ///
  /// [timerId] is the hex-encoded epoch-millisecond identifier that was
  /// previously passed to [startAlarm].
  ///
  /// Returns an [AlarmResult] indicating success or failure with a
  /// human-readable message. May throw [StateError] if the repository
  /// has already been disposed.
  Future<AlarmResult> cancelAlarm({required String timerId});

  /// Stream of connectivity status changes for reactive monitoring.
  ///
  /// Emits a new [ConnectivityStatus] whenever the server connection
  /// state changes (e.g., connected to disconnected, or vice versa).
  /// UI layers can listen to this stream to update connectivity indicators
  /// without polling [checkConnectivity] manually.
  ///
  /// The stream is a broadcast stream that begins emitting after the first
  /// connectivity check. Implementations should close the stream when
  /// [dispose] is called.
  Stream<ConnectivityStatus> get connectivityStream;

  /// Releases all resources held by this repository.
  ///
  /// Closes underlying HTTP clients, cancels connectivity check timers,
  /// and closes the [connectivityStream]. After disposal, calling
  /// [startAlarm] or [cancelAlarm] should throw [StateError].
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  void dispose();
}
