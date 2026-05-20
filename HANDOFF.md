# HANDOFF — MTLL Safety Clearance App

**Written:** 2026-05-20  
**Audience:** the next Codex or Claude session opened from this repo root  
**Repo cwd:** `~/projects/mtll-safety-app/`  
**Spec workspace:** `~/projects/safety/`  
**Status:** implementation handoff after the first repository-layer buildout for onboarding and configuration entities

Read this file first, then read `CLAUDE.md`. This handoff follows `HANDOFF_TEMPLATE.md` and is intended to be continuation-safe rather than narrative.

## Verified Facts

- The local Drift schema exists and is at `schemaVersion => 6`.
- `lib/data/database/app_database.dart` currently wires 16 tables:
  - `leagues`
  - `seasons`
  - `divisions`
  - `teams`
  - `volunteers`
  - `roles`
  - `volunteer_assignments`
  - `clearance_types`
  - `role_clearance_requirements`
  - `volunteer_clearances`
  - `evidence_files`
  - `exemptions`
  - `activity_logs`
  - `users`
  - `audit_log`
  - `audit_log_chain`
- Forward migrations exist for:
  - `v2`: `Volunteer`, `Role`, `VolunteerAssignment`, plus `teams.league_id` backfill
  - `v3`: `ClearanceType`, `RoleClearanceRequirement`, `VolunteerClearance`, `Exemption`
  - `v4`: `EvidenceFile`
  - `v5`: `ActivityLog`, `User`, `AuditLog`, `AuditLogChain`
  - `v6`: append-only `audit_log` triggers
- `audit_log` immutability is enforced in SQLite with `audit_log_no_update` and `audit_log_no_delete`.
- Manual indexes and partial/null-safe uniqueness DDL exist for cases Drift cannot express directly.
- Seed data currently implemented under `lib/data/database/seeds/`:
  - `clearance_seed_data.dart`: 12 clearance types, 96 default role-clearance requirement rows, `FUNDAMENTALS_2026.active = false`, `R/C` stored as `CONDITIONAL_OK`, and `ONE_TIME` as the only non-recurring category
  - `division_seed_data.dart`: preset onboarding divisions
  - `role_seed_data.dart`: the current 9-role onboarding seed
- The schema scope-wall guard is implemented in `test/data/database/schema_test.dart`. It rejects table names containing `player`, `roster`, `minor`, `athlete`, `draft`, `evaluation`, or `registration`.
- Repository-layer code currently implemented under `lib/data/repositories/`:
  - `session_context.dart`: current `leagueId` plus optional `userId`
  - `league_scoped_repository.dart`: shared tenant filter, audit-log write helper, cross-tenant assertion behavior, and basic field normalization helpers
  - `volunteer_repository.dart`: tenant-filtered `listAll()` and audited `getById()`
  - `league_onboarding_repository.dart`: transactional onboarding bootstrap for `League`, selected `Division` rows, first `User`, 9 seeded `Role` rows, 12 seeded `ClearanceType` rows, and the default `RoleClearanceRequirement` matrix
  - `division_repository.dart`: ordered same-tenant reads plus audited `create()` / `update()`
  - `role_repository.dart`: ordered same-tenant reads plus audited `create()` / `update()`
  - `clearance_type_repository.dart`: ordered same-tenant reads plus audited `create()` / `update()`
- `league_onboarding_repository.dart` redacts secret hash fields from the `User` audit payload before writing `after_json`.
- Repository tests currently implemented under `test/data/repositories/`:
  - `volunteer_repository_test.dart`: same-tenant list filtering, same-tenant fetch-by-id, and cross-tenant fetch-by-id audit + `AssertionError`
  - `league_onboarding_repository_test.dart`: onboarding bootstrap, role/count expectations, `FUNDAMENTALS_2026.active = false`, zero-division rejection, and division deduplication
  - `division_repository_test.dart`, `role_repository_test.dart`, and `clearance_type_repository_test.dart`: ordered same-tenant listing, cross-tenant fetch-by-id audit + `AssertionError`, and same-tenant `create()` / `update()` audit trails with before/after JSON
- `lib/data/database/app_database.g.dart` exists locally and should remain a local generated artifact rather than a committed source file.

## Verification Run

Verified in this repo on `2026-05-20` during the current session:

```bash
flutter test test/data/database/schema_test.dart
flutter test test/data/repositories/league_onboarding_repository_test.dart test/data/repositories/volunteer_repository_test.dart test/data/repositories/division_repository_test.dart test/data/repositories/role_repository_test.dart test/data/repositories/clearance_type_repository_test.dart
flutter analyze
flutter test
```

Result:

- `flutter test test/data/database/schema_test.dart` — passed
- `flutter test test/data/repositories/league_onboarding_repository_test.dart test/data/repositories/volunteer_repository_test.dart test/data/repositories/division_repository_test.dart test/data/repositories/role_repository_test.dart test/data/repositories/clearance_type_repository_test.dart` — passed
- `flutter analyze` — passed
- `flutter test` — passed

Notes:

- `build_runner` was not rerun in this session because the work was repository/tests/doc changes and did not modify Drift annotations or other codegen inputs.
- Flutter still prints non-fatal Swift Package Manager adoption warnings for `sqlcipher_flutter_libs` and `flutter_secure_storage*`; they did not block `analyze` or `test`.

## Conflicts / Inconsistencies

### 1. Onboarding role-count and matrix sizing still disagree across current spec sources

This is still unresolved and should not be silently “cleaned up” in code:

- `~/projects/safety/requirements/PRD-MTLL-Safety-Clearance-App.md` onboarding text still says onboarding creates `7 Role rows` and `12 × 7 = 84 RoleClearanceRequirement rows`
- that same PRD still mentions `Junior Scorekeeper` as optional seeded role material
- `~/projects/safety/plan/EXECUTION-PLAN.md` W1 / S2 / `W1-AC-1` says onboarding seeds `9` roles and implies the current `96`-row default matrix
- the repo currently implements the execution-plan shape: `Not Assigned` is seeded, `Junior Scorekeeper` is not seeded, and the default matrix is `96` rows

### 2. The execution plan still uses two different scope-wall token lists

This is a spec-side inconsistency, and the repo currently follows the broader set:

- Sprint / DoD text in `~/projects/safety/plan/EXECUTION-PLAN.md` names `player`, `roster`, `minor`, `athlete`, `draft`, and `evaluation`
- CI / security-test language in that same plan adds `registration`
- the repo test currently enforces the broader list including `registration`

## Open Risks / Missing Work

### Remaining explicit Sprint 1 / E1 gaps

- The custom cross-tenant `dart_analyzer` lint rule is not implemented yet.
- SQLCipher integration plus `KeyProvider` / Argon2id / OS-keystore key management is not implemented yet.
- Repository-layer authorization is still incomplete:
  - `SessionContext` does not yet carry role information
  - `_requireRole(...)` / `AUTHZ_DENIED` behavior from the execution plan is not implemented
- Repository coverage is improved but still incomplete for the Sprint 1 test gate:
  - no repository exists yet for `RoleClearanceRequirement`
  - no repository exists yet for `Team`
  - no repository exists yet for `VolunteerAssignment`
  - the config repositories do not yet implement delete / disable semantics

### Onboarding / workflow gaps

- The data-layer onboarding bootstrap exists, but the onboarding UI / wizard flow does not.
- The onboarding repository currently accepts a precomputed `ownerPasscodeHash`; PIN derivation, biometric enrollment, and keystore-backed key flow are still missing.
- Workflow-level integration tests against a real SQLCipher-backed database are still missing.

### Worktree cautions

Current `git status --short` in this session:

```text
 M CLAUDE.md
 M lib/main.dart
?? AGENTS.md
?? HANDOFF.md
?? HANDOFF_TEMPLATE.md
?? lib/data/database/app_database.dart
?? lib/data/database/seeds/
?? lib/data/database/tables/
?? lib/data/repositories/clearance_type_repository.dart
?? lib/data/repositories/division_repository.dart
?? lib/data/repositories/league_onboarding_repository.dart
?? lib/data/repositories/league_scoped_repository.dart
?? lib/data/repositories/role_repository.dart
?? lib/data/repositories/session_context.dart
?? lib/data/repositories/volunteer_repository.dart
?? test/data/
```

- `CLAUDE.md` and `lib/main.dart` already have local modifications; do not revert them blindly.
- All current schema, repository, test, and handoff work is still uncommitted.
- `AGENTS.md`, `HANDOFF.md`, and `HANDOFF_TEMPLATE.md` are new local docs in this worktree.

### Generated output

- `lib/data/database/app_database.g.dart` is intentionally local-only generated output and should stay uncommitted.

## Verified Next Steps

The following remaining work is explicitly supported by the current primary spec source in `~/projects/safety/plan/EXECUTION-PLAN.md`:

1. Finish the remaining Sprint `S1` / Epic `E1` security-kernel items:
   - cross-tenant `dart_analyzer` lint
   - SQLCipher setup
   - Argon2id KDF + OS keystore integration
2. Continue repository-layer implementation until the Sprint 1 test gate expectation of repository CRUD + cross-tenant assertion coverage is actually met.
3. Once the remaining `E1` work is closed, the next spec-canonical sprint is `S2`, which starts the W1 onboarding wizard and navigation shell.

## Recommendations

This is engineering judgment about the cleanest continuation order from the current repo state:

1. Finish repository coverage before switching to UI. The next three repositories should be `RoleClearanceRequirement`, `Team`, and `VolunteerAssignment`.
2. Keep all mutating paths going through `LeagueScopedRepository` helpers so audit behavior and tenant enforcement do not fork by entity.
3. Add role-aware session state and repository authorization before the onboarding UI starts writing directly into more entities.
4. Implement the cross-tenant analyzer lint before the SQLCipher slice if the goal is to reduce the chance of unsafe Drift call patterns spreading while the repository layer grows.
5. Leave `lib/main.dart` alone unless the task is explicitly about app bootstrap or UI, because it already contains unrelated local edits.
