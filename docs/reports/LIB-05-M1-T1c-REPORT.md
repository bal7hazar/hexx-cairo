# [Sonnet 5.5] LIB-05 M1-T1c — The gas gate: inherited budgets conformant, a split job, the drift instrumented

Model read from my session: Sonnet 5.5 (as the brief names).

## Summary

- **Split**: the `gas` job of `.github/workflows/ci.yml` is now a matrix, one job per package
  (`Gas hexx`, `Gas takeover_tests`, `Gas consumer`), each running `bench.py check --package P`
  against its own `gas/<package>.snap`. `bench.py` gained `--package` for `run`, `snapshot`, `check`
  (`snapshot --package` rewrites only the snapshot of the package measured; before, it deleted the
  others). `All checks passed` still `needs` the `gas` job (all matrix legs). `gas_tables.py --check`
  moved to the `fmt` job (a pure function of the snapshots, it needs no snforge); the class-size
  check runs in the `consumer` leg.
- **Drift instrumented, no rule changed**: every snforge run writes `target/gas-artifacts/<package>/`
  with `snforge-detailed-resources.txt` (raw output), `artifacts.sha256` (SHA-256 of
  `target/dev/<package>_*.json`, the compiled test files snforge executes), `versions.txt` (`scarb
  --version`, which prints Cairo 2.19.4 and Sierra 1.9.3; `snforge --version`; and
  `universal-sierra-compiler --version` = 2.10.1, the Sierra-to-CASM compiler snforge uses). Each
  job uploads the directory whatever the outcome (`gas-<package>-<sha>`, 30 days). A mismatch with
  the snapshot prints, per test, `snapshot measured X, budget Y; now measured Z (+n.nn %), budget W`
  and where the artefacts are. `bench.py repeat --package P --filter digger` runs the matching tests
  twice back to back and fails on any difference (or on no match); it runs in the `hexx` and
  `takeover_tests` legs (`consumer` has no test), also when the check failed (`!cancelled()`),
  writing `repeat-1.txt` / `repeat-2.txt` into the same artefact.
- **Budgets**: 702 inherited budgets set to `ceil(1.05 × measured)`, then the baseline removed
  (`gas/takeover-baseline.txt`, its rules and tests in `bench.py`, `gas_tables.py`, `check.sh`, the
  README paragraph). `gas/takeover-tests.txt` is **deleted too**: with the baseline gone only the
  `takeover` CI step `bench.py baseline --inherited --check` used it, so nothing did. That step is
  removed; `takeover_check.py` proves the move and needs no list.
- `takeover_check.py` ignores, on both sides and in `.cairo` files only, the lines that hold
  nothing but `#[available_gas(...)]` (`BUDGET_LINE`); a comment line mentioning the attribute or an
  attribute sharing a line is not ignored (tested).
- Pull request: https://github.com/bal7hazar/hexx-cairo/pull/37 — CI green (all 12 checks).

## Files changed

- `crates/hexx/src/**`, `crates/hexx/tests/readme.cairo` (25 files): only `#[available_gas(...)]` lines
  (699 changed/added by pass 1, 3 added for the ignored tests, 107 changed again by pass 2).
- `scripts/bench.py`: baseline machinery removed; `--package`; evidence; `repeat`;
  `snapshot_differences` (figures + artefact location); `write_snapshots` touches only the packages measured.
- `scripts/gas_tables.py`: no baseline, no "(inherited)" marks. `scripts/check.sh`: comment only.
- `scripts/takeover_check.py`: `BUDGET_LINE`, `without_budgets`.
- `scripts/tests/test_bench_baseline.py` deleted; `test_bench_gate.py` (approved-set and inherited
  classes removed), `test_takeover_check.py` (2 tests), new `test_bench_gate_split.py` (no exemption,
  package selection, snapshot writing/reading per package, mismatch message, evidence, `repeat`, gas table).
- `.github/workflows/ci.yml`; `gas/hexx.snap` (699 rows), `gas/takeover-baseline.txt` and
  `gas/takeover-tests.txt` deleted; `docs/GAS.md` regenerated; `crates/hexx/README.md` (the paragraph).

## Commands run

- Measure / set / measure (hexx, `scripts/lock.sh snforge test -p hexx --detailed-resources`):
  pass 1 from the committed snapshot (699 of the 702 tests are in it; the 3 `#[ignore]`d
  `test_bench_caver_print_{stats,rules,fills}` have no snapshot row and were measured with
  `--include-ignored`: 741,201,562 / 562,797,543 / 1,125,936,944 → 778,261,641 / 590,937,421 /
  1,182,233,792). Measure again: **107 budgets moved** (the attribute shifts small tests). Measure
  again: **0** moved. So 107 of the 702 needed a second pass, none a third. The setter was a
  throwaway script under `target/` (not committed).
- `python3 scripts/takeover_check.py --source sources/origami/crates/hexmap` →
  `29 pairs, 0 problem(s)`: 12 pairs `same`, 17 `same after scarb fmt`. Identical split on `origin/main`
  (checked with the same function on its tree), so the count is not changed by this task; the brief's
  "prints `same`" holds in that sense, not literally for the 17 whose `use` lines `scarb fmt` reorders.
- AC-1 proof that only budgets changed:
  `git diff origin/main -- crates/hexx | grep '^[+-]' | grep -v '^+++\|^---' | grep -vc '^[+-][ \t]*#\[available_gas(l2_gas: [0-9]*)\]$'`
  → `0` (`25 files changed, 702 insertions(+), 457 deletions(-)`; 702 − 457 = 245 tests had no
  attribute before). The take-over check above also proves it per moved file.
- `python3 -m unittest discover -s scripts/tests` → `Ran 151 tests … OK (skipped=8)`.
- `scripts/check.sh` (full, local) → `all checks passed` (about 10 min on the shared machine).
- `bench.py check --package P` local: hexx `708 tests OK` (declared 811, collected 811, ignored
  103), takeover_tests `630 tests OK`, consumer `0 tests OK`.
- `bench.py repeat --package hexx --filter digger` → `12 tests … measured the same in two runs`;
  `--package takeover_tests` → `38 tests … measured the same in two runs`.

## Cost

Gas figures are the snapshots (`gas/*.snap`, `docs/GAS.md`, regenerated); no engine code changed, so
only budgets moved. Times of the jobs (CI run 36561064778, 10 min limit each):

| Job | Time |
|---|---|
| Gas hexx (check + double run + upload) | 6 m 32 s |
| Gas takeover_tests | 2 m 32 s |
| Gas consumer (check + class size) | 27 s |
| Build and test hexx (unchanged, for reference) | 7 m 00 s |

The old single job was 6 m 56 s – 7 m 54 s and grew with each package; now the longest is `hexx`
alone (which holds 708 of the 1,338 tests), so `takeover_tests` and `consumer` no longer add to it.
`hexx` is the one to watch as L-M1 adds tests: 6 m 32 s of 10 with the double run included.

## Deviations

- `gas/takeover-tests.txt` deleted, and the `takeover` job's second step removed (see Summary).
- Three ignored tests were measured with `--include-ignored` because the gate cannot see them
  (they carry a budget that the gate then cannot verify, like any other ignored test with one).
- CASM compiler: neither scarb nor snforge reports one; `universal-sierra-compiler --version` is
  recorded as the Sierra-to-CASM tool (best effort: `unavailable (...)` is written if it fails).

## Escalations

None. Note on the drift, as an inference, not a finding: `hexx` has 29 fuzz tests
(`bench_spreader_generate_*`, 256 runs) whose gate figure is the maximum over the runs; they were
identical to their snapshot in the three local runs with different fuzzer seeds, but they are
the one place where a measurement depends on a random seed. The brief says the tests that moved all
go through `Digger::dig`, which those are not.

## Open questions

- What the instrumented runs showed: **no drift occurred** during this task. Locally, the first
  `hexx` run matched the committed snapshot exactly (708 tests), and so did the `check` runs
  after the snapshot (`hexx`, then the full `check.sh`), as did CI; the double run of the
  Digger tests was identical in both packages, locally and in CI (job green). The cause of the
  earlier drift is therefore still unknown; the artefacts of the next occurrence
  (`gas-<package>-<sha>`: raw output, hashes of the compiled files, versions) will say whether the
  compiled test file differed between two runs (hash) or only the measurement did.
- The `repeat` tolerance is exact by design; if a future double run differs, the job fails, which
  is the intended signal.

## Fix loop 1

Audit `sources/audits/M1-T1c-audit-gpt-6-sol-pass-1.md` (FAIL). Pull request 37, commits `5a3cda3` and
`c3cea4d`. CI green on `c3cea4d` (run 36572206142, 13 checks).

**Finding 1** — withdrawn by the orchestrator; the nine budgets are untouched.

**Finding 2 — ignored tests.** Verified: the three `test_bench_caver_print_*` had a budget and no row.
Measuring all ignored tests showed a larger problem: `snforge test -p hexx --ignored` runs the 103
ignored tests (all pass, about 140 s locally) and **89 of them had a budget outside
`[measured, ceil(1.05 × measured)]` or none** (the `bench_spreader_*` benchmarks, inherited, never
measured because ignored; the old rule called an unmeasured test with a budget "unjudgeable"). Done:
- `bench.py` measures every test: default scope `all` = `snforge test --include-ignored`. An
  unmeasured test with a budget is now an error like any other ("not measured … its budget cannot be
  verified").
- The 89 budgets set to `ceil(1.05 × measured)` (only in `bench_spreader.cairo`, `#[available_gas]`
  lines: `git diff origin/main -- crates/hexx` still shows nothing else in Cairo; the README paragraph
  is the only other line). Measured again with the attributes in place: 0 out of range, so none needed
  a second pass. The three print tests were already within range with their attribute.
- `gas/hexx.snap` has 811 rows (was 708): the 103 ignored tests are committed.
- **Cost in CI, as the brief asked me to say**: measuring them in the same job took `Gas hexx` from
  6 m 32 s to **9 m 45 s** of 10 (run 36568463132; +3 m 13 s), no room. I did not stop there: I split
  the job instead, which keeps each leg far from the limit. `--scope regular|ignored|all`
  (`snforge` without flag / `--ignored` / `--include-ignored`); CI legs: `hexx` (regular),
  `hexx (ignored tests)`, `takeover_tests`, `consumer`. Times (run 36572206142): **7 m 06 s**,
  **4 m 25 s**, 2 m 32 s, 24 s. A scope compares only its snapshot rows (a row of a test that no longer
  exists is reported by both `hexx` legs); `snapshot` needs scope `all`. Easy to revert to one job if
  you prefer to stop on this point; the ignored legs would then need `--scope all` and 10 minutes
  would not hold.

**Finding 3 — hashes per run.** Verified as described. Now `snforge-<run>.txt` and
`artifacts-<run>.sha256` exist per run (`check`, `repeat-1`, `repeat-2`), all uploaded (artefact
`gas-<package>-<scope>-<sha>`). `repeat` first compares the hashes of both repeats with those of the
check and prints `THE COMPILED FILES OF repeat-N DIFFER FROM THOSE OF check` with the differing files,
then fails, even if the measurements are equal; only then compares the measurements. Tested with fake
runs; locally the real check and repeats had identical hashes.

**Finding 4 — verified and fixed.** `check` computes and prints the violations, the snapshot
differences (test, both figures, percentage) and the location of the evidence together; it exits 1
on a violation, or with the mismatch message otherwise. Test: a violation plus a moved measurement.

**Tests**: `scripts/tests` 159 tests OK (8 skipped as before); `scripts/check.sh` passes locally.

### The drift recurred — twice locally, once in CI — with evidence

Not relaxed, not worked around. What was seen:
1. **Locally** during this loop, in `scripts/check.sh` (after `scarb build --workspace`, the
   package tests, then `bench.py check`): 42 `takeover_tests` tests moved by +0.22 % to +0.62 %
   against an unchanged snapshot (`test_digger_corridor_*`, `test_digger_maze_*`,
   `test_map_open_with_{corridor,maze}_*`, four `test_gas_open_with_*_origami_*`, two fixtures
   provenance tests): **every one goes through `Digger::dig`**. The source of the package had not
   changed. The same tree measured exactly the snapshot in two earlier and three later runs. The bad
   state persisted through a second `bench.py check` (no rebuild), i.e. it belongs to the compiled
   file, not to the measurement. Evidence kept: `target/drift/drift-snforge-check.txt` /
   `drift-artifacts-check.sha256` (bad), `good-snforge.txt` / `good-artifacts.sha256` (good) in the
   worktree (ignored by git).
2. **Hashes**: `takeover_tests_unittest.test.sierra.json` was `3e49f1fd…` in the good build,
   `d6b64150…` in the bad one, and `3d4ee664…` and `e13a04ef…` in two further clean rebuilds
   (`target/dev/incremental` and `.fingerprint` removed) that both measured exactly the snapshot.
   So **rebuilding the same sources gives a different compiled file every time** (four builds, four
   hashes), and one of the four had different gas. `test.json` was identical in all.
3. **In CI** (run 36568463132, `Gas hexx`, commit `5a3cda3`): `hexx_integrationtest::readme::
   test_readme_open` measured 2,053,706 against 2,030,366 (+1.15 %), the same test and figure as
   the first drift; that run's `Gas consumer` also failed its class-size check with
   `HexxGenerators` at 27,101 Sierra felts against the committed 27,092 (CASM 49,375 unchanged,
   Sierra class bytes 1,396,211 against 1,395,788), which contains the generators including Digger.
   The next run (`c3cea4d`, same code of the library) gave 27,092 again and everything green. Its
   artefacts (`gas-hexx-5a3cda3…`) are in the run's artefact list on GitHub (30 days); I could not
   download them from this profile.

**Reading (inference, not proved)**: the Cairo/Scarb compile of a package is not reproducible
byte for byte and, for code that reaches `Digger::dig`, sometimes produces a Sierra program whose
gas or size differs (0.2–1.3 %); the tests and the algorithm are the same. The size of the
`HexxGenerators` class changing between two CI runs on the same library sources supports it independently of any
measurement. This is not a runner-cache or measurement issue. What would settle it: compile
`hexx_unittest` N times from a clean `target/` and diff the two Sierra JSON files of a good and a
bad build (`diff` of `d6b64150…` and `3e49f1fd…` here; I kept the hashes, not the 180 MB files).
Consequences for the gate, for the orchestrator to decide, not done here: an exact gate on
`Digger`-reaching tests will fail intermittently whatever the tree; a CI re-run passes; the
class-size gate of `consumer` has the same exposure.

### Deviations of this loop
- The split of `hexx` into two jobs instead of stopping (see finding 2).
- `check`'s snapshot mismatch message no longer says the rule is exact for the source; unchanged rule.

### Escalations / open questions
- Whether to re-run failed gas jobs or to change the gate for Digger-reaching tests (the rule
  is unchanged here); whether to open a Cairo/Scarb issue with the two Sierra files of a good and a
  bad build.

## Reproduction for SPK-13 (added by the orchestrator `[Opus 5.5]`, 2026-09-29)

For the task SPK-13 of the game (decision D-154), which reproduces the non-deterministic compile
on another machine. What is known is above (§ *The drift recurred*); this is how to try it again.

| | |
|---|---|
| Repository and commit | `https://github.com/bal7hazar/hexx-cairo`, `main` at `f3198a9ae683653f28815ef436391f230f7b673b` (this lot merged). The CI drift was seen at `5a3cda3` (run 36568463132); the local one during the fix loop, same sources of the library |
| Toolchain | `.tool-versions` of the repository: Scarb 2.19.4 (Cairo 2.19.4, Sierra 1.9.3), starknet-foundry 0.61.0 (`universal-sierra-compiler` 2.10.1) |
| Where it shows | Tests that reach `Digger::dig`: in `takeover_tests`, `test_digger_corridor_*`, `test_digger_maze_*`, `test_map_open_with_{corridor,maze}_*`; in `hexx`, `hexx_integrationtest::readme::test_readme_open`; and the class `HexxGenerators` of `crates/consumer` |

Commands, from the root of a clone at that commit, repeated N times (the local occurrence was one
build in four):

```bash
rm -rf target
scarb build --workspace
sha256sum target/dev/*.json > build-$i.sha256
python3 scripts/bench.py check --package takeover_tests
python3 scripts/bench.py check --package hexx --scope regular
python3 scripts/bytecode_size.py check
```

A gas-only mismatch prints the test, both figures and the directory of the evidence
(`target/gas-artifacts/<package>/`: raw `snforge --detailed-resources` output, SHA-256 of the
compiled files, tool versions). To settle the cause, keep the whole `target/dev/*.json` of one
good and one bad build (the files are large, about 180 MB) and diff the two Sierra programs of
`takeover_tests_unittest.test.sierra.json`; the bad build differs from the good one there, not in
the tests or the sources. `python3 scripts/bench.py repeat --package takeover_tests --filter
digger` measures the Digger tests twice on one build and compares their hashes first.
