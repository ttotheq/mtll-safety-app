# Pull Request

## Summary

<!-- What does this PR change, and which EXECUTION-PLAN section / workflow does it implement? -->

**Spec reference:** §

## Gates

- [ ] `flutter analyze` clean
- [ ] `flutter test` passing (includes the schema scope-wall test)
- [ ] `dart run custom_lint` clean (cross_tenant_query, EXECUTION-PLAN §6.3.5)
- [ ] Tests included for new behavior

## NO PLAYER DATA — non-negotiable gate (EXECUTION-PLAN §6.8.5)

- [ ] **NO PLAYER DATA INTRODUCED** — this PR adds no entity, field, query,
      or screen that stores or displays player/minor data (beyond the
      documented Junior Umpire `is_junior` flag and DOB age-gate)

## Locked decisions

- [ ] No locked decision (CLAUDE.md "Locked decisions") is reopened by this PR
