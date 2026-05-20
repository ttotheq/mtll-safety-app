# HANDOFF Template

Use this structure for any new or updated `HANDOFF.md` in this repo.

## Header

- Written date
- Audience
- Repo cwd
- Spec workspace path

## Verified Facts

- Current implementation state derived from code and repo files inspected in the same session
- Schema or feature version numbers
- What is implemented now

## Verification Run

- Record the exact commands re-run in the same session
- Record whether each command passed or failed
- Include the date of the verification run

## Conflicts / Inconsistencies

- List any disagreements between repo code, repo docs, and `~/projects/safety/`
- Cite exact file paths or section names
- Do not silently resolve the conflict in prose

## Open Risks / Missing Work

- Missing tests
- Pending implementation slices
- Easy-to-miss worktree cautions

## Verified Next Steps

- Only include steps explicitly supported by a current primary source
- If local numbering is used, state whether it is repo-local or spec-canonical

## Recommendations

- Put inferred sequencing or engineering judgment here
- Label it clearly as recommendation rather than verified project truth
