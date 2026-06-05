import 'package:meta/meta.dart';

/// Immutable snapshot of the server connectivity state.
///
/// Captures whether the client is currently connected to the server,
/// whether a connectivity check is in progress, and when the last
/// check occurred.
@immutable
class ConnectivityStatus {
  /// Whether the client is connected to the server.
  final bool isConnected;

  /// Whether a connectivity check is currently in progress.
  final bool isChecking;

  /// When the last connectivity check was performed.
  final DateTime lastChecked;

  const ConnectivityStatus({
    required this.isConnected,
    required this.isChecking,
    required this.lastChecked,
  });

  /// Connected state: server reachable, no check in progress.
  ConnectivityStatus.connected()
      : isConnected = true,
        isChecking = false,
        lastChecked = DateTime.now();

  /// Disconnected state: server unreachable, no check in progress.
  ConnectivityStatus.disconnected()
      : isConnected = false,
        isChecking = false,
        lastChecked = DateTime.now();

  /// Checking state: a connectivity check is in progress.
  ConnectivityStatus.checking()
      : isConnected = false,
        isChecking = true,
        lastChecked = DateTime.now();

  /// Creates a copy of this status with the given fields replaced.
  ConnectivityStatus copyWith({
    bool? isConnected,
    bool? isChecking,
    DateTime? lastChecked,
  }) {
    return ConnectivityStatus(
      isConnected: isConnected ?? this.isConnected,
      isChecking: isChecking ?? this.isChecking,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}
