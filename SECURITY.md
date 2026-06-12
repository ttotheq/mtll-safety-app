# Security Policy

This application manages volunteer safety-clearance records for youth
baseball leagues. It handles personally identifiable information (PII) of
adult volunteers and, in the narrow Junior Umpire case, minors' birth dates
used for age-gating. Security reports are taken seriously.

## Reporting a vulnerability

Please report vulnerabilities privately through
**GitHub → Security → Report a vulnerability** (private vulnerability
reporting is enabled on this repository). Do not open a public issue for
security problems.

Include what you can: affected file or component, reproduction steps, and
impact. You should receive an acknowledgment within a week.

## Scope notes for researchers

- The database is SQLCipher-encrypted with an Argon2id-derived key; the
  key derivation and keystore handling live in `lib/security/`.
- The audit log is append-only at the SQLite trigger level.
- Multi-tenant isolation is enforced at the repository layer and by a
  custom analyzer lint (`lints/mtll_lints/`).
- The app stores **no player data** by design; reports that the schema or
  exports leak player or minor data (beyond the documented Junior Umpire
  age-gate fields) are in scope and high priority.

## Supported versions

Pre-release (no published versions yet). Once releases ship via GitHub
Releases, the latest release is the supported version.
