# LIB-04b — Three findings of the tooling audit

## Agent

Title: `[Sonnet 5.5] LIB-04b tooling findings` · Profile: implement · Model: Sonnet 5.5
(three small, named fixes). Audit: `[GPT-6-Sol]`, one pass limited to the three findings.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything.

## Goal

After this task the parity tool and the release check no longer have the three defects left
open by the audit of LIB-04 ([pass 4](../audits/LIB-04-audit-gpt-6-sol-pass-4.md), findings
*New 1*, *New 2*, *P2-13*). It must be merged before the first release candidate
([decision](../decisions/LIB-04-fix-loops.md)).

## Scope

**In** — exactly three fixes, each with its unit tests:

| # | Finding | What holds after the task |
|---|---|---|
| 1 | Parity tool: a re-export through a chain (a `pub use` of a `pub use`, through private modules) is dropped without an error; two exports of the same item under two names keep only one | Re-exports are resolved transitively, on the Rust side and on the Cairo side, and every exported name is kept. A form that is still not supported raises an error with file and line. **Never silently wrong** |
| 2 | Release check: `0.1.0+build-1`, a stable version whose build metadata holds a hyphen, takes the informational branch meant for pre-releases | A version is a pre-release if and only if its part **before** any `+` holds a hyphen. The test is one function of the script, unit-tested, called by the workflow; not a pattern written in the workflow |
| 3 | Release check: for a pre-release, the list of missing items goes to stderr; the job summary and the artifact are empty, and only 40 items are printed | The whole list reaches the job summary and the uploaded artifact; nothing is truncated |

**Out**

- Anything else in the tooling, however tempting. A defect you notice goes into
  `REPORT.md` under *Open questions*.
- `crates/**`: another task (LIB-05, M1-T1a) is moving the engine there at the same time.
- Any publication, tag or release.

**Allowlist** (files this task may write)

- `scripts/api_parity.py`, `scripts/tests/**`
- `.github/workflows/release-check.yml`
- `docs/RELEASING.md`
- `docs/API_PARITY.md`, `docs/EXTENSIONS.md`: **only** if the fix changes what the tool
  generates from the tree as it is on `main`; say so in the report
- `REPORT.md` (ignored by git)

If `main` moves while you work (the take-over is merged), merge `origin/main` into your
branch and regenerate the generated documents.

## Acceptance criteria

- [ ] AC-1 The auditor's three failing scenarios are unit tests, and pass: the chain
      `pub use middle::Hex as Other` over `pub use super::inner::Hex`; two root exports of
      `inner::Hex` as `Hex` and `Other`; the version `0.1.0+build-1`.
- [ ] AC-2 `python3 scripts/api_parity.py --check-release L-M1 --report-only` prints the 66
      missing items of today, all of them, on a stream the workflow captures.
- [ ] AC-3 `scripts/check.sh` passes; CI is green; no workflow holds a secret or publishes.
- [ ] AC-4 Nothing outside the allowlist was written.

## What the auditor will check

The three scenarios of the findings and their neighbours (a chain of three re-exports, a
glob in the chain, a cycle of re-exports, versions `1.0.0-rc.1+build-1`, `1.0.0+a-b`,
`1.0.0-`), by its own probes; that no change of this lot alters the inventory of `hexx`
0.25.0; the diff of the workflow for any interpolation of a context into a `run` step.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7.
