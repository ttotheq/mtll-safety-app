# HANDOFF — MTLL Safety Clearance App

**Written:** 2026-06-10  
**Audience:** the next Codex or Claude session opened from this repo root  
**Repo cwd:** `~/projects/mtll-safety-app/`  
**Spec workspace:** `~/projects/safety/`  
**Status:** implementation handoff after closing the Sprint S1 / Epic E1 security-kernel gaps (repositories, repository-layer authorization, cross-tenant lint, SQLCipher key management)

Read this file first, then read `CLAUDE.md`. This handoff follows `HANDOFF_TEMPLATE.md` and is intended to be continuation-safe rather than narrative.

## Verified Facts

### Schema and database layer

- The local Drift schema is at `schemaVersion => 6` with 16 tables wired in `lib/data/database/app_database.dart` (`leagues` through `audit_log_chain`; same list as the previous handoff).
- `audit_log` immutability is enforced in SQLite with `audit_log_no_update` and `audit_log_no_delete` triggers, and `test/data/database/schema_test.dart` includes a tamper test ("AuditLog UPDATE and DELETE are blocked by triggers").
- The schema scope-wall guard in `test/data/database/schema_test.dart` rejects table names containing `player`, `roster`, `minor`, `athlete`, `draft`, `evaluation`, or `registration`.
- `lib/data/database/app_database.g.dart` remains local-only generated output (gitignored, never committed).

### Repository layer

- `lib/data/repositories/` now contains nine repository files. New since the previous handoff:
  - `role_clearance_requirement_repository.dart`: tenant-filtered listing, audited cross-tenant `getById()`, `create()`/`update()` validating the requirement level against the locked `REQUIRED / OPTIONAL / CONDITIONAL_OK / NOT_APPLICABLE` set (reused from `SeedRequirementLevels`).
  - `team_repository.dart`: computes the workbook-compatible `display_name` ("MAJORS - BONILLA") on write per design-notes §1.4 and tenant-asserts the referenced Division (cross-tenant division references are audited and rejected).
  - `volunteer_assignment_repository.dart`: `ACTIVE / REMOVED / REPLACED` status enum per design-notes §1.7, audited `create()`/`update()`.
- Repository-layer authorization is implemented per EXECUTION-PLAN §6.6:
  - `SessionContext` (`lib/data/repositories/session_context.dart`) carries `role` (`UserRole` enum, VIEWER < ADMIN < OWNER), defaulting to least-privilege VIEWER.
  - `LeagueScopedRepository.requireRole(...)` writes an `AUTHZ_DENIED` audit entry and throws `AuthorizationException` before any data access. The plan names this `_requireRole`; it is exposed without the underscore so subclass repositories in other libraries can call it.
  - All entity `create()`/`update()` methods are gated at ADMIN minimum (Division, Role, ClearanceType, RoleClearanceRequirement, Team, VolunteerAssignment). Reads remain open to VIEWER.
  - The W1 onboarding bootstrap (`league_onboarding_repository.dart`) is intentionally ungated — it runs pre-authentication, before any User row exists.

### Cross-tenant lint (EXECUTION-PLAN §6.3.5)

- A project-local `custom_lint` plugin package lives at `lints/mtll_lints/` (path dev-dependency). Its `cross_tenant_query` rule reports, at ERROR severity, any Drift `select()`/`delete()` on a league-scoped table whose enclosing query expression lacks a `leagueId` filter (`tenantFilter(...)` or a direct `leagueId` predicate).
- Run with `dart run custom_lint`. Wired via `analysis_options.yaml` (`analyzer.plugins: [custom_lint]`).
- `*_test.dart` files are exempt (tests query directly to verify audit behavior).
- `test/lints/cross_tenant_query_fixture.dart` holds the synthetic violation with an `// expect_lint: cross_tenant_query` marker — `dart run custom_lint` fails with `unfulfilled_expect_lint` if the rule ever stops firing (S1 exit criterion "cross-tenant lint fires on a synthetic violation" is therefore continuously verified). A negative control (bare violation in `lib/`, no marker) was confirmed to report `cross_tenant_query • ERROR` during this session.
- Intentional unfiltered reads (the fetch-then-`assertLeagueScope` audit pattern and post-update re-reads) carry justified `// ignore: cross_tenant_query` suppressions.
- `lib/main.dart` carries a scoped `// ignore: missing_provider_scope` (riverpod_lint) on the placeholder scaffold so the custom_lint gate stays clean; ProviderScope arrives with the S2 bootstrap.

### SQLCipher key management (EXECUTION-PLAN §6.1)

- `lib/security/` now contains:
  - `kdf_params.dart`: Argon2id parameter object — §6.1.1 floor (64 MiB / 3 iterations / parallelism 1 / 32-byte output), JSON round-trip, and `tuneKdfParams(...)` implementing the device-tuning ratchet (below 200 ms → step memory through 128 MiB then 256 MiB until the 300–500 ms target is met).
  - `secure_store.dart`: `SecureStore` abstraction + `KeychainSecureStore` over `flutter_secure_storage` with `first_unlock_this_device` accessibility on macOS/iOS (§6.1.2; salt never syncs to iCloud).
  - `key_provider.dart`: `KeyProvider` abstraction (§6.1.6 — v2 `RemoteKmsKeyProvider` stays a drop-in swap) + `LocalKeystoreKeyProvider`: per-league 32-byte random salt under `db_salt_<stem>`, tuned params JSON under `db_kdf_params_<stem>`, Argon2id derivation via pointycastle. Passcode and derived key are never stored.
  - `master_key_holder.dart`: §6.1.3 in-memory-only key holder with buffer zeroing.
  - `sqlcipher_database.dart`: raw-hex `PRAGMA key` / `PRAGMA rekey` builders (§6.1.1 step 3, §6.1.5) and `openEncryptedDatabase(...)` returning a Drift `NativeDatabase` that applies the key pragma at connection setup.
- `test/security/sqlcipher_database_test.dart` runs real-SQLCipher integration tests against a host SQLCipher library (Homebrew `libsqlcipher.dylib` or `$SQLCIPHER_LIB`; tests auto-skip when absent): encrypted file header check, wrong-key rejection, §6.1.5 rekey rotation, and Drift `AppDatabase` open-persist-reopen over an encrypted file. Homebrew `sqlcipher` (3.53.1) was installed on this machine during this session as a dev dependency for these tests.

### Test inventory

15 test files, 71 tests, all passing: schema/scope-wall/uniqueness/audit-trigger tests, onboarding bootstrap, per-entity repository same-tenant + cross-tenant tests, repository authorization tests, KDF/key-provider/key-holder/SQLCipher security tests, and the default widget smoke test.

### GitHub state

- `main` is the default branch; all S1 work landed via merged PRs #1–#5 (docs, repositories, authorization, cross-tenant lint, SQLCipher key management). Worktree was clean at handoff time.

## Verification Run

Verified in this repo on `2026-06-10` during the current session, on a clean `main` checkout (after PR #5 merged):

```bash
flutter analyze
flutter test
dart run custom_lint
```

Result:

- `flutter analyze` — passed ("No issues found!")
- `flutter test` — passed (71/71)
- `dart run custom_lint` — passed ("No issues found!"); the `expect_lint` fixture marker confirms the cross-tenant rule fires

Notes:

- `build_runner` was not rerun this session: no Drift table or other codegen inputs changed.
- Flutter still prints non-fatal Swift Package Manager adoption warnings for `sqlcipher_flutter_libs` and `flutter_secure_storage*`; they do not block any gate.
- The SQLCipher integration tests ran against Homebrew `libsqlcipher` 3.53.1 and passed; on machines without a host SQLCipher library they skip with an explanatory message.

## Conflicts / Inconsistencies

### 1. Onboarding role-count and matrix sizing still disagree across current spec sources (unchanged, unresolved)

- `~/projects/safety/requirements/PRD-MTLL-Safety-Clearance-App.md` onboarding text still says `7 Role rows` and `12 × 7 = 84 RoleClearanceRequirement rows`, and still mentions `Junior Scorekeeper` as optional seeded role material.
- `~/projects/safety/plan/EXECUTION-PLAN.md` W1 / S2 / `W1-AC-1` says onboarding seeds `9` roles and implies the `96`-row default matrix.
- The repo implements the execution-plan shape (9 roles, 96 rows, `Not Assigned` seeded, no `Junior Scorekeeper`).

### 2. The execution plan still uses two different scope-wall token lists (unchanged, unresolved)

- Sprint/DoD text in `~/projects/safety/plan/EXECUTION-PLAN.md` names `player`, `roster`, `minor`, `athlete`, `draft`, `evaluation`; CI/security-test language adds `registration`.
- The repo test enforces the broader list including `registration`, per `CLAUDE.md`.

### 3. Argon2id implementation package: §3 stack table vs §6.1.1 / pubspec

- `~/projects/safety/plan/EXECUTION-PLAN.md` line ~382 (key-derivation stack row) says "Argon2id via `cryptography` package".
- EXECUTION-PLAN §6.1.1 step 1 references "`dart:math` SecureRandom (or the `pointycastle` equivalent)", and this repo's `pubspec.yaml` has carried the comment "pointycastle: Argon2id for SQLCipher master-key derivation (§6.1.1 step 2)" since the scaffold commit.
- The repo implements Argon2id via `pointycastle` (`Argon2BytesGenerator`). The `cryptography ^2.7` package remains in the stack for XChaCha20-Poly1305 evidence encryption (§6.4). Not silently resolved — flag to the spec workspace whether the §3 stack row should be corrected to pointycastle.

### 4. `_requireRole` naming

- EXECUTION-PLAN §6.6.2 names the guard `_requireRole(session, minimum: UserRole.admin)`. Dart underscore-privacy is library-scoped, so a literal `_requireRole` on the base class would be invisible to subclass repositories in other files. The repo implements it as `requireRole(...)` on `LeagueScopedRepository` with identical semantics (`AuthorizationException` + `AUTHZ_DENIED` audit entry).

## Open Risks / Missing Work

### Remaining S1 / E1 scope not covered by the six closed conditions

- **AuditLogChain daily hash sealing logic** is not implemented — the `audit_log_chain` table exists with a uniqueness test, but no `AuditChainVerifier` (Merkle chain computation, startup scan, tamper modal trigger) exists yet in `lib/security/`.
- **"Encrypted DB opens on macOS and iOS" exit criterion** is verified at the library level (host SQLCipher integration tests) but not yet as a running app: there is no `DatabaseService` / `AuthenticationCoordinator` wiring `KeyProvider` → `openEncryptedDatabase` → `AppDatabase` at startup, no PIN-entry flow, and no biometric unlock (§6.5). That is S2 bootstrap territory.
- **KDF device tuning is not invoked anywhere** — `tuneKdfParams` exists with tests, but the "measure on first open" startup path that calls it is part of the missing app bootstrap.
- **Key-zeroing lifecycle hooks** (screen lock / backgrounding / timeout / termination, §6.1.3) are not wired; `MasterKeyHolder.zero()` exists but nothing calls it yet.

### Other gaps carried forward

- Config repositories still lack delete / disable semantics.
- The onboarding UI / wizard flow (W1, Sprint S2) does not exist; `lib/main.dart` is still the default counter scaffold (with a scoped riverpod-lint ignore).
- `test/widget_test.dart` is still the default counter smoke test and will need replacement with the S2 shell.
- Biometric-outcomes test coverage (§6.5.1 table; a CLAUDE.md test of record) and the CSV PII denylist test (W11) are not yet implementable — their subjects don't exist yet.
- OWNER-only operations (§6.6.4: user management, league settings, retention, audit export) have no repository surfaces yet, so the OWNER gate is exercised only by the role-hierarchy test.

### Worktree cautions

- Worktree was clean on `main` at handoff. No uncommitted work.
- `lib/data/database/app_database.g.dart` stays local-only generated output (gitignored).
- The SQLCipher integration tests depend on Homebrew `sqlcipher` on this machine; do not mistake their skip message on another machine for a failure.

## Verified Next Steps

Supported by `~/projects/safety/plan/EXECUTION-PLAN.md` (spec-canonical):

1. Close the remaining S1 / E1 item: AuditLogChain daily hash sealing (§6.2, S1 scope "AuditLogChain daily hash"), including the startup verification scan that drives the §5.D.1 tamper modal.
2. S2 (per §7.2, dated 2026-06-02 – 2026-06-15): W1 onboarding wizard end-to-end, first User (OWNER) with PIN + biometric, navigation shell, responsive breakpoints, Season selector. The S2 PIN/biometric work is where `KeyProvider`, `tuneKdfParams`, `MasterKeyHolder`, and `openEncryptedDatabase` get wired into a real `AuthenticationCoordinator` (§6.5.1 sealed state machine).

## Recommendations

Engineering judgment, not verified project truth:

1. Implement AuditLogChain sealing before starting S2 UI — it completes the S1 security kernel while the audit-layer context is fresh, and S2's onboarding writes will then be chain-covered from day one.
2. When building the S2 bootstrap, construct `SessionContext` with the authenticated user's `UserRole` parsed from `User.role` (stored as `OWNER`/`ADMIN`/`VIEWER` wire strings); a `UserRole.fromWire(...)` helper was deliberately not added until that call site exists.
3. Keep the custom_lint gate in any future CI workflow as a required step alongside `flutter analyze` and `flutter test` (`dart run custom_lint` is the command; EXECUTION-PLAN §6.3.5 calls it build-blocking).
4. Surface spec inconsistencies #1–#3 above to the spec workspace (`~/projects/safety/`) in one batch rather than patching them piecemeal from this repo.
