import 'package:get_it/get_it.dart';
import '../../infrastructure/api/alarm_api_client.dart';
import '../../domain/repositories/alarm_repository.dart';
import '../../data/repositories/alarm_repository_impl.dart';

/// Global service locator instance.
final serviceLocator = GetIt.instance;

/// Registers long-lived singleton services with the service locator.
///
/// This function should be called once during app initialization,
/// typically in the [main] function before running the app.
void setupServiceLocator() {
  // Register AlarmApiClient as a singleton.
  //
  // The client is configured with environment-based URL resolution:
  // 1. Constructor parameter takes precedence
  // 2. Falls back to --dart-define API_BASE_URL
  // 3. Defaults to http://127.0.0.1:54010 for debug web
  // 4. Empty string if not configured (for offline-only scenarios)
  serviceLocator.registerSingleton<AlarmApiClient>(
    AlarmApiClient(),
  );

  // Register AlarmRepository as a singleton.
  //
  // The repository wraps the API client and provides domain-level
  // abstractions. Registering it as a singleton ensures the same
  // repository instance is used throughout the app, maintaining
  // consistent state and behavior.
  serviceLocator.registerSingleton<AlarmRepository>(
    AlarmRepositoryImpl(apiClient: serviceLocator<AlarmApiClient>()),
  );
}
