# StayWithMe Architecture Decisions

**Purpose:** Canonical rationale for architecture choices used by this repository.  
**Status:** Active

## AD-001: State Management Uses Riverpod

- **Decision:** Use Riverpod providers/notifiers for app and feature state.
- **Why:** Safety-critical flows require explicit async loading/error/data states and controlled recomputation.
- **Tradeoff:** More upfront architecture than Provider/ChangeNotifier.
- **Alignment note:** Flutter supports multiple approaches; this app chooses Riverpod due to reliability requirements.

## AD-002: Navigation Uses GoRouter

- **Decision:** Use `go_router` for route definition, deep links, and guarded navigation.
- **Why:** Predictable route state and clear redirection handling for auth and emergency states.
- **Tradeoff:** Additional abstraction compared with direct Navigator API.

## AD-003: Hybrid DI (GetIt + Riverpod)

- **Decision:** GetIt manages app-lifetime singletons; Riverpod manages scoped reactive state.
- **Why:** Separates infrastructure lifecycle from feature/view lifecycle.
- **Tradeoff:** Two DI concepts to understand.
- **Clarification:** This is complementary, not conflicting.

## AD-004: Server-Authoritative Timer and Alert

- **Decision:** Timer truth, expiration checks, and alert scheduling are server-authoritative.
- **Why:** Alert must still fire if app is backgrounded, disconnected, or device is unavailable.
- **Tradeoff:** Strong backend dependency and reconnect handling complexity.

## AD-005: Domain Layer Is Mandatory

- **Decision:** Domain layer is required for timer/alert/medical logic.
- **Why:** These workflows contain non-trivial rules and safety-sensitive behavior.
- **Tradeoff:** More structure than a simple UI-first app.
- **Alignment note:** Flutter allows conditional domain layers; this app qualifies for mandatory use.

## AD-006: Strict Layering and No Silent Failures

- **Decision:** Enforce one-way dependencies and explicit error surfacing.
- **Why:** Predictability, maintainability, and safety diagnostics.
- **Tradeoff:** Less convenience for ad-hoc shortcuts.

## Update Rule

When architecture changes, append a new `AD-###` entry with:

1. Decision
2. Why
3. Tradeoff
4. Flutter-alignment or safety-exception note
