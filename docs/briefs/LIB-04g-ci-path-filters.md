# LIB-04g — CI runs a test job only when its files changed

## Agent

Profile `impl-sonnet` (a clear task with acceptance criteria). Review: `review-opus`. No audit (D-177:
no value, access, randomness or published interface; the review and the checks cover it).
**Do not start before the orchestrator says the workflow may be modified** (the owner is adjusting the
permission classifier). Edit the workflow with the file-editing tool only, never with a script that
rewrites the file.

## Goal

The owner's rule for every repository: "CI tests must absolutely run only if files related to the tests
were modified, so docs should skip all tests." On a pull request, each job of `ci.yml` runs only when a
file that concerns it changed; a documents-only pull request runs no test. One light final job always
runs and summarises, so `gh pr checks` always has a result and the standard's merge command
(`gh pr checks <n> && gh pr merge …`) keeps working. Pushes to `main` and the release workflows run
exactly what they run today.

## Context — read first

1. `.github/workflows/ci.yml` (jobs: `links`, `scripts`, `fmt`, `takeover`, `test`, `package`, `gas`,
   `gas-complete`, `determinism`, `golden`, `all-checks`). `all-checks` already has `if: always()` and
   fails only on a `failure` or `cancelled` need, so skipped jobs already pass it.
2. `scripts/prepush.sh`, its `CHECKS` table: it already maps paths to checks (gas tables, class size,
   parity, extensions, deviations, take-over, golden vectors). Use the same mapping, so a push that
   prepush lets through is classified the same way in CI.
3. `scripts/check.sh` and each script a job runs, to know every input of every job.

## Workflow files this task changes (rule nexus #60)

- `.github/workflows/ci.yml` — **only**: a new first job `changes`, an `if:` on each existing job, and
  `changes` added to `all-checks`'s `needs` with its result checked. No trigger, permission, step of an
  existing job, timeout, partition or matrix changes. No job removed.
- `.github/workflows/consumer_check.yml` and `.github/workflows/release-check.yml`: **not changed**
  (the first is already path-filtered on pull requests; the second runs on dispatch only).

## Scope

1. **`scripts/ci_changes.py`** (new): reads the list of changed paths on standard input and prints one
   `<group>=true|false` line per group, for `$GITHUB_OUTPUT`. Groups and their paths (derive the exact
   lists from the scripts each job runs; the table below is the starting point, complete it):

   | Group | Jobs | Paths that select it |
   |---|---|---|
   | `links` | `links` | any `*.md`, the link checker's configuration |
   | `shell` | `scripts` | `scripts/*.sh`, `.githooks/**` |
   | `docs_checks` | `fmt` | `**/*.cairo`, `Scarb.toml`, `Scarb.lock`, `crates/*/Scarb.toml`, `.tool-versions`, `scripts/**`, `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/**` |
   | `takeover` | `takeover` | `crates/hexx/**`, `scripts/takeover_check.py`, `.tool-versions` |
   | `cairo` | `test`, `package`, `gas`, `gas-complete`, `determinism` | `crates/**`, `Scarb.toml`, `Scarb.lock`, `.tool-versions`, `gas/**`, `scripts/bench.py`, `scripts/bytecode_size.py`, `tools/consumer_check/**` if a job uses it |
   | `golden` | `golden` | `tools/refgen/**`, `crates/hexx/tests/golden_*.cairo`, `crates/hexx/src/board/{line,tables,hexagon}.cairo`, `docs/deviations/line_ties.md` |

   A change to `.github/workflows/ci.yml` or to `scripts/ci_changes.py` itself selects **every** group.
   An empty or unreadable list selects every group (fail open: never skip a test by accident).
2. **Job `changes`** (first, `ubuntu-latest`, light, no toolchain): on `pull_request`, checks out with
   enough history and lists `git diff --name-only <base sha>...<head sha>` into `scripts/ci_changes.py`;
   on any other event (push to `main`), sets every group to `true` without computing anything. Actions
   pinned by SHA like the others.
3. **Each job** gets `needs: changes` and `if: needs.changes.outputs.<group> == 'true'`, keeping any
   condition it already has (combine them; `gas-complete` keeps `!cancelled()` and its `needs: gas`).
4. **`all-checks`**: `needs` gains `changes`; it still runs `if: always()`, passes when every need is
   `success` or `skipped`, and fails when any is `failure` or `cancelled` (as today), and also when
   `changes` itself did not succeed.
5. **Tests** `scripts/tests/test_ci_changes.py`: a documents-only list (`STATUS.md`, `PLAN.md`,
   `docs/briefs/x.md`) selects `links` only; a Cairo source selects `docs_checks`, `takeover` (if under
   `crates/hexx`), `cairo`; `gas/hexx.snap` selects `docs_checks` and `cairo`; a refgen spec selects
   `golden` and `docs_checks`; `ci.yml` selects all; an empty list selects all.
6. **`AGENTS.md`**: one paragraph: which group runs for which paths, and that a new job or input must be
   added to `scripts/ci_changes.py`.

## Allowlist

`.github/workflows/ci.yml` (as above), `scripts/ci_changes.py`, `scripts/tests/test_ci_changes.py`,
`AGENTS.md` (the new paragraph only).

## Acceptance criteria

- [ ] AC-1 The unit tests of `ci_changes.py` pass, and cover the cases of Scope 5.
- [ ] AC-2 This pull request itself (it changes `ci.yml`) runs every job, and `All checks passed` is green.
- [ ] AC-3 After the merge, the orchestrator's next documents-only pull request shows only `changes`,
      `Markdown links` and `All checks passed` run, the rest `skipped`, and the merge command works
      (verified by the orchestrator, recorded in STATUS).
- [ ] AC-4 A push to `main` runs every job, as today (the first push after the merge, checked by the
      orchestrator).
- [ ] AC-5 Nothing outside the allowlist changed; no trigger, permission or existing step changed.

## Rules

`AGENTS.md`, `docs/briefs/COMMON.md`. Run `scripts/prepush.sh` before the push. No CI polling (API limit):
open the PR and report. No external issue links in commit messages or PR text. A refused command is
reported, never worked around.
