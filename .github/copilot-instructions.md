# Copilot Instructions for stay_with_me_flutter

## Build, Test, and Lint Commands

### Standard test run
```bash
flutter test
```

### Run a single test file
```bash
flutter test test/widget_test.dart
```

### Run web-based smoke test (requires local server)
```bash
# Terminal 1: Start the request capture server
python3 scripts/request_capture_server.py --host 127.0.0.1 --port 54010

# Terminal 2: Run the smoke test
flutter test --platform chrome test/web_alarm_request_smoke_test.dart \
  --dart-define=API_BASE_URL=http://127.0.0.1:54010
```

### Lint
```bash
flutter analyze
```

### Run app in Chrome
```bash
flutter run -d chrome
```

## Architecture

### API Client with Configurable Base URL

`AlarmApiClient` (`lib/api/alarm_api_client.dart`) resolves the API base URL using the following precedence:
1. Constructor parameter `baseUrl` (explicit override)
2. Dart compilation define `API_BASE_URL` (via `--dart-define`)
3. Default: `http://127.0.0.1:54010` (debug web builds only)
4. Empty string (all other cases)

This supports running tests and the app against different backends without code changes.

### Request Capture Test Harness

The project includes a Python-based request capture server for validating API wiring in tests:
- **Server**: `scripts/request_capture_server.py` (lightweight HTTP server that logs requests)
- **Fixture**: `test/test_harness/request_capture_fixture.dart` (Dart wrapper that starts/stops the server and fetches captured requests)
- **Usage**: Tests can verify the exact HTTP method, path, headers, and JSON payload sent by the client

The fixture automatically allocates an ephemeral port and waits for the server to report readiness before proceeding. This pattern allows deterministic testing of HTTP client behavior without network dependencies.

### Timer Correlation with `timerId`

`AlarmApiClient.sendStartAlarm()` and `sendCancelAlarm()` both require a `timerId` parameter. This is a caller-generated hex string (typically derived from the current epoch milliseconds) used to correlate start/cancel pairs on the backend. The client does not generate timer IDs internally—the caller is responsible.

### CountDownTimer Widget

`CountDownTimer` (`lib/countdown_timer.dart`) is a custom countdown widget that:
- Targets a specific wall-clock time (not elapsed duration)
- Recomputes remaining time on each tick using a configurable `nowProvider` to avoid drift
- Displays time in `MM:SS` format
- Fires threshold callbacks (`onEightyPercentWarning`, `onNinetyFivePercentWarning`, `onExpired`) exactly once when crossed
- Requires `totalDuration` to be set for percentage-based thresholds

**Testing**: Inject a fake clock via `nowProvider` to control time in tests without waiting in real time.

## Key Conventions

### Dependency Injection for Testing

Widgets and API clients accept optional constructor parameters for testability:
- `nowProvider` (type: `DateTime Function()`) — Injectable clock for time-based logic
- `apiClient` — Allows tests to inject mocked or fixture-backed clients
- `tickInterval` — Controls countdown refresh rate (useful for fast tests)

### Time Format

Countdown timers display time in `MM:SS` format. Test assertions must use this format (e.g., `"01:00"` for 60 seconds, not `"60"`).

### Python Script Entry Points

Python scripts under `scripts/` use a `main()` entrypoint with the pattern:
```python
if __name__ == '__main__':
    raise SystemExit(main())
```

Convenience launchers at the project root (e.g., `request_capture_server.py`) delegate to the actual implementation in `scripts/`.

### Test Helpers

Use `test/test_harness/` for reusable test utilities. The `RequestCaptureFixture` is the canonical example: it manages server lifecycle and provides a clean API for fetching captured requests.
