# [Opus 5.5] LIB-05 M1-T9b — N-8: the steps of the walkers, and the tick

## Summary

**STOPPED on the stop condition.** `FloodTrait::next_step` for a walker **on the ring** measures
**121,771 L2 gas**. It was benchmarked on R-N8-5's walker `(0, 8)`, which scans 7 layers. The
upper bound of its range, derived from §7 and stated below before any measurement, is
**97,745**. As the brief and the launch prompt require, I stopped after that measurement:

- nothing was optimised or rewritten;
- no budget was set: the 36 new tests still carry the placeholder `1000000000`;
- nothing was pushed, and no pull request was opened.

Every other figure is within its range or below its lower bound, the tick on both boards included
(see *Cost*). **The tick measures 1,066,089 on the cave and 1,113,746 on the serpentine**, against
the range **[1,144,778, 1,430,973]** derived for 15 layers.

What exists now: branch `feat/lib-05-m1-t9b-steps`, one local commit `e5df8cd`, not pushed.

- **`FloodTrait::{next_step, next_step_away, distance}`** in `crates/hexx/src/finders/flood.cairo`.
  - They are additions only. `depth`, `spread`, `spread_small` and `FloodAssert` are unchanged.
  - The contract of §6.9 is implemented as written: the least layer touching the neighbourhood, the lowest free index, the fallback to layer `k + 1` (the walker's own layer), and `None` outside the board, beyond `depth` or when every candidate is blocked. `distance` infers D-26's value, and a walker may step onto an open edge source (D-32).
  - The algorithm is the §6.9 sketch:
    - Each walker's neighbourhood comes from `BfsInternal::endpoint`: the neighbour mask inside, `LayoutTrait::edge_neighbours` on the ring.
    - The layers are scanned on the limbs that hold the neighbourhood: low only, high only or both, through a private `Touch` trait.
    - The lowest set bit is found with the engine's `x & (x − 1)` step and identified by `BfsInternal::identify`.
    - `distance` is one pass: a test for layer 0, then the first layer touching the neighbourhood; its index is the number of layers popped.
    - `next_step_away` computes `around & ~blocked` once and scans downward.
  - Every helper is in `FloodInternal`, and there is no free function.
- **Tests** in `tests/test_steps.cairo` (19 tests, all passing) against a scalar oracle.
  - The oracle is neighbour by neighbour: the six board neighbours from `LayoutTrait::neighbor`, sorted, and the layers from the scalar BFS `Oracle::distances` of `test_flood`.
  - It compares all three functions on every tile of the board and on two tiles beyond it.
  - Each board runs with four `blocked` sets: none, the obstacles, a spread pattern, and everything.
  - A property check covers every step: it is adjacent, walkable, not blocked, and interior or the source.
  - Boards: 7 × 7 (5 fixtures), an 11 × 11 cave, 15 × 16 (the serpentine, R-N8 cases, the cave), a 17 × 14 cave, a 19 × 13 cave from an open edge source, and 17 × 14 with an entrance. Both limb paths are covered.
- **The tick benchmark** in `tests/bench_tick.cairo` (17 tests):
  - window from 4 chunks (`ox = oy = 7`, odd chunk row);
  - flood capped at 15 on the frozen occupancy;
  - 8 walkers in ascending id order, `blocked` updated after each move (tile left freed, tile entered occupied).
  - It runs on two windows. Each selection function is also measured alone.
- **Fixtures** (`tests/fixtures.cairo`, additions only):
  - `SERPENTINE_15X16_WALKERS`, and `SERPENTINE_15X16_CHUNKS` and `SERPENTINE_15X16_8_CHUNKS`: the 4 terrain and occupancy chunks that assemble to the serpentine window;
  - `CAVE_15X16_8`, `CAVE_15X16_WALKERS`, `CAVE_15X16_CHUNKS`, `CAVE_15X16_8_CHUNKS`: the cave tick, its eight walkers pinned from the scalar oracle.
  - Both chunk sets are checked by assembling them in a test.

The model of this session is Opus 5.5, the model the brief names.

## Ranges derived before measuring

(Written into this file before the first benchmark ran.) The tick of §7 was estimated with a flood
of 25 layers; the game caps it at 15 (D-127). I used §7's formula and unit costs, with §14
finding 44 applied: `window` at 98,862, since §14 wins over the body's 98,762.

- `window`, 4 chunks, 2 layers: **98,862**.
- Flood at `depth() = 15`: `55,000 + 19,300 × 15` = **344,500**.
- 8 × `next_step` at `s = 15`: `8 × (17,747 + 4,662 × 15)` = `8 × 87,677` = **701,416**.
- `L = 98,862 + 344,500 + 701,416` = **1,144,778**. `U = ceil(1.25 × L)` = **1,430,973**.
- **Tick range for 15 layers: [1,144,778, 1,430,973].** With the body's 98,762 it would be
  [1,144,678, 1,430,848].

| Benchmark | Range, from §7 |
|---|---:|
| `next_step`, `s = 15` | [87,677, 109,597] (§7 row) |
| `next_step`, `s = 46` (`(1, 2)` of R-N8-1) | [232,199, 290,249] (§7 row) |
| `next_step` on the ring, `s = 7`: `17,747 + 4,662 × 7 + 27,815` | **[78,196, 97,745]** (derived: §7 gives "+ 27,815 on the ring" without an instance) |
| `distance`, `s = 46` | [218,711, 273,389] (§7 row) |
| `next_step_away`, all blocked, `s = 46` (R-N8-6) | [373,047, 466,309] (§7 row) |

## Files changed

- `crates/hexx/src/finders/flood.cairo`: the three selection functions on `FloodTrait`; the helpers (`walker`, `first`, `last`, `up`, `down`, `without`, `lowest`) on `FloodInternal`; the private `Touch` trait with `Low` and `High`; two `use` lines widened; the module doc's last paragraph rewritten to describe the selection.
- `crates/hexx/src/tests.cairo`: `pub mod bench_tick;`, `pub mod test_steps;`.
- `crates/hexx/src/tests/test_steps.cairo`: new. The oracle and 19 tests.
- `crates/hexx/src/tests/bench_tick.cairo`: new. 17 benchmarks.
- `crates/hexx/src/tests/fixtures.cairo`: additions only (above).
- `REPORT.md` (ignored).

Not done, because of the stop:

- `crates/consumer` call sites, `gas/hexx.snap`, `gas/bytecode.size`;
- `docs/GAS.md`, `docs/EXTENSIONS.md`, `docs/API_PARITY.md`;
- the budgets, the push, the pull request and CI.

## Commands run

- `scripts/lock.sh scarb build -p hexx`:
  - The first build failed: `#[inline(always)]` is not allowed on a function with impl generic parameters. The scan became two `#[inline]` functions, `up` and `down`.
  - The build then finished.
- `scripts/lock.sh snforge test -p hexx test_steps`:
  - The first two runs failed on the oracle's own cost: the placeholder budget and the step limit. Its neighbour list looped over every tile of the board, so it now sorts six neighbours, precomputed per board.
  - One source of the 11 × 11 cave was a wall (`'Bfs: position not walkable'`). The test now takes the first open tile from 60.
  - No run showed a mismatch between a function and its oracle.
  - Final run: `Tests: 19 passed, 0 failed, 0 ignored, 912 filtered out`, between 1,297,532 and 626,937,270 L2 gas per test.
- `scripts/lock.sh snforge test -p hexx bench_tick`: `Tests: 17 passed, 0 failed`. The raw figures are below.
- `scarb fmt -p hexx`: applied before the commit.
- A scratch Python model of the §6.9 contract (deleted after use). It was not a measurement; it was used to:
  - reproduce every R-N8 case of the plan: R-N8-1 `45 45 46 32`; R-N8-2 `15 None None`; R-N8-3 `43 None None`; R-N8-4 moves `[36, None×3, 186, None×3]`, distances `[42, None×3, 28, None×3]`; R-N8-5 `121`; R-N8-6 `None`; R-N8-7 `21`/`22`. **The plan's figures are right**;
  - pin the cave walkers;
  - invert the assembly into the 4 chunks of each window.
- **Not run, because of the stop:**
  - `snforge test -p takeover_tests`;
  - `scripts/check.sh`, `bench.py check|snapshot`, `bytecode_size.py`, `api_parity.py`, `gas_tables.py`;
  - CI.

  No file of the engine taken over, of `assembly.cairo` or of `crates/takeover_tests` was touched (`git diff --stat origin/main..HEAD`: the five files above only).

Raw L2 gas of `bench_tick`:

```
baseline 27,350 | cave_window 91,574 | cave_flood 448,842 | cave 1,093,439
serpentine_window 91,574 | serpentine_flood 456,742 | serpentine 1,141,096
next_step_15 once 466,802 twice 548,856 | next_step_46 once 1,244,041 twice 1,432,568
next_step_ring once 1,196,871 twice 1,318,642 | distance_46 once 1,236,562 twice 1,417,710
next_step_away_46 once 1,315,686 twice 1,576,148
```

## Cost

Method (as SPK-7): the tick is the tick test minus the baseline (the opaque inputs and one
assertion). The breakdown is:

- window = window test − baseline;
- flood = (window + flood) − window;
- steps = tick − (window + flood).

Each stage ends with one assertion of the same shape, so a few hundred gas of assertion noise may
move between the components. Each selection function is measured as the test calling it twice
minus the test calling it once, on the same flood.

### The tick (flood capped at 15, 8 walkers, occupancy updated after each move)

| Benchmark | Measured | SPK-7 | Range derived from §7 | |
|---|---:|---:|---:|---|
| **Tick, cave** (window + flood + 8 steps) | **1,066,089** | 1,150,737 (flood and 8 steps, window given); 1,456,429 with assembly and the chunks' occupancy | [1,144,778, 1,430,973] | below L |
| **Tick, serpentine** | **1,113,746** | same | [1,144,778, 1,430,973] | below L |
| — window, 4 chunks, 2 layers | 64,224 (both) | 65,224 | [98,862, 123,578] (§14: 98,862) | below L |
| — flood, 15 layers, cave | 357,268 | 634,655 (capped worst case, with its target tests) | [344,500, 430,625] | in |
| — flood, 15 layers, serpentine | 365,168 | same | [344,500, 430,625] | in |
| — 8 steps, cave | 644,597 (80,575 per walker) | 516,082 (1,150,737 − 634,655) | [701,416, 876,770] (8 × `s = 15`) | below L |
| — 8 steps, serpentine | 684,354 (85,544 per walker) | same | same | below L |
| Flood and 8 steps, window given, cave / serpentine | 1,001,865 / 1,049,522 | **1,150,737** | — | 13 % / 9 % below SPK-7 |

- **The cave tick.** The walkers' inferred distances are 15, 15, 15, 14, 14, 13, 3 and 12. All eight move: 55, 42, 57, 71, 73, 86, 96, 102.
  - W2 steps onto 42 because W1 took 55 first. On the frozen occupancy alone, W2 would take 55.
  - The test asserts both, so the benchmark models the game's rule: current occupancy, updated in id order.
- **The serpentine tick** uses the pinned `SERPENTINE_15X16_8`. At the cap of 15, no walker is reached: each scans all 16 layers, gets `None` and holds its position (D-127).
- **Against SPK-7**: the flood and the 8 steps together (window given) are 9 to 13 % below SPK-7's 1,150,737.
  - The flood is cheaper than SPK-7's: 357k against 635k, which includes SPK-7's per-layer target tests.
  - The steps cost more: 645k against 516k. SPK-7 filters by the tiles moved into this tick (sparse); here `blocked` is the whole current occupancy, the rule of the contract.
  - The window is the in-memory assembly only. The ~720,000 of SPK-7 is on the node, with storage.

### Each selection function alone

| Benchmark | Measured | Range | |
|---|---:|---:|---|
| `next_step`, `s = 15` (cave, W1 → 55) | 82,054 | [87,677, 109,597] | below L |
| `next_step`, `s = 46` (`(1, 2)` of R-N8-1 → 32) | 188,527 | [232,199, 290,249] | below L |
| **`next_step` on the ring, `s = 7`** (R-N8-5, `(0, 8)` → 121) | **121,771** | **[78,196, 97,745]** | **ABOVE U: STOP** |
| `distance`, `s = 46` (`(1, 2)` → 46) | 181,148 | [218,711, 273,389] | below L |
| `next_step_away`, all blocked, 46 layers (R-N8-6 → `None`) | 260,462 | [373,047, 466,309] | below L |
| Per layer scanned by `next_step`, `(188,527 − 82,054) / 31` | 3,435 | 4,662 (sketch) | below |

**What explains the overrun.** These figures are inferred from the measurements above, not
isolated by a benchmark of their own:

- At 3,435 per layer, an interior `next_step` at `s = 7` would cost about `82,054 − 8 × 3,435 ≈ 54,574`.
- The ring walker therefore pays about **67,200** more than an interior one, where §7 charges +27,815: `edge_neighbours` at 30,378 replacing `neighbour_mask` at 2,563.
- The extra is `LayoutTrait::edge_neighbours`, taken over unchanged from 1.8.0 and reached through `BfsInternal::endpoint`. It loops over the 6 directions and calls `LayoutTrait::neighbor` for each: a `u8` `DivRem`, a parity `%`, and a `match` with bounds checks. It then adds `Bits::pow` of each neighbour.
- §7's 30,378 for it is itself an estimate: "as a standalone call", `6 × (neighbor 3,696 + lookup 1,269 + addition 98)`.
- Only walkers on the ring pay it. §7's tick assumes none (condition 3), and neither tick here has one.

What I would try (not done): a direct ring neighbour mask. It would be the interior mask cleared of the off-board offsets by the walker's column and row, with no per-direction loop. The alternative is to accept the measurement as the ring's figure.

## Deviations

- **The flood's signature** is `Bfs::flood(grid, width, height, from, obstacles, depth)`, from M1-T9a. The selection functions are methods on `Flood`, as in §6.9.
- **The serpentine tick** uses the plan's `SERPENTINE_15X16_8` at the cap of 15, so no walker is reached. This follows the brief ("the serpentine"; the pinned eight-walker fixture) and D-127. The steps of that tick are eight full scans without a move.
- **The cave tick** uses `CAVE_15X16`, the generated window of M1-T9a (16 layers from `(7, 8)`), as the window. Its 4 chunks were obtained by inverting the assembly at `Origin { cx: 3, cy: 5, ox: 7, oy: 7 }`: the tiles of the chunks outside the window are wall. So it is "a cave assembled from 4 chunks" in cost and in result (`window(chunks) == CAVE_15X16` is asserted), but not 4 chunks generated independently. Chunks generated independently would need openings in their rings to join (D-134), which N-1 and N-2 (not yet done) provide.
- **Cave walkers**: the plan says "at distances 3 to 15". Their distances are 15, 15, 15, 14, 14, 13, 3 and 12: one at 3, the rest as far as the board allows, and one move that depends on an earlier one.
- **`next_step_away` returns `None` early** when `around & ~blocked` is empty. This is sound: there is then no candidate in any layer. The worst case, R-N8-6, still scans all 46 layers, because its neighbourhood holds wall tiles that are not blocked.

## Escalations

1. **Stop condition: `next_step` on the ring measures 121,771 L2 gas, above 97,745**, the upper bound of the range I derived from §7 (`17,747 + 4,662 × 7 + 27,815`, uplift 1.25) for R-N8-5's walker at `s = 7`. The breakdown and the options are under *Cost*. Nothing was optimised, and no budget was set.
2. **`scripts/takeover_check.py`** must list `src/tests/test_steps.cairo` and `src/tests/bench_tick.cairo` in `OWN_FILES`. `flood.cairo` is already there, and `fixtures.cairo` is checked in additions-only mode. The script is not in my allowlist.
3. **`scripts/tests/test_bench_gate.py`**: the hard-coded count of `hexx` tests will move by +36, if it still exists as in M1-T4a's report.

## Open questions

- Should the ring walker's `next_step` be made cheaper? That would mean a direct ring neighbour mask in `flood.cairo`: `edge_neighbours` itself is taken over and out of scope. Or should the measurement replace the §7 target, as for `FloodTrait::depth` in M1-T9a? §7's tick excludes walkers on the ring. In the game, a goblin on the window's ring is frozen: SPK-7 says "goblins there are frozen, and the flood never enters the ring".
- Once decided, what remains is:
  - the budgets (`ceil(1.05 × measured)`);
  - the `crates/consumer` call sites (`HexxFlood`: `next_step`, `next_step_away`, `distance`);
  - `gas/hexx.snap`, `gas/bytecode.size`, `docs/GAS.md`, `docs/EXTENSIONS.md`, `docs/API_PARITY.md`;
  - `takeover_tests`, `scripts/check.sh`, the push, the pull request and CI.

## Follow-up 1

**Pull request: https://github.com/bal7hazar/hexx-cairo/pull/43. CI green: all 14 checks pass**
(run 36603356620) on the first run, including "Take-over of origami_hexmap is a move", "Gas hexx"
and "Build and test takeover_tests". No re-run was needed, so D-154 did not come up.

### Decision of the orchestrator, recorded

The ring measurement (121,771) is **not** accepted as the target. A goblin at the edge of the
window is an ordinary case of the game. The ring walker had to be made cheap inside
`finders/flood.cairo` only, leaving `LayoutTrait::edge_neighbours` unchanged. The orchestrator
committed `510264f` on this branch: the two test files in `OWN_FILES` of
`scripts/takeover_check.py`. I did not edit that script.

### The change

`FloodInternal::walker` no longer calls `BfsInternal::endpoint`, whose ring branch is the
per-direction loop of `edge_neighbours`. It builds the `Endpoint` itself:

- one `DivRem` by `2W` gives the column, the row and the row parity;
- a walker's neighbour bits are `2^i × offsets` for every tile;
- inside, the offsets are the engine's precomputed `around_odd` / `around_even`;
- on the ring, `FloodInternal::edge` sums the offsets whose tile is on the board:
  - `2^-1` if `x > 0`, and `2` if `x < W − 1`;
  - `2^-W · r` if `y > 0`, and `2^W · r` if `y < H − 1`;
  - where `r` is the pair of columns of the next row: `1 + 2` on an odd row (`{x, x + 1}`, the `+ 2` only if `x < W − 1`), and `2^-1 + 1` on an even row (`{x − 1, x}`, the `2^-1` only if `x > 0`).

Every kept offset is a bit of the board, so the product is exact. There is no loop and no table:
one field product and at most four additions. The inner product is the same field sum as the
engine's, so an interior walker's result is unchanged.

### The proof

`test_steps`, 5 new tests and one more tick test:

- `test_steps_ring_neighbourhoods`: on every tile of 3 × 3, 7 × 7, 11 × 11, 8 × 16, 15 × 15, 15 × 16, 17 × 14 and 19 × 13, the walker's neighbour bits equal `LayoutTrait::edge_neighbours` (the taken-over reference), and its column, row and parity are correct. This covers both limb paths, both row parities, odd and even heights and every corner. The tile `W × H` gives `None`.
- `test_steps_ring_corners`: the four corners of 15 × 16 by hand (`0 → {1, 15}`, `14 → {13, 28, 29}`, `225 → {210, 211, 226}`, `239 → {224, 238}`), with their steps on an open board.
- `test_steps_ring_open_7x7_11x11`, `_15x16`, `_19x13`: the full oracle sweep on boards where every tile is open, the ring included. Every ring walker then touches a layer, and every step and distance is compared, with 4 `blocked` sets.
- `test_steps_tick_cave_ring`: the cave tick with W8 on the ring (below).
- All 25 tests of `test_steps` pass.

### Ring figures, before and after

| Benchmark | Before | After | Range §7 |
|---|---:|---:|---:|
| `next_step` on the ring, `s = 7` (R-N8-5, `(0, 8)` → 121) | 121,771 | **64,771** | [78,196, 97,745]: below L |
| `next_step`, `s = 15` (interior) | 82,054 | 80,144 | [87,677, 109,597]: below L |
| `next_step`, `s = 46` (interior) | 188,527 | 186,617 | [232,199, 290,249]: below L |
| `distance`, `s = 46` | 181,148 | 179,338 | [218,711, 273,389]: below L |
| `next_step_away`, all blocked, 46 layers | 260,462 | 258,552 | [373,047, 466,309]: below L |

- **The ring now costs about 12,100 more than an interior walker** at the same depth, against about 67,200 before. The interior estimate at `s = 7` is `80,144 − 8 × 3,434 ≈ 52,670`, inferred from the per-layer cost `(186,617 − 80,144) / 31 = 3,435`; it is not a separate benchmark.
- Every interior figure moved down by 1,810 to 1,910. `walker` now builds the `Endpoint` without the engine's branch into `edge_neighbours`.
- No figure is above its range, so the stop condition did not apply again.

### The tick, again

The baseline of `bench_tick` is now 30,250, against 27,350 before: the inputs gained one window.
The differences are unaffected.

| Benchmark | Measured | SPK-7 | Range derived from §7 |
|---|---:|---:|---:|
| **Tick, cave** | **1,050,809** (was 1,066,089) | flood and 8 steps 1,150,737 | [1,144,778, 1,430,973]: below L |
| **Tick, cave, W8 on the ring** (`(14, 4)`, at 13, steps onto 88) | **1,055,612** | | same: below L |
| **Tick, serpentine** | **1,098,466** (was 1,113,746) | | same: below L |
| — window (all three) | 64,224 | 65,224 | [98,862, 123,578] |
| — flood, cave / cave with W8 on the ring / serpentine | 357,268 / 357,268 / 365,168 | 634,655 | [344,500, 430,625] |
| — 8 steps, cave / cave with W8 on the ring / serpentine | 629,317 / 634,120 / 669,074 | 516,082 | [701,416, 876,770] |

- The ring walker variant replaces W8 `(12, 5)` at 12 with `(14, 4)`, the deepest ring tile the cave offers, at 13. Its steps cost 4,803 more than the cave's: about one more layer plus the ring's ~12k, less the interior walker's cost. **It does not change the picture.**
- Eight walkers on the ring would add about `8 × 12,100 ≈ 97,000` over interior walkers at the same depths (inferred), and the tick would stay below the lower bound.
- The ring variant's fixtures are in `fixtures.cairo`: `CAVE_15X16_RING`, `CAVE_15X16_RING_WALKERS`, `CAVE_15X16_RING_CHUNKS`. Its flood equals the cave's, because the walker sits on the ring, which is never flooded.

### The rest of the task

1. **Budgets**: the 44 new tests (25 in `test_steps`, 19 in `bench_tick`) carry `ceil(1.05 × measured)` in their attributes.
2. **`crates/consumer`**: `HexxFlood` gained the entry points `next_step`, `next_step_away` and `distance`, one call site each. `gas/bytecode.size`: `HexxFlood` is 5,737 Sierra felts and 10,717 CASM felts (13.1 % of the CASM limit), 287,048 / 241,063 bytes (7.0 %).
3. **Regenerated**:
   - `gas/hexx.snap`: 44 rows added, none changed or removed;
   - `docs/GAS.md`;
   - `docs/EXTENSIONS.md`: `Flood.next_step`, `Flood.next_step_away`, `Flood.distance`;
   - `docs/API_PARITY.md` and `docs/DEVIATIONS.md`: regenerated, no change.
4. **`scripts/check.sh`**: exit 0, `all checks passed`:
   - hexx `836 passed, 0 failed, 103 ignored`;
   - takeover_tests `630 passed`;
   - `gas budgets and snapshot OK (1569 tests)`;
   - `bytecode size snapshot OK (5 contracts)`;
   - every generated document up to date.
   - The take-over check was skipped locally (no origami checkout), and CI's "Take-over of origami_hexmap is a move" passes.
5. **Pushed** with `git push -u origin HEAD`, and **opened** #43 with `gh pr create --base main`, titled `[Opus 5.5] LIB-05 M1-T9b steps and tick`.

### Commits

- `e5df8cd`: the functions and tests.
- `510264f`: the orchestrator's `OWN_FILES` change.
- `8b14dc3`: the ring neighbourhood, its proof, and the ring tick.
- `196fa1f`: the budgets, the consumer, the snapshots and the docs.

### Housekeeping

- My scratch files (a Python model under `tmp/t9b/`, and the measurement outputs, budget script and PR body under `target/`) were deleted, each by name. The empty directories `tmp/t9b` and `tmp` were removed with `rmdir`.
- A recursive `rm -r` of the scratch directory was refused by the permissions, so I removed the file by name instead.

### Acceptance criteria

- **AC-1**: met. Every oracle equals its function on every tile of every fixture and `blocked` set, the open rings included. Every R-N8-* case passes with the plan's expected output.
- **AC-2**: met. The tick is measured on both boards, and on the cave with a ring walker, with its breakdown, compared with SPK-7 and with the range derived before measuring.
- **AC-3**: met. `crates/takeover_tests` is untouched and green (630). The move proof passes in CI.
- **AC-4**: met. The functions are scoped (`FloodTrait`, `FloodInternal`, the private `Touch` trait). There is no free function; the one new free item is the constant `INV_2`.
- **AC-5**: met. `scripts/check.sh` passes and CI is green.
- **AC-6**: met. Only allowlisted files were written, plus `REPORT.md` and my deleted scratch files. `510264f` is the orchestrator's.

## Fix loop 1

**STOPPED on the stop condition.** With D-127 enforced in the tick caller, as the orchestrator
decided, the cave tick measures **1,566,922 L2 gas** and the cave tick with a walker on the ring
**1,576,528**. Both are above **1,430,973**, the upper bound of the tick range I derived for 15
layers before the first measurement. As required:

- nothing was optimised;
- no budget was set: `bench_tick_cave` and `bench_tick_cave_ring` still carry their old budgets and fail on them;
- `gas/hexx.snap` and `docs/GAS.md` were not regenerated;
- `scripts/check.sh` was not run;
- nothing was pushed: the fix is the local commit `ea5866f` on top of `196fa1f`, and PR #43 is unchanged on GitHub.

### The finding, and the fix

Audit pass 1, finding 1 (major): the tick moved a walker at inferred distance 16 that touches
layer 15, where D-127 says a goblin the flood did not reach holds its position. The orchestrator
decided that the selection contract stays as it is and that the tick models the game's rule. The
fix follows that decision:

- **`bench_tick.cairo`**:
  - `Tick::steps` takes the cap. For each walker in id order it reads `flood.distance(walker)` and calls `next_step` only when the distance is `Some(d)` with `d ≤ cap`. Otherwise the walker holds its position and never calls `next_step`.
  - The module doc now says that the cap is the caller's rule, and why: `next_step` answers for the layers the flood has.
- **`test_steps.cairo`**:
  - `Steps::tick` takes the cap and applies the same rule. It checks each `distance` against the oracle, as it already did each step.
  - The capped ticks (cave, cave with the ring walker, serpentine) pass 15. R-N8-4 passes 255: its flood is not truncated, as the plan pins it.
  - `test_steps_beyond_the_cap` keeps its assertions: they are the library's contract. A comment now says the game's tick holds that walker.
- **The auditor's regressions**, on `SERPENTINE_15X16`, source 127, cap 15, the walkers in id order `[first, 31, 32, 33, 34, 181, 182, 183]`, all frozen as obstacles:
  - `test_steps_tick_cap_16_holds`: `first = 95`, `(5, 6)`. `distance(95) = Some(16)` and `next_step(95, occupied) = Some(96)`, since the library's contract is unchanged. The tick's moves are eight `None`: W1 holds.
  - `test_steps_tick_cap_15_moves`: `first = 96`, `(6, 6)`. `distance(96) = Some(15)`, and the tick moves W1 to 97, `(7, 6)`, in layer 14. The others hold.
  - Both pass.
- `cap_walkers` is a method of the `Steps` test impl, not a free function (D-143).

### Measurements

The baseline is 30,250. `bench_tick_cave` and `bench_tick_cave_ring` exceed their old budgets, so
their figures are the consumption snforge reports for the failed runs ("Test cost exceeded the
available gas. Consumed … l2_gas: ~1597172" and "~1606778"). Every other test passed.

| Tick | Before (follow-up 1) | After (fix loop 1) | Range derived from §7 | |
|---|---:|---:|---:|---|
| Cave | 1,050,809 | **1,566,922** | [1,144,778, 1,430,973] | **ABOVE U: STOP** |
| Cave, W8 on the ring | 1,055,612 | **1,576,528** | same | **ABOVE U: STOP** |
| Serpentine | 1,098,466 | 1,097,866 | same | below L |

| Breakdown | Cave | Cave, ring | Serpentine |
|---|---:|---:|---:|
| Window | 64,224 | 64,224 | 64,224 |
| Flood, 15 layers | 357,268 | 357,268 | 365,168 |
| 8 walkers, before | 629,317 | 634,120 | 669,074 |
| 8 walkers, after | **1,145,430** | **1,155,036** | 668,474 |

**What explains the overrun.** The breakdown is inferred from measurements, not isolated by a new benchmark:

- **The cave**: every walker is reached, so each one now pays a `distance` scan before its `next_step` scan, and the flood's layers are scanned twice per walker.
  - `distance` costs about `179,338 − 3,435 × (46 − s)` at `s` layers: the measured `distance` at 46 and the measured cost per layer.
  - For the eight walkers at 15, 15, 15, 14, 14, 13, 3 and 12 (101 layers), that sums to `8 × 179,338 − 3,435 × (368 − 101) ≈ 517,600`.
  - The measured increase is `1,145,430 − 629,317 = 516,113`.
- **The serpentine does not move**: no walker is reached, so `distance` (16 scans, `None`) replaces `next_step` (16 scans, `None`) for each of them.
- §7's tick has no `distance` call per walker. The range was derived for `window + flood + 8 × next_step`.

**Other figures.** Every selection function alone is unchanged, and still below its lower bound:
`next_step` 80,144 / 186,617, ring 64,771, `distance` 179,338, `next_step_away` 258,552.

### Options (not done)

1. **One scan per walker** (a change of the library's contract, the orchestrator's call): `next_step` could take the cap, returning `None` when the least layer touching the neighbourhood is at or above `cap`. Or a variant could return the step together with the walker's inferred distance. Either would restore the tick to about the follow-up 1 figures (~1.05M), plus a comparison per walker.
2. **A flood capped at 14 layers**, with `next_step` alone: a walker's inferred distance is at most 15 exactly when it touches a layer at most 14. But the fallback to the walker's own layer 15 would then be missing for a walker at 15 whose layer-14 candidates are all blocked. So this is not equivalent to D-127 with the fallback: it changes moves, which are numeric API.
3. **Accept the measurement** as the tick's figure (~1.57M on the cave), with the range re-derived for `window + flood + 8 × (distance + next_step)`.

### Escalation

The tick exceeds the upper bound of its range once D-127 is enforced by the caller through
`distance`, as decided. Which of the options above applies, or another, is the orchestrator's
decision. When decided, what remains is:

- the budgets of `bench_tick_cave`, `bench_tick_cave_ring`, `bench_tick_serpentine` and of the changed and new tests of `test_steps` (`test_steps_tick_*`, `test_steps_r_n8_4`);
- `gas/hexx.snap` and `docs/GAS.md`;
- `scripts/check.sh`, the push and CI.

## Fix loop 2

**STOPPED on an ambiguity (COMMON §1, "ambiguity stops you"), before any code change.**

- No file was changed in this loop, and nothing was committed, pushed or measured.
- The branch is as fix loop 1 left it: `ea5866f` is local, unpushed, and holds the caller-side `distance` check. PR #43 on GitHub is at `196fa1f`.

### The decision, and the point it leaves open

Decision of the orchestrator (fix loop 2): `next_step` and `next_step_away` return `None` for a
walker whose inferred distance is greater than "the flood's `depth`", decided in the same scan.
The walker is reached if and only if the lowest layer of its neighbours is below `depth`.
`distance` is unchanged. The decision cites D-25 (§12): "The flood is computed to `depth` layers
and gives no move to a walker beyond them".

"`depth`" can be read two ways. They give different results on floods that were not truncated:

**(A) `FloodTrait::depth()`, the layers actually computed.** This can be implemented in `flood.cairo` in the same scan (`None` when the least layer touched is `depth()`). But it breaks two of the plan's normative regression cases, both with `depth = 182` and no truncation:

- **R-N8-1**: `(1, 2)` is inferred at 46 and `depth()` is 45. Its least layer touched is 45 = `depth()`, so `next_step((1, 2), 0)` becomes `None`. The plan pins `Some(32)`.
- **R-N8-4**: W1 `(5, 2)` is inferred at 42 and `depth()` is 41. Its least layer touched is 41 = `depth()`, so it becomes `None`. The plan pins `Some(36)`, and calls this case "the frozen-occupancy rule as the project manager decided it". W5, inferred at 28, is unaffected.

The flood of R-N8-4 ends at layer 41 only because W1, frozen, closes the corridor. Under (A), the walker that closes the flood is never reached, at any depth: the lead goblin of a corridor would be stuck for good. That is not D-25's "beyond `depth` layers" when `depth = 182`.

**(B) The `depth` requested from `Bfs::flood`, which is D-25's.** A walker is reached if and only if `least layer + 1 ≤ depth` (the parameter).

- R-N8-1 and R-N8-4 keep their moves.
- The capped cases behave as the auditor asks. With `depth = 15` the flood is truncated, `depth() = 15`, and a walker at 16 gets `None` while a walker at 15 moves.
- It needs one piece of information the `Flood` does not hold: the requested `depth`, or equivalently whether the flood was truncated (`depth() == depth`). Given that, the rule is `least layer < depth` when the flood was truncated and always true otherwise: one comparison in the same scan, as the decision asks.
- Storing it means a field on `Flood` set by `Bfs::flood`, one line in `finders/bfs.cairo`. That line is in the entry point added by M1-T9a, not a line of `origami_hexmap`, so the move proof in additions-only mode would still pass.
- But `bfs.cairo` is not in this task's allowlist. The only other place the requested depth passes through is `FloodInternal::spread` / `spread_small`, existing functions of `flood.cairo` whose behaviour the brief excludes changing, and they only return layers. I found no way to obtain it inside `flood.cairo` without changing what the layers hold.

The two readings agree on every truncated flood, and so on every regression the auditor asked
for. They differ only when the flood ends before `depth`.

### Question to the orchestrator

1. **Which reading holds?**
   - (A) `depth()`: then R-N8-1 and R-N8-4 change (the arithmetic above), and the plan's pinned moves are overridden.
   - (B) the requested `depth`: then may the task add a field to `Flood` (for example `depth: u8`, the requested depth, or `truncated: bool`), set in `Bfs::flood` in `finders/bfs.cairo`? That widens the allowlist by that one line and the struct field.
2. Once decided, the work is as the decision lists:
   - revert the caller-side `distance` of `ea5866f`;
   - the contract docs of `next_step` and `next_step_away`;
   - the updated tests (`test_steps_beyond_the_cap`, and R-N8-1 / R-N8-4 under (A));
   - the regression pairs at 15 and 16 for `next_step`, `next_step_away` and a ring walker;
   - the re-measurement of the three ticks and the changed tests, the budgets, `gas/hexx.snap`, `docs/GAS.md`, `scripts/check.sh`, the push and CI.

### Fix loop 2, carried out (follow-up 4: reading B)

**Done, pushed (`28ee1d4`), PR #43 updated. CI: 13 of 14 checks green.** "Gas consumer" failed on
a class-size drift of `HexxGenerators`, a contract this change does not touch (below), and so did
the "All checks passed" summary that follows from it. Re-running the job
(`gh run rerun 36609917335 --failed`, then `--job 109548400787`) needs an approval that was not
given. A re-run is needed from the orchestrator.

#### What changed

- **`finders/bfs.cairo`** (allowlist widened by the orchestrator for this line only): `Bfs::flood` builds `Flood { width, height, cap: depth, layers }`. That line is in the entry point M1-T9a added; no line of `origami_hexmap` changed, and "Take-over of origami_hexmap is a move" passes in CI.
- **`finders/flood.cairo`**:
  - `Flood.cap: u8` (`pub(crate)`) is the `depth` requested from `Bfs::flood`.
  - Two helpers on `FloodInternal`: `capped` (the last layer is at the cap: `layers.len() == cap + 1`) and `source` (the walker stands on layer 0). `distance` now calls `source` for its layer-0 test; its results are unchanged.
  - **`next_step`**: the scan is unchanged. When the least layer touched is the last one and the flood is capped, the walker's inferred distance is `cap + 1`: `None`. The source is the one exception, reached at 0. This costs one length comparison after the scan.
  - **`next_step_away`**: when the flood is capped, the last layer is tested first. A free neighbour there is the step only if the walker is reached: it touches a lower layer (scanned downward from the next layer) or it is the source. Otherwise the downward scan continues as before, and any free neighbour found below the cap means the walker is reached.
  - Both contract docs state the rule and D-25.
  - A walker in no layer beyond the cap still gets its `distance` (`cap + 1`), unchanged, as decided.
- **`tests/bench_tick.cairo`**: the caller-side `distance` check of `ea5866f` is undone by hand, since `git revert` needed an approval. `Tick::steps` calls `next_step` alone again, and a walker that gets `None` holds. The module doc says the cap is the flood's (D-25).
- **`tests/test_steps.cairo`**:
  - The oracle's `Board` carries `cap`, the requested depth. `Steps::next_step` and `Steps::next_step_away` return `None` when `Steps::distance > cap`. `Steps::tick` calls `next_step` alone again.
  - **Tests changed**:
    - `test_steps_beyond_the_cap`: `(5, 6)` at 16 now gets `None` towards and away; `(6, 6)`, in layer 15, still moves. On a flood of depth 0, the source's neighbours, at 1, get `None`. On depth 1 they step onto the source, and the source itself steps to `(6, 8)` (the source exception), with a sweep.
    - `test_steps_tick_cap_16_holds`: `next_step(95, occupied)` is now `None`.
  - **R-N8-1 and R-N8-4 are unchanged and pass**: the moves `Some(32)`, `Some(36)` and `Some(186)` on their uncapped floods (requested depth 182).
  - **Regression pairs**, all on `SERPENTINE_15X16`, source 127, walkers `[first, 31, 32, 33, 34, 181, 182, 183]` frozen as obstacles:

    | Case | Test | At the cap | Cap + 1 |
    |---|---|---|---|
    | `next_step` | `test_steps_tick_cap_15_moves` / `_16_holds` | `(6, 6)` at 15 moves to 97 | `(5, 6)` at 16 holds |
    | `next_step_away` | `test_steps_cap_away` | `(6, 6)` at 15 kites to 97 | `(5, 6)` at 16 gets `None`, blocked or not |
    | a walker on the ring | `test_steps_cap_ring` | `(0, 6)` at 21 with the cap 21: towards, away and the tick give 91 | with the cap 20 it holds (`next_step`, `next_step_away` and the tick) |

    `test_steps_cap_away` also runs a full oracle check on both of its floods.
- All 29 tests of `test_steps` pass, every sweep against the updated oracle included.

#### Measurements (stop condition checked: nothing above its upper bound)

| Tick | Follow-up 1 | Fix loop 1 (caller `distance`) | **Fix loop 2** | Range derived from §7 |
|---|---:|---:|---:|---:|
| Cave | 1,050,809 | 1,566,922 | **1,064,209** | [1,144,778, 1,430,973]: below L |
| Cave, W8 on the ring | 1,055,612 | 1,576,528 | **1,069,012** | same: below L |
| Serpentine | 1,098,466 | 1,097,866 | **1,106,666** | same: below L |

Breakdown after fix loop 2 (baseline 30,250):

| | Cave | Cave, ring | Serpentine |
|---|---:|---:|---:|
| Window | 64,224 | 64,224 | 64,224 |
| Flood, 15 layers | 357,368 | 357,368 | 365,268 |
| 8 walkers | 642,617 | 647,420 | 677,174 |

- The flood costs 100 more than before: the new field. The steps cost about 1,650 more per walker on the cave (13,300 over 8): the check after the scan. The cave's walkers all move (distances 3 to 15, at most the cap). The serpentine's all hold, now also by the library's rule.

Selection functions alone (twice − once):

| Benchmark | Follow-up 1 | **Fix loop 2** | Range |
|---|---:|---:|---:|
| `next_step`, `s = 15` | 80,144 | **81,794** | [87,677, 109,597]: below L |
| `next_step`, `s = 46` (uncapped) | 186,617 | **189,017** | [232,199, 290,249]: below L |
| `next_step` on the ring, `s = 7` | 64,771 | **66,421** | [78,196, 97,745]: below L |
| `distance`, `s = 46` | 179,338 | **179,638** | [218,711, 273,389]: below L |
| `next_step_away`, all blocked, 46 layers | 258,552 | **260,802** | [373,047, 466,309]: below L |

#### Budgets, snapshots, checks

- Every test of `test_steps` (29) and `bench_tick` (19) was re-measured from a placeholder budget and set at `ceil(1.05 × measured)` in its attribute.
- The tests of `test_flood` and `bench_flood` measure 100 to 18,000 more (one field per flood built). Their budgets hold that, so they were left.
- Regenerated:
  - `gas/hexx.snap`: 79 rows changed, 4 added. The changes are in `test_steps`, `bench_tick`, `test_flood` and `bench_flood` only.
  - `gas/bytecode.size`: `HexxFlood` is 6,968 Sierra felts and 11,630 CASM felts (14.2 %).
  - `docs/GAS.md`.
- **`scripts/check.sh`**: exit 0, `all checks passed`:
  - hexx `840 passed, 0 failed, 103 ignored` (`test_steps_r_n8_4` included);
  - takeover_tests `630 passed`;
  - `gas budgets and snapshot OK (1573 tests)`;
  - `bytecode size snapshot OK (5 contracts)`;
  - docs up to date.
- My scratch files under `target/` were deleted by name.

#### CI (run 36609917335)

- **Green**:
  - Build and test hexx, takeover_tests and consumer;
  - Gas hexx, Gas hexx (ignored tests), Gas takeover_tests;
  - Format and parity/deviations/gas docs;
  - Golden vectors, Package rehearsal, Markdown links, Shell scripts;
  - Take-over of origami_hexmap is a move.
- **Red: Gas consumer** (and "All checks passed"):
  - `HexxGenerators: {'sierra_felts': 27092, 'casm_felts': 49375, 'sierra_bytes': 1395788, 'casm_bytes': 997126} -> {'sierra_felts': 27101, 'casm_felts': 49375, 'sierra_bytes': 1396211, 'casm_bytes': 997304}`;
  - `bytecode size mismatch (1)`.
- Evidence that this is compile drift, not this change:
  - `HexxGenerators` calls no flood function. It calls `Digger` (`open_with_corridor`, `open_with_maze`), the code of D-154's known drift. Its CASM felt count is identical, and only 9 Sierra felts and 178 CASM bytes differ.
  - Locally, `python3 scripts/bytecode_size.py check` on the same commit gives 27,092 twice (in `check.sh`, then alone): `bytecode size snapshot OK (5 contracts)`.
  - `origin/main` has not moved since the branch point (`git log HEAD..origin/main` is empty), so the merge ref CI builds holds the same sources.
  - PR #43's previous run, at `196fa1f`, measured 27,092 in CI.
- D-154 names a gas-only mismatch on a test reaching `Digger::dig` and says to re-run once. This is the same kind of drift, in the class size of the contract that holds `Digger`. I could not re-run: `gh run rerun` needs an approval that was not given. I did not push a commit only to trigger CI, since that would work around the refusal. **Needed from the orchestrator: a re-run of the "Gas consumer" job of run 36609917335.** If it fails again, the snapshot of `HexxGenerators` differs between CI and this machine, which is a question for `scripts/bytecode_size.py` (the orchestrator's).

## Decisions of the orchestrator (`[Opus 5.5]`, 2026-09-29)

- `next_step` on the ring (121,771 against [78,196, 97,745]) was **not** accepted: a goblin at
  the edge of the window is an ordinary case of the game. Replaced by a computation without the
  per-direction loop, inside `flood.cairo`; the helper taken over is unchanged (66,421 at the end).
- The game's rule D-127 (a goblin the capped flood did not reach holds) is held **by the library**,
  as decision D-25 of the plan says: `next_step` and `next_step_away` return `None` for a walker
  whose inferred distance is greater than the cap given to `Bfs::flood`, stored in `Flood`. A first
  fix on the caller's side doubled the scans (tick 1.57M) and was reverted.
- One CI run failed on the class size of `HexxGenerators` (27,101 against 27,092 Sierra felts):
  the compile drift of D-154, re-run once, recorded.
