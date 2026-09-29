# [GPT-6-Sol] Audit — LIB-04b — tooling findings

## Verdict

**PASS.** The three reported findings and four follow-up defects are resolved for the requested scenarios. No remaining finding blocks the first release candidate.

## Findings

| # | Severity (blocker, major, minor, note) | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| — | note | `scripts/api_parity.py`; `.github/workflows/release-check.yml` | No remaining finding. | Independent probes and checks are detailed below. | None. First release candidate: not blocked. |

## Coverage

- **New 1:** Independent in-memory probes retained both names of one export and resolved two-link and three-link re-export chains and a glob in a chain. A named cycle raised with `fixture.cairo:1`; a glob cycle terminated.
- **New 2:** The CLI classified `0.1.0+build-1` and `1.0.0+a-b` as stable, and `1.0.0-rc.1+build-1` and `1.0.0-rc.1` as pre-releases. It rejected `1.0.0-`.
- **P2-13:** `--check-release L-M1 --report-only` exited 0 with a heading and all **66** items on stdout, none on stderr. The enforced mode exited 1 with all 66 on stderr. The workflow captures both streams with `tee`, appends the report to the job summary, and includes it in the artifact path. This was checked from the workflow; no hosted run was performed.
- **Four follow-ups:** Probes recognized `pub(super)`, `pub(crate)`, and `pub(in …) use`; found a `use` after another statement on the same line; kept an inline module’s `use` in that module; and raised file:line errors for aliased Rust and Cairo types with members. The invalid-version CLI case above also passed.
- **Inventory and scope:** `--check` and `--extensions --check` passed. Fresh parsing of `sources/hexx` equalled the embedded inventory at **692 items**. The diff contains only the four allowlisted files, `git diff --check` passed, and the worktree remains unchanged. Workflow contexts enter run steps through `env`; review found no executable secret use or publication step.