# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## What this project is

The **MTLL Safety Clearance App** — a cross-platform Flutter desktop + mobile application that replaces Mission Trails Little League's volunteer safety-clearance Excel spreadsheet (191 volunteers × 12 clearances). Multi-tenant from day one so other Little Leagues can adopt it.

This repository holds the **implementation**. The specification lives separately at `~/projects/safety/`:

- `~/projects/safety/requirements/PRD-MTLL-Safety-Clearance-App.md` — 17-section Product Requirements Document (canonical "what to build")
- `~/projects/safety/requirements/design-notes.md` — 10-section design derivation
- `~/projects/safety/plan/EXECUTION-PLAN.md` — 10-section integrated execution plan (the actual build instructions)

**When the implementation conflicts with the spec, fix the implementation. When new constraints surface that the spec didn't anticipate, update both the spec and the implementation in the same change.**

## Locked stack (EXECUTION-PLAN §3.1, §10.1 — do NOT change without reopening the decision)

- **Flutter 3.x** (currently 3.44.0 via Homebrew cask)
- **Dart 3.x**
- **Riverpod ^2.5** — state management (codegen flavor)
- **Drift ^2.18** — SQLite ORM with code-generation
- **SQLite + SQLCipher** — encrypted local database
- **cryptography ^2.7** — XChaCha20-Poly1305 for per-file evidence encryption
- **flutter_secure_storage ^9** — OS keystore wrapper (Keychain / DPAPI / Android Keystore)
- **local_auth** — biometric unlock (Touch ID / Face ID / Windows Hello)
- **freezed + json_annotation** — immutable models + JSON serialization
- **uuid** — UUIDv7 primary keys

## Locked decisions (from 2026-05-19 — do NOT relitigate)

See `~/projects/safety/CLAUDE.md` for the canonical list. Summary:

- Background Check + LiveScan are distinct clearance items (no merge).
- 3-year retention post final season; 90-day soft-archive window before PII nullification.
- CONDITIONAL counts as Cleared (single yellow KPI bucket).
- Email via `mailto:` (v1); OAuth (v2).
- Distribution: GitHub Releases self-install — each league downloads from a public artifact store.
- Code-signing budget: DEFERRED until first signed binary needs to ship to a non-developer machine (see EXECUTION-PLAN §10.3 #5).
- Assistant Coach split into On-Field / Dugout sub-roles in seed; Junior Umpires are a separate role with `permits_minor=true`.

## Scope wall (load-bearing — enforced by tests)

This app stores **no player data**. The data-model chain terminates at Team. There is no Player, Roster, Game, Pitch, Score, Draft, or Practice entity.

The scope wall is enforced at three layers:

1. **Schema test / CI guard** — maintain a load-bearing schema check that rejects table names containing `player`, `roster`, `minor`, `athlete`, `draft`, `evaluation`, or `registration`. If older repo docs mention a narrower token list, treat the broader EXECUTION-PLAN wording as authoritative. See EXECUTION-PLAN §6.8.2, §7.4, and §9.
2. **CSV export PII denylist** — compile-time `Set<String>` in `CsvExportPolicy.kPiiDeniedColumns` blocks `dob`, `phone_e164`, `address_json` from W11 reverse-export. See §6.8.4.
3. **PR template checklist** — `[ ] NO PLAYER DATA INTRODUCED`. See §6.8.5 and §7.4 Definition of Done.

The one accommodation for minors is **Junior Umpires** (under-18 volunteers) supported via `Role.permits_minor`, `RoleClearanceRequirement.min_age`, and `Volunteer.is_junior`. See PRD §2.4 and §6.

## Multi-tenant model

Multi-tenant from v1 day one (EXECUTION-PLAN §6.3):

- Local mode: each league's database is a separate encrypted SQLite file at `<app-data>/leagues/<league_uuid>/db.enc`. File boundary is the outer tenancy boundary.
- `league_id` column on every league-scoped entity provides defense-in-depth. The `LeagueScopedRepository<T>` base class enforces tenant scoping at query time.
- Cross-tenant access attempts emit `CROSS_TENANT_ACCESS_ATTEMPT` audit entries and throw `AssertionError`.
- A custom Dart analyzer lint blocks any `select()` / `delete()` on a league-scoped table that lacks a `leagueId` filter.

## Two-repo layout

The project spans two sibling directories. **Code lives here; spec lives next door.**

```
~/projects/
├── safety/                       ← SISTER REPO — spec workspace (PRD, design, plan, source workbook archive)
│                                 see ~/projects/safety/CLAUDE.md and HANDOFF.md
│
└── mtll-safety-app/              ← THIS REPO — Flutter implementation
    ├── CLAUDE.md                 this file
    ├── HANDOFF.md                current implementation handoff / continuation guide
    ├── HANDOFF_TEMPLATE.md       required structure for future handoffs
    ├── README.md                 project intro
    ├── pubspec.yaml              locked stack (Drift ^2.18, SQLCipher, Riverpod ^2.5, etc.)
    ├── analysis_options.yaml     Dart analyzer config
    ├── .claude/agents/           7 read-only sub-agents (copied from spec workspace)
    ├── .gitignore                Flutter + native build + generated code + *.db.enc + evidence/
    │
    ├── lib/                      Dart application code
    │   ├── main.dart             Flutter entry point (default scaffold; will be replaced)
    │   ├── app/                  root widget + global UI overlays (§5.D tamper modal, migration-failed modal)
    │   ├── data/
    │   │   ├── database/         Drift schema — 16 entities + 3 supporting tables (Sprint 1 fills this)
    │   │   └── repositories/     LeagueScopedRepository<T> base + per-entity repos
    │   ├── domain/               Freezed models + business invariants
    │   ├── security/             KeyProvider, AuditChainVerifier, AuthenticationCoordinator
    │   ├── presentation/         screens, widgets (Sprint S3+ UI work)
    │   └── l10n/                 ARB files (en-US v1, es-MX v2)
    │
    ├── test/                     unit + widget tests (load-bearing: no-player-table, audit-immutability, cross-tenant)
    │
    ├── android/                  Android native scaffold (v1 target, no SDK installed yet)
    ├── ios/                      iOS native scaffold (MVP target, needs Xcode for build)
    ├── macos/                    macOS native scaffold (MVP target, needs Xcode for build)
    └── windows/                  Windows native scaffold (v1 target)
```

**Pick the right cwd for the work.** Open Claude Code from `~/projects/mtll-safety-app/` (here) to write app code; open from `~/projects/safety/` to edit the spec. Sub-agent discovery is anchored to cwd — opening from a subdirectory like `lib/` may miss them. The seven sub-agents at `.claude/agents/` are copies of the spec workspace's set; they're read-only design advisors, not code authors.

## Sub-agents

Seven project-scoped read-only sub-agents at `.claude/agents/` (copied from `~/projects/safety/.claude/agents/`):

- `project-manager.md` — §1 scope, charter, phasing
- `chief-systems-engineer.md` — §2 data model, NFRs, invariants
- `chief-architect.md` — §3 tech architecture, deployment, build pipeline
- `chief-engineer.md` — §4 functional workflows W1–W13
- `lead-ui-ux-engineer.md` — §5 screens, IA, accessibility
- `chief-software-engineer.md` — §6 implementation patterns, security
- `agile-scrum-expert.md` — §7 sprints, DoD, test strategy

These are read-only advisors that produce Markdown sections. Use them for design clarification questions, not for code edits.

## Working rules

- **Spec is the source of truth.** When in doubt about *what* to build, consult `~/projects/safety/plan/EXECUTION-PLAN.md`. When in doubt about *how* to build it, the implementation patterns in §6 of that plan are canonical.
- **Tests of record are non-negotiable** (EXECUTION-PLAN §7.6): no-player-table schema test; audit-log-immutability tamper test; cross-tenant access guard; CSV PII denylist; biometric outcomes coverage. These ship with the first sprint.
- **AuditLog is append-only at the DB layer.** Two SQLite triggers (`audit_log_no_update` / `audit_log_no_delete`) make this a hard enforcement, not a UI convention. See §6.2.1.
- **AuditLogChain** seals each day's audit rows in a Merkle hash chain. Tamper detection fires a global modal overlay (§5.D.1) and puts the app in read-only mode.
- **Drift migrations are forward-only.** No rollback path. Failed migrations land the app on a `MIGRATION_FAILED` modal (§5.D.2) and require restoring from backup.

## Handoff protocol

When writing or revising `HANDOFF.md`, follow `HANDOFF_TEMPLATE.md`.

- Use current repo state and commands run in the same session for implementation facts.
- Use the current spec workspace for requirements, DoD gates, and any claimed continuation order.
- Treat prior handoffs as secondary context only.
- Re-run commands before claiming they passed, and record the exact commands under a verification section.
- Include a `Conflicts / Inconsistencies` section whenever repo code, repo docs, or spec docs disagree. Cite exact files.
- Separate `Verified Next Steps` from `Recommendations`.
- Do not present local numbering, inferred task order, or narrative summaries as canonical project truth unless a current primary source explicitly says so.

## Concurrent sessions

Two Claude Code workspaces share this Mac:

- `~/projects/safety/` — spec workspace (PRD, design-notes, EXECUTION-PLAN, HANDOFF)
- `~/projects/mtll-safety-app/` — this repo (Flutter implementation)

When working in this repo, edits to spec files in `~/projects/safety/` go through the concurrent-write-guard. Re-read before reconciling. Do not work around blocks with shell redirection.

## Session memory pointer

This project's cross-conversation memory is at `~/.claude/projects/-Users-ttotheq-projects-mtll-safety-app/memory/` (will populate as sessions accumulate).
