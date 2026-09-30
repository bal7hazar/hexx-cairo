# [Opus 5.5] LIB-05 M1-T3 — N-7 and the board's coordinates

## Summary

Pull request: **https://github.com/bal7hazar/hexx-cairo/pull/54**, branch
`feat/lib-05-m1-t3-directions`. CI is green: all 15 jobs pass, including "All checks passed", on
run `36790137081`, commit `e7b000e`. It is not merged. The model of this session is Opus 5.5, the
model the brief names.

The first run of this task stopped on the gas stop condition, at commit `0ca5d42`. The
orchestrator then decided the stop and amended the brief (section "Decisions of the orchestrator on
the stop (2026-09-30)"). I merged `origin/main` into the branch, carried out those decisions and
finished the task.

What exists now:

- **N-7** (`board/direction.cairo`):
  - `DirectionTrait::rotate` and `DirectionTrait::arc`.
  - The enum `Arc`, re-exported at the root beside `Direction`.
  - `Into<Direction, EdgeDirection>` and `Into<EdgeDirection, Direction>`, which preserve the index.
- **Coordinates** (`board/geometry.cairo`): `GeometryTrait::distance_between`, `chunk_of`,
  `to_hex`, `from_hex`, `index_to_hex` and `hex_to_index`.
- **Adjacency** (`board/layout.cairo`): `LayoutTrait::neighbor_direction`.
- **The three renames of §5.2**: `edge_neighbors`, `neighbor_in` and `neighbor_mask`, at every call
  site on the `hexx` side.
  - The move proof has three rewrites and three `EXTENDED` entries.
  - It prints `29 pairs, 0 problem(s)`.
- **Tests**: every new test and benchmark is in its module (D-167). Each test has a real budget of
  `ceil(1.05 × measured)`; the placeholders are gone.
- **Consumer**: a `HexxCoordinates` contract in `crates/consumer`, with one call site per new
  public item.
- **Plan**: the accepted figures are written in §14 of the plan.

## Files changed

The diff of the pull request against `main`:

- `crates/hexx/src/board/direction.cairo`:
  - `Arc`, `rotate`, `arc`, the two `Into` impls, and the private `DirectionIndexTrait::from_index`.
  - In `mod tests`:
    - `rotate` against its definition on 6 × 256 values, and against the mirror's `rotate_cw`;
    - `rotate(3) == opposite`;
    - the 36 `arc` pairs against the angle between the directions;
    - the game's arcs (`design/04-combat.md`);
    - R-N7-1 and R-N7-2;
    - the `Into` round trips;
    - the benchmarks.
- `crates/hexx/src/board/geometry.cairo`:
  - the six functions, with `distance_between` on `bounded_int` and the helper impls of its ranges;
  - in `mod tests`:
    - R-D1;
    - every pair of 7 × 7 at 3 global origins against the engine's `distance`;
    - 512 seeded pairs against the cube distance on `i32` and the `Hex` distance;
    - every `y1` of `u8` against the edge rows and extreme columns;
    - `chunk_of` on every column and row of `u8`;
    - `to_hex` against `from_offset_coordinates([-x, y], Even, Pointy)`;
    - `from_hex` on every row with the column at each end of `0..=255`, just beyond it, and at
      `i32::MIN` and `i32::MAX`;
    - the round trip on 12 boards;
    - the directions coinciding on 7 × 7 and 15 × 16;
    - the benchmarks.
- `crates/hexx/src/board/layout.cairo`:
  - the three renames;
  - `neighbor_direction`;
  - a new `mod tests`: R-D2, R-D3 and R-D4, every pair of 7 × 7 and 8 × 5, 512 seeded pairs on each
    of six boards (including 85 × 3, 127 × 2, 128 × 1 and 251 × 1), and the benchmark.
- `crates/hexx/src/lib.cairo`: `pub use board::direction::{Arc, Direction};`.
- Renames only:
  - `crates/hexx/src/finders/{bfs,dial,flood}.cairo` (`flood` in a doc comment);
  - `crates/hexx/src/generators/{digger,mazer}.cairo`;
  - `crates/hexx/src/tests/{properties,bench_foundation,test_flood,test_steps}.cairo`;
  - `crates/hexx/tests/readme.cairo`.
- `crates/takeover_tests/src/layout.cairo`: the renamed calls on the `H::` side, plus two lines of
  module doc.
- `crates/consumer/src/lib.cairo`: the `HexxCoordinates` contract, 11 entry points.
- `scripts/takeover_check.py`: the three rewrites and the three `EXTENDED` entries.
- `scripts/tests/test_takeover_check.py`: updated for the rewrites (accepted by the orchestrator).
- `docs/research/LIB-03-porting-plan.md`: one row "Accepted figures (M1-T3)" in §14.
- `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/GAS.md`: regenerated.
- `gas/hexx.snap`: 44 new rows. No existing row changed.
- `gas/bytecode.size`: a new `HexxCoordinates` row.
- `gas/takeover_tests.snap`: unchanged from `main` in the end (see Deviations 1).

## Commands run

Merge of `origin/main`:

```
$ git fetch origin && git merge origin/main -m "Merge origin/main into feat/lib-05-m1-t3-directions"
 gas/accepted.md                                 |  18 ++++
 scripts/gas_tables.py                           |   5 ++
 6 files changed, 206 insertions(+), 5 deletions(-)
```

The three attempts, in place, all measured in one run:

```
$ scripts/lock.sh snforge test -p hexx board::
[PASS] …bench_geometry_distance_between_once  l2_gas: ~21000
[PASS] …bench_geometry_distance_between_twice l2_gas: ~25220
[PASS] …bench_geometry_from_hex_once          l2_gas: ~21230
[PASS] …bench_geometry_from_hex_twice         l2_gas: ~25220
[PASS] …bench_geometry_hex_to_index_once      l2_gas: ~23010
[PASS] …bench_geometry_hex_to_index_twice     l2_gas: ~28780
[PASS] …bench_layout_neighbor_direction_once  l2_gas: ~27260
[PASS] …bench_layout_neighbor_direction_twice l2_gas: ~39280
[PASS] …test_geometry_distance_between_rows   l2_gas: ~152339340
[PASS] …test_geometry_from_hex_rows           l2_gas: ~8362410
[PASS] …test_layout_neighbor_direction_seeded l2_gas: ~219719820
[PASS] …test_layout_neighbor_direction_pairs  l2_gas: ~296394290
Tests: 103 passed, 0 failed, 0 ignored, 1021 filtered out
```

The widened oracle tests also ran green on the variants. After the two reverts, the board tests
were measured again before the budgets were set:

```
$ scripts/lock.sh snforge test -p hexx board::
Tests: 103 passed, 0 failed, 0 ignored, 1021 filtered out
```

Move proof. I downloaded `dojoengine/origami` `04ab30c` as a tarball into the ignored `work/`, and
removed it afterwards. The first run failed on `direction.cairo`: a line of its tests was modified,
not added, and `scarb fmt` merges `use super::` lines. I imported `Arc` by its full path and ran it
again:

```
$ python3 scripts/takeover_check.py --source work/origami-04ab30c…/crates/hexmap
src/types/direction.cairo -> src/board/direction.cairo: same, with additions only (M1-T3 (N-7))
src/helpers/layout.cairo -> src/board/layout.cairo: same, with additions only (M1-T3 (neighbor_direction))
src/helpers/geometry.cairo -> src/board/geometry.cairo: same, with additions only (M1-T3 (§6.1, §3.5))
…
29 pairs, 0 problem(s)
```

Snapshots, generated documents and class size:

```
$ python3 scripts/bench.py snapshot
(all packages; gas/hexx.snap +44 rows, no existing row changed)

$ python3 scripts/bench.py snapshot --package takeover_tests     (re-run once, D-154)
(identical to the first run: the same 40 digger rows above main)

$ python3 scripts/api_parity.py && python3 scripts/api_parity.py --extensions \
    && python3 scripts/deviations.py && python3 scripts/gas_tables.py
wrote docs/API_PARITY.md
wrote docs/EXTENSIONS.md
wrote docs/DEVIATIONS.md
wrote docs/GAS.md

$ python3 scripts/bytecode_size.py snapshot
| `HexxCoordinates` | 1,587 | 3,771 | 4.6 % | 78,264 | 85,595 | 2.1 % |
| `HexxGenerators` | 27,092 | 49,375 | 60.3 % | 1,395,788 | 997,126 | 34.1 % |
```

`HexxGenerators` stayed at 27,092 on this build, with no D-154 class-size drift.

Equality tests, then the full local gate:

```
$ scripts/lock.sh snforge test -p takeover_tests
[PASS] takeover_tests::layout::test_layout_edge_neighbours (… l2_gas: ~150588748)
[PASS] takeover_tests::layout::test_layout_neighbour_mask (… l2_gas: ~44603488)
[PASS] takeover_tests::layout::test_layout_neighbour_in (… l2_gas: ~490564114)
Tests: 630 passed, 0 failed, 0 ignored, 0 filtered out

$ scripts/check.sh ; echo exit=$?
  hexx: declared 1124, collected 1124, with a gas row 1124, ignored 0
  takeover_tests: declared 630, collected 630, with a gas row 630, ignored 0
gas budgets and snapshot OK (1754 tests)
bytecode size snapshot OK (8 contracts)
Ran 181 tests in 1.917s
OK (skipped=9)
docs/API_PARITY.md is up to date
docs/EXTENSIONS.md is up to date
docs/DEVIATIONS.md is up to date
takeover_check: no source checkout at …/sources/origami/crates/hexmap: SKIPPED
all checks passed
exit=0
```

`check.sh` skips the move proof when `sources/origami` is absent. I ran the proof on its own above,
and CI runs it.

Pull request and CI:

```
$ git push -u origin HEAD
 * [new branch]      HEAD -> feat/lib-05-m1-t3-directions
$ gh pr create --base main --title "[Opus 5.5] LIB-05 M1-T3 directions and coordinates" …
https://github.com/bal7hazar/hexx-cairo/pull/54
```

CI run `36789168415` (commit `f936a34`): 13 jobs passed; `Gas takeover_tests` failed, and with it
"All checks passed".

```
CHANGED takeover_tests::digger::test_digger_corridor_15x15: snapshot measured 91464618, budget 95784306; now measured 91223148 (-0.26 %)
…  (the 40 digger, corridor and maze rows, now exactly main's figures)
CHANGED takeover_tests::gas::test_gas_open_with_maze_long_hexx_twice: snapshot measured 6887752, budget 7094695; now measured 6756852 (-1.90 %)
```

I restored `main`'s `gas/takeover_tests.snap` (`git checkout origin/main -- gas/takeover_tests.snap`),
ran `gas_tables.py` again, committed `e7b000e` and pushed.

```
$ gh pr checks 54 --watch --interval 30 ; echo exit=$?     (run 36790137081)
All checks passed	pass
Gas takeover_tests	pass	2m33s
Gas hexx	pass	6m7s
Take-over of origami_hexmap is a move	pass	10s
…  (15 of 15 pass)
exit=0
```

Grep for the project manager's rule: does anything on the tick or the reveal path call the six
functions?

```
$ grep -rnE "chunk_of|to_hex|from_hex|hex_to_index|distance_between|neighbor_direction" \
    crates/hexx/src/tests/bench_tick.cairo crates/hexx/src/tests/bench_assembly.cairo \
    crates/hexx/src/board/assembly.cairo crates/hexx/src/finders/ crates/hexx/src/board/map.cairo \
    crates/hexx/src/board/cut.cairo crates/hexx/src/generators/ ; echo "exit=$?"
exit=1
```

There is no match.

## Cost

Measured with Scarb 2.19.4 and snforge 0.61.0.

The geometry and layout figures are per call, the raw `twice − once` of `bench_assembly`: one
call plus its `assert!` comparison (decision 1 of the orchestrator). The direction figures are
`(test − baseline) / 102`, the method of `bench_mirror`.

**The three attempts**, one each and taken from my own list, as the orchestrator decided:

| Function | Before | Attempt | After the attempt | Oracle | Kept |
|---|---:|---|---:|---|---|
| `distance_between` | 7,220 | `bounded_int` arithmetic. Two `div_rem` by `UnitInt<2>`, bounded add and sub, the signs by `constrain` at 0; no overflow check | **4,220** (25,220 − 21,000) | green: 7 × 7 at 3 origins, 512 seeded, every `y1` × edge rows × extreme columns, R-D1 | **yes** |
| `from_hex` | 3,840 | `bounded_int` constrain: `hex.x + ceil(y/2) + 255` bounded, then `constrain` at 0 and at 256, instead of the `felt252 → u8` `try_into` | 3,990 (25,220 − 21,230); `hex_to_index` 5,770 | green | no: dearer, dropped |
| `neighbor_direction` | 9,640 | one `DivRem` of `from` by `2W` on `u16`, which gives its column and row parity, instead of the division by `W` and the parity `DivRem` | 12,020 (39,280 − 27,260) | green: all pairs of 7 × 7 and 8 × 5, 6 × 512 seeded, R-D2 to R-D4 | no: dearer, dropped |

**Final figures of this task:**

| Function | Worst case | Measured (`gas/hexx.snap`) | Per call | §7 range | Verdict |
|---|---|---|---:|---|---|
| `Geometry::distance_between` | `(0,0)`–`(255,255)`, 383 | 25,220 − 21,000 | **4,220** | [5,196, 6,495] | below the range after the attempt |
| `Geometry::chunk_of` | `(255, 255)` | 23,280 − 20,260 | **3,020** | [2,196, 2,745] | accepted (decision 1) |
| `Geometry::to_hex` | `(255, 255)` | 22,740 − 19,990 | **2,750** | [1,998, 2,498] | accepted (decision 1) |
| `Geometry::from_hex` | `Hex(-383, 255)` | 24,770 − 20,930 | **3,840** | [2,198, 2,748] | accepted after the attempt |
| `Geometry::hex_to_index` | 15 × 16, success | 27,980 − 22,610 | **5,370** | [2,998, 3,748] | accepted; inherits `from_hex` |
| `LayoutTrait::neighbor_direction` | odd row, non-adjacent, one row above | 34,520 − 24,880 | **9,640** | [4,294, 5,368] | accepted after the attempt |
| `Geometry::index_to_hex` | 15 × 16, position 239 | 24,760 − 21,000 | 3,760 | [4,194, 5,243] | below |
| `Direction::rotate` | `steps` 255…239 | (832,006 − 568,082) / 102 | 2,588 | [2,496, 3,120] | in range |
| `Direction::arc` | every pair | (768,306 − 641,252) / 102 | 1,246 | [1,998, 2,498] | below |
| `Into<Direction, EdgeDirection>` | any | (568,082 − 520,482) / 102 | 467 | [500, 625] | below |
| `Into<EdgeDirection, Direction>` | any | (615,682 − 520,482) / 102 − 467 | 467 | [500, 625] | below |
| `Geometry::distance`, the engine's reference beside `distance_between` | 15 × 16, corners | 27,420 − 22,380 | 5,040 | — | reference |

- **Stop condition:** no figure other than the six decided is above its range.
- **Hot path:** `distance_between` is now 4,220. The engine's `Geometry::distance`, on the same
  method, is 5,040, and `hex_distance` itself 10,393 (measured, `GAS.md:1878`).
- **Plan:** every figure above is written in §14 of the plan, row "Accepted figures (M1-T3)".

**The project manager's rule** (a figure that moves the library's share of a worst tick or of a
reveal by more than 10 %):

| Function | Called by a benchmark of `bench_tick` or of the assembly? |
|---|---|
| `chunk_of` | no |
| `to_hex` | no |
| `from_hex` | no |
| `hex_to_index` | no |
| `distance_between` | no |
| `neighbor_direction` | no |

The grep above has no match. It covers `bench_tick.cairo`, `bench_assembly.cairo`,
`assembly.cairo`, the finders, the generators, the facade and `cut`. None of the six moves the
library's share of the tick measured by M1-T9b. The game's own tick will call `distance_between`
(ENG-02); that is outside this library's benchmarks.

**Class size:** `HexxCoordinates` is 1,587 Sierra felts and 3,771 CASM felts (4.6 % of the limit).

## Deviations

1. **`gas/takeover_tests.snap` keeps `main`'s version.**
   - Locally, `bench.py snapshot` measured the 40 digger, corridor and maze rows of `takeover_tests`
     0.2 to 1.9 % above `main`, within their unchanged budgets. A second run gave the same figures.
   - CI measured exactly `main`'s figures, so its `Gas takeover_tests` job failed on the locally
     written snapshot.
   - This is the known D-154 compile drift of `Digger::dig`, on this machine's build. It is
     inferred from CI reproducing `main` bit for bit; no `hexx` row moved.
   - I restored `main`'s snapshot and regenerated `docs/GAS.md`. CI is then green.
   - The `HexxGenerators` class-size drift (27,101 against 27,092) did not show up: 27,092 locally.
2. **The oracle "over the whole domain" of the three attempts.**
   - `distance_between` and `from_hex` have domains of `2^32` and `2^64` points, so they cannot be
     tested exhaustively.
   - The tests cover every row of `u8` against every branch boundary: each sign of `dq` and `dr`,
     the ends of their ranges, both ends of the column range and just beyond, and the `i32`
     extremes.
   - The `bounded_int` ranges are declared in helper impls, and I rely on the compiler to check them
     against the operands at compile time. I have not tried a wrong range to confirm this.
   - The `neighbor_direction` variant was tested on every pair of 7 × 7 and 8 × 5 and on seeded
     pairs of boards up to `W = 251`. It was dropped anyway, as dearer.
3. **Import in the tests of `direction.cairo`.** `use hexx::board::direction::Arc;` imports by full
   path rather than through `super::`. `scarb fmt` merges a separate `use super::Arc;` into the line
   taken over from 1.8.0, and the additions-only move proof then reads that line as modified.
4. **Kept from the first run:**
   - Names that only contain an old helper name stay in the byte-proven files:
     `bench_neighbour_mask`, `Variants::neighbour_mask_lookups`, and the `takeover_tests` test names
     and messages of the `origami_hexmap` side.
   - New benchmarks live in their modules.
   - `to_hex` computes in `felt252`, and `from_hex` never panics.

## Escalations

None open. The four escalations of the first run are decided in the brief's section "Decisions of
the orchestrator on the stop".

## Open questions

- **`gas/accepted.md`:** it needs rows for `chunk_of`, `to_hex`, `from_hex`, `hex_to_index` and
  `neighbor_direction`. They are for the orchestrator, as decided; I did not edit that file.
  `distance_between` no longer needs a row: it measures 4,220, below its range.
- **D-154 drift:** can the check of a snapshot tolerate it for `takeover_tests`, or should the
  snapshot not be rewritten locally for that package? As it stands, an agent that runs
  `bench.py snapshot` on this machine writes drifted digger rows, and CI rejects them.
