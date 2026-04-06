# stay_with_me_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local Request Capture Testing

This project includes a local Python server that captures request logs so API wiring can be validated in tests.

Run default tests (includes server-backed Dart test):

```bash
flutter test
```

Run browser smoke test against local capture server:

```bash
python3 scripts/request_capture_server.py --host 127.0.0.1 --port 54010
flutter test --platform chrome test/web_alarm_request_smoke_test.dart \
	--dart-define=API_BASE_URL=http://127.0.0.1:54010
```

Configure runtime request target for the app:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:54010
```
