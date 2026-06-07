---
description: "StayWithMe architecture operating rules and file-structure standards."
applyTo: "**/*.dart"
---

# StayWithMe Architecture Instructions

Before making Dart/Flutter changes, use this read order:

1. `.github/instructions/architecture_usage_guide.md`
2. `.github/instructions/architecture_decisions.md`
3. `.github/instructions/master_architecture.md`
4. `.github/instructions/dart_n_flutter.instructions.md`

## Enforcement Rules

1. Use the feature-first structure defined in `master_architecture.md`.
2. Respect dependency direction: `presentation -> state -> domain -> data -> infrastructure`.
3. Keep entities immutable and strongly typed.
4. Do not silently swallow exceptions; surface or rethrow with context.
5. Keep timer/alert behavior server-authoritative.
6. Prefer Riverpod providers/notifiers for state and async orchestration.
7. Use GetIt only for app-lifetime infrastructure singletons.
8. Follow naming rules in `master_architecture.md` for files and types.
9. For any architectural change, add/update a decision entry in `architecture_decisions.md`.
10. If a rule conflicts with generic Flutter guidance, follow `dart_n_flutter.instructions.md` unless a safety-critical exception is explicitly documented in `architecture_decisions.md`.

## Safety-Critical Exceptions

The following intentional deviations are approved for this app:

- Riverpod is preferred over Provider/ChangeNotifier for async safety and explicit error handling.
- The domain layer is mandatory for timer, alert, and medical-profile logic.
- Server time and server scheduling are authoritative for countdown/alert outcomes.
