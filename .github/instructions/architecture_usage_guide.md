# Architecture Docs Usage Guide

Use this guide to keep architecture docs consistent and actionable.

## Read Order

1. `architecture_decisions.md` (why)
2. `master_architecture.md` (what/how)
3. `architecture.instructions.md` (agent enforcement)
4. `dart_n_flutter.instructions.md` (language/framework baseline)

## Which file to update

- Update `architecture_decisions.md` when an architectural decision changes.
- Update `master_architecture.md` when structure, naming, layering, or implementation rules change.
- Update `architecture.instructions.md` only when enforcement behavior or rule precedence changes.

## Rule precedence

1. Safety-critical, explicitly documented architecture decisions
2. `master_architecture.md` operational constraints
3. `dart_n_flutter.instructions.md` baseline Dart/Flutter guidance

If there is conflict, follow Dart/Flutter baseline unless a safety exception is explicitly documented in `architecture_decisions.md`.
