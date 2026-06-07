# StayWithMe Master Architecture

**Purpose:** Operational rules (what/how) for project structure, naming, layering, and implementation boundaries.

## 1. Folder Strategy (Feature-First + Layers)

```text
lib/
  config/
  core/
  infrastructure/
  domain/
  data/
  presentation/
    shared/
    features/
      <feature_name>/
        screens/
        widgets/
        providers/
```

### Required meanings

- `config`: app-level config and routing.
- `core`: shared primitives (errors, extensions, reusable widgets, utilities).
- `infrastructure`: external integrations (Supabase client, secure storage, connectivity wrappers).
- `domain`: entities, repository contracts, orchestration services.
- `data`: repository implementations against infrastructure.
- `presentation`: UI and feature-facing provider entry points.

## 2. Dependency Rules

One-way dependency direction only:

`presentation -> state/providers -> domain -> data -> infrastructure`

Never import upward or laterally across features when shared code belongs in `core` or `domain`.

## 3. Naming Rules

- Files: `snake_case.dart`
- Types: `PascalCase`
- Providers variables: `lowerCamelCase`
- Domain entities: `*Entity`
- Repository contracts: `*Repository`
- Repository implementations: `*RepositoryImpl`
- Screens: `*_screen.dart`
- Feature providers/notifiers: `*_provider.dart` / `*_notifier.dart`

## 4. State and DI Rules

- Riverpod is the default state-management mechanism.
- GetIt is limited to long-lived infrastructure singletons.
- Riverpod notifiers are this project's ViewModel-equivalent layer.

## 5. Error and Safety Rules

- No silent failures; never swallow exceptions.
- Convert infrastructure exceptions to explicit domain/app exceptions.
- Keep timer and alert behavior server-authoritative.
- Avoid raw `dart:async` orchestration in screens; consume providers instead.

## 6. Flutter Alignment and Intentional Deviations

- Aligned with Flutter recommendations on separation of concerns, repository boundaries, naming, and typed APIs.
- Intentional deviations documented in `architecture_decisions.md`:
  - Riverpod preference over Provider/ChangeNotifier for safety-critical async handling.
  - Mandatory domain layer for complex timer/alert/medical behavior.

## 7. Change Management

Before creating or moving files:

1. Confirm target feature and layer.
2. Validate naming against Section 3.
3. Validate imports against Section 2.
4. Check `architecture_decisions.md` for rationale constraints.
5. Update `architecture_decisions.md` when introducing new architecture direction.
