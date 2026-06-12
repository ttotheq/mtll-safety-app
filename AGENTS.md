# Repository Guidelines

## Project Structure & Module Organization
`lib/` uses a layered Flutter layout: `app/` for bootstrap and app wiring, `data/` for Drift schema and repositories, `domain/` for business models, `presentation/` for screens/widgets, `security/` for auth and key-management work, and `l10n/` for localization assets. Current database work lives in `lib/data/database/`, with tables in `lib/data/database/tables/`. The project-local `cross_tenant_query` lint lives in the `lints/mtll_lints/` path package, with its synthetic-violation fixture at `test/lints/`. Tests mirror source paths under `test/`; see `test/data/database/schema_test.dart` for the current pattern. Native runners live in `android/`, `ios/`, `macos/`, and `windows/`.

## Build, Test, and Development Commands
- `flutter pub get` installs project dependencies.
- `dart run build_runner build --delete-conflicting-outputs` regenerates Drift, Riverpod, Freezed, and JSON code after annotation changes.
- `dart format lib test` applies standard Dart formatting.
- `flutter analyze` must stay clean; this repo uses `flutter_lints`, `custom_lint`, and `riverpod_lint`.
- `dart run custom_lint` must stay clean; it hosts the project-local `cross_tenant_query` rule (EXECUTION-PLAN §6.3.5, build-blocking).
- `flutter test` runs the full test suite.
- `flutter test test/data/database/schema_test.dart` runs focused schema coverage.
- `flutter run` launches the app on an attached device. macOS and iOS targets require Xcode/CocoaPods (not yet installed on the primary dev machine; UI work is verified through widget tests meanwhile).

## Coding Style & Naming Conventions
Follow standard Dart style: 2-space indentation, `PascalCase` for types, `camelCase` for members, and `snake_case.dart` for filenames. Keep data access in `lib/data/` and UI code in `lib/presentation/`. Prefer small, focused table and repository files over large mixed modules. Generated files such as `*.g.dart` and `*.freezed.dart` are local build artifacts and should not be committed.

## Testing Guidelines
Use `flutter_test` for widget, schema, and repository tests. Name tests after behavior and mirror the source path when adding files. New schema or repository work should cover round-trip inserts, constraints, and regressions. Preserve the scope wall: this app stores no player data, and the model must stop at `Team`.

## Commit & Pull Request Guidelines
Current history uses concise conventional prefixes such as `scaffold:`, `feat:`, and `chore:`. Keep commit subjects imperative and specific, for example `feat: add season uniqueness constraint`. Every PR should pass `flutter analyze`, `flutter test`, and `dart run custom_lint`, include tests for new behavior, and reference the relevant section of `~/projects/safety/plan/EXECUTION-PLAN.md`. Include screenshots only when a visible UI change is part of the review.

## Configuration Management & GitHub
Use GitHub as the canonical remote and collaboration system of record for this repo. Prefer short-lived branches, focused commits, and pull requests for non-trivial changes, and keep `main` releasable by running `flutter analyze` and `flutter test` before merge-ready handoff.

Treat configuration as code. Version non-secret defaults, templates, and build-critical wrappers; document configuration changes in PRs and handoffs; and keep secrets, tokens, local databases, machine-specific overrides, and generated artifacts out of version control unless the repo guidelines explicitly require them.

## Handoff Discipline
When creating or updating `HANDOFF.md`, use `HANDOFF_TEMPLATE.md` and keep the document evidence-first rather than narrative-first.

- Implementation facts must come from the current repo state and commands run in the same session.
- Requirements, Definition of Done gates, and continuation order must come from the current spec workspace in `~/projects/safety/`, not from memory.
- Prior handoffs are secondary context only; never let an older handoff outrank code, tests, or current spec files.
- Every verification claim must be backed by commands re-run in the same session, with the commands and date recorded in the handoff.
- Separate `Verified Next Steps` from `Recommendations`. If a task order is inferred rather than explicitly stated in a primary source, label it as a recommendation.
- If repo code, repo docs, and spec docs disagree, add a `Conflicts / Inconsistencies` section with exact file references instead of silently picking one.
- Do not invent ticket numbering or imply a canonical sequence unless a current primary source explicitly defines it.
