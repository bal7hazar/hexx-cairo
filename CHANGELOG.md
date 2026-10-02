# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). One entry per version, four
fixed headings (plan §9.4): *Parity* (items ported, counterparts, exclusions, the percentage),
*Extensions* (new or changed functions, with their need), *Deviations* (new or changed documented
differences from `hexx`), *Results changed* (any numeric change, with the affected functions and
the reason; empty on a PATCH). The game reads the last heading to know whether its test vectors
move. Versions before `0.1.0` are pre-releases (`0.1.0-rc.N`); nothing is published yet
(decision L-G2: publication needs the owner's explicit go).

## [Unreleased]

## [0.1.0-rc.2] — unreleased

The second release candidate of `hexx`, the first built on Scarb 2.20.1. It adds needs N-1, N-2
and N-6 (`hexagon`, `hexagon_ring`), which `0.1.0-rc.1` lacked. Published only after the go of D-132 (`docs/RELEASING.md`).

### Changed

- Built with Scarb 2.20.1 and starknet-foundry 0.64.0 (Cairo 2.20.0; LIB-04f, D-180); gas
  snapshots, budgets and class sizes are re-measured on the new toolchain (`docs/GAS.md`).
  `0.1.0-rc.1` stays as published, built on Scarb 2.19.4.
- Requires Cairo >= 2.20.0 (Scarb 2.20.1); consumers on 2.19.x cannot resolve this version.
- Builds run the compiler on a single thread (`RAYON_NUM_THREADS=1`, LIB-04e, D-176). Gas, Sierra
  felt counts and CASM are the compared figures; class hash: not compared until the build-root rule
  (programme OPERATIONS).
- Release check (`.github/workflows/release-check.yml`, no change to the package): its reports are
  written outside the checkout and the tree is checked clean before `scarb package` (run
  `36809681077` of `0.1.0-rc.1` had passed the full gate, then `scarb package` refused an
  untracked report). Merged without a review: Codex unavailable (quota), by the project manager's
  decision of 2026-10-01 under the standard's exception.
- Tooling, no change to the package: a consumer check against the published `hexx` (N-9), CI
  partitions and per-job gas reports, a pre-push hook (`scripts/prepush.sh`), and CI runs
  cancelled only for a pull request's superseded runs.

### Fixed

- `Caver::smooth` (and `HexMap::smooth`) ignores the bits of `grid` at or above `W * H` and clears
  them in the result, as its contract states (#95, a fix of N-1): a stray bit used to be returned
  and, for some positions on 15 x 15, change in-board tiles. Cost on
  `bench_map_smooth_15x15_order_1`: 94826 to 98842 (+4.2 %). `smooth` is new in this candidate, so
  no published result changes.

### Parity

Unchanged since `0.1.0-rc.1`: 67 items of `hexx` 0.25.0 ported and 2 renamed counterparts, 10.0 %
of its 692 items (`python3 scripts/api_parity.py --check`, `docs/API_PARITY.md`); 316 items are
`dropped`. N-1, N-2 and N-6 are extensions: they mirror nothing in `hexx`.

### Extensions

240 extension items listed in `docs/EXTENSIONS.md` (`python3 scripts/api_parity.py --extensions`),
19 more than the 221 of `0.1.0-rc.1`. New functions, with their need:

- **N-1** `HexMapTrait::new_cave_with_margins` (`generate_with_margins`) and `HexMapTrait::smooth`
  (`generators/caver`): the cave automaton with frozen tiles; the ring of a chunk holds the tiles
  copied from its neighbours and never evolves, `smooth` also holds chosen tiles; rows have the
  global parity of the chunk, the four corners are wall.
- **N-2** `SeamTrait::{side, openings, is_open_across}` for the seams between chunks
  (`board/seams`), and `LayoutTrait::new_odd`, a layout whose rows have the odd global parity.
- **N-6** `HexagonTrait::{hexagon, hexagon_ring}` (`board/hexagon`): the tiles within a radius of
  a tile, and those at exactly that radius. `Layout::hexagon` and `HexMapTrait::new_hexagon` were
  already in `0.1.0-rc.1`.

### Deviations

59 documented deviations (`python3 scripts/deviations.py --check`, `docs/DEVIATIONS.md`), the
same as `0.1.0-rc.1`; the new items are extensions and add none.

### Results changed

None. Every function of `0.1.0-rc.1` returns the same result for the same input: the changes to
files of `0.1.0-rc.1` are additions (N-1, N-2, N-6) and re-measured gas budgets on Cairo 2.20.0
(lower or equal gas, no change of value). Gas figures differ from `0.1.0-rc.1`'s (`docs/GAS.md`).

## [0.1.0-rc.1] — 2026-10-01

The first release candidate of `hexx`, for the game's ENG-02: the engine of `origami_hexmap`
1.8.0 taken over, the mirror items of milestone L-M1, and needs N-3, N-4, N-5, N-7 and N-8.
N-1, N-2 (they wait for the game's study of hexagonal chunks, SPK-14) and N-6 come in later
candidates. Published only after the go of D-132 (`docs/RELEASING.md`).

### Parity

67 items of `hexx` 0.25.0 ported and 2 renamed counterparts, 10.0 % of its 692 items
(`docs/API_PARITY.md`: `(ported + renamed) / all`); 316 items are excluded (`dropped`), among
them whole modules whose subject belongs to the client (`layout`, `storage`, `mesh`: world
positions, `f32` and rendering), each with its reason in the table. Every mirror item of L-M1 is
present: `Hex` and its distances, `HexTrait::line_to`, `EdgeDirection` and its rotations,
the offset coordinates (`OffsetHexMode`, `to_offset_coordinates`, `from_offset_coordinates`),
`HexOrientation`. They are checked against golden vectors generated from the crate itself
(`tools/refgen`; `HexOrientation` through the conversions of both orientations, its `Default` and
`Not` by Cairo tests), except `line_to` at its ties: there `refgen` encodes the game's integer rule,
and the vectors give identity with `hexx` on every non-tie pair of the window and on the seeded
sample.

### Extensions

- **The engine of `origami_hexmap` 1.8.0** (`board`, `finders`, `generators`): moved, its code
  preserved byte for byte or up to `scarb fmt` except the three renames below, and five files
  extended with additions only (`scripts/takeover_check.py`, `EXTENDED`); every public function
  compared with the published 1.8.0 by `crates/takeover_tests`: 630 tests, of which 334 equality
  tests, 204 panic tests, 88 gas tests and 4 provenance tests.
- **N-3** `AssemblyTrait::{origin, local, assemble, window}`: the window of 15 × 16 assembled
  from 2 or 4 chunks of 15 × 15, a void chunk assembled as wall without a read.
- **N-4** `CutTrait::cut`: `grid & mask`, the ring kept inside the mask.
- **N-5** `LineTrait::{line, line_of_sight, approach}` on the board: the integer line with the
  game's tie rule (the lower tile index), symmetric; a table for width 15 within distance 6.
- **N-7** `DirectionTrait::{rotate, arc}`, `Arc`, the conversions between `Direction` and
  `EdgeDirection`; `GeometryTrait::{distance_between, chunk_of, to_hex, from_hex, index_to_hex,
  hex_to_index}`; `LayoutTrait::neighbor_direction`.
- **N-8** `Bfs::flood` with its `depth`, and `FloodTrait::{next_step, next_step_away, distance}`:
  one flood per tick gives every walker its next step.
- Gas: the measured budget of every test (1,853) in `docs/GAS.md`; at its end, the functions
  whose measurement was accepted above the plan's range, with their reasons. Per-function
  figures are in the task reports (`docs/reports/`).

### Deviations

59 documented deviations (`docs/DEVIATIONS.md`): `i32` overflow panics where `hexx` wraps,
iterators returned as spans, and `line_to`'s integer tie rule, which differs from `hexx`'s `f32`
line at ties and at large coordinates; every differing pair of the compared sets (the 15 × 16
window, 7 × 7, the seeded sample and the adversarial large-coordinate pairs) is listed in
`docs/deviations/line_ties.md`.

### Results changed

Against `origami_hexmap` 1.8.0: none; every function taken over returns 1.8.0's result on the
equality and panic tests of `crates/takeover_tests`. Three
helpers are renamed, a change of name only: `edge_neighbours` → `edge_neighbors`,
`neighbour_in` → `neighbor_in`, `neighbour_mask` → `neighbor_mask`. First pre-release of `hexx`:
no earlier version to compare.
