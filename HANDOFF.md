# HANDOFF — MTLL Safety Clearance App

**Written:** 2026-06-12  
**Audience:** the next Codex or Claude session opened from this repo root  
**Repo cwd:** `~/projects/mtll-safety-app/`  
**Spec workspace:** `~/projects/safety/`  
**Status:** implementation handoff after Sprint S2 core delivery (W1 onboarding wizard, app bootstrap, navigation shell) on top of the completed S1 security kernel

Read this file first, then read `CLAUDE.md`. This handoff follows `HANDOFF_TEMPLATE.md` and is intended to be continuation-safe rather than narrative.

## Verified Facts

### Carried forward from the 2026-06-10 handoff (unchanged)

- Drift schema at `schemaVersion => 6`, 16 tables; `audit_log` append-only triggers with a tamper test; scope-wall schema guard (`player`, `roster`, `minor`, `athlete`, `draft`, `evaluation`, `registration`).
- Nine repositories under `lib/data/repositories/` with same-tenant + cross-tenant tests; repository-layer authorization (`UserRole` VIEWER < ADMIN < OWNER, `requireRole` → `AUTHZ_DENIED` audit + `AuthorizationException`).
- `cross_tenant_query` custom lint at `lints/mtll_lints/` (run `dart run custom_lint`), with the committed `expect_lint` fixture at `test/lints/cross_tenant_query_fixture.dart`.
- §6.1 SQLCipher key management in `lib/security/` (KdfParams + tuning ratchet, KeychainSecureStore, LocalKeystoreKeyProvider, MasterKeyHolder, key/rekey pragma builders) with real-SQLCipher integration tests (Homebrew `libsqlcipher`, auto-skip when absent).

### New in Sprint S2 (PR #7, merged 2026-06-12)

- **App bootstrap** (`lib/app/`):
  - `MtllApp` + `RootGate` implement the W1 trigger routing: no league on device → onboarding wizard; league present → PIN unlock screen; open database → navigation shell.
  - Riverpod providers in `lib/app/providers.dart`: `databaseGatewayProvider` (must be overridden at start), `appDatabaseProvider`, `sessionContextProvider`, `activeLeagueProvider`, `seasonsProvider`.
  - `DatabaseGateway` (`lib/app/database_gateway.dart`): `EncryptedFileDatabaseGateway` implements §6.3.1 `<app-data>/leagues/<league_uuid>/db.enc` with a `catalog.json` index (stem → name/short_name, used for W1 AF-1 collision checks) over the §6.1 KeyProvider flow; `InMemoryDatabaseGateway` for tests. `lib/main.dart` wires the production gateway (counter scaffold removed).
- **W1 onboarding wizard** (`lib/presentation/onboarding/onboarding_wizard_screen.dart`): 3-step Stepper — league profile (name required; short_name, district, charter, timezone, contacts, color validated inline), divisions (7 preset + custom add, AF-3 ≥ 1 required), owner account (name, email, 6-digit PIN + confirm). AF-1 duplicate short_name warns and blocks. Submit creates the database via the gateway, runs `bootstrapLeague`, sets an OWNER `SessionContext`, then shows the W1 step 8 season-or-dashboard prompt (W2 stubbed to a snackbar until S3).
- **PasscodeHasher** (`lib/security/passcode_hasher.dart`): §6.5.2 Argon2id PIN hash in a PHC-style string (`argon2id$v=19$m=…,t=…,p=…$salt$hash`), constant-time verify, parameters carried in the encoding. Default 19 MiB / t=2 / p=1 (interactive posture; the 64 MiB §6.1.1 floor applies to the DB master key, not the login check).
- **Unlock screen** (`lib/presentation/unlock/unlock_screen.dart`): minimal PIN path — derive key, open database, verify `local_passcode_hash`, set session. Carries a justified `// ignore: cross_tenant_query` (pre-session read; the file is the tenancy boundary).
- **Navigation shell** (`lib/presentation/shell/home_shell.dart`): §5.0.1 — `NavigationRail` ≥ 600dp / `NavigationBar` < 600dp (`HomeShell.railBreakpointDp`), compact top-bar actions at mobile width, league name in the top bar, Season selector with empty-state CTA, six destinations (Dashboard live; Volunteers/Teams/Clearances/Matrix/Settings labeled placeholders).
- **Dashboard empty state** (`lib/presentation/dashboard/dashboard_screen.dart`): league name + "Add a volunteer", "Import from spreadsheet/CSV", "Set up a season" CTAs per §5.1/W1.
- **`bootstrapLeague` extended**: optional `leagueId` passthrough (league UUID doubles as the file stem per §6.3.1) and W1 profile fields (timezone, contacts, primaryColorHex).
- **`UserRole.fromWire`** added for session construction from stored `User.role`.

### S2 exit-criteria verification (per §7.2)

All verified by tests in `test/presentation/`:

- Empty Dashboard renders after onboarding with league name and CTAs — `onboarding_wizard_test.dart` W1 happy path.
- Role list has 9 correct rows (permits_minor / is_on_field flags asserted) — same test, plus the pre-existing onboarding repository test.
- AuditLog CREATE entry for League — asserted in the happy-path test.
- No-player-data schema test still passes — full suite green.
- Navigation reaches all primary screens without crash — `home_shell_test.dart`, both rail (1280×900) and bottom-nav (420×900) widths.

### Test inventory

18 test files, 83 tests, all passing. New since last handoff: `test/presentation/` (onboarding wizard, home shell, root gate) and `test/security/passcode_hasher_test.dart`. The default counter `widget_test.dart` was removed with the scaffold. Drift prints a benign "multiple databases" warning in widget tests (each test owns an in-memory instance).

## Verification Run

Verified in this repo on `2026-06-12` during the current session, on clean `main` (after PR #7 merged):

```bash
flutter analyze
flutter test
dart run custom_lint
```

Result:

- `flutter analyze` — passed ("No issues found!")
- `flutter test` — passed (83/83)
- `dart run custom_lint` — passed ("No issues found!")

Notes:

- `build_runner` was not rerun: no Drift table or codegen inputs changed.
- Swift Package Manager adoption warnings from `sqlcipher_flutter_libs` / `flutter_secure_storage*` remain non-fatal.

## Conflicts / Inconsistencies

Items 1–4 from the 2026-06-10 handoff stand unchanged (PRD 7-role vs plan 9-role onboarding text; dual scope-wall token lists; Argon2id package row in the §3 stack table vs pointycastle; `_requireRole` underscore naming). One addition:

### 5. S2 scope item "PIN + biometric" is partially delivered

`~/projects/safety/plan/EXECUTION-PLAN.md` §7.2 S2 scope says "first User (OWNER) with PIN + biometric". The PIN path is implemented and tested. Biometric enrollment/unlock is **not** implemented: `local_auth` requires platform entitlements and a real macOS/iOS build, and this development machine has no full Xcode (see Open Risks). The S2 exit-criteria column does not reference biometric, so the sprint gate is met; the biometric gap is tracked here rather than silently dropped.

## Open Risks / Missing Work

### W1 / S2 deferrals

- **Biometric enrollment + unlock** (§6.5.1): deferred as above. The full sealed `AuthenticationCoordinator` state machine is also still pending; the unlock screen implements only the PIN path.
- **Logo upload (W1 AF-2)**: not implemented — there is no blob store until the EvidenceFile work (S5). `League.logo_blob_id` stays null; the wizard has no logo field yet.
- **KDF device tuning** (`tuneKdfParams`) is still not invoked at startup; `EncryptedFileDatabaseGateway` uses the default floor parameters.
- **Key-zeroing lifecycle hooks** (§6.1.3) are still not wired to app lifecycle events.
- **Timezone auto-detect** (W1 step 2 "auto-detected from OS") is a default-text field (`America/Los_Angeles`), not OS detection.

### Carried-forward gaps

- AuditLogChain daily hash sealing logic (S1 remainder) — still the highest-priority security-kernel gap.
- The whole app has never been launched on a real platform target: this machine lacks full Xcode (`xcodebuild` missing) and CocoaPods, so macOS/iOS builds fail at toolchain. The S1 "Encrypted DB opens on macOS" criterion remains verified only at the library level (host SQLCipher tests).
- Config repositories still lack delete/disable semantics; OWNER-only operations (§6.6.4) have no repository surfaces.
- CSV PII denylist (W11) and biometric-outcomes tests of record remain unimplementable until their subjects exist.

### Worktree cautions

- Worktree clean on `main` at handoff; PRs #1–#7 merged.
- `lib/data/database/app_database.g.dart` remains local-only generated output.
- SQLCipher integration tests skip on machines without Homebrew `sqlcipher`.

## Verified Next Steps

Supported by `~/projects/safety/plan/EXECUTION-PLAN.md` (spec-canonical):

1. **S3 (2026-06-16 – 2026-06-29 per §7.2): Season Setup (W2, no clone) + Requirements Matrix Editor (5.6)** — Season creation wizard, season-specific RoleClearanceRequirement overrides, matrix-change impact preview with cascading `VolunteerClearance` N_A writes, Settings → Seasons + Matrix tabs. The shell's Season selector and "Set up a season" CTAs already route to W2 stubs.
2. AuditLogChain daily hash sealing (S1 scope remainder) — no sprint reassignment exists in the plan; it remains open S1 work.

## Recommendations

Engineering judgment, not verified project truth:

1. Close the AuditLogChain sealing before or alongside early S3 — every sprint that writes more audit rows without chain coverage widens the unverifiable window.
2. When S3 builds Settings tabs, surface the seeded Role list there — it gives the W1 "view the seeded Role list" acceptance stub a UI home (currently verified at the data layer).
3. Wire `tuneKdfParams` and the lifecycle key-zeroing when the first real device build happens (Xcode install) — both need wall-clock and lifecycle behavior that only a running app exhibits.
4. Decide whether the biometric S2 gap moves to S3 or to the first device-build milestone; it needs entitlements work that is pointless before Xcode exists on the dev machine.
