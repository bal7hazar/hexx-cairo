# LIB-05 M1-T1c — The gas gate: inherited budgets conformant, a split job, the drift instrumented

## Agent

Title: `[Sonnet 5.5] LIB-05 M1-T1c gas gate` · Profile: implement · Model: Sonnet 5.5 (a
mechanical change of many budgets, and CI plumbing). Audit: `[GPT-6-Sol]`.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill
only what you created, named exactly; temporary directories under your worktree.

## Goal

After this task the gas gate holds every test of the repository to the same rule, runs
within the time of CI with room for L-M1, and records what is needed to find the cause of the
drift seen twice in CI. Three parts, in this order.

## Context

- The drift: in two CI runs, tests measured more than their snapshot on an unchanged tree
  (`test_readme_open`, +1.1 %; then 47 tests, +0.5 to +1.3 %), and passed on the next run.
  **Every test that moved goes through `Digger::dig`.** The toolchain, the runner image and the
  restored cache were the same; every action is pinned by commit; the auditor found nothing
  in `generators/digger.cairo` that can make the same call cost differently between two
  executions of the same compiled code. So the next suspects are the compiled artefact and the
  measurement, not the algorithm. Reports: `docs/reports/LIB-05-M1-T1a-REPORT.md`,
  `docs/reports/LIB-05-M1-T1b-REPORT.md` (sections on CI), audit
  `docs/audits/LIB-05-M1-T1b-audit-gpt-6-astra-pass-3.md` (last paragraph).
- The gas job takes 6 min 56 s to 7 min 54 s of its 10 minutes, and grows with every package.
- The baseline `gas/takeover-baseline.txt` holds 702 inherited tests of `crates/hexx` whose
  budget is absent or above `ceil(1.05 × measured)`.
- Rule (COMMON §4): the measurement is that of the test as committed, attribute included;
  `N = ceil(1.05 × measured)`.

## Scope

**In**

1. **Split the gas job** of `.github/workflows/ci.yml`: one job per package (`hexx`,
   `takeover_tests`, `consumer`), each measuring and checking its own package against its
   own `gas/<package>.snap`; `scripts/bench.py` gains the package selection it needs. The
   aggregate check "all checks passed" still depends on all of them. Report the time of each.
2. **Instrument the drift**, without changing any rule: every gas job keeps, as an artefact
   of the run, the raw output of `snforge test --detailed-resources` and a list of the
   compiled test artefacts with their SHA-256 (the files under `target/` that snforge
   executes), plus the versions of `scarb`, `snforge` and of the Sierra and CASM compilers it
   reports. When `bench.py check` finds a measurement different from the snapshot, it prints
   the test, both figures, and says where the artefact is. In the same job, run the tests of
   `Digger` twice and compare the two measurements: if they differ within one run, fail with
   a clear message; say in the report what you observed.
3. **The inherited budgets made conformant**: for each of the 702 tests of the baseline, set
   `#[available_gas(l2_gas: N)]` with `N = ceil(1.05 × measured)` on the committed measurement
   of that test, attribute included (measure, set, measure again, set again until stable;
   report how many needed a second pass). Then delete `gas/takeover-baseline.txt`, remove the
   baseline rules from `bench.py` and their tests, and keep `gas/takeover-tests.txt` only if
   something still uses it (say what). `scripts/takeover_check.py` must still prove the move:
   it ignores the `#[available_gas(…)]` lines of the moved files, and only those; the list of
   rewrites is otherwise unchanged. **No other line of a moved file changes.**

**Out**

- Any change of the engine's code; any change of a budget of `crates/takeover_tests` (they
  are conformant); any extension; any publication.
- A tolerance in the gate. The gate stays exact; if the drift recurs during your task, keep
  its artefacts, report it, do not relax the rule.

**Allowlist**

- `crates/hexx/src/**` and `crates/hexx/tests/**`: **only** the lines `#[available_gas(…)]`
- `scripts/bench.py`, `scripts/gas_tables.py`, `scripts/takeover_check.py`, `scripts/check.sh`,
  `scripts/tests/**`
- `.github/workflows/ci.yml`
- `gas/**`, `docs/GAS.md`, `crates/hexx/README.md` (the paragraph on the baseline)
- `REPORT.md` (ignored by git)

## Acceptance criteria

- [ ] AC-1 `python3 scripts/takeover_check.py --source <pinned origami>` prints `same` for the
      29 pairs; `git diff origin/main -- crates/hexx` shows only `#[available_gas(…)]` lines
      (show the command that proves it).
- [ ] AC-2 Every test of every package has a budget within the rule; no baseline remains.
- [ ] AC-3 One gas job per package, each under 10 minutes; the times are in the report.
- [ ] AC-4 Every gas job uploads the raw output and the artefact hashes; the double run of the
      `Digger` tests exists and passes.
- [ ] AC-5 `scripts/check.sh` passes; CI is green.
- [ ] AC-6 Nothing outside the allowlist was written.

## What the auditor will check

That no line of a moved file changed except the budgets (by its own diff), that every budget
equals `ceil(1.05 × measured)` of the committed snapshot, that the baseline and its rules are
gone and nothing else of the gate was relaxed, the split of the jobs and their dependencies,
the artefacts of the drift (would they let someone find the cause at the next occurrence), and
the organisation lens of `COMMON.md` §4 on the scripts it touches only where it applies.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the times of the jobs, the number of budgets
changed, and what the instrumented runs showed.
