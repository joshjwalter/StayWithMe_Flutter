import 'package:meta/meta.dart';

@immutable
class AlarmResult {
  final bool success;
  final String message;
  final DateTime timestamp;

  const AlarmResult({
    required this.success,
    required this.message,
    required this.timestamp,
  });

  AlarmResult.success({required this.message})
      : success = true,
        timestamp = DateTime.now();

  AlarmResult.failure({required this.message})
      : success = false,
        timestamp = DateTime.now();

  AlarmResult copyWith({
    bool? success,
    String? message,
    DateTime? timestamp,
  }) {
    return AlarmResult(
      success: success ?? this.success,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
