# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). One entry per version, four
fixed headings (plan §9.4): *Parity* (items ported, counterparts, exclusions, the percentage),
*Extensions* (new or changed functions, with their need), *Deviations* (new or changed documented
differences from `hexx`), *Results changed* (any numeric change, with the affected functions and
the reason; empty on a PATCH). The game reads the last heading to know whether its test vectors
move. Versions before `0.1.0` are pre-releases (`0.1.0-rc.N`); nothing is published yet
(decision L-G2: publication needs the owner's explicit go).

## [Unreleased]

Toolchain (LIB-04f, D-180): the next release candidate, `0.1.0-rc.2`, is built with Scarb 2.20.1 and
starknet-foundry 0.64.0 (Cairo 2.20.0); `0.1.0-rc.1` stays as published, built on Scarb 2.19.4. Gas
snapshots, budgets and class sizes are re-measured on the new toolchain (`docs/GAS.md`).

Release check (`.github/workflows/release-check.yml`, no change to the package): its reports are
written outside the checkout and the tree is checked clean before `scarb package` (run
`36809681077` of `0.1.0-rc.1` had passed the full gate, then `scarb package` refused an untracked
report). Codex review: none — Codex unavailable (quota), merged by the project manager's decision
of 2026-10-01 under the standard's exception.

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
