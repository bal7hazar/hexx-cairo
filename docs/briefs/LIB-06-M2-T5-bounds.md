# LIB-06 M2-T5 — `HexBounds` and `HexSpanExt`

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T5 bounds` · Profile: `impl-sonnet` (a port item by item against the
crate's vectors; the one deviation is inherited from M2-T3's `div_scalar`). Review: `review-opus`.
Audit: **none** (D-177: no value, access control or randomness; the release M2-R carries the one
audit of the published interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T1, M2-T2 and M2-T3 are merged.** **Runs in parallel with M2-T4, M2-T6 and
M2-T7** (disjoint files; `lib.cairo` is shared at line level only: your re-export goes in the
`bounds` block, M2-T7's in the `hex` block).

## Goal

After this task the library has `HexBounds`, a hexagonal area given by a centre and a radius, with
membership, wrapping, corners, intersection and the smallest bounds of a set of hexes; and
`HexSpanExt`, the counterpart on `Span<Hex>` of `hexx`'s `HexIterExt` (`average`, `center`,
`bounds`). It is the task M2-T5 of plan §8, L-M2.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §8 L-M2 (row "Tasks…": M2-T5),
   §4.4 (the rows of `bounds` and the `HexIterExt` row of "swizzles, conversions, euclidean,
   iterator helpers"), §4.3 (`bounds`: radii `0..=6` around 8 centres).
2. What exists: `hex.cairo` after M2-T0 and M2-T2 (`range`, `wrap_in_range`, `splat`,
   `range_count`, `to_cubic_array`), `hex/impls.cairo` after M2-T3 (`div_scalar`, the operators),
   `direction/impls.cairo` after M2-T1 (direction `mul_scalar`), `docs/deviations/div_scalar.md`,
   the scaffolded `bounds.cairo` and `hex/iter.cairo`, `tools/refgen/src/{bounds,iter}.rs`,
   `crates/consumer/src/mirror_bounds.cairo`.
3. The pinned `hexx` 0.25.0: `src/bounds.rs`, `src/hex/iter.rs`.

## Scope

**In**

1. `bounds.cairo`: `HexBounds { pub center: Hex, pub radius: u32 }` (derives as `Hex`), trait
   `HexBoundsTrait`: `new`, `from_radius`, `from_min_max` (`(min + max) / 2` is `hexx`'s
   `Div<i32>`, the rescale, so here `div_scalar(2)`: it **inherits M2-T3's deviation** and says so
   under `#### Deviations`), `positive_radius`, `is_in_bounds`, `hex_count` (`usize`), `hex_count32`
   (`u32`), `all_coords`, `intersecting_with` (`Span<Hex>`, `hexx`'s order: the smaller bounds'
   `all_coords` filtered by the larger's membership, the tie as `hexx` breaks it), `wrap_local`,
   `wrap`, `corners` (`[Hex; 6]` in `ALL_DIRECTIONS` order), and `from_span(Span<Hex>)`, the
   counterpart of `FromIterator<Hex>` (`:161`; the empty span gives `from_radius(0)`, as `hexx`),
   with `to_cubic_array` in place of `as_ivec3` (L-M3). `lib.cairo`: the re-export of `HexBounds`
   (plan §2.4) **in the `bounds` block only**.
2. `hex/iter.cairo`: the trait `HexSpanExt` (that exact name: the parity table maps `HexIterExt` to
   it) implemented for `Span<Hex>`: `average` (the sum, then `div_scalar(max(count, 1))`: inherits
   the deviation), `center` (`bounds().center`), `bounds` (`HexBoundsTrait::from_span`).
3. Golden vectors: `tools/refgen/src/{bounds,iter}.rs` (replace M2-T0's placeholder bodies) and
   their specs: every item at radii `0..=6` around 8 centres (§4.3); `from_min_max` on every
   ordered pair of 16 seeded points (pairs that hit a listed `div_scalar` deviation are marked as
   such, not dropped); `intersecting_with` on every pair of 8 bounds, equal radii included; `wrap`
   and `wrap_local` on 64 seeded points per bounds; `from_span`, `average`, `center` on the empty
   span, one point, the 64 seeded points and 16 seeded spans of `1..=32` points, including
   triangular shapes (the `trio_size` branch of `:161-230`). Golden files
   `crates/hexx/tests/golden_{bounds,iter}.cairo`.
4. Oracles in the tests (D-167, in each module): `from_span` returns bounds that contain every
   point of the span and whose radius minus one does not (minimality), on every seeded span;
   `is_in_bounds` against `unsigned_distance_to ≤ radius` over `all_coords` of a larger bounds;
   `intersecting_with` as a set against the per-hex membership of both bounds.
5. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_bounds.cairo` (contract `HexxBounds`); the generated
   documents and snapshots regenerated.

**Targets** (not budgets; from the L-M1 measurements in `gas/hexx.snap` at your base by the method
of `src/tests/bench_mirror.cairo`, and the L-M2 tasks' measurements where they exist — use those
first; if LIB-04f re-measured them, say so): 1,030 per `i32`/`u32` operation, `unsigned_distance_to`
11,043, `const_add` and `Add`/`Sub` 2,930, `to_cubic_array` 2,059, direction `mul_scalar` 4,341,
`div_scalar` 28,957, `wrap_in_range` 33,828, **7,358 per element of a span built by a loop**
(`line_to` at `N = 22`). `U = ceil(1.25 × L)`. An item not listed: its `L` and `U` by the same rule
in its bench's doc comment before its first measurement; constructors and field reads need no bench.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `is_in_bounds` | any | 11,043 + 1,030 = 12,073 | [12,073, 15,092] |
| `hex_count`, `hex_count32` | radius 64 | `range_count` 4,120 | [4,120, 5,150] |
| `wrap`, `wrap_local` | radius 6 | 2,930 + 33,828 + 2,930 = 39,688 | [39,688, 49,610] |
| `from_min_max` | any | 2,930 + 28,957 + 11,043 = 42,930 | [42,930, 53,663] |
| `corners` | radius 6 | 6 × (4,341 + 2,930) = 43,626 | [43,626, 54,533] |
| `all_coords` | radius 6 | 127 × 7,358 = 934,466 | [934,466, 1,168,083] |
| `intersecting_with` | radii 6 and 6 | 127 × (7,358 + 12,073) = 2,467,737 | [2,467,737, 3,084,672] |
| `from_span`, `HexSpanExt::{bounds, center}` | 16 points | 16 × (2,059 + 6,180 + 1,030) + 20 operations (20,600) = 168,904 | [168,904, 211,130] |
| `HexSpanExt::average` | 16 points | 16 × (2,930 + 1,030) + 28,957 = 92,317 | [92,317, 115,397] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle
is a stop.

**Out**: `div_scalar` and the operators (M2-T3: a deviation they carry is inherited, not fixed
here); `range`, `wrap_in_range` (M2-T2); `as_ivec3` (L-M3); any change of an L-M1 or earlier L-M2
result; `scripts/**` (a parity row the script cannot match: an escalation); `.github/**`;
`CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/bounds.cairo`, `crates/hexx/src/hex/iter.cairo`;
`crates/hexx/src/lib.cairo` (the `bounds` block, Scope 1); `crates/hexx/tests/golden_{bounds,iter}.cairo`;
`tools/refgen/src/{bounds,iter}.rs`, `tools/refgen/specs/{bounds,iter}.toml`;
`crates/consumer/src/mirror_bounds.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Consumed: M2-T0 (`splat`, `range_count`, `to_cubic_array`, `const_add`), M2-T1 (direction
`mul_scalar`), M2-T2 (`range`, `wrap_in_range`), M2-T3 (`div_scalar`, `Add`, `Sub`, `AddAssign`),
L-M1 (`unsigned_distance_to`, `ALL_DIRECTIONS`). Provided: `HexBounds`, `HexBoundsTrait`,
`HexSpanExt`; nothing of L-M2 consumes them.

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 and 2 exists with its `hexx` name or its §4.4 counterpart and
      passes its golden vectors; `cargo run -- check` is green.
- [ ] AC-2 The oracles of Scope 4 pass on their stated domains; the inherited deviation is written
      on `from_min_max` and `average`.
- [ ] AC-3 `--check-release L-M2 --report-only` lists no item of `HexBounds` nor `HexSpanExt`;
      `api_parity.py --check` and `deviations.py --check` pass.
- [ ] AC-4 Scoped (D-143), tests in their modules (D-167).
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
open pull request and they conflict (M2-T4, M2-T6 and M2-T7 run beside you), merge `origin/main`
into your branch (a merge commit; never a rebase), regenerate them with their scripts on Linux, and
push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx bounds::` and
`hex::iter`; `cd tools/refgen && cargo run -- gen bounds && cargo run -- gen iter && cargo run --
check`; `python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

Each item against `hexx` 0.25.0 (the centre placement of `FromIterator` on triangular sets, the
order of `intersecting_with` and its tie, `wrap` around a non-zero centre); the inherited deviation
written, not hidden; the vectors regenerated from the pinned crate equal the committed ones; the
oracles; the organisation lens.

## Report

As COMMON.md §7, with the targets table beside the measurements.
