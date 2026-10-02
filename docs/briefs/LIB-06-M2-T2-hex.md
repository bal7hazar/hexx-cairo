# LIB-06 M2-T2 — The rest of `HexTrait`: diagonals, ways, rotations, ranges, resolutions

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T2 hex` · Profile: `impl-sonnet` (a port item by item against
vectors from the crate; one deviation already settled by the plan, `to_lower_res`). Review:
`review-opus`. Audit: **none** (D-177: no value, access control or randomness; every result is
checked against the crate's own vectors; the release M2-R carries the one audit of the published
interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T0 and M2-T1 are merged.** **Runs in parallel with M2-T3** (disjoint files;
neither calls the other: this task calls named methods, never an operator impl of M2-T3, plan §8).

## Goal

After this task `HexTrait` holds every item of `src/hex/mod.rs` that milestone L-M2 schedules:
diagonal neighbours, the ways and main directions to another hex, the rotations and reflections, the
rectilinear path, the ranges, the resolution changes and wrapping, and `hexx`'s `Debug`. It is the
task M2-T2 of plan §8, L-M2; M2-T4, M2-T5 and M2-T6 build on its `range` and `wrap_in_range`.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §8 L-M2 (row "Tasks…":
   M2-T2, and why the edge `T3 → T2` is dropped), §4.4 (the rows of `hex` — struct, constants,
   constructors: every row marked L-M2 that M2-T0 did not take), §3.1, §4.3 (`hex`: every pair for
   `way_to`, `rotate_*`, `reflect_*`, `to_lower_res(1..=6)`).
2. What exists: `hex.cairo` after M2-T0, `direction/{edge_direction,vertex_direction,way,impls}.cairo`
   after M2-T1, `tools/refgen/src/hex.rs` and `specs/hex.toml` after M2-T0,
   `crates/consumer/src/mirror_hex.cairo` (scaffold).
3. The pinned `hexx` 0.25.0, `src/hex/mod.rs:641-1195`.

## Scope

**In**

1. On `HexTrait` in `hex.cairo` (doc template `Mirrors …` / `#### Panics` / `#### Deviations` on
   each): `diagonal_neighbor_coord`, `add_diag_dir` (crate-private in `hexx`: `pub(crate)` or
   private here), `diagonal_neighbor`, `all_diagonals`; `neighbor_direction` (`Option<EdgeDirection>`,
   first match in `ALL_DIRECTIONS` order); `main_diagonal_to`, `diagonal_way_to`,
   `main_direction_to`, `way_to` (`DirectionWay<…>`, through M2-T1's `way_from`; written with
   `const_sub`, not the operator); `counter_clockwise`, `ccw_around`, `rotate_ccw`,
   `rotate_ccw_around`, `clockwise`, `cw_around`, `rotate_cw`, `rotate_cw_around`; `reflect_x`,
   `reflect_y`, `reflect_z`; `rectiline_to(self, other, clockwise: bool) -> Span<Hex>` (`count + 1`
   items, endpoints included, the order of `hexx`); `range(self, range: u32) -> Span<Hex>` and
   `xrange` (same order as `hexx`: `x` then `y`); `to_lower_res`, `to_higher_res`, `to_local`,
   `wrap_in_range`.
2. **`to_lower_res`, the deviation of §4.4**: exact floor division in place of `hexx`'s `f32`
   floor. Identical to `hexx` while every intermediate is exact in `f32` (`|value| < 2^24`); exact
   beyond. Documented under `#### Deviations` with that bound; `to_local` and `wrap_in_range`
   inherit it and say so.
3. `Hex`'s `Debug`: the derived one replaced by a manual impl printing what `hexx`'s prints
   (`:1189`: `x`, `y`, `z`).
4. Golden vectors: extend `tools/refgen/src/hex.rs` and `specs/hex.toml` (§4.3): every ordered pair
   of the 64 seeded points for `way_to`, `diagonal_way_to`, the `*_around` forms and
   `rectiline_to` (both senses); every point for the rotations at `m ∈ 0..=12` and 255, the
   reflections, `all_diagonals`, `neighbor_direction` against every neighbour and one non-neighbour;
   `range`/`xrange` at radii `0..=6` around 8 centres, spans compared element by element;
   `to_lower_res`, `to_higher_res`, `to_local`, `wrap_in_range` at radii `1..=6`; a seeded sample of
   points with `2^22 ≤ |value| < 2^24` where `hexx` is still exact, and the `i32` bounds where this
   port panics (`#[should_panic]`). `Debug` strings compared with `format!("{:?}")`.
5. Oracles in the tests (`grimworld:docs/CAIRO.md` §2): `range` against the per-hex definition
   (`distance_to ≤ r`, every hex of the square `[-r, r]²` around the centre) for radii `0..=8`;
   `rectiline_to` against its properties (length `distance + 1`, each step a neighbour, only the two
   directions of `main_diagonal_to(...).edge_directions()`); each `rotate_*` against `m` repeated
   single rotations. Tests in the module (D-167).
6. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_hex.cairo` (contract `HexxHex`); the generated documents and
   snapshots regenerated.

**Targets** (not budgets; from the L-M1 measurements in `gas/hexx.snap` at your base by the method
of `src/tests/bench_mirror.cairo`, and M2-T0's and M2-T1's measurements where they exist; if LIB-04f
re-measured them, use those and say so): 1,030 per `i32`/`u32` operation (`Hex::z`), `const_sub`
2,930, `to_cubic_array` and `const_neg` 2,059, `distance_to` 8,722, **7,358 per element of a span
built by a loop** (`line_to` at `N = 22`: 169,230 for 23 elements). `U = ceil(1.25 × L)`. An item not
listed: its `L` and `U` by the same rule in its bench's doc comment before its first measurement.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `way_to` | a tie | 2,930 + 2,059 + 14 operations (14,420) + `way_from` 4,683 = 24,092 | [24,092, 30,115] |
| `diagonal_way_to` | a tie | `way_to` minus 3 operations = 20,002 | [20,002, 25,003] |
| `neighbor_direction` | not a neighbour (6 tries) | 6 × (`neighbor` 4,341 + 1,030) = 32,226 | [32,226, 40,283] |
| `rotate_cw`, `rotate_ccw` | `m = 4` (two turns) | 2 × (2,059 + 2,060) + 1,100 (`% 6`) = 9,338 | [9,338, 11,673] |
| `rotate_cw_around` | `m = 4` | 9,338 + 2 × 2,930 = 15,198 | [15,198, 18,998] |
| `range` | radius 6 (127 hexes) | 127 × 7,358 = 934,466 | [934,466, 1,168,083] |
| `rectiline_to` | distance 20 | 21 × 7,358 + `way_to` 24,092 + `distance_to` 8,722 = 187,332 | [187,332, 234,165] |
| `to_lower_res` | radius 6 | 2,059 + `range_count` 4,120 + 16 operations (16,480) = 22,659 | [22,659, 28,324] |
| `to_local`, `wrap_in_range` | radius 6 | 22,659 + `to_higher_res` (2,059 + 6,180) + 2,930 = 33,828 | [33,828, 42,285] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle
is a stop.

**Out**: the operator impls, swizzles, Euclidean, packing and array conversions (M2-T3); rings,
wedges, spirals and `circular_range_squared` (M2-T4); `HexBounds` and `HexSpanExt` (M2-T5); shapes
(M2-T6); `Hex::all_edges`, `all_vertices` (M2-T7); any change of an L-M1 or M2-T0 item's results;
moving `src/tests/test_hex.cairo`; `scripts/**`; `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/hex.cairo` (additions, and the `Debug` of Scope 3);
`crates/hexx/tests/golden_hex.cairo`; `tools/refgen/src/hex.rs`, `tools/refgen/specs/hex.toml`;
`crates/consumer/src/mirror_hex.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Consumed: M2-T0's helpers, M2-T1's `VertexDirection`, `DirectionWay`, `way_from`, direction
`mul_scalar`, `edge_directions`. Provided: the items of Scope 1, in particular `range(self, range:
u32) -> Span<Hex>` (M2-T4's `circular_range_squared`, M2-T5's `all_coords`, M2-T6's `hexagon`),
`wrap_in_range(self, range: u32) -> Hex` (M2-T5's `wrap`), `diagonal_way_to` and `way_to` (M2-T4's
wedges).

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 and 3 exists with its `hexx` name and passes its golden vectors;
      `cargo run -- check` is green; the oracles of Scope 5 pass on their stated domains.
- [ ] AC-2 `to_lower_res` equals `hexx` on every vector below `2^24` and carries its deviation;
      `deviations.py --check` passes.
- [ ] AC-3 `--check-release L-M2 --report-only` lists none of these items; `api_parity.py --check`
      passes.
- [ ] AC-4 Scoped (D-143), tests in the module (D-167).
- [ ] AC-5 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-6 Nothing outside the allowlist was written.

## Measurements (programme rule, 2026-10-02)

Every committed pin — `gas/hexx.snap`, `gas/bytecode.size`, and any class hash — is generated and
checked **on Linux only** (the VPS or CI), never on the Mac, with the single-thread build of D-176
that the scripts apply. A heavy build may run tests on the Mac; a Mac/Linux difference is reported
with both figures, never as a regression. **Never state a class hash as reproducible across
machines.**

## Shared generated files

`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`
and `gas/bytecode.size` are regenerated, never edited or merged by hand. If `main` moves under your
open pull request and they conflict (M2-T3 runs beside you), merge `origin/main` into your branch
(a merge commit; never a rebase), regenerate them with their scripts on Linux, and push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx hex::`;
`cd tools/refgen && cargo run -- gen hex && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

Each item against `hexx` 0.25.0 in the source (the order of `range` and `rectiline_to`, the tie
directions of `way_to`, the rotation sense, `to_lower_res`'s floor on negative values); the vectors
regenerated from the pinned crate equal the committed ones; the oracles; the deviation written and
bounded; no operator of M2-T3 called; the organisation lens.

## Report

As COMMON.md §7, with the targets table beside the measurements.
