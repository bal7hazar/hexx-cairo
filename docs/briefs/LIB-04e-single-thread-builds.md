# LIB-04e — One build: the compiler pinned to one thread (D-154 explained, D-176)

## Agent

Title: `[Sonnet 5.5] LIB-04e single-thread builds` · Profile: implement · Model: Sonnet 5.5
(workflows, scripts and snapshots; the cause is known and the remedy decided). Review:
`nexus review` (Codex, or its fallback).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task every build whose result is measured or declared is reproducible, and the gates
accept exactly one value again. The game's SPK-13 found the cause of the compile drift (D-154):
the compiler places the `withdraw_gas` check of a call-graph cycle by salsa intern-id order,
which follows rayon's thread order; with `RAYON_NUM_THREADS=1` a build is one build (10 of 10 on
the owner's Mac). The project manager decided on 2026-10-01 (the game's D-176): pin
`RAYON_NUM_THREADS=1` on every such build, re-take the snapshots single-threaded, drop both
`.builds` files, and check in CI that clean builds give one class hash.

## Context — read, in this order

1. `.github/workflows/ci.yml` (the `test`, `package`, `gas` and `gas-complete` jobs),
   `.github/workflows/release-check.yml` (the full gate, `scarb package`), `scripts/check.sh`.
2. `scripts/bench.py` (its `.builds` support from LIB-04d), `scripts/bytecode_size.py`
   (`read_builds`, `accepted`), `gas/bytecode.builds`, `gas/takeover_tests.builds`,
   `scripts/tests/`.
3. `STATUS.md` § "The compile drift (D-154)" and `.claude/worktrees/logs/drift-occurrences.txt`
   if present (local record).

## Scope

**In**

1. `RAYON_NUM_THREADS=1` set for every build that is measured or declared: the CI jobs `gas`
   (every scope and partition), the class-size check, `package`, the `test` jobs if they build
   what the gates read, the release check (its full gate and its `scarb package`), and
   `scripts/check.sh` (so that a local gate measures what CI measures). Set once per job or
   workflow (`env:`), not per command, and say where.
2. **Drop the second builds**: delete `gas/takeover_tests.builds` and `gas/bytecode.builds`; remove
   their reading from `scripts/bench.py` and `scripts/bytecode_size.py` and the unit tests of that
   path, so that one value only is accepted again. Say in the report whether keeping the generic
   support (with no file) is simpler than removing it, and do the simpler.
3. **Re-take the snapshots single-threaded**: `gas/*.snap` and `gas/bytecode.size`, with
   `RAYON_NUM_THREADS=1`, locally on the VPS and confirmed equal by CI. A value may change: report
   every row that changed against `main` (test, old, new), and set each budget by the rule
   `ceil(1.05 × measured)` where the old budget no longer fits. `docs/GAS.md` regenerated.
4. **A determinism check in CI**: a job (or a step of the class-size job) that builds
   `crates/consumer` three times from clean (`scarb clean` between, single-threaded) and fails if
   the class hashes or sizes differ. Measure its time.
5. **The cost**: measure the slowdown of single-threaded builds (the slowest CI jobs before and
   after, on comparable runs) and report it. If a job comes near its timeout, say so under
   *Escalations*; do not raise a timeout.
6. **Evidence of one build**: the gas jobs run at least ten times in CI on the same commit (re-runs
   of one workflow run are enough; if `gh run rerun` is refused to you, write the run id in the
   report and end your turn there: the orchestrator re-runs it and resumes you with the run ids).
   Report the values of the 40 rows that drifted
   (`takeover_tests::digger::*`, `takeover_tests::map::test_map_open_with_*`,
   `takeover_tests::gas::test_gas_open_with_*`) and of `HexxGenerators`' class size. **If ten CI
   builds do not give one value, stop and report**: the gates then stay as they are, by the project
   manager's decision.

**Out**: any Cairo file; any budget change other than what Scope 3 requires; the tests' content;
any publication.

**Allowlist**: `.github/workflows/ci.yml`, `.github/workflows/release-check.yml`,
`scripts/check.sh`, `scripts/bench.py`, `scripts/bytecode_size.py`, `scripts/tests/**`,
`gas/*.snap`, `gas/bytecode.size`, `gas/bytecode.builds` and `gas/takeover_tests.builds`
(deletion), `docs/GAS.md`, `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 Every measured or declared build runs with `RAYON_NUM_THREADS=1`; the report lists
      where it is set.
- [ ] AC-2 No `.builds` file remains; each gate accepts one value.
- [ ] AC-3 Ten CI builds on one commit give one value for each of the 40 rows and for the class
      size (the values in the report); the three-build determinism check passes.
- [ ] AC-4 Every changed snapshot row reported; budgets conform; `scripts/check.sh` passes; CI
      green; the slowdown measured.
- [ ] AC-5 Nothing outside the allowlist was written.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the ten runs' values, the changed rows and the
job times before and after.
