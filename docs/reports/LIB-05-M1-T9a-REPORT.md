# [Opus 5.5] LIB-05 M1-T9a — N-8: the flood

## Summary

**STOPPED on the stop condition of the brief.** `FloodTrait::depth` costs **670 L2 gas** per call
(measured), above the upper bound **250** of its target range in plan §7 (`FloodTrait::depth`,
`[200, 250]`, "a length", marked *estimate*). As the brief requires, I did not optimise or rewrite
anything after that measurement, and I set no budget.

Every other measured figure is inside its range: the flood at depth 10, 15, 20 and without a limit,
the eight walkers, the cave window at 15 layers, the cost per layer, and the fixed cost (which is
below its lower bound). See *Cost*.

What exists now (branch `feat/lib-05-m1-t9a-flood`, 2 local commits `c57d5ff` and `43a8b1f`,
**not pushed, no pull request**, because I stopped):

- `Bfs::flood(grid, width, height, from, obstacles, depth) -> Flood`, the only addition to
  `finders/bfs.cairo`. It is built on the engine's own layer step (`BfsInternal::check_one`,
  `constants`, `endpoint`, `layer`, `layer_small`, `ArrayStore`). No existing function changed.
- `finders/flood.cairo`: `Flood { width, height, layers: Span<u256> }` (fields `pub(crate)`),
  `FloodTrait::depth`, `FloodAssert::assert_free` with its `errors` module, and
  `FloodInternal::{spread, spread_small}`: the store-every-layer loops over
  `BfsInternal::layer` / `layer_small`.
- Tests (`tests/test_flood.cairo`, 29 tests, all passing): a scalar queue-BFS oracle compared layer
  by layer with the flood. It covers every R-N8-* case (the flood part of each), both limb paths
  (7 × 7, 11 × 11, 15 × 16, 17 × 14, 19 × 13), `depth` 0, 1, 15, around the reach and beyond it, a
  disconnected source, and open edge sources (D-32).
- Benchmarks (`tests/bench_flood.cairo`, 11 tests), measured.
- Fixture `SERPENTINE_15X16` in `tests/fixtures.cairo`, added with `SERPENTINE_15X16_FROM` and
  `SERPENTINE_15X16_8` (the eight walkers of the plan).

The model named by the brief is the model of this session (Opus 5.5).

## Files changed

- `crates/hexx/src/finders/flood.cairo`: new. `Flood`, `FloodTrait`, `FloodAssert` with `errors`,
  and `FloodInternal`.
- `crates/hexx/src/finders/bfs.cairo`: one `use` line and `Bfs::flood`, nothing else (diff below).
- `crates/hexx/src/finders.cairo`: `pub mod flood;`.
- `crates/hexx/src/tests.cairo`: `pub mod bench_flood;`, `pub mod test_flood;`.
- `crates/hexx/src/tests/test_flood.cairo`: new. The oracle, the tests, and the cave window
  `CAVE_15X16`.
- `crates/hexx/src/tests/bench_flood.cairo`: new. The benchmarks.
- `crates/hexx/src/tests/fixtures.cairo`: additions only (`SERPENTINE_15X16`, `_FROM`, `_8`).

Not done because of the stop: `crates/consumer` call sites, `gas/hexx.snap`, `gas/consumer.snap`,
`gas/bytecode.size`, `docs/EXTENSIONS.md`, `docs/GAS.md`, `docs/API_PARITY.md`. The budgets of
the new tests are placeholders (`1000000000` / `100000000`), so `bench.py check` will fail on them.

## Commands run

- `scripts/lock.sh snforge test -p hexx test_flood_`: `Tests: 29 passed, 0 failed`. Measured L2
  gas: R-N8-1 13,864,276; R-N8-3 86,694,466; fixtures 17 × 14 814,173,430; cave sweep 15 × 16
  525,644,191; the other tests are between 15,520 and 276,349,571.
- `scripts/lock.sh snforge test -p hexx bench_flood`: `Tests: 11 passed, 0 failed`. The figures
  are under *Cost*.
- `scripts/lock.sh snforge test -p takeover_tests`: `Tests: 630 passed, 0 failed, 0 ignored`.
- `python3 scripts/takeover_check.py`: `takeover_check: no source checkout at .../sources/origami/crates/hexmap`.
  It could not run locally (no origami checkout in this worktree).
- `scarb fmt -p hexx`: applied; `scarb fmt --check -p hexx` is clean after it.
- An independent Python BFS of `SERPENTINE_15X16` (scratch, deleted) reproduces every hand
  distance of plan §6.9: `(13, 8)` 6, `(1, 6)` 20, `(1, 5)` 20, `(13, 4)` 32, `(2, 2)` 45,
  `(1, 2)` 46, `(6, 12)` 27, `(1, 12)` 32, and so on. It also reproduces R-N8-1 (depth 45, 82
  tiles), R-N8-3 (43, 80 tiles, `(2, 2)` unreached, `(4, 2)` at 43) and R-N8-4 (41, 73 tiles,
  `(6, 2)` at 41, `(6, 12)` at 27). **The plan's figures are right.**
- Not run, because of the stop: `scripts/check.sh`, `bench.py check|snapshot`,
  `bytecode_size.py`, `api_parity.py`, `gas_tables.py`, and CI.

The diff of `bfs.cairo` against `origin/main` has exactly two hunks: `+use
hexx::finders::flood::{Flood, FloodAssert, FloodInternal};`, and the new method `Bfs::flood` added
at the end of `impl Bfs` (57 lines, doc comment included).

## Cost

Method (as SPK-7): each figure is the test minus `bench_flood_baseline` (16,240: the opaque
inputs and one assertion). Each figure includes one `depth()` call and its assertion. The ranges
for depths 10, 15, 16 and 20 are **derived by me** from the §7 row's bound
`55,000 + 19,300 × depth()` with `U = ceil(1.25 × L)`; §7 states instances only for 25 (cave), 45
and 41.

| Benchmark | Measured | SPK-7 (on `origami_hexmap` 1.8.0, with target tests) | §7 target [L, U] | |
|---|---:|---:|---:|---|
| Serpentine 15 × 16, R-N8-1, `depth` 10 | 251,148 | 323,900 (deep board, cap 10) | [248,000, 310,000] | in |
| same, `depth` 15 (D-127) | 364,878 | 456,160 | [344,500, 430,625] | in |
| same, `depth` 20 | 478,608 | 588,420 | [441,000, 551,250] | in |
| same, no limit (45 layers) | 1,028,534 | 2,407,277 (83 layers, another board) | [923,500, 1,154,375] | in |
| `SERPENTINE_15X16_8` (41 layers) | 935,180 | — | [846,300, 1,057,875] | in |
| Cave window 15 × 16, `depth` 15 (truncated) | 357,768 | 634,655 (capped worst case: flood with 8 targets' hit tests; not the same work) | [344,500, 430,625] | in |
| Cave window, no limit (16 layers) | 396,550 | — | [363,800, 454,750] | in |
| Per layer, `(d20 − d10) / 10` | **22,746** | 26,452 | [19,300, 24,125] | in |
| Per layer, `(d15 − d10) / 5` | 22,746 | | | check |
| Per layer, `(unlimited − d20) / 25` | 21,997 | | | the last layers are cheaper |
| Fixed, `d10 − 10 × 22,746` | **23,688** | 59,380 | [55,000, 68,750] | below L |
| Serpentine, `depth` 0 (checks, constants, endpoint, layer 0) | 35,132 | — | — | |
| **`FloodTrait::depth`**, `bench_flood_depth_twice − bench_flood_depth_once` (268,628 − 267,958) | **670** | — | **[200, 250]** (estimate) | **ABOVE U: STOP** |

**The breakdown of `depth()` I could measure.** It is `((*self.layers).len() - 1).try_into().unwrap()`
(`finders/flood.cairo`). The pair above isolates exactly one call: `depth() + depth() == 20`
against `depth() + input == 20`. A first try compared a second `assert!(depth() == …)` (+1,170)
and was inflated by the assertion itself: a plain `assert!(a == b + 10)` alone costs +1,070.
Estimate, not measured: most of the 670 goes to the `u32` subtraction with its overflow check and
the `u32 → u8` `try_into` with its range check and `unwrap` branch; the `len` itself is small.

**What I would try (not done):**

1. Store `depth: u8` in `Flood` at construction. `spread` already counts layers down, so the count
   is free at the end. `depth()` then becomes a field read, about 100 by the plan's unit.
2. Or return the length without the conversion.
3. Or accept the measurement as the target: the §7 figure is an estimate, "a length".

Option 1 adds a field to the plan's struct: that is the owner's or orchestrator's call.

## Deviations

- **Signature.** `Bfs::flood(grid, width, height, from, obstacles, depth)`, in the form of every
  other `Bfs` function, rather than §6.9's `flood(self: HexMap, …)`. The facade
  `HexMapTrait::flood` (§6.9 "Module") would go in `board/map.cairo`, which is not in the
  allowlist. See *Escalations*.
- **Fields of `Flood`** are `pub(crate)`. The plan writes them without `pub` (private), but `Bfs`
  builds the struct in another module, and M1-T9b's selection is in the same crate.
- **`u256` layers** (principle 5): this is the plan's type (`Span<u256>`), and the two limbs of the
  engine's own `ArrayStore`. The single-limb path widens each layer (`high: 0`), so both paths
  build one `Flood`.
- **The layer loops live in `flood.cairo`** (`FloodInternal::spread`, `spread_small`), not in
  `BfsInternal`. This keeps the diff of `bfs.cairo` to the entry point alone. They call
  `BfsInternal::layer` / `layer_small` and are not unrolled (the engine's search loops are, four
  times). No optimisation was attempted.
- **The sketch is kept.** It is the layer loop of `Bfs` storing every layer, with an edge source
  seeded by its open interior neighbours. The one change is that layer 1 is the neighbourhood
  without the source (layer 0 is `{from}` alone, as the contract says), where the engine's first
  layer holds both.
- **`FloodAssert`'s `errors::FLOOD_POSITION_NOT_WALKABLE`** has the message
  `'Bfs: position not walkable'`, the panic the contract requires. It is a second constant with
  `Bfs`'s string.
- **The cave window** is `Caver::generate(15, 16, 3, 30)` (constant `CAVE_15X16`, checked against
  the generator in a test), not a window assembled from 4 chunks. Its flood from `(7, 8)` is 16
  layers, so the cap of 15 truncates it. §7's cave row at 25 layers (a pinned input for M1-T9) is
  not reproducible on it. The comparison uses the parameterised bound.
- **`SERPENTINE_15X16_FROM` and `SERPENTINE_15X16_8`** were added next to the fixture: the plan's
  source and eight walkers.

## Escalations

1. **Stop condition: `FloodTrait::depth` measures 670 L2 gas, above 250**, the upper bound of
   §7's range. Figure, breakdown and options are under *Cost*. Nothing was optimised, and no
   budget was set.
2. **`scripts/takeover_check.py`** will fail in CI (`takeover` job) until the orchestrator:
   - adds `src/finders/flood.cairo`, `src/tests/test_flood.cairo` and
     `src/tests/bench_flood.cairo` to `OWN_FILES`;
   - accepts the added entry point of `bfs.cairo`. The script compares whole files, so the diff
     above (one `use` line, one method) is reported `DIFFERENT`.

   The script is not in my allowlist.
3. **The facade `HexMapTrait::flood`** (§6.9 "Module") needs `board/map.cairo`, which is outside
   the allowlist. It was not added.
4. **The fixed cost** measures 23,688, below §7's lower bound 55,000. This is not a stop, but the
   tick target of M1-T9b (`55,000 + 19,300 × depth()`) is then conservative on its fixed part and
   slightly optimistic per layer (22,746 measured against 19,300).

## Open questions

- Should `Flood` carry its `depth` as a field (the cheapest `depth()`), or should the §7 target of
  `depth()` be replaced by the measurement?
- Once that is decided, the remaining steps of Scope 4 and 5 are still to do: set the budgets,
  add the `crates/consumer` call site (a `HexxFlood` contract calling `Bfs::flood(…).depth()`),
  regenerate the snapshots and the generated docs, push, open the pull request, and bring CI to
  green.

## Follow-up 1

**Pull request: https://github.com/bal7hazar/hexx-cairo/pull/41. CI green: all 14 checks pass**
(run 36592313540), including "Take-over of origami_hexmap is a move", "Gas hexx" and
"Gas consumer". No re-run was needed (no D-154 drift).

### Decisions of the orchestrator, recorded

- **`FloodTrait::depth`: the measurement replaces the estimate.** The measured 670 L2 gas per
  call replaces the §7 target `[200, 250]`. The plan's struct `Flood` does not change (no `depth`
  field). The reason given: 8 calls per tick cost about 5,400, negligible against the flood. The
  budgets of `bench_flood_depth_once` and `bench_flood_depth_twice` are set on the measurement.
- **The fixed cost** (23,688) below its range `[55,000, 68,750]` is not a stop.
- **`scripts/takeover_check.py`**: the orchestrator committed commit `6442866` on this branch. It
  puts the three new files in `OWN_FILES` and checks `bfs.cairo` and `fixtures.cairo` in
  "additions only" mode. The CI job passes on it. I did not edit the script.
- **The facade `HexMapTrait::flood`** is the orchestrator's (`board/map.cairo`), added with the
  forwarding methods at the release. Not in this task.
- **The cave window** stays a generated 15 × 16 cave (`Caver::generate(15, 16, 3, 30)`, constant
  `CAVE_15X16`), not a window assembled from 4 chunks. The tick benchmark on an assembled window
  is M1-T9b's.

### What was done

1. **Budgets**: the 40 new tests (29 in `test_flood`, 11 in `bench_flood`) now carry
   `ceil(1.05 × measured)`, attributes included. The measurements are unchanged from those
   reported above; no new figure is above a §7 upper bound, so the stop condition was not met
   again.
2. **`crates/consumer`**: new contract `HexxFlood`, whose entry point `flood` calls
   `Bfs::flood(…).depth()`, one call site of each new public function. `FloodAssert::assert_free`
   is reached through `Bfs::flood`, as `HexxAssembly` treats `AssemblyAssert`. Its class size is
   in `gas/bytecode.size`: `HexxFlood: 3079 4486 136501 113407` (Sierra felts, CASM felts, Sierra
   bytes, CASM bytes; 5.5 % of the CASM felt limit).
3. **Regenerated**:
   - `gas/hexx.snap`: 40 rows added, none changed or removed.
   - `gas/bytecode.size`: the `HexxFlood` row.
   - `docs/GAS.md`.
   - `docs/EXTENSIONS.md`: `Bfs.flood`, `Flood`, `FloodTrait`, `Flood.depth`, `FloodAssert`,
     `FloodAssertTrait`, `FLOOD_POSITION_NOT_WALKABLE`.
   - `docs/API_PARITY.md`: regenerated, no change.
   - `gas/consumer.snap` does not exist in this repository: `crates/consumer` has no tests, and
     its snapshot is `gas/bytecode.size`.
4. **`scripts/check.sh`**: `all checks passed`. The take-over check was skipped locally (no
   origami checkout); CI runs it. The gas budgets and snapshot are OK for 1,525 tests, the
   bytecode size snapshot is OK for 5 contracts, and the docs are up to date.
5. **Pushed** (`git push -u origin HEAD`) and **opened the pull request** #41
   (`gh pr create --base main`, title `[Opus 5.5] LIB-05 M1-T9a flood`).

### Commits

`c57d5ff` (flood and tests), `43a8b1f` (benchmarks), `6442866` (orchestrator: the take-over
script), `97a3352` (budgets, consumer, snapshots, docs).

### Acceptance criteria

- **AC-1**: met. The oracle equals the layers on every case, and every R-N8-* case matches the
  plan.
- **AC-2**: met. `crates/takeover_tests` is unchanged and green; the CI move proof passes with
  `bfs.cairo` in additions-only mode.
- **AC-3**: met, with `depth()` settled by the orchestrator's decision.
- **AC-4**: met. No free function.
- **AC-5**: met. `check.sh` passes and CI is green.
- **AC-6**: met. Only allowlisted files were written (plus `REPORT.md`).

## Disposition of the orchestrator (`[Opus 5.5]`, 2026-09-29)

Audit finding 1 (minor, on the orchestrator's `scripts/takeover_check.py`): an original line kept only in a comment passed the additions-only check. Fixed before the merge: comments are removed on both sides before the comparison, with adversarial tests. The equality tests of `crates/takeover_tests` remain the proof that no result of 1.8.0 changed.
