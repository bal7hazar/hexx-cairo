# LIB-04d — The gas gate accepts the second observed build (D-164 extended)

## Agent

Title: `[Sonnet 5.5] LIB-04d gas builds` · Profile: implement · Model: Sonnet 5.5 (tooling with unit
tests, on a rule already written for class size). Review: `nexus review` (Codex, or its fallback).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task a pull request's CI no longer fails on the compile drift of Scarb 2.19.4 (D-154)
while every other change of a gas figure still fails. The project manager extended D-164 to the
gas gate on 2026-10-01 (`bal7hazar/grimworld`, `docs/decisions/2026-09-29-compiler-determinism.md`):
for a test whose measurement has a recorded second build, `scripts/bench.py check` accepts the
snapshot's value **or that exact second value**, nothing in between; any third value fails.

## Context — read, in this order

1. `gas/bytecode.builds` and `scripts/bytecode_size.py` (`read_builds`, `accepted`): the same rule
   for class size, which this task mirrors for gas rows.
2. `scripts/bench.py` (the docstring, `check`, the `CHANGED` path, `--partition` and `complete`
   from LIB-04c) and `scripts/tests/test_bench*.py`.
3. The two CI occurrences: run `36809041479` (pull request #61) and run `36836722836` (pull request
   #70), job `Gas takeover_tests`: the same 40 rows (`takeover_tests::digger::*`,
   `takeover_tests::map::test_map_open_with_*`, `takeover_tests::gas::test_gas_open_with_*`)
   measured +0.22 to +1.94 % against `gas/takeover_tests.snap`. Their logs (`gh run view <run>
   --log-failed`) and their artifacts hold the exact values.

## Scope

**In**

1. `gas/takeover_tests.builds` (new), the format of `gas/bytecode.builds`: a header stating the rule
   (D-164 extended, the project manager's decision of 2026-10-01; exact values only; a new line needs
   the project manager's decision; the file is removed when the game's SPK-13 explains the cause),
   then one line per test: its full path, the exact second measured value, and where it was observed
   (the run ids). The values are **read from the two runs**, never computed; a test whose two runs
   disagree with each other is listed in the report, not in the file.
2. `bench.py check` (every scope and partition): a row whose measurement equals the snapshot passes
   as today; one that equals its recorded second value passes and is reported as `SECOND BUILD`;
   anything else is `CHANGED` as today. The budget rule is unchanged: the budget must cover the larger
   of the two accepted values within the rule (`[measured, ceil(1.05 × measured)]` against the
   snapshot's value; say in the report whether every one of the 40 budgets also covers the second
   value, and list any that does not). `snapshot` never writes a `.builds` file.
3. The generic form: `gas/<package>.builds` is read for any package if present; only
   `takeover_tests` has one now.
4. Unit tests in `scripts/tests/`: the snapshot value passes, the exact second value passes, a third
   value fails, a malformed or duplicated line fails loudly, a row of the file absent from the
   snapshot fails.

**Out**: any change of a budget or of `gas/*.snap`; `.github/**` unless the gate needs it (say
why); any Cairo file; the class-size gate.

**Allowlist**: `scripts/bench.py`, `scripts/tests/**`, `gas/takeover_tests.builds` (new),
`REPORT.md`.

## Acceptance criteria

- [ ] AC-1 The 40 rows of the two runs are in `gas/takeover_tests.builds` with their exact values
      and runs; `bench.py check --package takeover_tests` passes on either build and fails on a
      third value (unit tests).
- [ ] AC-2 `python3 -m unittest discover -s scripts/tests` and `scripts/check.sh` pass; CI green.
- [ ] AC-3 Nothing outside the allowlist was written.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the 40 rows (snapshot value, second value,
runs) and the budgets that do or do not cover the second value.
