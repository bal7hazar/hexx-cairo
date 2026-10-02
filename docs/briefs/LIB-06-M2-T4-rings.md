# LIB-06 M2-T4 — Rings, ring edges, wedges, spirals, and `circular_range_squared`

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T4 rings` · Profile: `impl-sonnet` (a port item by item; the order of
every span is `hexx`'s and the crate's vectors fix it element by element). Review: `review-opus`.
Audit: **none** (D-177: no value, access control or randomness; every span is compared with the
crate element by element; the release M2-R carries the one audit of the published interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T1, M2-T2 and M2-T3 are merged.** **Runs in parallel with M2-T5, M2-T6 and
M2-T7** (disjoint files).

## Goal

After this task `Hex` has every item of `src/hex/rings.rs`: rings in either sense from any start
direction, ring edges, wedges in their six forms, spirals, the cached forms as arrays, and the
integer counterpart of `circular_range`. It is the task M2-T4 of plan §8, L-M2.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §8 L-M2 (row "Tasks…": M2-T4,
   and why `circular_range_squared` is here and not in M2-T3), §4.4 (the rows of `hex` — rings,
   wedges, spirals; and `circular_range(f32)`), §4.3 (`rings`: radii `0..=6` around 8 centres,
   spans compared element by element), §2.4 (`Hex::ring` and `HexMap::ring` are different things).
2. What exists: `hex.cairo` after M2-T0 and M2-T2 (`ring_count`, `wedge_count`, `range`,
   `diagonal_way_to`, `way_to`), `direction/*` after M2-T1, `hex/euclidean.cairo` after M2-T3, the
   scaffolded `hex/rings.cairo`, `tools/refgen/src/rings.rs`, `crates/consumer/src/mirror_rings.cairo`.
3. The pinned `hexx` 0.25.0, `src/hex/rings.rs` in full, `src/hex/euclidean.rs:110-125`.

## Scope

**In**

1. `hex/rings.cairo`, trait `HexRingsTrait` (D-143), every public item of `src/hex/rings.rs` but
   `ring_count` and `wedge_count` (M2-T0): `custom_ring`, `ring`, `rings`, `custom_rings`,
   `custom_ring_edge`, `ring_edge`, `ring_edges`, `custom_ring_edges`, `custom_wedge`,
   `custom_wedge_to`, `custom_full_wedge`, `wedge`, `wedge_to`, `full_wedge`, `corner_wedge`,
   `corner_wedge_to`, `custom_spiral_range`, `spiral_range`, and the private helper
   `__vertex_dir_to_edge_dir` (not public). Iterators become `Span<Hex>`; an `impl Iterator<Item =
   u32>` of radii becomes `Span<u32>`; an iterator of `Vec<Hex>` becomes `Span<Span<Hex>>`. Every
   span keeps `hexx`'s order and length, radius 0 included.
2. The cached forms (counterparts, §4.4): `cached_custom_ring_edges`, `cached_ring_edges`,
   `cached_rings`, `cached_custom_rings` — the const generic `RANGE` becomes a runtime
   `range: usize` (or `u32`, say which), returning `Span<Span<Hex>>`; each documents what it
   replaces under `#### Deviations`.
3. **`circular_range_squared(self, range_squared: i32) -> Span<Hex>`** (the signature of §4.4), the counterpart of
   `circular_range(f32)` (`euclidean.rs:110`), contract (normative): for `range_squared = r²` with
   `r` an integer in `0..=40`, it equals `hexx`'s `circular_range(r as f32)` element by element
   (the hexes of `self.range(r + r / 6)` whose `squared_euclidean_distance_to` is at most `r²`, in
   `range`'s order); for any other `range_squared`, it is the set `{h : squared_euclidean_distance
   (self, h) ≤ range_squared}` in `range`'s order over a radius you prove large enough (a hex whose
   squared Euclidean distance is at most `s` lies within hex distance `ceil(2·sqrt(s/3))`: prove the
   bound you use in a test over `s ∈ 0..=1,700`). A negative `range_squared` returns the empty span,
   as `hexx` does for a negative `range` (the radius saturates to 0 and no hex passes the filter).
4. Golden vectors: `tools/refgen/src/rings.rs` (replace M2-T0's placeholder body) and
   `specs/rings.toml`: every item at radii `0..=6` around 8 centres (§4.3), every start direction
   and both senses for the `custom_` forms, every `VertexDirection` for the wedges and ring edges,
   `wedge_to`/`custom_wedge_to`/`corner_wedge_to` on every ordered pair of 8 points, the radii spans
   `[0..=6]`, `[3, 1, 5]` and the empty span, `circular_range` at `r ∈ 0..=12` and at 40 around 2
   centres; spans compared element by element. Golden file `crates/hexx/tests/golden_rings.cairo`.
5. Oracles in the tests (D-167, in the module): `ring` against the per-hex definition (the hexes at
   `distance_to = r`, as a set) for `r ∈ 0..=10`; `spiral_range(0..=r)` as a set equals `range(r)`;
   each wedge as a set against its geometric definition (the hexes whose `diagonal_way_to` from the
   centre contains the direction, at the stated radii); `circular_range_squared` against the per-hex
   filter of Scope 3 on `range(r + r / 6 + 1)`.
6. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_rings.cairo` (contract `HexxRings`); the generated documents
   and snapshots regenerated.

**Targets** (not budgets; from the L-M1 measurements in `gas/hexx.snap` at your base by the method
of `src/tests/bench_mirror.cairo`, and the L-M2 tasks' measurements where they exist; if LIB-04f
re-measured them, use those and say so): **7,358 per element of a span built by a loop**
(`line_to` at `N = 22`: 169,230 for 23 elements), 1,030 per `i32`/`u32` operation,
`squared_euclidean_distance_to` as measured by M2-T3 (8,080 if not measured). `U = ceil(1.25 × L)`.
An item not listed: its `L` and `U` by the same rule in its bench's doc comment before its first
measurement.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `ring`, `custom_ring` | radius 6 (36 hexes) | 36 × 7,358 = 264,888 | [264,888, 331,110] |
| `full_wedge` | radius 6 (`wedge_count(6)` = 28 hexes) | 28 × 7,358 = 206,024 | [206,024, 257,530] |
| `spiral_range`, `cached_rings` | radii `0..=6` (127 hexes) | 127 × 7,358 = 934,466 | [934,466, 1,168,083] |
| `circular_range_squared` | `range_squared = 36` (`range(7)`, 169 hexes) | 169 × (7,358 + 8,080 + 1,030) = 2,783,092 | [2,783,092, 3,478,865] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle
is a stop; so is a `circular_range` vector the contract of Scope 3 does not reproduce.

**Out**: `ring_count`, `wedge_count` (M2-T0); `range`, `xrange` (M2-T2); the board's
`HexMapTrait::ring` and `HexagonTrait::hexagon_ring` (unchanged extensions); any change of an L-M1
or earlier L-M2 result; `scripts/**`; `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/hex/rings.cairo`; `crates/hexx/tests/golden_rings.cairo`;
`tools/refgen/src/rings.rs`, `tools/refgen/specs/rings.toml`; `crates/consumer/src/mirror_rings.cairo`;
`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`,
`gas/bytecode.size`.

## Interfaces

Consumed: M2-T0 (`const_add`, `ring_count`, `wedge_count`, `NEIGHBORS_COORDS` of L-M1), M2-T1
(direction `mul_scalar`, `direction_cw`, `direction_ccw`, the `EdgeDirection` rotations of L-M1),
M2-T2 (`range`, `diagonal_way_to`, `way_to`), M2-T3 (`squared_euclidean_distance_to`), L-M1
(`unsigned_distance_to`, `EdgeDirection::index`). Provided: `HexRingsTrait` with the items of
Scopes 1 to 3; nothing of L-M2 consumes them.

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 to 3 exists with its `hexx` name or its §4.4 counterpart and
      passes its golden vectors element by element; `cargo run -- check` is green.
- [ ] AC-2 The oracles of Scope 5 pass on their stated domains; `circular_range_squared` satisfies
      Scope 3, the radius bound proved by its test.
- [ ] AC-3 `--check-release L-M2 --report-only` lists no item of `rings.rs` nor `circular_range`;
      `api_parity.py --check` and `deviations.py --check` pass.
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
open pull request and they conflict (M2-T5, M2-T6 and M2-T7 run beside you), merge `origin/main`
into your branch (a merge commit; never a rebase), regenerate them with their scripts on Linux, and
push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx hex::rings`;
`cd tools/refgen && cargo run -- gen rings && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

The order of every span against `hexx` 0.25.0 (start point, sense, `start_dir`, radius 0, the
corner wedges); the cached forms' deviation notes; `circular_range_squared`'s contract and its
radius bound; the vectors regenerated from the pinned crate equal the committed ones; the oracles;
the organisation lens.

## Report

As COMMON.md §7, with the targets table beside the measurements.
