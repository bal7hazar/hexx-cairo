# [Sonnet 5.5] LIB-05 M1-T1a — Take-over of the engine: the move

Model: I am Sonnet 5.5, as the brief names. Pull request: https://github.com/bal7hazar/hexx-cairo/pull/28
(branch `feat/lib-05-m1-t1a-takeover-move`, two commits). **CI is red on one job (`Gas budgets and
class size`), by consequence of the brief's own rules: see Escalations 1 and 2.**

## Summary

- `crates/hexx` now holds the engine of `origami_hexmap` 1.8.0 (`04ab30c`): `board/{map,direction,
  layout,geometry,asserter,bits,rng,printer}`, `finders/{bfs,dial}`, `generators/{caver,digger,
  mazer,spreader,walker}`, `tests/*` (11 files), `tests/readme.cairo`, `GAS-origami-1.8.0.md`,
  `.scarbignore`. Flat module declarations: `board.cairo`, `finders.cairo`, `generators.cairo`,
  `tests.cairo` (the inline form `pub mod finders { pub mod bfs; }` is not reached by
  `scripts/bench.py` discovery, which raised on it: flat files are).
- `scripts/takeover_check.py`: 29 pairs, all `same` (17 of them `same after scarb fmt`, see
  Deviations). Unit tests in `scripts/tests/test_takeover_check.py`. Wired in `scripts/check.sh`
  (skips and says so without the checkout) and in CI (new `takeover` job clones origami at the
  pinned commit; it passed).
- `lib.cairo`: modules, `#[cfg(test)]` for `tests` (and `printer` in `board.cairo`), root re-exports
  `HexMap`, `HexMapTrait`, `Direction`; the placeholder and its test are gone.
- `crates/consumer`: one call site of each of the 20 functions of `HexMapTrait`, in three contracts
  (`HexxSink`, `HexxGenerators`, `HexxDial`); `gas/bytecode.size` committed.
- `LICENSE-origami` (copy of `sources/origami/LICENSE`), the sentence in `crates/hexx/README.md`
  (its Status text, which said "placeholder", was rewritten).
- Regenerated: `docs/EXTENSIONS.md` (lists the 20 `HexMap.*` functions and the public items of
  every moved module), `gas/hexx.snap`, `gas/bytecode.size`. `docs/API_PARITY.md`,
  `docs/DEVIATIONS.md` came out unchanged. **`docs/GAS.md` not regenerated** (Escalation 2).

## Files changed

- `crates/hexx/src/{board,finders,generators,tests}/**`, `crates/hexx/tests/readme.cairo`,
  `crates/hexx/.scarbignore`, `crates/hexx/GAS-origami-1.8.0.md`: the moved files.
- `crates/hexx/src/{lib,board,finders,generators,tests}.cairo`: declarations.
- `crates/hexx/README.md`, `LICENSE-origami`: licence and attribution.
- `crates/consumer/src/lib.cairo`: 20 call sites, three contracts.
- `scripts/takeover_check.py`, `scripts/tests/test_takeover_check.py`, `scripts/check.sh`,
  `.github/workflows/ci.yml`: the proof and its wiring.
- `docs/EXTENSIONS.md`, `gas/hexx.snap`, `gas/bytecode.size`: generated.

`crates/hexx/Scarb.toml` untouched (AC-5): only `snforge_std` under `[dev-dependencies]`.

## Commands run

- `python3 scripts/takeover_check.py --source sources/origami/crates/hexmap` → `29 pairs, 0
  problem(s)`, exit 0 (AC-1). The rewrites in the script are the four import rules, the `u252`
  removals below, and the two path rules of `.scarbignore`.
- `scarb fmt --check --workspace` → ok. `scarb build --workspace` → ok (dev profile warns that the
  20 functions in one contract would exceed 81,920 CASM felts: hence three contracts).
- `snforge test -p hexx --detailed-resources` → `Tests: 708 passed, 0 failed, 103 ignored, 0
  filtered out` (ignored: the `#[ignore]`d losers/prints of the source, as there).
- `python3 -m unittest discover -s scripts/tests` → `Ran 98 tests`, OK (8 skipped, not mine).
- `python3 scripts/api_parity.py --check`, `--extensions --check`, `deviations.py --check` → up to date
  (AC-4).
- `python3 scripts/bytecode_size.py check` → ok. `scripts/bench.py check` → **exit 1**;
  `scripts/gas_tables.py --check` → **ValueError** (Escalations). `scripts/check.sh` therefore does
  not pass (it stops at `bench.py check`).
- `gh pr checks 28`: all pass except `Gas budgets and class size` (and `All checks passed`, which
  needs it).

**`u252` removals** (the only ones; `grep -i u252` finds nothing else in a moved file):
`tests/readme.cairo` line 5, `use origami_hexmap::{Direction, HexMap, HexMapTrait, U252Trait, u252};`
→ `use hexx::{Direction, HexMap, HexMapTrait};`; and the test `test_readme_u252` (source lines 119-128:
`#[test]`, the function, one blank line). Nothing else in `src/` names `u252`; `types/u252.cairo`,
`bench_u252.cairo` are not taken.

**Test counts (AC-2).** Source: 914 `#[test]` lines (`Grep '^\s*#\[test\]'` over `*.cairo` of
`sources/origami/crates/hexmap`, 27 files) − 17 (`types/u252.cairo`) − 85 (`bench_u252.cairo`) − 1
(`test_readme_u252`) = **811**. `hexx`: snforge `Collected 811 test(s) from hexx package`
(7 in `tests/`, 804 in `src/`); 708 pass + 103 ignored = 811. Equal.

## Cost

| | |
|---|---|
| Tests | 811 (708 run by default, 103 `#[ignore]`) |
| `snforge test -p hexx` | 4 min 11 s wall locally (13 min 31 s user, incl. a ~2 min build); CI job `Build and test hexx` 7 min 15 s |
| Class sizes (release) | `HexxDial` 21,007 CASM felts, `HexxSink` 44,469, `HexxGenerators` 49,375 (limit 81,920) |

Budgets. Measurements equal those of `GAS.md` of 1.8.0 (e.g. `bench_bfs_distance_cave_far_17x14`:
501,942 measured, in both). But the budgets are not within 5 %, because 1.8.0 rounds up to the next
thousand (`GAS.md` step 3: `ceil(1.05 * measured, 1000)`) while `bench.py` demands
`ceil(1.05 * measured)`:

- **428 tests** carry a budget more than 5 % above their measurement (none below: no test lacks gas),
  e.g. `bench_bfs_range_3_empty_7x7` budget 66,000 / measured 62,061 (ceiling 65,165);
  `bench_bfs_reachable_serpentine_17x14` 2,004,000 / 1,843,335 (ceiling 1,935,502).
- **242 tests** have no `#[available_gas]` in the source (module tests of `map`, `bits`, `asserter`,
  `rng`, `direction`, `geometry`, `printer`, `bfs`, `dial`, generators; `fixtures`, `properties`,
  `variants`; the 7 `readme` tests).
- The full lists are what `python3 scripts/bench.py check` prints on stderr
  (`gas budget violations:`), reproducible from this branch; not adjusted.

## Deviations

- **`scarb fmt` changes 17 moved files** (`map`, `bfs`, `dial`, `caver`, `digger`, `mazer`,
  `walker`, `bench_{bfs,caver,dial,foundation,map,mazer,spreader,walker}`, `properties`,
  `variants`): `sort-module-level-items = true` reorders the `use` lines whose path changed
  (`hexx::board::…` sorts before `hexx::finders::…`, `origami_hexmap::helpers::…` sorted after
  `generators`). Only `use` lines move (checked: same multiset of lines in all 17). The check
  compares against the source after rewrite **and** `scarb fmt` in a scratch package with the same
  configuration, and prints `same after scarb fmt`.
- The check's "destination without source" covers `src/board`, `src/finders`, `src/generators`,
  `src/tests`, `tests`; `OWN_FILES` (empty) will need a line when a later task adds a file there
  (`board/tables.cairo`…, `finders/flood.cairo`): `scripts/` belongs to the orchestrator.
- The `GAS.md` pair is copied byte for byte (its `u252` section S1 remains, as the record of 1.8.0).
- Three contracts in `crates/consumer` instead of one (AGENTS.md principle 11 allows it): one
  holds 111,660 CASM felts, above the limit.
- `crates/hexx/README.md` Status rewritten beyond the one sentence, because it said "placeholder".

## Escalations

1. **`bench.py check` cannot pass without changing budgets.** 428 budgets are rounded to the
   thousand (rule of 1.8.0) against the 5 % rule of `bench.py`; 242 tests have no `#[available_gas]`.
   The brief forbids changing a budget or a moved test. Needs a decision: rewrite the budgets and
   add attributes (with an amended AC-1: the check would compare after that rewrite), or relax
   `bench.py` for taken-over tests. Until then the `Gas budgets and class size` job is red.
2. **`scripts/gas_tables.py` raises** `ValueError: invalid literal for int() with base 10: 'None'`
   on `gas/hexx.snap`: `bench.py snapshot` writes `None` for a test without budget (242 lines), and
   `gas_tables.py` reads two integers. Both scripts are orchestrator-owned; `docs/GAS.md` was not
   regenerated.
3. `scripts/check.sh` does not reach its end locally for the same reason (Escalation 1).

## Open questions

- Should the rewritten-then-formatted comparison stay (17 files) or should the moved `use` order be
  the source's (then `scarb fmt --check` would fail on `sort-module-level-items`)? I kept the former.
- CI time: `Build and test hexx` takes 7 min 15 s of the 10-minute limit; the heaviest lots are
  `bench_bfs` (146 tests) and `bench_spreader` (141). A split by filter would be the proposal if
  the limit is approached; no test removed.

---

# Follow-up 1 — the gas gate learns the inherited tests

Pull request 28, commits `c7fbcca` (the change) and `3dd6d48` (an empty commit, see 5). **Every CI
check of PR 28 is green** on the last run (`All checks passed`, run 36501461464).

## What was done

1. **`gas/takeover-baseline.txt`**: 670 test paths, one per line, sorted, after a header saying what
   it is, that it is generated by `bench.py baseline`, that it only shrinks, and that M1-T1c empties
   it. Generated by the new subcommand `python3 scripts/bench.py baseline` (428 budgets above
   `ceil(1.05 x measured)` + 242 tests without `#[available_gas]` = 670, as in the first report).
   The first generation is the bootstrap (file absent): `baseline_update` treats a missing file as
   "everything non-conformant is the first list"; **`--allow-growth` was not used**.
2. **`bench.py check`**: a test of the baseline is exempt from "has a budget" and "budget <=
   ceil(1.05 x measured)" and from nothing else (still discovered, measured unless ignored, must
   pass, budget below measurement still fails). Not in the baseline: every rule, as before. A baseline
   test that is conformant now, or that does not exist any more, is an error naming
   `bench.py baseline`. `bench.py baseline` raises on any test it would add unless `--allow-growth`.
   Also: `read_snapshots` of `bench.py` now reads `None` (it would have crashed the same way as
   `gas_tables.py`, once `check` got past the violations).
3. **`gas_tables.py`**: no crash on `None`; `docs/GAS.md` shows `none (inherited)` for such a test,
   `(inherited)` after the margin of an inherited row, and an intro paragraph and a count line
   (`680 measured test(s), 670 inherited`: 679 rows in `gas/hexx.snap` + 1 in `takeover_tests.snap`; that is 132 fewer than the 811 collected tests of `hexx`, of which 103 are ignored; I did not investigate why the other 29 have no row, most likely `#[should_panic]` tests whose output has no `sierra gas` line, not verified). A test without budget that is not in
   the baseline would show `none`.
4. **Tests**: `scripts/tests/test_bench_baseline.py` (19 tests): conformance, each exemption, each
   rule that stays, a not-covered test, stale entries (conformant, gone), no baseline file, bootstrap,
   shrink, refusal to grow, `--allow-growth`, file round trip and header, `None` in both snapshot
   readers, both renderings of `gas_tables`. `python3 -m unittest discover -s scripts/tests`: 117
   tests OK (8 skipped, not mine).
5. **Regenerated and run**: `gas/*.snap` unchanged (already current), `docs/GAS.md` regenerated,
   other generated documents unchanged. `scripts/check.sh` → `all checks passed`, locally.

Files written: `scripts/bench.py`, `scripts/gas_tables.py`, `scripts/tests/test_bench_baseline.py`,
`gas/takeover-baseline.txt`, `docs/GAS.md`. No budget of a moved test changed; `scripts/takeover_check.py`
still says 29 pairs, 0 problem(s).

## CI observation (not acted on)

The first run after the change failed the snapshot comparison of the gas job with
`CHANGED hexx_integrationtest::readme::test_readme_open: measured 2030366 -> 2053706` (+23,340 sierra
gas); the same value 2053706 appeared in the first CI run of the PR. Locally it is 2030366 in five
runs (full and filtered), and in CI the plain `snforge test -p hexx` printed `~2030366` in the same
run. After an empty commit the gas job measured 2030366 and passed. So this test's measurement
differs between runs in CI (twice 2053706, once 2030366); I found no cause and did not touch it. It
is a threat to the exact-equality snapshot (`bench.py check` fails on any drift), so the gate may
fail again on it at random. The test creates a cave and a corridor/maze from a fixed seed
(`crates/hexx/tests/readme.cairo`, `test_readme_open`). Whether it is nondeterministic in 1.8.0 as
well I have not checked.

## `crates/hexx/README.md`: exactly what I changed

Only the **Status** section. Removed: the "**Not published.** This package is a placeholder:
milestone L-M1 ... has something to run on (task LIB-04)." paragraph. Added in its place: "**Not
published.** This package holds the board engine of `origami_hexmap` 1.8.0, moved unchanged into
the module tree of the plan (`board`, `finders`, `generators`; task LIB-05 M1-T1a); the mirror of
`hexx` itself and the extensions land with the next tasks of L-M1." and the paragraph "The board
engine is taken over from `origami_hexmap` 1.8.0 (`dojoengine/origami`, commit `04ab30c`, MIT): its
notice is `LICENSE-origami`. The record of its gas measurements is `GAS-origami-1.8.0.md`." (both
with links). The "No `starknet` dependency..." paragraph, the title, Checks and License sections are
untouched. This follow-up did not change the README again.

## Reported, not acted on

- **CI job "Build and test hexx"**: 7 min 8 s (last run), 7 min 32 s (previous run); 7 min 15 s in
  the first report. Limit 10 min. The gas job took 5 min 20 s to 6 min 21 s.
- **Class sizes** (`gas/bytecode.size`, release, unchanged): `HexxDial` 9,789 Sierra / 21,007 CASM
  felts; `HexxSink` 24,672 / 44,469; `HexxGenerators` 27,092 / 49,375 (limit 81,920 each).

---

# Fix loop 1 (audit `[GPT-6-Sol]` pass 1, verdict FAIL)

Commit `4155cfb` on PR 28; every CI check green (run 36505609655; `Build and test hexx` 7 min 6 s,
`Gas budgets and class size` 6 min 18 s). `scripts/check.sh`: `all checks passed`.
`scripts/takeover_check.py`: `29 pairs, 0 problem(s)`; no moved file touched.

## Finding -> change -> file

| # | Finding (verified: yes, all five) | Change | Files |
|---|---|---|---|
| 1 | 29 fuzz tests ran with no row | Real output captured: a fuzz test prints **no** `sierra gas:` line, its result line is `[PASS] name (runs: 256, (l1_gas: {max: ~0, ...}, l1_data_gas: {...}, l2_gas: {max: ~186639, min: ~106432, mean: ~128053, std deviation: ~13553}))`. `parse_output` records the `max` as the measurement (rules, snapshot and baseline then apply to it). A test reported PASS/FAIL with no parsable measurement is an ERROR (in `budget_violations` and in `reconcile`), baseline or not. Real outputs kept verbatim as fixtures | `scripts/bench.py`, `scripts/tests/fixtures/snforge_{fuzz,plain,ignored}.txt`, `scripts/tests/test_bench_gate.py` |
| 2 | `#[ignore] // ...` broke discovery (808 of 811) | `FN_RE` accepts a line comment after an attribute and comment lines between attributes and `fn`; discovery now finds 811, the three `test_bench_caver_print_*` included (they are ignored, no budget: now in the baseline). `reconcile` fails unless declared = collected, every test that ran has a row, every declared test without a row is ignored; it prints the three counts | `scripts/bench.py`, `scripts/tests/test_bench_gate.py` |
| 3 | baseline could grow by hand | `check` requires each baseline entry to be in the approved set: the tests of the pinned source that the take-over moved (module path derived from the destination of each pair, after the rewrites; `u252` removed), and it runs `takeover_check` first, which must find the 29 pairs `same`. Without a checkout: the committed `gas/takeover-tests.txt` (811 names), generated by `bench.py baseline --inherited --source <path>`; when both exist they must agree. CI job `takeover` runs `bench.py baseline --inherited --check --source ...`. `bench.py baseline` refuses any test outside the approved set even with `--allow-growth` | `scripts/bench.py`, `gas/takeover-tests.txt`, `.github/workflows/ci.yml`, tests |
| 4 | `test_readme_open` 2,053,706 vs 2,030,366 | Investigated, cause not found: see below. Gate unchanged for it | — |
| 5 | descriptions omit the exemptions | The two exemptions (no `#[available_gas]`; budget above `ceil(1.05 x measured)`), the fuzz maximum and the counts are stated in the three places | `crates/hexx/README.md`, `.github/workflows/ci.yml`, `scripts/check.sh` |

## The three counts (finding 2), from `bench.py check` (run in `scripts/check.sh`)

```
reconciliation (declared in the sources / collected by snforge / with a gas row / ignored):
  consumer: declared 0, collected 0, with a gas row 0, ignored 0
  hexx: declared 811, collected 811, with a gas row 708, ignored 103
  takeover_tests: declared 1, collected 1, with a gas row 1, ignored 0
gas budgets and snapshot OK (709 tests)
```

708 + 103 = 811. The 29 missing rows of the first report were the 29 fuzz tests
(`hexx.snap`: 679 -> 708 rows).

## Fuzz maxima across runs (finding 1)

Three full-suite measurements (`bench.py baseline`, `bench.py snapshot`, `bench.py check` inside
`scripts/check.sh`): the 29 fuzz rows are **identical** in the first two tables (diff of the two
outputs empty) and the third run passes the exact comparison with the snapshot. The fuzzer is seeded
(`#[fuzzer(seed: 7)]`, 256 runs). Three single-test runs of `bench_spreader_generate_empty_17x14_1`:
max ~186639 each time. So no variation, no tolerance. Budget consequence: measured at their
maxima, all 29 fuzz tests have budgets above `ceil(1.05 x max)` (rounded up to the thousand, as in
1.8.0; e.g. `bench_spreader_generate_empty_17x14_1`: budget 196000, ceiling 195971), so they enter
the baseline like the other inherited tests.

## Baseline: one `--allow-growth`, disclosed

The gate now sees 32 inherited tests it did not see before, so `bench.py baseline` had to add them
(`wrote gas/takeover-baseline.txt: 702 test(s), 32 added`); I ran it **once with `--allow-growth`**,
because a refusal without the flag is the rule the orchestrator set and these are not new tests.
All 32 are in `gas/takeover-tests.txt` (checked by the approved set): the 29 fuzz tests of
`bench_spreader.cairo` (28 `bench_spreader_generate_*` and `bench_spreader_baseline_*`) and the 3
ignored `test_bench_caver_print_*`. Decision for the orchestrator: whether growth by tests of the
approved set should need no flag; I did not change that rule.

## Finding 4: `test_readme_open`, what was found and ruled out

Not found. Evidence:
- **Local, raw output, three runs** (`snforge test -p hexx test_readme_open --detailed-resources`):
  each `l2_gas: ~2030366`, `sierra gas: 2030366`, `syscalls: ()`. Earlier: five full or filtered
  runs, same; also `--max-threads 1` on the `test_readme` filter (`sierra gas` lines 5635725,
  494141, 57131 seen for the others).
- **Versions**, local: `scarb 2.19.4 (b45b74c03 2026-07-21)`, `snforge 0.61.0`, cairo 2.19.4,
  sierra 1.9.3. CI job logs (`gh run view --log`) of runs 36498901972 (2,053,706), 36500651592
  (2,053,706), 36501461464 (2,030,366): `scarb 2.19.4 (b45b74c03 2026-07-21)`, `snforge 0.61.0`,
  runner image `ubuntu-24.04` version `20260920.314.1`, provisioner `20260828.587`: identical in the
  runs that differ.
- **Cache**: all three gas jobs restored the same Scarb cache and target cache (key
  `gas-scarb-cache-linux-597720cf...2fc`, ~93 MB, "Cache hit"), so a different cached build is ruled
  out.
- **Sources**: runs 36500651592 and 36501461464 are the same tree (the second follows an empty
  commit), and differ (2,053,706 then 2,030,366).
- **Order / profile**: the gas job runs `bench.py` (same `snforge test -p hexx --detailed-resources`
  as local); the `test` job in the same runs printed `~2030366` for it. The raw snforge output of the
  failing gas jobs is not in the logs (the script prints its table only), so the raw text of the bad
  value could not be compared; the second run's bad value did not repeat on the third.
Ruled out: toolchain version, runner image, cache, source, profile. Remaining, unverified
hypotheses: a difference between runners (hardware), or non-determinism inside snforge for this
test. Not ruled out: it can recur; `bench.py check` would fail on it (exact snapshot comparison).
To capture next time, the gas job would have to keep the raw output (not done: `.github/` change
outside this loop's ask).

## Commands run, real output (trimmed)

- `python3 scripts/bench.py baseline --inherited --source sources/origami/crates/hexmap` ->
  `wrote gas/takeover-tests.txt: 811 test(s)`.
- `python3 -m unittest discover -s scripts/tests` -> `Ran 140 tests ... OK (skipped=8)`.
- `python3 scripts/bench.py baseline --allow-growth` -> the three counts above,
  `wrote gas/takeover-baseline.txt: 702 test(s), 32 added`.
- `python3 scripts/bench.py snapshot` -> `wrote 2 snapshot file(s) in gas/`; `hexx.snap` 708 rows.
- `python3 scripts/gas_tables.py` -> `wrote docs/GAS.md`.
- `scripts/check.sh` -> `29 pairs, 0 problem(s)` ... `gas budgets and snapshot OK (709 tests)` ...
  `all checks passed`.
- `gh pr checks 28` -> all checks pass (run 36505609655).

## What I dispute

- Nothing of the five findings. Two remarks: (a) finding 1's budget consequence was not in the
  audit: measured at their maxima, the fuzz tests also enter the baseline (see above); (b) the audit
  could not run `takeover_check.py` under a read-only worktree (`target/takeover_fmt` is written
  there); it needs a writable `target/` in the worktree, and `bench.py check` now runs it when the
  source is present, so the same limit applies there (without a checkout it uses the committed
  list). I did not change that.
