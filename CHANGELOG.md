# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). One entry per version, four
fixed headings (plan §9.4): *Parity* (items ported, counterparts, exclusions, the percentage),
*Extensions* (new or changed functions, with their need), *Deviations* (new or changed documented
differences from `hexx`), *Results changed* (any numeric change, with the affected functions and
the reason; empty on a PATCH). The game reads the last heading to know whether its test vectors
move. Versions before `0.1.0` are pre-releases (`0.1.0-rc.N`); nothing is published yet
(decision L-G2: publication needs the owner's explicit go).

## [Unreleased]

## [0.3.0] — unreleased (dated at publication)

The third line of `hexx`: milestone L-M3, the algorithms of `hexx` 0.25.0 (`hexx::algorithms`) and
the companion package `hexx_glam` (the `glam` interop), which is new and versioned with `hexx`
(`0.3.0`, depending on `hexx = "0.3.0"`; it has no changelog of its own). Additive: nothing of
`0.2.0` changes. A stable version: published only after the owner's go (D-132 as narrowed,
`docs/RELEASING.md`), `hexx` first, then `hexx_glam`.

### Parity

350 items of `hexx` 0.25.0 ported and 22 renamed counterparts, 53.6 % of its 694 items
(`python3 scripts/api_parity.py --check`, `docs/API_PARITY.md`), against 344 and 19, 52.3 %, in
`0.2.0`; 322 items are `dropped`, each with its reason in the table, and none is `missing`
(`python3 scripts/api_parity.py --check-release L-M3` passes). Added, by module:

- `algorithms` (M3-T1, M3-T2): `field_of_movement`, `a_star` (`algorithms/pathfinding`),
  `range_fov` and `directional_fov` (`algorithms/fov`), over a `HexMap` and its cost classes.
- `hexx_glam` (M3-T3, new package): `HexGlamTrait::as_ivec2` and `as_ivec3` (ported), and the
  three conversions `From<Hex> for IVec2`, `From<Hex> for IVec3`, `From<IVec2> for Hex` as
  `Into` impls (`HexIntoIVec2`, `HexIntoIVec3`, `IVec2IntoHex`; renamed, 3 more than in `0.2.0`).

### Extensions

240 extension items listed in `docs/EXTENSIONS.md` (`python3 scripts/api_parity.py --extensions`),
the same as `0.2.0`. L-M3 adds no extension of `docs/EXTENSIONS.md`; its Cairo-only items are the
45 extra items of `docs/API_PARITY.md`.

### Deviations

329 documented deviations (`python3 scripts/deviations.py --check`, `docs/DEVIATIONS.md`), 9 more
than the 320 of `0.2.0`: one per algorithm, see that file for the new rows. `range_fov` and
`directional_fov` differ from `hexx` on lines where `hexx`'s `f32` rounding meets a tie: the
inputs are listed in `docs/deviations/fov_ties.md` (the line rule of the game is
`docs/deviations/line_ties.md`). The impls of `hexx_glam` must be imported by the consumer for
`.into()` to find them (`crates/hexx_glam/README.md`).

### Results changed

None. L-M3 adds items and changes no result of `0.2.0`.

## [0.2.0] — 2026-10-05

The second published line of `hexx`: milestone L-M2, the mirror of `hexx` 0.25.0 beyond what
L-M1 needed (`Hex`, the directions, the conversions, rings, bounds, shapes and the grid edges and
vertices). Additive: nothing of `0.1.0-rc.2` changes. A stable version: published only after the
owner's go (D-132 as narrowed, `docs/RELEASING.md`).

### Parity

344 items of `hexx` 0.25.0 ported and 19 renamed counterparts, 52.3 % of its 694 items
(`python3 scripts/api_parity.py --check`, `docs/API_PARITY.md`), against 67 and 2, 10.0 %, in
`0.1.0-rc.2`; 322 items are `dropped`, each with its reason in the table. 9 items are `missing`,
all of L-M3 (`hexx_glam` interop, the algorithms: `python3 scripts/api_parity.py --check-release
L-M2` passes). Added, by module:

- `hex`: the rest of `HexTrait` (M2-T2), the operators, swizzles, euclidean and convert items
  (M2-T3), the rings and wedges (`hex/rings`, M2-T4) and the grid edges and vertices
  (`hex/grid/{edge,vertex}`, M2-T7: `GridEdge`, `GridVertex`).
- `direction`: `VertexDirection` (all of it), `DirectionWay` and the rest of
  `EdgeDirection` (L-M1 carried its core), with their impls and rotations (M2-T1).
- `conversions`: `DoubledHexMode` and the doubled and hexmod conversions (M2-T3); the offset ones
  are L-M1's.
- `bounds`: `HexBounds` (M2-T5).
- `HexSpanExt` (`average`, `bounds`, `center`, the mirror of hexx's `HexIterExt`, `hex/iter`,
  M2-T5).
- `shapes`: the shape generators (M2-T6).

**Not ported, deferred:** `impl Sum`, `impl Sum<Hex>`, `impl Product`, `impl Product<Hex>` of
`Hex` (M2-T3, #107; `PLAN.md`, *Deferred*). They are recorded `dropped` in the parity table:
corelib's `core::iter::Sum` and `Product` need the experimental feature
`associated_item_constraints` in the published manifest. Reversible when the feature is stabilised
or enabled by decision.

### Extensions

240 extension items listed in `docs/EXTENSIONS.md` (`python3 scripts/api_parity.py --extensions`),
the same as `0.1.0-rc.2`. L-M2 adds no extension of `docs/EXTENSIONS.md`; its Cairo-only items
are the 46 extra items of `docs/API_PARITY.md`, 41 more than the 5 of `0.1.0-rc.2`.

### Deviations

320 documented deviations (`python3 scripts/deviations.py --check`, `docs/DEVIATIONS.md`), 261
more than the 59 of `0.1.0-rc.2`: see that file for the new rows. The texts of the deviations were
corrected after the parity audit of L-M2, and `HexSpanExt` is re-exported at `hexx::hex` and at
the crate root (#118). Two are of consumer interest:

- `DirectionWay::map` takes a closure (`Fn`, the bound of corelib's `Option::map`: a `Tie` calls it
  twice). **A closure in a library function puts a closure type into every consumer class that
  calls `DirectionWay::map`: the class hash of such a class depends on the build path until the
  upstream compiler issue 10359 (cairo#10359) ships in a Scarb.** A class that does not call `map`
  is unaffected, and so are its code and its gas. Class hashes are taken from CI only (programme
  build-root rule).
- `-direction` (`Neg`) needs `EdgeDirectionNeg` / `VertexDirectionNeg` imported from
  `hexx::direction::impls`; `const_neg` needs nothing. `map` spells its bound
  `impl Func: Fn<F, (T,)>` with `Func::Output`: the constraint form `Fn<F, (T,)>[Output: U]` needs an
  experimental feature in the consumer's manifest.

### Results changed

None. L-M2 adds items and changes no result of `0.1.0-rc.2`.

## [0.1.0-rc.2] — 2026-10-03

The second release candidate of `hexx`, the first built on Scarb 2.20.1. It adds needs N-1, N-2
and N-6 (`hexagon`, `hexagon_ring`), which `0.1.0-rc.1` lacked. Published only after the go of
D-132 (`docs/RELEASING.md`).

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

- rc.1's archive lacks the origami_hexmap and hexx licence notices; rc.2 corrects it.
- `Caver::smooth` (and `HexMapTrait::smooth`) ignores the bits of `grid` at or above `W * H` and clears
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
19 more than the 221 of `0.1.0-rc.1`. New public items, with their need:

- **N-1** `hexx::board::map::HexMapTrait::{new_cave_with_margins, smooth}` and
  `hexx::generators::caver::CaverTrait::{generate_with_margins, smooth}`: the cave automaton with
  frozen tiles; the ring of a chunk holds the tiles copied from its neighbours and never evolves,
  `smooth` also holds chosen tiles; rows have the global parity of the chunk, the four corners are
  wall. `hexx::generators::caver::errors::CAVER_DIMENSIONS_TOO_LARGE` is the new panic of the
  caver. `HexMapTrait::smooth` is in `board/map`, not in `generators/caver`.
- **N-2** `hexx::board::seams::{Side (East, West, North, South), SeamTrait::{side, openings,
  is_open_across}}` for the seams between chunks, `hexx::board::layout::LayoutTrait::new_odd`, a
  layout whose rows have the odd global parity, and the table
  `hexx::board::tables::ROW_FROM_16`.
- **N-6** `hexx::board::hexagon::HexagonTrait::{hexagon, hexagon_ring}`: the tiles within a radius
  of a tile, and those at exactly that radius. `Layout::hexagon` and `HexMapTrait::new_hexagon`
  were already in `0.1.0-rc.1`.

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
