# MTLL Safety Clearance App

A cross-platform Flutter app that replaces Mission Trails Little League's volunteer safety-clearance spreadsheet — multi-tenant by design so other Little Leagues can adopt it.

## Status

**Pre-MVP, Sprint 1 (data layer).** Scaffolded 2026-05-19. MVP target 2026-09-05 (macOS + iOS); v1 target 2027-01-10 (adds Windows + Android). See [EXECUTION-PLAN §7.2](../safety/plan/EXECUTION-PLAN.md) for the sprint plan.

## What it does

- Tracks volunteer clearances (Background Check, LiveScan, Concussion / SCA / Diamond Leader, Safety Training, First Aid, Abuse Awareness, three clinic items, 2026 Safety, 2026 Fundamentals) across seasons, roles, and teams.
- Enforces role-specific clearance requirements via a per-league `RoleClearanceRequirement` matrix (the multi-tenant lever).
- Stores no player data — the data-model chain terminates at Team. PII handled per local + LLI requirements.
- Offline-first: every v1 capability works without a network. Per-file XChaCha20-Poly1305 encryption for evidence blobs; SQLCipher for the database; PIN + biometric unlock.

## Spec

This repo is the implementation. Authoritative spec lives at `~/projects/safety/`:

- `requirements/PRD-MTLL-Safety-Clearance-App.md` — 17-section PRD
- `requirements/design-notes.md` — design derivation
- `plan/EXECUTION-PLAN.md` — 10-section integrated execution plan (sprints, schemas, patterns, tests)

## Stack

Flutter 3.x · Riverpod ^2.5 · Drift ^2.18 · SQLite + SQLCipher · cryptography ^2.7 · flutter_secure_storage ^9 · local_auth · freezed · uuid

## Workflow

GitHub is the canonical system of record for this project. From here forward, changes should follow standard configuration-management practices: keep non-secret configuration and build-critical tooling in version control, use focused commits and pull requests for meaningful changes, and keep secrets, generated artifacts, and machine-local overrides out of the repository.

## License

TBD. (Distribution model is GitHub Releases self-install; license decision before first public release.)
