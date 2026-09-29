# [Opus 5.5] LIB-05 M1-T1b — Take-over of the engine: the proof of equality

## Summary

`crates/takeover_tests` now proves in CI that every public function of the engine in `hexx`
returns the same value as the published `origami_hexmap` 1.8.0 (scarbs.xyz, lock checksum
`sha256:789ecf7b…`) on the same inputs, and panics with the same message where 1.8.0 panics.
This is layer 2 of plan §5.4.

- **Result: no difference found.** All 532 tests pass. That covers 96 panic pairs and the gas
  comparison, where all 20 facade functions cost exactly the same through both libraries.
- One module per engine module (`map`, `direction`, `layout`, `geometry`, `asserter`, `bits`,
  `rng`, `bfs`, `dial`, `caver`, `digger`, `mazer`, `spreader`, `walker`), plus:
  - `common`: the seeded inputs and the comparisons.
  - `fixtures`: the 1.8.0 fixture values with their source lines, and the 32 generated boards.
  - `gas`: Scope 5.
- Each test calls `origami_hexmap::…` and `hexx::…` on the same input and compares the whole
  result: grid, `Span<u8>`, `Option`, tuple, `u256`, or `HexMap` / `Layout` / `Dilation` /
  `Rng` field by field. Directions are compared through a `match` written in the tests, not
  through either library's `Into`.
- `crates/hexx/` is unchanged. `takeover_check.py` still reports 29 pairs `same`.
- Pull request: https://github.com/bal7hazar/hexx-cairo/pull/34. CI is green on every job; the
  longest is the gas job at 7m34s.
- Model of this session: Opus 5.5, the same as the brief names.

### AC-1: function → test → number of inputs

Notation used in the table:

- **Seeds**: 64 seeds (`common::generator_seed`, tag `'gen'`).
- **Dims**: the 9 dimensions `3x3`, `7x7`, `15x15`, `15x16`, `17x14`, `19x13`, `25x10`, `83x3`,
  `3x83`.
- **Boards**: the 10 fixtures of 1.8.0 plus 32 generated boards, 42 in all. 8 are `15x16`; 13
  have open edge entrances.
- **E**: 585 endpoint pairs over the 42 boards. Per board: 12 seeded pairs, `from == to` once,
  and each entrance paired both ways with a seeded tile and with the next entrance.
- **S**: 265 flood sources over the 42 boards: 6 seeded tiles per board plus every entrance.
- **Q**: 1,073 query positions (every position of a `7x7`, plus 512 seeded positions each of a
  `17x14` and a `15x16`).
- **P**: 3,425 query pairs (every pair of the `7x7`, plus 512 seeded pairs each of the `17x14`
  and the `15x16`).
- **R**: the 9 radii or budgets `[0, 1, 2, 3, 4, 6, 9, 14, 40]`.
- **Dims\***: all 675 valid dimensions.

| 1.8.0 item | Test(s) | Inputs |
|---|---|---|
| `HexMapTrait::new` | `map::test_map_new` | 42 boards + 2 boundary maps |
| `new_empty` | `map::test_map_new_empty` | 675 (every valid dimension) |
| `new_maze` | `map::test_map_new_maze_<dims>[_k]` | 64 seeds × 9 dims × orders 0–1 = 1,152 |
| `new_cave` | `map::test_map_new_cave_<dims>` | 64 × 9 × orders 0–5 = 3,456 |
| `new_random_walk` | `map::test_map_new_random_walk_<dims>` | 64 × 9 × 10 step counts = 5,760 |
| `new_hexagon` | `map::test_map_new_hexagon` | radii 0–6 × 64 = 448 |
| `open_with_corridor` / `open_with_maze` | `map::test_map_open_with_{corridor,maze}_<dims>` | 64 × 9 × orders 0–1 = 1,152 each |
| `keep_component` | `map::test_map_keep_component_<dims>`, `…_boards_{fixtures,boards}` | up to 576 seeded grids + S (265) |
| `compute_distribution` | `map::test_map_compute_distribution_<dims>`, `…_boards_*` | 1,152 + 42 × 9 = 1,530 |
| `search_path` | `map::test_map_search_path_*`, `test_map_fixture_endpoints` | E + 20 = 605 |
| `search_path_weighted` | `map::test_map_search_path_weighted_*`, `test_map_fixture_endpoints` | E + 20 × 4 = 665, 0 to 3 cost classes |
| `field_of_movement` | `map::test_map_field_of_movement_*` | S × R = 2,385, 0 to 3 classes |
| `distance_to` | `map::test_map_distance_to_*`, `test_map_fixture_endpoints` | 605 |
| `hex_distance` | `map::test_map_hex_distance` | P = 3,425 |
| `reachable` | `map::test_map_reachable_*` | S = 265 |
| `range` / `ring` | `map::test_map_range_*` / `test_map_ring_*` | S × R = 2,385 each |
| `neighbor` | `map::test_map_neighbor` | (Q + 241 positions outside the board) × 6 = 7,884 |
| `is_walkable` | `map::test_map_is_walkable` | 42 boards × positions 0–255 = 10,752 |
| `Direction`, `DIRECTION_COUNT`, `DIRECTION_SIZE` | `direction::test_direction_constants` | — |
| `DirectionTrait::opposite` | `direction::test_direction_opposite` | 6 |
| `DirectionTrait::next` | `direction::test_direction_next` | Q × 6, where the neighbour lies in the board (its domain) |
| `DirectionTrait::pop_front` | `direction::test_direction_pop_front` | 720 permutations × 6 pops + 258 `u32` × 8 pops |
| `DirectionIntoU8` / `U8TryIntoDirection` | `test_direction_into_u8` / `test_direction_try_into` | 6 / 256 |
| `Bfs::search` / `distance` | `bfs::test_bfs_{search,distance}_*`, `test_bfs_fixture_endpoints` | 605 each |
| `Bfs::reachable` | `bfs::test_bfs_reachable_*` | 265 |
| `Bfs::tiles_within_range` | `bfs::test_bfs_tiles_within_range_*` | 2,385 |
| `Dial::search` | `dial::test_dial_search_*`, `test_dial_fixture_endpoints` | 665 |
| `Dial::field_of_movement` | `dial::test_dial_field_of_movement_*` | 2,385 |
| `Caver::generate` | `caver::test_caver_generate_<dims>` | 3,456 |
| `Caver::keep_component` | `caver::test_caver_keep_component_<dims>` | up to 576; a grid with no floor tile has no input |
| `Digger::maze` / `corridor` | `digger::test_digger_{maze,corridor}_<dims>` | 1,152 each; start is a seeded side tile, grid is a cave or a walk |
| `Mazer::generate` | `mazer::test_mazer_generate_order_{0,1}_<dims>` | 1,152 |
| `Spreader::generate` | `spreader::test_spreader_generate_*` | 1,530 |
| `Walker::generate` | `walker::test_walker_generate_<dims>` | 5,760 |
| `Layout`, `LayoutTrait::{new, board, even, interior, with_interior, dilation}` | `layout::test_layout_*` | 675 each |
| `LayoutTrait::hexagon` | `layout::test_layout_hexagon` | radii 0–6 |
| `expand` / `DilationTrait::dilate` | `test_layout_expand` / `test_dilation_dilate` | 9 dims × 34 frontiers |
| `expand_small` (both traits) | `test_layout_expand_small` / `test_dilation_expand_small` | 8 boards of ≤ 128 tiles × 34 frontiers |
| `edge_neighbours` / `neighbour_in` / `neighbour_mask` | `test_layout_{edge_neighbours,neighbour_in,neighbour_mask}` | Q / Q × 2 sets / interior positions of Q |
| `index` / `coords` / `parity` / `neighbor` | `test_layout_{index,coords,parity,neighbor}` | Q / Q / Q / Q × 6 |
| `Geometry::to_axial` / `distance` | `geometry::test_geometry_*` | Q / P |
| `Bits` (18 functions) | `bits::test_bits_*` | 256 seeded values plus 0, 1, `2^128−1`, `2^128`, `2^250`, reduced to each domain; `get` at every index 0–251; `pow`/`inv` at 0–251 |
| `Set`, `WideSet`, `SmallSet` | `test_bits_wide_set`, `test_bits_small_set` | 261 values / 523 limbs, 9 methods each |
| `TWO_POW_128`, `TWO_POW_32`, `TWO_POW_64`, `BYTES_ONE`, `TWO_POW_120`, `POW`, `INV`, `POW128` | `test_bits_constants`, `test_bits_tables` | every index |
| `Rng`, `RngTrait` (9 functions) | `rng::test_rng_*` | 64 seeds × 32 draws, generator compared after every call; `mix` 265 pairs; `split216` 261 pools; `refill` 64 × 8 |
| `PERMUTATIONS` | `rng::test_rng_permutations` | 720 |
| `MAX_SIZE`, `Asserter` (6 functions), `errors` | `asserter::test_asserter_*` | Q; the 675 valid dimensions; 630 side tiles |
| Every `errors` constant | `*_errors` / `*_constants` | — |

**Functions without a test: none.** `u252` is dropped and `HexPrinter` is out, as the brief
says. I also checked the list against every item of `docs/EXTENSIONS.md` and found none missing.

### AC-2: panics

There are 96 `#[should_panic(expected: …)]` pairs: one test per side, same input, same message.
They are the last section of `asserter`, `bfs`, `dial`, `caver`, `digger`, `mazer`, `spreader`,
`walker` and `map`. They cover:

- Every row of § Panics in the README of 1.8.0, through the facade (49 pairs in `map`).
- Every `errors` constant through its own module. That includes `Caver: position not floor`,
  `Spreader: invalid grid` on both limb paths (`7x7` and `17x14`), and `Dial: too many costs`.

A changed message fails the test on that side. `snforge` checks `expected`.

### Liveness of the comparisons

I did **not** change a line of the engine to check this. `crates/hexx/` is outside the
allowlist, and the profile refused the `sed -i` (see *Escalations*). Instead I checked from
inside the allowlist that the comparisons are live: I passed `radius + 1` to the `hexx` side of
`check_ring` only. All 4 ring tests then failed with `'ring'`. I reverted the change before any
commit.

## Files changed

- `crates/takeover_tests/Scarb.toml`: `hexx = { path = "../hexx" }` added. It was not there;
  see *Deviations*.
- `crates/takeover_tests/src/lib.cairo`: module list; the placeholder test is removed.
- `crates/takeover_tests/src/common.cairo`: seeded inputs (Poseidon of a tag and an index
  written in the tests), dimensions, endpoints, sources, costs, comparisons.
- `crates/takeover_tests/src/fixtures.cairo`: fixture values of 1.8.0
  (`src/tests/fixtures.cairo:25…215` at `04ab30c`), their 20 endpoints, and the 32 generated
  boards with their recipes. `test_boards_provenance` regenerates the boards through
  `origami_hexmap`.
- `crates/takeover_tests/src/{map,direction,layout,geometry,asserter,bits,rng,bfs,dial,caver,digger,mazer,spreader,walker}.cairo`:
  the equality tests and the panic pairs.
- `crates/takeover_tests/src/gas.cairo`: Scope 5, 80 tests.
- `Scarb.lock`: `takeover_tests` now depends on `hexx`.
- `gas/takeover_tests.snap`: regenerated. `docs/GAS.md`: regenerated.
- `REPORT.md`: this file, ignored by git.

## Commands run

- `scripts/lock.sh snforge test -p takeover_tests`
  - Final run: `Tests: 532 passed, 0 failed, 0 ignored, 0 filtered out`, real 1m05s locally.
  - The first version had 617 tests and ran in 1m24s.
- `python3 scripts/bench.py snapshot`: exit 0. Only `gas/takeover_tests.snap` changed.
- `python3 scripts/gas_tables.py`: `wrote docs/GAS.md`. `--check`: `docs/GAS.md is up to date`.
- `scripts/check.sh`: exit 0, real 7m38s. The relevant lines:
  ```
  takeover_tests: declared 532, collected 532, with a gas row 532, ignored 0
  29 pairs, 0 problem(s)
  all checks passed
  ```
  `bench.py check` runs inside it. The package has no test in `gas/takeover-baseline.txt`,
  which was not touched.
- `scarb fmt --check --workspace`: ok.
- `git diff --stat origin/main -- crates/hexx`: empty.
- `gh pr checks 34 --watch --interval 30`: every job passes. Durations:

  | Job | Duration |
  |---|---:|
  | Build and test hexx | 7m04s |
  | Build and test takeover_tests | 2m22s |
  | Gas budgets and class size | 7m34s |
  | Take-over of origami_hexmap is a move | 14s |
  | Everything else | ≤ 21s |

## Cost

**Tests:** 532 in total, broken down as:
- 259 equality tests;
- 96 panic pairs (192 tests);
- 80 gas-comparison tests;
- 1 provenance test.

Their measured total is 41.4 B l2 gas. The heaviest is `layout::test_layout_neighbour_in` at
490,564,114. Every other test is at most about 409 M: the seeds and boards of a heavy function
are split over several tests, and each test's doc comment states its range. Every test carries
`#[available_gas(l2_gas: ceil(1.05 × measured))]`.

**Time:**
- Locally, `snforge test -p takeover_tests` takes 1m05s including the build (8 vCPU).
- In CI:
  - the package's own job takes 2m22s (build 64 s, 532 tests 61 s);
  - its share of the serial gas job is 1m28s;
  - the gas job takes 7m34s in all.
- Every job is under 10 minutes, so no split of the CI job was needed and `ci.yml` is
  untouched.

**Scope 5: gas of the 20 facade functions, `origami_hexmap` 1.8.0 against `hexx`.** Taken from
`gas/takeover_tests.snap`; "call" is twice minus once.

| Function | origami once | origami twice | origami call | hexx once | hexx twice | hexx call | difference |
|---|---:|---:|---:|---:|---:|---:|---:|
| `new` | 270,390 | 270,590 | 200 | 270,390 | 270,590 | 200 | 0 |
| `new_empty` | 277,970 | 284,530 | 6,560 | 277,970 | 284,530 | 6,560 | 0 |
| `new_maze` | 3,196,573 | 6,124,376 | 2,927,803 | 3,196,573 | 6,124,376 | 2,927,803 | 0 |
| `new_cave` | 404,387 | 539,904 | 135,517 | 404,387 | 539,904 | 135,517 | 0 |
| `new_random_walk` | 2,631,957 | 4,994,844 | 2,362,887 | 2,631,957 | 4,994,844 | 2,362,887 | 0 |
| `new_hexagon` | 412,830 | 554,550 | 141,720 | 412,830 | 554,550 | 141,720 | 0 |
| `open_with_corridor` | 341,698 | 412,086 | 70,388 | 341,698 | 412,086 | 70,388 | 0 |
| `open_with_maze` | 341,698 | 412,086 | 70,388 | 341,698 | 412,086 | 70,388 | 0 |
| `keep_component` | 728,525 | 1,188,080 | 459,555 | 728,525 | 1,188,080 | 459,555 | 0 |
| `compute_distribution` | 405,708 | 542,446 | 136,738 | 405,708 | 542,446 | 136,738 | 0 |
| `search_path` | 997,235 | 1,725,500 | 728,265 | 997,235 | 1,725,500 | 728,265 | 0 |
| `search_path_weighted` | 1,766,919 | 3,264,168 | 1,497,249 | 1,766,919 | 3,264,168 | 1,497,249 | 0 |
| `field_of_movement` | 549,989 | 830,308 | 280,319 | 549,989 | 830,308 | 280,319 | 0 |
| `distance_to` | 794,642 | 1,318,074 | 523,432 | 794,642 | 1,318,074 | 523,432 | 0 |
| `hex_distance` | 282,490 | 293,870 | 11,380 | 282,490 | 293,870 | 11,380 | 0 |
| `reachable` | 728,525 | 1,188,080 | 459,555 | 728,525 | 1,188,080 | 459,555 | 0 |
| `range` | 387,413 | 505,856 | 118,443 | 387,413 | 505,856 | 118,443 | 0 |
| `ring` | 385,193 | 501,516 | 116,323 | 385,193 | 501,516 | 116,323 | 0 |
| `neighbor` | 278,870 | 286,630 | 7,760 | 278,870 | 286,630 | 7,760 | 0 |
| `is_walkable` | 278,803 | 286,196 | 7,393 | 278,803 | 286,196 | 7,393 | 0 |

**Differences: none.** The inputs and their caveats:

- The input is `CAVE_17X14` with:
  - endpoints 52 → 20;
  - tile 191;
  - side tile 8, order 0;
  - two cost classes;
  - `'seed'`.
- Every value goes through an `#[inline(never)]` identity, so nothing is constant-folded.
- Each result is checked against an impossible value, so no call is dropped. That check is
  inside the difference, the same on both sides.
- Each test's baseline includes a fixed loop of 200 iterations in `board()`, which cancels in
  the difference (see *Deviations* 4).
- **Caveat:** `open_with_corridor` and `open_with_maze` both measure 70,388. The side tile 8
  lies next to a floor tile of that cave, so both take the early exit of `Digger::dig`. The
  comparison holds, but that figure is not the cost of a long dig.
- Commands: `python3 scripts/bench.py snapshot`, then the table above computed from
  `gas/takeover_tests.snap` (`test_gas_<fn>_<side>_{once,twice}`).

## Deviations

1. **`hexx` was not yet a dependency of `crates/takeover_tests`.** The brief (*Context*) says
   the package "already depends … on `hexx` by path"; its `Scarb.toml` only had
   `origami_hexmap`. I added `hexx = { path = "../hexx" }` (inside the allowlist), and
   `Scarb.lock` changed accordingly.
2. **Several tests per heavy function.** `snforge test` runs with its default step limit in
   CI and in `check.sh`. The first attempt exceeded it at about 1 B l2 gas ("RunResources has
   no remaining steps"). So the 64 seeds of a heavy generator, or the boards of a heavy finder,
   are split over 2 to 4 tests of at most about 409 M.
3. **The walker has no order.** "Every `order` … up to 5" applies to `Caver` (0–5), `Mazer`
   and `Digger` (0–1). For `Walker` / `new_random_walk` I chose the step counts
   `[0, 1, 2, 3, 17, 18, 19, 37, 72, 250]`. They cover each remainder of its blocks of 3 and
   of 18 moves, two permutations, and seven.
   - The first push also had 1,000 steps. That was three quarters of the walker's cost and
     pushed the CI gas job to 9m37s of its 10 minutes, so I removed it.
4. **Padding in the gas comparison.** With the budget rule, a gas test of one cheap call
   (`neighbor`, about 22,000 gas) failed: the static pre-charge of its costliest branch
   exceeds 5 % of its measurement. `gas.cairo`'s `board()` therefore burns a fixed loop of 200
   iterations. It is charged per iteration and cancels in twice − once.
5. **Two inputs that are not literally the brief's.**
   - The 32 generated boards are built by `origami_hexmap` 1.8.0 from written recipes and seeds,
     then written as constants, with `test_boards_provenance` regenerating them. This is so the
     finder tests do not regenerate them each time.
   - `keep_component` and `Caver::keep_component` skip a seed whose input grid has no floor
     tile. That can happen on `3x3`. I did not count those skips.
6. **The British-spelt helpers.** `edge_neighbours`, `neighbour_in` and `neighbour_mask` are
   tested under their 1.8.0 names on both sides. The rename task must point the `hexx` side of
   `layout.cairo`'s three tests at the new names.
7. **Scaffolding not committed.** The repetitive test stubs (per dimension, per seed range),
   the panic pairs, `gas.cairo` and the budgets were written by throwaway scripts in my
   `tmp/`. The committed Cairo is self-contained, and I deleted `tmp/` at the end.

## Escalations

1. **The CI gas job is close to its timeout, independent of this package.**
   - `bench.py check` runs every package serially in one job with a 10-minute timeout.
   - On `main` before this task it took 6m20s. With this PR it takes 7m34s; the first push
     took 9m37s.
   - The `hexx` part alone varies between runs: 7m25s and 5m47s in this PR's two runs, taken
     from the job logs' timestamps.
   - Splitting that job per package, or raising its timeout, touches `scripts/bench.py` and
     the `gas` job of `ci.yml`. Neither is in my allowlist: the brief allows `ci.yml` only to
     split this package's own test job, which stays at 2m22s.
2. **`#[available_gas]` itself adds about 900 gas to a test.** Measured without the attribute,
   the `asserter` panic tests show 14,620 and `test_bits_constants` 14,220. With the attribute
   they show 15,520 and 15,120, whatever the budget's value (checked with 15,351 and 16,296).
   - So `N = ceil(1.05 × measured)` only holds when "measured" is taken with the attribute in
     place.
   - I set every budget in two passes (without, then with), and `bench.py check` accepts them.
   - The rule's text in `COMMON.md` §4 and `bench.py` does not say this. Both belong to the
     orchestrator.
3. **I did not run an engine mutation myself.** A deliberate one-line change of `crates/hexx`
   is what the auditor will do. Doing it here, even temporarily, would write outside the
   allowlist, and the profile refused the `sed -i`. The liveness check under *Summary* stands
   in for it.

## Open questions

- Should the scaffolding scripts (stub generation per dimension and seed range, budget setting
  from an `snforge` log) be kept in the repository, under `scripts/` (owned by the
  orchestrator), for the later tasks that must keep this package green? The committed tests do
  not need them.
- Would the orchestrator want a wider seed or board range for the heavy finders when the gas
  job is split? The package's own CI job has about 7 minutes of headroom.

## Fix loop 1

This loop answers the audit `sources/audits/M1-T1b-audit-gpt-6-astra-pass-1.md` (`[GPT-6-Astra]`,
FAIL on finding 1). I verified each finding before fixing it.

- Commits on the same branch and pull request (#34): `06c99fa` (the tests) and `a105c02` (the
  gas snapshot and `docs/GAS.md`).
- `crates/hexx/` is unchanged.
- **CI is green on every job.** The longest is the gas job at 7m54s.

### Finding → change → file

| # | Verified | Change | File |
|---|---|---|---|
| 1 (major) | **Confirmed.** Decoding the 32 generated boards gives 19 with no entrance and 13 with exactly one, so every "entrance, next entrance" pair was `(e, e)`. | See *Finding 1* below. | `fixtures.cairo`, `common.cairo`, `bfs.cairo`, `dial.cairo`, `map.cairo` |
| 2 (minor) | **Confirmed by running.** Probe tests with a wrong `expected` printed the actual panic data on both libraries: radius 127 gives `[0x75385f616464204f766572666c6f77] (u8_add Overflow)`, radius 128 gives `[0x75385f6d756c204f766572666c6f77] (u8_mul Overflow)`. | Two pairs, `test_map_new_hexagon_revert_radius_{127,128}_{origami,hexx}`, with those messages. | `map.cairo` |
| 3 (minor) | **Confirmed.** `new` had 64 seeds plus 0 and `-1`; `mix` had the boundaries 0, 1, `-1`. | See *Finding 3* below. | `rng.cairo` |
| 4 (minor) | **Confirmed.** No Spreader input had 128 tiles, and the small-board invalid-grid pair set bit 49. | See *Finding 4* below. | `spreader.cairo`, `map.cairo` |
| 5 (minor) | **Confirmed: my figure of 15,120 was wrong.** It was inferred, not measured. | Measured again; see *Finding 5* below. | `REPORT.md` only (the budgets were already right) |
| 6 (note) | **Confirmed.** `result \|\| !result` and `len() != 255` could not fail. | See *Finding 6* below. | `gas.cairo` |
| Walker comment | **Confirmed.** The step counts cover the remainders 0, 1, 2, 3, 16 and 17 modulo 18, and every remainder modulo 3; I checked this in Python. | Comment corrected. | `walker.cairo` |

#### Finding 1

- **15 new boards with several entrances** (`fixtures::ENTRANCE_BOARDS`), written as fixed
  values.
  - **9 written by hand.** Each is an interior mask of 1.8.0, or a 1.8.0 fixture, plus the listed
    edge tiles. `test_entrance_boards_provenance_hand` rebuilds them.
  - **6 generated by 1.8.0** with 2 to 4 corridors or maze openings (`generate_entrances`).
    `test_entrance_boards_provenance_generated` regenerates them.
- **Coverage of the new boards:**
  - Single-limb path (at most 128 tiles): `7x7` ×3, `16x8` and `8x16` (exactly 128 tiles each),
    `11x11` (corrected in fix loop 2: `8x16` was listed under two limbs).
  - Two limbs: `17x14` ×2, `15x16` ×5, `19x13`, `25x10`.
  - The 15 boards together have 2 to 6 entrances each.
  - Adjacent entrances: tiles 1 and 2, and 7 and 14 of a `7x7`; 2 and 3 of the `8x16`; 1 and 2
    of the `17x14` and of the `15x16`.
  - Entrances joined through the interior: every board.
  - Entrances in disconnected components: `ENTRANCES_7X7_SPLIT`, `ENTRANCES_8X16_SPLIT`,
    `ENTRANCES_15X16_SPLIT`, and the generated raw cave.
- **The endpoints are now three separate sets:**
  - `common::endpoints`: 12 seeded pairs, plus each entrance paired both ways with a seeded
    tile.
  - `common::identical_endpoints`: `from == to`. These are kept as their own tests:
    `test_bfs_identical_endpoints`, `test_dial_identical_endpoints`,
    `test_map_identical_endpoints`, on all 57 boards.
  - `common::entrance_pairs`: every ordered pair of distinct entrances.
- **New tests compare, on every entrance board:**
  - complete paths (`Bfs::search`, `Dial::search`, `search_path`, `search_path_weighted`) between
    every ordered pair of distinct entrances and on the seeded endpoints;
  - distances (`Bfs::distance`, `distance_to`) on the same pairs;
  - floods from every entrance and 6 seeded sources: `Bfs::reachable`,
    `Bfs::tiles_within_range`, `reachable`, `keep_component`, `range`, `ring` at every radius,
    and `Dial::field_of_movement` / `field_of_movement` at every budget.
- **The auditor's scenario** is pinned in `bfs::test_bfs_audit_scenario` and
  `map::test_map_audit_scenario`: `EMPTY_7X7` plus tiles 1 and 43, from 1 to 43. 1.8.0 returns
  `[43, 36, 29, 22, 15, 8]` (read from a run) and `distance` is `Some`. The test asserts the
  path is non-empty, equals `hexx`'s, and equals that value.
- **Would the auditor's mutation now fail a test?** The mutation is
  `if !start.interior && !target.interior { return array![].span(); }` added to `Bfs::search`.
  By reasoning, yes: under it, `H::search` returns `[]` wherever 1.8.0 returns a path between
  two entrances. The tests that fail:
  - `bfs::test_bfs_audit_scenario` fails on `'search'`: `[]` against `[43, 36, 29, 22, 15, 8]`.
  - `bfs::test_bfs_search_entrances_hand` and `…_generated` fail on `'search'` at the first
    joined pair of distinct entrances. A run with a temporary counter showed, per board: `7x7`:
    2, 12 and 4 joined pairs; `16x8` (128 tiles, single-limb path): 20; `8x16`: 8; `17x14`: 20;
    `15x16`: 30 and 4; `19x13`: 6. The generated boards have 6, 6, 12, 2, 6 and 4 joined pairs.
    So the mutation fails on both limb paths and on the `15x16`.
  - Through the facade, which forwards to `Bfs::search`: `map::test_map_audit_scenario` and
    `map::test_map_paths_entrances_*` fail on `'search_path'`.
  - Every one of these tests also asserts that its range contains at least one joined pair of
    distinct entrances. The hand-made search test asserts at least one separated pair too
    (disconnected components: 8, 12, 8 and 8 pairs on the split boards).
  - As in the first round, I did not modify `crates/hexx`.

#### Finding 3

- `test_rng_new`: 256 seeded values and the boundaries 0, 1, `2^128 − 1`, `2^128`, `2^250`, `−1`.
- `test_rng_mix`: 256 seeded pairs and all 36 pairs of those boundaries.
- New `test_rng_pool_boundaries`: starts generators from pools at the boundaries of the `u128`
  domain. The brief's boundaries are adapted to that domain as 0, 1 and `2^128 − 1`, because
  `2^128` and `2^250` are not `u128`; `2^64 − 1` and `2^64` are added on each side of the refill
  threshold.
  - 262 states: seed `k` with the pool of index `k % 5`, one pool per seed (corrected in fix
    loop 2: this line said the pools were crossed with the seeds).
  - From each state it calls once each of `draw`, `draw6`, `draw_byte`, `next_below`,
    `shuffle6` and `refill`, and compares the returned value and the generator.
- `test_rng_split216`: its documentation now states the same adaptation.

#### Finding 4

- `test_spreader_generate_128_tiles` and `test_map_compute_distribution_128_tiles` run on `16x8`
  and `8x16`.
  - Masks: empty (count 0), the full 128 tiles, the interior, and 8 caves.
  - Counts per mask: 0, the full count, and 8 seeded counts.
- Panic pairs on a grid with bit 128 set, rejected through its high limb, with `Spreader:
  invalid grid`, both directly and through the facade:
  - a `7x7` (`…_revert_small_bit_128_*`);
  - a `16x8` (`…_revert_128_tiles_bit_128_*`).
- If `size == 128 ||` were removed, the 16x8 full-mask case would index `POW128` at 128, and
  `test_spreader_generate_128_tiles` would fail on both sides. That is reasoning, not a run.

#### Finding 5

- **Correction:** my first report said `#[available_gas]` adds "about 900 gas", and that
  `test_bits_constants` measures 15,120 with the attribute. The 15,120 was inferred, not
  measured, and it was wrong.
- **What the measurement shows**, comparing the same 586 committed tests:
  - Run 1: `scripts/lock.sh snforge test -p takeover_tests` on the tests as committed, attribute
    included.
  - Run 2: the same command after deleting every `#[available_gas]` line. The files were then
    restored with `git checkout`, and `git status` was clean.

  | Change with the attribute | Tests | Of which `should_panic` | Example (without → with) |
  |---|---:|---:|---|
  | none | 369 | — | — |
  | −100 | 48 | 0 | `bfs::test_bfs_audit_scenario` 1,023,370 → 1,023,270 |
  | +100 | 6 | 0 | `asserter::test_asserter_constants` 13,620 → 13,720 |
  | +900 | 120 | 120 | `asserter::test_asserter_corner_hexx` 14,620 → 15,520 |
  | +920 | 26 | 24 | `digger::test_digger_corridor_revert_corner_hexx` 17,260 → 18,180 |
  | +1,120 | 2 | 0 | `gas::test_gas_distance_to_hexx_once` 793,422 → 794,542 |
  | +1,230 | 2 | 0 | `direction::test_direction_pop_front` 50,925,432 → 50,926,662 |
  | +1,320 | 11 | 0 | `bfs::test_bfs_search_entrances_generated` 206,408,656 → 206,409,976 |
  | +1,440 | 2 | 0 | `bits::test_bits_limb_functions` 21,534,056 → 21,535,496 |

  So the attribute changes the measurement of 217 tests out of 586, by amounts from −100 to
  +1,440, and leaves 369 unchanged. That is **not** a fixed surcharge.
- **The value of the budget does not change the measurement.** Two runs of the committed tests
  that differ only in their budget values (passes B and C) gave identical figures for all 586
  tests.
- **The rule, as applied:** the measurement is taken on the test as committed, attribute
  included, and `N = ceil(1.05 × that measurement)`.
  - Every budget of the package was set that way. A first pass gave each new test an attribute;
    a second pass measured with it and set the final budgets; a third confirmed.
  - `bench.py check`, run inside `scripts/check.sh`, accepts all 586.

#### Finding 6

- Every gas test now checks its result against the value the equality tests establish for both
  libraries. The `EXPECTED_*` constants were read from 1.8.0 by a probe run: the grid, the
  bitmap, the whole path, the `Option`, the `u8`, the `bool`. A wrong result fails the check.
- The module documentation, and this report, now say that the figures are **the marginal costs of
  the measured call sites**, argument helpers and result check included.
- `open_with_corridor_long` and `open_with_maze_long` measure a long dig beside the early exit:
  side tile 8 of a `17x14` whose only open tile is 202. The corridor adds 58 tiles and the
  maze 89, against 1 for the early exit (corrected in fix loop 2: their grids hold 59 and 90
  open tiles against 1; this line said 57 and 88).

**Scope 5, updated** (`gas/takeover_tests.snap`; "call" is twice − once). There is still **no
difference on any of the 22 call sites.** `search_path`, `search_path_weighted`, `distance_to`,
`hex_distance`, `neighbor` and `is_walkable` moved by a few hundred gas against the first round
because their checks changed. They moved the same amount on both sides.

| Call site | origami once | origami twice | origami call | hexx once | hexx twice | hexx call | difference |
|---|---:|---:|---:|---:|---:|---:|---:|
| `new` | 270,390 | 270,590 | 200 | 270,390 | 270,590 | 200 | 0 |
| `new_empty` | 277,970 | 284,530 | 6,560 | 277,970 | 284,530 | 6,560 | 0 |
| `new_maze` | 3,196,573 | 6,124,376 | 2,927,803 | 3,196,573 | 6,124,376 | 2,927,803 | 0 |
| `new_cave` | 404,387 | 539,904 | 135,517 | 404,387 | 539,904 | 135,517 | 0 |
| `new_random_walk` | 2,631,957 | 4,994,844 | 2,362,887 | 2,631,957 | 4,994,844 | 2,362,887 | 0 |
| `new_hexagon` | 412,830 | 554,550 | 141,720 | 412,830 | 554,550 | 141,720 | 0 |
| `open_with_corridor` | 341,698 | 412,086 | 70,388 | 341,698 | 412,086 | 70,388 | 0 |
| `open_with_corridor_long` | 2,267,584 | 4,263,858 | 1,996,274 | 2,267,584 | 4,263,858 | 1,996,274 | 0 |
| `open_with_maze` | 341,698 | 412,086 | 70,388 | 341,698 | 412,086 | 70,388 | 0 |
| `open_with_maze_long` | 3,514,081 | 6,756,852 | 3,242,771 | 3,514,081 | 6,756,852 | 3,242,771 | 0 |
| `keep_component` | 728,525 | 1,188,080 | 459,555 | 728,525 | 1,188,080 | 459,555 | 0 |
| `compute_distribution` | 405,708 | 542,446 | 136,738 | 405,708 | 542,446 | 136,738 | 0 |
| `search_path` | 1,051,405 | 1,831,200 | 779,795 | 1,051,405 | 1,831,200 | 779,795 | 0 |
| `search_path_weighted` | 1,821,089 | 3,369,868 | 1,548,779 | 1,821,089 | 3,369,868 | 1,548,779 | 0 |
| `field_of_movement` | 549,989 | 830,308 | 280,319 | 549,989 | 830,308 | 280,319 | 0 |
| `distance_to` | 794,542 | 1,317,874 | 523,332 | 794,542 | 1,317,874 | 523,332 | 0 |
| `hex_distance` | 282,590 | 294,070 | 11,480 | 282,590 | 294,070 | 11,480 | 0 |
| `reachable` | 728,525 | 1,188,080 | 459,555 | 728,525 | 1,188,080 | 459,555 | 0 |
| `range` | 387,413 | 505,856 | 118,443 | 387,413 | 505,856 | 118,443 | 0 |
| `ring` | 385,193 | 501,516 | 116,323 | 385,193 | 501,516 | 116,323 | 0 |
| `neighbor` | 278,770 | 286,430 | 7,660 | 278,770 | 286,430 | 7,660 | 0 |
| `is_walkable` | 279,003 | 286,596 | 7,593 | 279,003 | 286,596 | 7,593 | 0 |

### Commands run (fix loop 1)

- Finding 2 probes, `scripts/lock.sh snforge test -p takeover_tests probe_hexagon` with
  `expected: 'probe'`: four `[FAIL]` results, printing the actual data quoted above (removed
  afterwards).
- Budget passes, `scripts/lock.sh snforge test -p takeover_tests`, run three times: each gave
  `Tests: 586 passed, 0 failed, 0 ignored, 0 filtered out`. Comparing passes B and C:
  `tests in both: 586; identical: 586`. Heaviest test: `layout::test_layout_neighbour_in` at
  490,564,114; every test is at most that.
  - The first version of the facade entrance tests reached 835 M. I split them by board range to
    stay clear of the step limit.
- The attribute experiment of finding 5: the same command without the attributes gave
  `Tests: 586 passed`, and the comparison is the table above.
- `python3 scripts/bench.py snapshot`: exit 0. `python3 scripts/gas_tables.py`:
  `wrote docs/GAS.md`.
- `scripts/check.sh`: exit 0, real 13m20s:
  ```
  takeover_tests: declared 586, collected 586, with a gas row 586, ignored 0
  29 pairs, 0 problem(s)
  all checks passed
  ```
- `gh pr checks 34 --watch --interval 30`: every job passes. Durations:

  | Job | Duration |
  |---|---:|
  | Build and test hexx | 7m05s |
  | Build and test takeover_tests | 2m48s (build 68 s, 586 tests 87 s) |
  | Gas budgets and class size | **7m54s** (`hexx` 5m54s, `takeover_tests` 1m44s) |
  | Take-over of origami_hexmap is a move | 14s |
  | Everything else | ≤ 18s |

  Every job is under 10 minutes.
- Locally, `snforge test -p takeover_tests` took between 1m23s and 2m21s real across the passes;
  the machine is shared.

### Cost (fix loop 1)

- **586 tests:** 291 equality tests, 102 panic pairs (204 tests), 88 gas tests (22 call sites ×
  2 libraries × once/twice), and 3 provenance tests.
- The measured total is 49.5 B l2 gas.

### What I dispute

Nothing in the findings. Two points of detail:

- **Finding 5:** the auditor is right that 15,120 was not measured. The measurement also shows
  that the attribute does change some measurements (by −100 to +1,440, on 217 tests), which the
  audit allowed as "plausible". The committed budgets were correct in both rounds, because each
  was set from a measurement with the attribute present.
- **Audit counts:** the audit reports 500 `Caver::keep_component` comparisons and 765 through the
  facade, from a scalar reconstruction; my first report left these uncounted. I have not
  recounted them.

### Deviations (fix loop 1)

- Finding 5 asked me to "measure again on the final tests". To compare, I also ran the same
  tests with the attributes removed. That was a temporary edit inside the allowlist, restored
  from git and never committed.
- The heavy facade and Dial entrance tests are split by board range (`…_hand_0` to `…_hand_2`,
  `…_generated_0`, `…_generated_1`), as the other heavy families already were.
- The scaffolding (stub, budget and gas-module generators, the comparison script) was written
  again in my `tmp/`, which is not committed and was deleted at the end of this loop.


## Fix loop 2

This loop answers the audit `sources/audits/M1-T1b-audit-gpt-6-astra-pass-2.md` (`[GPT-6-Astra]`,
FAIL on finding 7). The six findings of pass 1 are closed by the audit. I verified findings 7
and 8 before fixing them, and I dispute neither.

- Commits on the same branch and pull request (#34):
  - `3a99161`: the tests and comments.
  - `8584d8d`: the gas snapshot and `docs/GAS.md`.
  - `b77667f`: an empty commit that re-ran CI (see *CI*).
- `crates/hexx/` is unchanged (`git diff --stat origin/main -- crates/hexx` is empty).
- **CI is green on every job.** The longest is `Build and test hexx` at 7m06s; the gas job took
  6m56s.

### Finding → change → file

| # | Verified | Change | File |
|---|---|---|---|
| 7 (major) | **Confirmed, by running.** `Bfs::reachable(6, 15, 16, 1)` returns 6 on both libraries. The mutation `let near = next;` survived the corpus of loop 1: it was mutant B31 of the table below, killed only by the witness test I added first. Its twin in `tiles_within_range` (B37 on one limb, B38 on two) survived outright. | See *Finding 7* below. | `fixtures.cairo`, `common.cairo`, `bfs.cairo`, `dial.cairo`, `map.cairo` |
| 8 (minor) | **Confirmed.** `8x16` has 128 tiles, so it runs on the single-limb path. The RNG pool test has 262 states, one pool per seed. The long digs add 58 and 89 tiles (their grids hold 59 and 90 tiles against 1). There are five `15x16` entrance boards. | The fixtures comment on the limb paths and the `15x16` count; the comment of `test_rng_pool_boundaries` (262 states, one pool per seed); the gas module documentation (tiles added by each dig); and the three lines of `REPORT.md` (Fix loop 1), each marked "corrected in fix loop 2". | `fixtures.cairo`, `rng.cairo`, `gas.cairo`, `REPORT.md` |

#### Finding 7

- **The witness is pinned:** `bfs::test_bfs_reachable_audit_witness` asserts
  `O::reachable(6, 15, 16, 1) == 6` and equality with `hexx`.
- **12 fixed boards of adjacent open edge tiles** (`fixtures::EDGE_BOARDS`).
  `test_edge_boards_provenance` rebuilds them from their tiles.
  - Two per size: `7x7`, `16x8` and `8x16` on the single-limb path (at most 128 tiles);
    `15x16`, `17x14` and `19x13` on the two-limb path.
  - Each has the open edge tiles 1, 2, 3 (a chain: 1–2 and 2–3 adjacent), an adjacent pair on
    each side, an adjacent pair on the top, and an isolated edge tile.
  - In the first board of a size no interior tile is open, so the adjacent edge tiles have **no
    interior connection**.
  - The second adds an interior pocket that touches tiles 2, 3 and the left side pair. There the
    edges are joined both directly and through the interior.
- **Every function the orchestrator named is compared** on these boards, one test per size and
  family (both limb paths, and `15x16`):
  - From every open tile: `Bfs::reachable` and `Bfs::tiles_within_range` (every radius of
    `common::RADII`), in `bfs::test_bfs_floods_edges_<size>`.
  - Between every ordered pair of distinct open tiles: `Bfs::search` and `Bfs::distance`, in
    `bfs::test_bfs_paths_edges_<size>`.
  - `Dial::search` between every pair, and `Dial::field_of_movement` from every tile at every
    budget, with 0 to 3 cost classes: `dial::test_dial_search_edges_<size>` and
    `dial::test_dial_field_of_movement_edges_<size>`.
  - Through the facade:
    - `reachable`, `keep_component`, `range`, `ring`: `map::test_map_floods_edges_<size>`;
    - `search_path`, `distance_to`, `search_path_weighted`: `map::test_map_paths_edges_<size>`;
    - `field_of_movement`: `map::test_map_field_of_movement_edges_<size>`.
- **The semantics are pinned too:** `check_floods_edges` asserts `O::reachable(grid, W, H, 1) == 6`
  on all 12 boards. That is `{1, 2}`: tile 1 reaches the adjacent tile 2 directly and does not
  cross it to 3.
- **Result:** B31 (`let near = next;`) is now killed by 13 tests: the six `bfs` flood tests, the
  six `map` flood tests and the witness. B37 is killed by exactly the six single-limb flood tests;
  B38 by exactly the six two-limb ones.

### The systematic table (the deliverable of this loop)

I read `finders/bfs.cairo` and `finders/dial.cairo` in full, together with the facade's `ring`
(`board/map.cairo`), which has its own edge handling. I listed every branch and every expression
that treats an edge endpoint, both limb variants where the code is written twice, and the early
returns and target tests. Each is listed below with its simplest wrong form.

Each wrong form was then **run**, not reasoned about:
- **Harness:** `tmp/mut/` held a separate workspace with a **copy** of `crates/hexx` and a copy of
  this package whose `hexx` path dependency pointed at that copy.
- **Per mutant:** edit the copy, run
  `scripts/lock.sh snforge test -p takeover_tests` on the whole package, and record every failing
  test with its panic data.
- **Validity check:** the unmutated copy passed all tests (`baseline: passed 587, failed 0`).
- **Scope:** `crates/hexx` was never edited. The harness, its copies and its results lived only in
  my `tmp/`; they are not committed and were deleted at the end of this loop.
- **Which corpus:**
  - The 77 mutants ran first against the corpus of loop 1 (finding 7's witness included).
  - The survivors, and B27 and B31 (each killed only by the witness), ran again against the final
    corpus.
  - Killing tests found in the first run still exist, because this loop only adds tests.

**Totals:**

| Result | Mutants |
|---|---:|
| Killed by an equality or panic assertion | 64 |
| Killed only by the gas budgets (B35, R08: performance-only changes, equivalent in result) | 2 |
| Survive, equivalent (argued in the table) | 11 |

- No non-equivalent mutant survives.
- Before this loop, three non-equivalent mutants survived: B31 (the audit's), B37 and B38.
  Another, B27, was caught only by the witness. All four are now killed by the new tests.
- "Simplest wrong form" means: a branch condition replaced by `false` (the branch removed) or
  `true` (always taken); an operand dropped; an edge-specific expression replaced by the
  interior one or by `0`; or a layer ignored.

The table follows. "Tests" gives the number of failing tests, the first ones in alphabetical
order, and their panic data. The input of each failing test is the input its doc comment states:
- `*_edges_*`: the boards of adjacent edge tiles;
- `*_entrances_*`: the boards with several entrances;
- `*_boards_*` / `*_fixtures`: the finder boards and the fixtures of 1.8.0;
- `*_identical_endpoints`: `from == to`;
- `test_*_audit_*`: the auditors' two scenarios.

| # | Where (`crates/hexx/src/…`) | Branch or expression → simplest wrong form | Verdict | Tests of this package that fail (count, first ones) |
|---|---|---|---|---|
| B01 | `finders/bfs.cairo` | Bfs::search, `from == to` returns [] | killed | 11: `bfs::test_bfs_identical_endpoints`, `bfs::test_bfs_search_boards_0`, `bfs::test_bfs_search_boards_2` … (panic data: 'search', 'search_path') |
| B02 | `finders/bfs.cairo` | Bfs::distance, `from == to` returns Some(0) | killed | 10: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to') |
| B03 | `finders/bfs.cairo` | BfsInternal::endpoint, `interior` (every tile taken as interior) | killed | 30: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated` … (panic data: 'Option::unwrap failed.', 'distance', 'distance_to') |
| B04 | `finders/bfs.cairo` | BfsInternal::endpoint, `interior` without its last clause (top row taken as interior) | killed | 15: `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand`, `bfs::test_bfs_floods_entrances_generated` … (panic data: 'Option::unwrap failed.', 'distance', 'range') |
| B05 | `finders/bfs.cairo` | BfsInternal::endpoint, `around` of an edge tile (edge_neighbours) replaced by 0 | killed | 35: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated` … (panic data: 'distance', 'distance_to', 'map grid') |
| B06 | `finders/bfs.cairo` | Bfs::search, edge start next to the target returns [to] | killed | 8: `bfs::test_bfs_search_boards_2`, `bfs::test_bfs_search_entrances_generated`, `bfs::test_bfs_search_entrances_hand` … (panic data: 'search', 'search_path') |
| B07 | `finders/bfs.cairo` | Bfs::distance, edge start next to the target returns Some(1) | killed | 8: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to') |
| B08 | `finders/bfs.cairo` | Bfs::distance, interior start next to the target after one layer returns Some(1) | killed | 10: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to') |
| B09 | `finders/bfs.cairo` | search_wide, interior start next to the target returns [to] | killed | 9: `bfs::test_bfs_search_boards_0`, `bfs::test_bfs_search_boards_1`, `bfs::test_bfs_search_boards_2` … (panic data: 'search', 'search_path') |
| B10 | `finders/bfs.cairo` | search_small, interior start next to the target returns [to] | killed | 7: `bfs::test_bfs_search_boards_2`, `bfs::test_bfs_search_entrances_hand`, `bfs::test_bfs_search_fixtures` … (panic data: 'search', 'search_path') |
| B11 | `finders/bfs.cairo` | search_wide, edge target taken as interior (no `enter`) | killed | 5: `bfs::test_bfs_search_entrances_generated`, `bfs::test_bfs_search_entrances_hand`, `map::test_map_paths_entrances_generated_1` … (panic data: 'search', 'search_path', 'u8_add Overflow') |
| B12 | `finders/bfs.cairo` | search_small, edge target taken as interior (no `enter`) | killed | 7: `bfs::test_bfs_search_boards_2`, `bfs::test_bfs_search_entrances_generated`, `bfs::test_bfs_search_entrances_hand` … (panic data: 'Option::unwrap failed.', 'search', 'search_path') |
| B13 | `finders/bfs.cairo` | search_wide, the tile entered from an edge target not appended | killed | 10: `bfs::test_bfs_search_boards_0`, `bfs::test_bfs_search_boards_1`, `bfs::test_bfs_search_boards_2` … (panic data: 'search', 'search_path') |
| B14 | `finders/bfs.cairo` | search_small, the tile entered from an edge target not appended | killed | 9: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_search_boards_2`, `bfs::test_bfs_search_entrances_generated` … (panic data: 'search', 'search_path') |
| B15 | `finders/bfs.cairo` | BfsInternal::enter, the layer ignored (first board neighbour of the edge target) | killed | 13: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_search_boards_0`, `bfs::test_bfs_search_boards_1` … (panic data: 'Option::unwrap failed.', 'search', 'search_path') |
| B16 | `finders/bfs.cairo` | advance, empty target neighbourhood returns false | survives, **equivalent** | Equivalent: with an empty target neighbourhood no layer can hit the goal; the layers run until the frontier is empty and `advance` returns `false` all the same (the early return only saves the layers). |
| B17 | `finders/bfs.cairo` | advance_small, empty target neighbourhood returns false | survives, **equivalent** | Equivalent, as B16 on a single limb. |
| B18 | `finders/bfs.cairo` | advance, the goal is the target neighbourhood (replaced by the target bit itself) | killed | 24: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to', 'result') |
| B19 | `finders/bfs.cairo` | advance_small, the goal is the target neighbourhood (replaced by the target bit itself) | killed | 19: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated` … (panic data: 'distance', 'distance_to', 'search') |
| B20 | `finders/bfs.cairo` | advance, goal in the low limb only (LowGoal always) | killed | 20: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to', 'search') |
| B21 | `finders/bfs.cairo` | advance, first layer of an edge start (`around` only) replaced by around + power | survives, **equivalent** | Equivalent: an edge tile is never in `free` (interior tiles only), so `(around + power) & free` equals `around & free`. |
| B22 | `finders/bfs.cairo` | advance, first layer of an interior start without the start | killed | 6: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_search_boards_0`, `bfs::test_bfs_search_boards_1` … (panic data: 'distance', 'distance_to', 'search') |
| B23 | `finders/bfs.cairo` | advance_small, first layer of an interior start without the start | killed | 4: `bfs::test_bfs_distance_fixtures`, `bfs::test_bfs_search_fixtures`, `map::test_map_distance_to_fixtures` … (panic data: 'distance', 'distance_to', 'search') |
| B24 | `finders/bfs.cairo` | advance, one layer too many skipped below the hex distance | killed | 20: `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated`, `bfs::test_bfs_distance_entrances_hand` … (panic data: 'distance', 'distance_to', 'search') |
| B25 | `finders/bfs.cairo` | advance_small, one layer too many skipped below the hex distance | killed | 19: `bfs::test_bfs_audit_scenario`, `bfs::test_bfs_distance_boards`, `bfs::test_bfs_distance_entrances_generated` … (panic data: 'distance', 'distance_to', 'search') |
| B26 | `finders/bfs.cairo` | Bfs::reachable, first layer of an interior centre without the centre | killed | 3: `map::test_map_keep_component_3x3`, `map::test_map_keep_component_3x83`, `map::test_map_keep_component_83x3` (panic data: 'map grid') |
| B27 | `finders/bfs.cairo` | Bfs::reachable, an edge centre not added to the result | killed | 13: `bfs::test_bfs_floods_edges_15x16`, `bfs::test_bfs_floods_edges_16x8`, `bfs::test_bfs_floods_edges_17x14` … (panic data: 'reachable') |
| B28 | `finders/bfs.cairo` | Bfs::reachable, early return without open edge tiles | survives, **equivalent** | Equivalent: with no open edge tile, `reach = near & 0 = 0`, and the result is `whole` (the early return only saves the dilation). |
| B29 | `finders/bfs.cairo` | Bfs::reachable, next layer of the ball not dilated (single limb) | killed | 8: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_reachable_boards` … (panic data: 'map grid', 'reachable') |
| B30 | `finders/bfs.cairo` | Bfs::reachable, next layer of the ball not dilated (two limbs) | killed | 9: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_reachable_boards` … (panic data: 'map grid', 'reachable') |
| B31 | `finders/bfs.cairo` | Bfs::reachable, `near` without the neighbours of the centre (audit finding 7) | killed | 13: `bfs::test_bfs_floods_edges_15x16`, `bfs::test_bfs_floods_edges_16x8`, `bfs::test_bfs_floods_edges_17x14` … (panic data: 'reachable') |
| B32 | `finders/bfs.cairo` | Bfs::reachable, `reach` not restricted to the open edge tiles | killed | 11: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_reachable_audit_witness` … (panic data: 'map grid', 'reachable') |
| B33 | `finders/bfs.cairo` | tiles_within_range, `range == 0` returns the position | killed | 16: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_tiles_within_range_boards_0` … (panic data: 'u8_sub Overflow') |
| B34 | `finders/bfs.cairo` | tiles_within_range, an edge centre not added to the ball | killed | 14: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_tiles_within_range_boards_0` … (panic data: 'range', 'ring', 'tiles_within_range') |
| B35 | `finders/bfs.cairo` | tiles_within_range, early return without open edge tiles | killed by the gas budgets only (a performance change) | 4: `bfs::test_bfs_tiles_within_range_fixtures`, `gas::test_gas_range_hexx_once` |
| B36 | `finders/bfs.cairo` | tiles_within_range, `range == 1` takes the neighbours of the centre | survives, **equivalent** | Equivalent: for `range == 1` the flood runs 0 steps and returns `inner = 0`; `dilate(0) | around` is `around`. |
| B37 | `finders/bfs.cairo` | tiles_within_range, `near` without the neighbours of the centre (single limb) | killed | 6: `bfs::test_bfs_floods_edges_16x8`, `bfs::test_bfs_floods_edges_7x7`, `bfs::test_bfs_floods_edges_8x16` … (panic data: 'range', 'tiles_within_range') |
| B38 | `finders/bfs.cairo` | tiles_within_range, `near` without the neighbours of the centre (two limbs) | killed | 6: `bfs::test_bfs_floods_edges_15x16`, `bfs::test_bfs_floods_edges_17x14`, `bfs::test_bfs_floods_edges_19x13` … (panic data: 'range', 'tiles_within_range') |
| B39 | `finders/bfs.cairo` | tiles_within_range, edges next to the ball of radius `range` instead of `range - 1` (single limb) | killed | 7: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_tiles_within_range_boards_1` … (panic data: 'range', 'tiles_within_range') |
| B40 | `finders/bfs.cairo` | tiles_within_range, edges next to the ball of radius `range` instead of `range - 1` (two limbs) | killed | 10: `bfs::test_bfs_floods_entrances_generated`, `bfs::test_bfs_floods_entrances_hand`, `bfs::test_bfs_tiles_within_range_boards_0` … (panic data: 'range', 'tiles_within_range') |
| B41 | `finders/bfs.cairo` | flood, an exhausted flood returns (ball, inner) instead of (ball, ball) | survives, **equivalent** | Equivalent: when the flood runs dry, the last `inner` was computed after the last non-empty layer, so `inner == ball` already. |
| B42 | `finders/bfs.cairo` | flood_small, an exhausted flood returns (ball, inner) instead of (ball, ball) | survives, **equivalent** | Equivalent, as B41 on a single limb. |
| R01 | `board/map.cairo` | ring, `radius == 0` returns the position | killed | 9: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_0` … (panic data: 'u8_sub Overflow') |
| R02 | `board/map.cairo` | ring, an edge centre goes through outer - inner | killed | 5: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_0` … (panic data: 'Option::unwrap failed.', 'ring') |
| R03 | `board/map.cairo` | ring, `radius == 1` takes the open neighbours of the centre | killed | 9: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_0` … (panic data: 'u8_sub Overflow') |
| R04 | `board/map.cairo` | ring, first ball without the centre | killed | 9: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_0` … (panic data: 'ring') |
| R05 | `board/map.cairo` | ring, `radius == 2` inner ball is the centre (single limb) | killed | 2: `map::test_map_floods_entrances_hand_1`, `map::test_map_ring_boards_2` (panic data: 'ring') |
| R06 | `board/map.cairo` | ring, `radius == 2` inner ball is the centre (two limbs) | killed | 4: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_hand_1`, `map::test_map_floods_entrances_hand_2` … (panic data: 'ring') |
| R07 | `board/map.cairo` | ring, early return without open edge tiles (single limb) | survives, **equivalent** | Equivalent: with no open edge tile, the edge terms `(near & edges)` and `(far & edges)` are 0. |
| R08 | `board/map.cairo` | ring, early return without open edge tiles (two limbs) | killed by the gas budgets only (a performance change) | 2: `gas::test_gas_ring_hexx_once`, `gas::test_gas_ring_hexx_twice` |
| R09 | `board/map.cairo` | ring, edge tiles next to the inner ball not removed (single limb) | killed | 4: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_hand_0`, `map::test_map_floods_entrances_hand_1` … (panic data: 'ring') |
| R10 | `board/map.cairo` | ring, edge tiles next to the inner ball not removed (two limbs) | killed | 7: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_1` … (panic data: 'ring') |
| R11 | `board/map.cairo` | ring, open edge tiles of the ring not added (single limb) | killed | 4: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_hand_0`, `map::test_map_floods_entrances_hand_1` … (panic data: 'ring') |
| R12 | `board/map.cairo` | ring, open edge tiles of the ring not added (two limbs) | killed | 7: `map::test_map_floods_entrances_generated_0`, `map::test_map_floods_entrances_generated_1`, `map::test_map_floods_entrances_hand_1` … (panic data: 'ring') |
| D01 | `finders/dial.cairo` | Dial::search, `from == to` returns [] | killed | 4: `dial::test_dial_identical_endpoints`, `dial::test_dial_search_entrances_hand`, `map::test_map_identical_endpoints` … (panic data: 'search', 'weighted') |
| D02 | `finders/dial.cairo` | Dial::search, `from_edge` always false | killed | 14: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'Option::unwrap failed.', 'search', 'search_path_weighted') |
| D03 | `finders/dial.cairo` | Dial::search, `to_edge` always false | killed | 14: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'search', 'search_path_weighted', 'weighted') |
| D04 | `finders/dial.cairo` | Dial::search, an interior start left unvisited | survives, **equivalent** | Equivalent: the start, left unvisited, is re-scheduled at time `cost(start)`, but a tile next to the start has predecessor time 0, so the backtracking stops before it; no path contains it. |
| D05 | `finders/dial.cairo` | Dial::search, an edge target not added to the unvisited tiles | killed | 14: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'search', 'search_path_weighted', 'weighted') |
| D06 | `finders/dial.cairo` | solve, edge start next to the target returns [to] | killed | 8: `dial::test_dial_search_boards_2`, `dial::test_dial_search_entrances_generated`, `dial::test_dial_search_entrances_hand` … (panic data: 'search', 'search_path_weighted', 'weighted') |
| D07 | `finders/dial.cairo` | seeds, adjacency of an edge start to the target | survives, **equivalent** | Equivalent: without the shortcut the target is among the seeds, `forward` finds it at time 0, and the backtracking returns `[to]` all the same. |
| D08 | `finders/dial.cairo` | seeds, neighbours of an edge start not restricted to the tiles a path may enter | killed | 28: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'Option::unwrap failed.', 'field', 'field_of_movement') |
| D09 | `finders/dial.cairo` | seeds, `around` (edge_neighbours) replaced by 0 | killed | 28: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'field', 'field_of_movement', 'search') |
| D10 | `finders/dial.cairo` | solve, an edge start seeded like an interior one (dilation) | killed | 12: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_entrances_generated` … (panic data: 'Option::unwrap failed.', 'search', 'search_path_weighted') |
| D11 | `finders/dial.cairo` | forward, target test of the arrivals | killed | 19: `dial::test_dial_fixture_endpoints`, `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1` … (panic data: 'Option::unwrap failed.', 'result', 'search') |
| D12 | `finders/dial.cairo` | forward_unit, target test of the arrivals | killed | 18: `dial::test_dial_fixture_endpoints`, `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1` … (panic data: 'Option::unwrap failed.', 'search', 'search_path_weighted') |
| D13 | `finders/dial.cairo` | backtrack, `time == 0` returns [to] | killed | 2: `dial::test_dial_search_boards_2`, `map::test_map_search_path_weighted_boards_2` (panic data: 'Option::unwrap failed.') |
| D14 | `finders/dial.cairo` | backtrack, edge target taken as interior | killed | 13: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'Option::unwrap failed.') |
| D15 | `finders/dial.cairo` | backtrack, the tile entered from an edge target not appended | killed | 14: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'search', 'search_path_weighted', 'weighted') |
| D16 | `finders/dial.cairo` | backtrack, the layer ignored when entering from an edge target | killed | 14: `dial::test_dial_search_boards_0`, `dial::test_dial_search_boards_1`, `dial::test_dial_search_boards_2` … (panic data: 'Option::unwrap failed.', 'search', 'u128_sub Overflow') |
| D17 | `finders/dial.cairo` | field_of_movement, `budget == 0` returns the start | killed | 16: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'field', 'field_of_movement') |
| D18 | `finders/dial.cairo` | field_of_movement, `edges` always false | killed | 14: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'field', 'field_of_movement') |
| D19 | `finders/dial.cairo` | field_of_movement, the open edge tiles left out of the unvisited tiles | killed | 14: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'field', 'field_of_movement') |
| D20 | `finders/dial.cairo` | field_of_movement, `from_edge` without other open edge tile: the interior tiles | survives, **equivalent** | Unreachable: a walkable edge start makes the grid differ from its interior, so `edges` is true whenever `from_edge` is. |
| D21 | `finders/dial.cairo` | field, an edge start seeded like an interior one (dilation) | killed | 12: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'Option::unwrap failed.', 'field', 'field_of_movement') |
| D22 | `finders/dial.cairo` | field_weighted, edge tiles expanded like interior ones | killed | 12: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'Option::unwrap failed.', 'field', 'field_of_movement') |
| D23 | `finders/dial.cairo` | field_unit, edge tiles expanded like interior ones | killed | 12: `dial::test_dial_field_of_movement_boards_0`, `dial::test_dial_field_of_movement_boards_1`, `dial::test_dial_field_of_movement_boards_2` … (panic data: 'Option::unwrap failed.', 'field', 'field_of_movement') |

- **Both limb variants:**
  - Code written twice has two rows: B09/B10, B11/B12, B13/B14, B16/B17, B22/B23, B24/B25,
    B29/B30, B37/B38, B39/B40, B41/B42, R05/R06, R07/R08, R09/R10, R11/R12.
  - Code written once serves both paths: the endpoint, the early returns, and `Dial`, which is
    generic over `u128` / `u256`. Its killing tests include boards of both paths: for example,
    `*_edges_7x7` and `*_edges_15x16` fail together for B27 and B31.
- **Out of the table (not edge handling):** the layer arithmetic shared by every endpoint
  (`layer`, `dilate`, `back` / `identify`, the `Frontier::neighbours` limb selection, the cost
  classes). They are covered by the equality tests of loop 0; I did not run mutants on them.

### Commands run (fix loop 2)

- Witness: `scripts/lock.sh snforge test -p takeover_tests test_bfs_reachable_audit_witness`
  gave `[PASS] … (l2_gas: ~232336)`.
- Harness:
  - `python3 tmp/mut/run.py baseline` gave
    `{"compiled": true, "passed": 587, "failed": 0, "seconds": 113}`.
  - Then four batches, `python3 tmp/mut/run.py B01 … D23`: 77 mutants, 74 to 265 s each. Their
    per-mutant lines are summarized in the table.
  - Rerun of the survivors, the witness-only kills B27 and B31, and the equivalents on the final
    corpus: `B27`, `B31`, `B37`, `B38` killed (13, 13, 6, 6 tests); the other 11 survive.
- New tests: `scripts/lock.sh snforge test -p takeover_tests edges_` gave
  `Tests: 42 passed, 0 failed`.
  - A first version of `map::test_map_paths_edges_*` grouped three sizes and exceeded the
    snforge step limit (`RunResources has no remaining steps`). I split it per size and
    separated the facade paths from the fields; the heaviest edge test is now 356,716,820.
- Budget passes (the rule of loop 1: measured on the test as committed, attribute included,
  `N = ceil(1.05 × measured)`), `scripts/lock.sh snforge test -p takeover_tests` three times:
  `Tests: 630 passed` each. Passes B and C: `tests in both: 630; identical: 630`. The heaviest
  test is still `layout::test_layout_neighbour_in` at 490,564,114.
- `python3 scripts/bench.py snapshot`: exit 0. `python3 scripts/gas_tables.py`: `wrote docs/GAS.md`.
- `scripts/check.sh`: exit 0, real 10m27s:
  ```
  takeover_tests: declared 630, collected 630, with a gas row 630, ignored 0
  29 pairs, 0 problem(s)
  all checks passed
  ```
- A fresh build: I deleted `tmp/mut/target` and ran
  `snforge test -p takeover_tests test_digger_corridor` on an unmutated copy. Every figure equals
  the committed snapshot, for example `test_digger_corridor_15x15`: 91,223,148 both.

### CI

- **Run 36548419370 (commit `8584d8d`): the gas job failed on a snapshot mismatch.** It ran
  8m02s, so this was not a timeout.
  - 47 tests measured 0.5 to 1.3 % above the snapshot. All of them, and only them, go through
    `Digger::dig`: `open_with_*`, `Digger::{maze,corridor}`, the provenance tests that open
    boards, and `hexx`'s own inherited `hexx_integrationtest::readme::test_readme_open`
    (2,030,366 → 2,053,706, from `gas/hexx.snap`, which this task never touched).
  - The origami side of the long-dig gas tests moved as much as the hexx side.
  - The budgets held; `Build and test takeover_tests` passed.
- **What was identical to the previous green run:**
  - the Digger values and `gas/hexx.snap` (`git diff a105c02 HEAD` shows no change to them);
  - `crates/hexx`;
  - the toolchain: Scarb 2.19.4, universal-sierra-compiler v2.10.1, runner image 20260920.314.1;
  - the restored cache key (`gas-scarb-cache-linux-dcd012de…`), which the green run had not
    re-saved;
  - the only change on `main`, `688ff7f`, touches documentation only.
- A fresh local build reproduced the committed figures.
- I could not re-run the job (`gh run rerun` needs an approval I do not have), so I pushed the
  empty commit `b77667f`.
- **Run 36550572650: every job green**, the gas job included, against the same snapshot.

| Job | Duration |
|---|---:|
| Build and test hexx | 7m06s |
| Build and test takeover_tests | 2m55s (build 65 s, 630 tests 90 s) |
| Gas budgets and class size | 6m56s (`hexx` 4m58s, `takeover_tests` 1m33s) |
| Everything else | ≤ 22s |

Every job is under 10 minutes.

### Cost (fix loop 2)

- **630 tests:** 334 equality tests, 102 panic pairs (204 tests), 88 gas tests, and 4 provenance
  tests.
- The new tests are the witness, the 42 edge tests (12 each in `bfs` and `dial`, 18 in `map`,
  counting the facade fields separately), and `test_edge_boards_provenance`.
- The measured total is 56.2 B l2 gas.

### Escalations (fix loop 2)

1. **CI gas measurement is not reproducible between runs.** The same sources, toolchain and cache
   key gave two different sets of figures for the code that goes through `Digger::dig`: run
   36548419370 against runs 36525953107 and 36550572650, and against a fresh local build.
   - I did not find the cause, and I did not bend the snapshot to the outlier.
   - If it recurs, it will fail an unrelated pull request, since `hexx`'s own
     `test_readme_open` is affected.
   - Pinning `setup-universal-sierra-compiler` (it uses the floating tag `@v1`, though both runs
     installed v2.10.1), or ruling out the target cache (`cache-targets: true`), touches
     `.github/workflows/ci.yml`. That is outside my allowlist for this purpose.
2. **The equivalent mutants are equivalent in result, not in cost.** B16, B17, B28, R07 (and the
   gas-only B35, R08) are early returns that save work. The equality corpus cannot, and should
   not, detect their removal; the gas snapshot does for B35 and R08. A later task that relies on
   those shortcuts for gas should keep that in mind.

### Deviations (fix loop 2)

- The table was built by running mutants on a copy of the engine in my `tmp/`, not by reasoning
  alone. `crates/hexx` was never edited. The copies, harness and results are not committed and
  were deleted at the end of this loop, as was the rest of my `tmp/`.
- The empty commit `b77667f` exists only to re-run CI.
