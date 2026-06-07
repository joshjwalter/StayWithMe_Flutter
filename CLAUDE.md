# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Lint Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run web-based smoke test (requires local server)
python3 scripts/request_capture_server.py --host 127.0.0.1 --port 54010
flutter test --platform chrome test/web_alarm_request_smoke_test.dart \
  --dart-define=API_BASE_URL=http://127.0.0.1:54010

# Lint
flutter analyze

# Run app in Chrome
flutter run -d chrome

# Run app with custom API base URL
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:54010
```

## High-Level Architecture

### Application Overview

This is a Flutter safety timer application where users start a countdown timer. If the timer expires, an alert is sent to emergency contacts. Users can cancel the timer before expiry. The app maintains server connectivity to ensure reliable alert delivery.

### Core Components

**AlarmPage** (`lib/alarm.dart`)
- Main timer UI with four lifecycle phases: idle, active, expired, cancelled
- Manages server connectivity polling at adaptive intervals (5s active/disconnected, 10s active/connected, 30s idle)
- Displays server connection status in AppBar as an animated pill
- Generates `timerId` from epoch milliseconds in hex for start/cancel correlation
- Implements connectivity-aware cancel (disabled when offline)

**CountDownTimer** (`lib/countdown_timer.dart`)
- Targets wall-clock time, not elapsed duration—recomputes from clock each tick to avoid drift
- Fires threshold callbacks exactly once: 80% (shoulder-tap SnackBar), 95% (full-screen overlay), expired
- Requires `totalDuration` for percentage-based thresholds
- Uses `formatMmSs()` for MM:SS display format

**AlarmApiClient** (`lib/api/alarm_api_client.dart`)
- Resolves API base URL precedence: constructor param → `--dart-define API_BASE_URL` → default (debug web only) → empty
- Sends JSON payloads with UTC timestamps and `timerId` correlation
- Includes `checkConnectivity()` for health polling
- Disposes owned HTTP client when not injected

### Request Capture Test Harness

**Server**: `scripts/request_capture_server.py` — Lightweight HTTP server that logs requests
**Fixture**: `test/test_harness/request_capture_fixture.dart` — Dart wrapper managing server lifecycle
- Allocates ephemeral port automatically
- Waits for server readiness before proceeding
- Returns captured requests for verification (method, path, headers, body)

This enables deterministic HTTP client testing without network dependencies.

### Dependency Injection for Testing

Widgets and API clients accept optional constructor parameters:
- `nowProvider` (`DateTime Function()`) — Inject deterministic clock for time-based logic
- `apiClient` — Inject mocked or fixture-backed clients
- `tickInterval` — Control countdown refresh rate for fast tests

### Timer Correlation with `timerId`

`AlarmApiClient.sendStartAlarm()` and `sendCancelAlarm()` require a caller-generated `timerId` parameter. The page generates this as a hex string from epoch milliseconds:

```dart
final timerId = now.millisecondsSinceEpoch.toRadixString(16).toUpperCase();
```

This correlates start/cancel pairs on the backend. The client does not generate timer IDs internally.

### Time Format Convention

All countdown displays and test assertions use `MM:SS` format (e.g., `"01:00"` for 60 seconds). Use `CountDownTimer.formatMmSs(seconds)` for consistency.

### Architecture Documentation

Comprehensive architecture documentation exists in `.github/instructions/`:
- `architecture_usage_guide.md` — How to use the docs
- `architecture_decisions.md` — Why certain decisions were made
- `master_architecture.md` — What and how
- `architecture.instructions.md` — Enforcement rules
- `dart_n_flutter.instructions.md` — Dart/Flutter baseline

When guidance conflicts, prefer `dart_n_flutter.instructions.md` unless `architecture_decisions.md` documents a safety-critical exception.

### Python Script Pattern

Scripts in `scripts/` use this entrypoint pattern:

```python
if __name__ == '__main__':
    raise SystemExit(main())
```

Project root may contain convenience launchers that delegate to `scripts/`.

### Web Search Usage Policy

**Brave Search Usage Rule**:
- Use Brave search ONLY ONCE per question
- Only use web search if you cannot find an answer from:
  - Available Context7 documentation (preferred for library/framework questions)
  - Existing codebase knowledge
  - Project documentation (CLAUDE.md, .github/instructions/)
- For research questions, determine if search is absolutely necessary before proceeding
- Brave search is token-based and has monthly limits - use conservatively
- Prefer Context7 for programming/library documentation over web search
