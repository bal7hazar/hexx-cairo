# [Opus 5.5] LIB-02 hexx analysis — report

Pull request: https://github.com/bal7hazar/hexx-cairo/pull/2. Branch `docs/lib-02-hexx-analysis`,
commit `7a9f362`, one file: `docs/research/LIB-02-hexx-analysis.md`. CI (Markdown links) is green.
Not merged.

## Summary

1. `hexx` 0.25.0 is built on unbounded `i32` axial coordinates.
   - Most of it is floating point (layout, angles, `line_to`, `Div<i32>`, `to_lower_res`),
     meshes, Bevy and serde integrations, or heap-allocated sets (rings, field of view, A*,
     field of movement).
   - It has no board, no bitmap, no generator and no flood with distance layers.
2. `origami_hexmap` 1.8.0 is a bit-parallel engine on boards held in one felt, with gas
   budgets and scalar oracles. Every public function is listed with its file and line.
3. Conventions:
   - `origami_hexmap` is `hexx`'s pointy `Even` offset grid, mirrored horizontally (`+x` points
     West).
   - The direction numbering 0 to 5 is identical in both crates.
   - `hexx`'s "clockwise" turns counter-clockwise on a north-up map.
   - `distance_to`, `range` and `ring` have the same names in both crates but different meanings.
4. N-5: `hexx`'s `line_to` has **no nudge**, so exact ties depend on `f32` and on translation.
   The report derives an exact integer line and a lookup-table form.
5. The game's rule for ties ("lower tile index") means: the southern tile, or on the same row
   the eastern one. It is symmetric, so it is a documented deviation from `hexx`.
6. N-3: an odd window origin puts the library on a different hex grid. Chunks are 15 rows high,
   an odd number, so half of them start on odd global rows. This affects N-1 and N-2, not
   assembly.
7. N-8: the BFS already stores layers, and its backtracking step is exactly "next step, lowest
   index", but it is crate-private. One flood is estimated at about 300–450k, against about 5.6M
   for eight `search_path` calls.
8. The table need → `hexx` → `origami_hexmap` → work is in §5.10 of the report. Costs from
   `GAS.md` are cited; the others are marked as estimates.
9. Options A to D are assessed on dependency, parity table, users and maintenance.
10. Recommendation: **port partly**, landing in **B** (`origami_hexmap` extended in place).

## What was read and what was not

**Read in full:**
- the 7 game documents listed in the brief;
- every `origami_hexmap` source file outside `src/tests/` (module docs and test names only
  there);
- `README.md`, and `GAS.md` sections L0, L1, L3, L4, L8 and P1;
- `hexx`'s `Cargo.toml`, `hex/`, `direction/`, `conversions`, `algorithms/`, `bounds`, `layout`
  and `orientation`.

**Read through a sub-agent's inventory, with key facts checked in person:**
- the rest of `hexx`: `storage/`, `mesh/` (public types only), `grid/`, `shapes`, examples and
  benches;
- the facts checked in person were `round`, `line_to`, the absence of a nudge, `Div<i32>`,
  `way_to`, `field_of_movement`, `a_star` and `Cargo.toml`.

**Not read:**
- `GAS.md` sections L2, L5, L6 and L7 in detail;
- the bodies of the Bevy examples;
- `origami`'s other crates (out of scope).

No code was run and nothing was measured.

## Recommendation (three lines)

A port of `hexx` is **partly** relevant: only its integer geometric subset (directions and
rotation, the line, and range and ring as geometry), with `hexx` names and a parity table.
It lands in `origami_hexmap`, extended in place (option B). All of N-1 to N-8 go there as
additive functions, because they build on its private internals. `bal7hazar/hexx-cairo` keeps
the plans, the research and the parity-vector harness.

## Deviations from the brief

- **The nudge.** The brief asks how the game's tie-break compares with "the nudge `hexx`
  uses". `hexx` 0.25.0 uses no nudge. The report states this, with evidence, and compares the
  game's rule with `hexx`'s actual tie behaviour instead.
- **A partial sub-agent read.** Part of the `hexx` inventory came from a read-only research
  sub-agent. Every fact the conclusions depend on was verified directly in the source.

## Escalations

None. Only the allowlisted files were written. Nothing under `sources/` was changed.

## Open questions for the orchestrator

1. **N-1, margins.** Are the margins the chunk's own outer ring, copied from its neighbours, or
   the neighbours' tiles outside the chunk? The second does not fit one felt (17 × 17 = 289
   bits). This is a design ambiguity for the owner or LIB-03.
2. **Global axes.** Does global `+x` point East? The index of `origami_hexmap` has `+x` West.
   This has to be fixed before N-3 and the global distance.
3. **Sight beyond the window.** The window re-centres only when the adventurer comes within 3
   tiles of its edge. The adventurer can then be up to 4 tiles off centre, so sight of radius 6
   and ranged lines can leave the window. That is a game-design interplay, flagged, not a
   library question.
4. **Releases through `origami`.** Option B puts every L-M1 pre-release through an `origami`
   workspace release. Is that cadence acceptable for SPK-7?

## Fix loop 1

This loop answers the audit by GPT-6-Sol, as verified by the orchestrator. It is one new
commit, `67b7392`, on the same branch and pull request (#2), and it changes only
`docs/research/LIB-02-hexx-analysis.md`. CI (Markdown links) is green. Not merged.

1. **(major, AC-3) Part 2.1 now lists every public function of `origami_hexmap` by name, with
   its file and line.**
   - `src/types/u252.cairo` is split into four rows:
     - the type and inherent methods;
     - every conversion (`into`, `try_into`, `pack`, `unpack`);
     - arithmetic: `checked_add` `:320`, `checked_sub`, `checked_mul`, `add`, `sub`, `mul`,
       `div`, `rem`, and `wrapping_*`;
     - order, bits and constants: `lt`, `le`, `gt`, `ge`, `bitand`, `bitor`, `bitxor`, `zero`,
       `is_zero`, `is_non_zero` `:502`, `one`, `is_one`, `is_non_one`, `MIN`, `MAX`, and the
       derives.
   - Every other module was re-checked against the source. Added:
     - the line of each public impl;
     - each error constant by name and line;
     - the eight `Set` methods of `WideSet` and of `SmallSet`, each with its line;
     - the `bits.cairo` constants, each with its line;
     - the lines of the `HexPrinter` methods;
     - the derives of `HexMap` and `Direction`;
     - the conversion lines of `Direction`.
   - It now states which impls are private or `pub(crate)`.
   - Nothing public was found missing beyond these items.
2. **(major) §5.9, N-8: the two occupancy rules are now stated.**
   - **(a) One flood per tick**, on the occupancy frozen at the start of the tick. Current
     occupancy only filters each walker's candidate tiles. A walker can be routed toward a tile
     a previous walker just blocked, and cannot use a tile one just freed. Cost: 1 flood,
     about 300–450k.
   - **(b) Distances follow current occupancy**, with a new flood after each move. Cost: up to
     8 floods, about 2.1–2.5M.
   - The design's "one flood per tick, not one per goblin" implies (a). This is marked as a
     point for LIB-03 and the game to confirm.
   - The estimates in §5.9, the summary table §5.10, part 6 and the recommendation (L-M1
     item 6, and a new "LIB-03 must settle" item) are now consistent with it.
3. **(minor) §5.8: the arc table now has its six entries.** For values 0 to 5: front,
   front-side, rear-side, back, rear-side, front-side.
4. **(minor, AC-2) §1.10: the mesh entry now cites each file and its public symbols.** It is
   now six rows: `mod.rs`, `column_builder.rs`, `plane_builder.rs`, `heightmap_builder.rs`,
   `uv_mapping.rs` and `face.rs`.

## Fix loop 2

This loop answers audit pass 2 by GPT-6-Sol (PASS WITH FINDINGS). It is one new commit,
`2a47fbe`, on the same branch and pull request (#2), and it changes only
`docs/research/LIB-02-hexx-analysis.md`. CI (Markdown links) is green. Not merged.

5. **§3.1 no longer calls pointy `hexx`'s default.** It now says "with a pointy `hexx` layout
   and y up", and notes that `hexx` defaults to the flat orientation
   (`src/orientation.rs:127-129`). No other sentence called pointy the default: §1.6 and §3
   already say flat.
6. **The report no longer says `search_path_weighted` covers `a_star`.**
   - In the recommendation, "What stays out" now says that `search_path_weighted` covers the
     game's bounded tile-cost pathfinding (at most 3 cost classes,
     `hexmap:src/map.cairo:252-253`). It does not cover the full `a_star` semantics, an
     arbitrary cost for each directed step (`src/algorithms/pathfinding.rs:110`).
   - Section 4 is aligned in the same way.
   - §3.2 made no such claim and is unchanged.
