# LIB-04c — CI under 10 minutes again: partitions for the gas gate and the tests

## Agent

Title: `[Sonnet 5.5] LIB-04c CI partitions` · Profile: implement · Model: Sonnet 5.5 (tooling,
with unit tests, in files the orchestrator owns and delegates here). Audit: none; the Codex review
of the pull request (`nexus review`) and the scripts' unit tests.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task every job of CI is again well under its 10-minute timeout, with room for the tests
that milestone L-M1 still adds, and the gas gate still measures **every** test exactly once. On
`main` at `295ff3d` (run `36792754888`) the job `Gas hexx` took **9 min 4 s** and `Build and test
hexx 1/2` 6 min 49 s; M1-T6 (N-5) adds exhaustive oracles of several billion L2 gas.

## Context — read, in this order

1. `.github/workflows/ci.yml`: the jobs `test` (two `snforge --partition` partitions of `hexx`)
   and `gas` (one job per package and scope; `hexx` regular takes the 9 minutes), and their
   comments.
2. `scripts/bench.py` (its docstring: what `check` enforces, the counts declared / collected /
   with a row / ignored, the snapshot), `scripts/tests/test_bench*.py`.
3. `docs/briefs/LIB-05-T1c-gas-gate.md` (why one gas job per package) and its report
   `docs/reports/LIB-05-M1-T1c-REPORT.md`.

## Scope

**In**

1. `bench.py check` (and `run`) accept `--partition INDEX/TOTAL`, the meaning snforge gives it,
   so that one gas job measures one share of a package. Inside a partition, `check` enforces the
   rule on the tests it ran and compares **only their rows** with `gas/<package>.snap`; nothing
   else of the rule is weakened.
2. **Completeness**: the union of the partitions of a package is every test of the package,
   each measured once. A job after the partitions (it downloads their reports, the artifacts the
   `gas` jobs already upload) fails when a declared test was measured in no partition or in two,
   or when the snapshot has a row no partition measured. The check is a function of `bench.py`,
   unit-tested; the workflow only calls it.
3. CI: `hexx` regular gas in **three** partitions; `hexx` tests in **three** partitions. Measure
   every job of the pull request's run and report its time; each must be under 6 minutes at
   `main`'s test count. If three partitions do not reach that, use four and say why.
4. `bench.py snapshot` unchanged in what it writes (all tests, one package or all); the local
   gate `scripts/check.sh` unchanged in what it checks.
5. Unit tests in `scripts/tests/` for the partition selection, the per-partition check, and the
   completeness check (a test missing, a test twice, a stale row).

**Out**: any change of the budget rule; any Cairo file; the `Double run of the Digger tests`
step (keep it in the partition that holds the Digger tests, or in its own step, as long as it
still runs once per package); `release-check.yml`; any publication.

**Allowlist**: `scripts/bench.py`, `scripts/tests/**`, `.github/workflows/ci.yml`, `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 Every job of CI under 6 minutes on the pull request's run, times in the report.
- [ ] AC-2 A test removed from every partition, a test measured twice, and a stale snapshot row
      each fail the completeness job (shown by unit tests and by the report's reasoning).
- [ ] AC-3 `python3 -m unittest discover -s scripts/tests` and `scripts/check.sh` pass; CI green.
- [ ] AC-4 Nothing outside the allowlist was written.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the time of every CI job before (run
`36792754888`) and after.
