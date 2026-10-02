# LIB-06 M2-T1 — `VertexDirection`, `DirectionWay`, the rest of `EdgeDirection`, the direction operators

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T1 directions` · Profile: `impl-sonnet` (a port item by item on
`u8` indices, every item checked against vectors from the crate, exhaustive on its domain).
Review: `review-opus`. Audit: **none** (D-177: no value, access control or randomness; the domain
is 6 directions × 12 rotations and the vectors cover it exhaustively, so nothing is left that only
an audit would prove; the release M2-R carries the one audit of the published interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T0 is merged** (`DIAGONAL_COORDS`, `Hex::mul_scalar`, `const_add`). **Runs
alone**: M2-T2 and M2-T3 start after it.

## Goal

After this task the library has the second direction type of `hexx`, `VertexDirection` (the six
diagonals), the enum `DirectionWay<T>` that `Hex::way_to` and `diagonal_way_to` return (M2-T2), the
links between edge and vertex directions, and the operators of both direction types. It is the
task M2-T1 of plan §8, L-M2.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-143, D-167, the accepted
   figures), then §8 L-M2 (row "Tasks…": M2-T1), §3.2 (two direction types, the north-up note,
   `hexx`'s `clockwise` sense kept), §4.4 (the rows of `direction`: every row marked L-M2), §4.3
   (`direction`: all 36 pairs, all rotations 0..=11, exhaustive).
2. What exists: `crates/hexx/src/direction.cairo`, `direction/edge_direction.cairo` (the L-M1 items,
   the style to follow), `hex.cairo` after M2-T0, `tools/refgen/src/direction.rs` and
   `specs/direction.toml`, `crates/consumer/src/mirror_directions.cairo` (scaffold of M2-T0).
3. The pinned `hexx` 0.25.0: `src/direction/{vertex_direction,way,impls}.rs`,
   `edge_direction.rs:571-640`.

## Scope

**In**

1. `direction/vertex_direction.cairo`: `VertexDirection { index: u8 }` (private field, derives as
   `EdgeDirection`), its 36 compass constants verbatim (`vertex_direction.rs:78-201`, north-up note
   as on `EdgeDirection`), `ALL_DIRECTIONS`, `iter` as `ALL_DIRECTIONS.span()`, `index`, `into_hex`
   (reads `DIAGONAL_COORDS`), `const_neg`, `clockwise`, `counter_clockwise`, `rotate_ccw`,
   `rotate_cw`, `direction_ccw`, `edge_ccw`, `direction_cw`, `edge_cw`, `edge_directions`,
   `Into<VertexDirection, Hex>`, and a manual `Debug` printing what `hexx`'s does (`:637`). The 18
   angle functions are excluded (§4.4): absent.
2. `direction/edge_direction.cairo`, additions: `diagonal_ccw`, `vertex_ccw`, `diagonal_cw`,
   `vertex_cw`, `vertex_directions` (`edge_direction.rs:571-623`), and the derived `Debug`
   replaced by a manual one printing what `hexx`'s does (`:635`). Nothing of L-M1 changes.
3. `direction/way.cairo`: `DirectionWay<T> { Single: T, Tie: [T; 2] }` (plan §3.2), `unwrap`,
   `contains`, `map`, `Into<T, DirectionWay<T>>` and `Into<[T; 2], DirectionWay<T>>` (the two
   `From` impls), and the crate-private `way_from(is_neg, eq_left, eq_right, dir)` (`way.rs:
   109-118`) that M2-T2 calls, for both direction types (the private trait `Way` of `hexx` is not
   public and is not in the table: implement its two methods however fits, without a public
   item). **`map` takes a closure** with the bound corelib uses for `Option::map` in Cairo 2.19
   (`F, +Drop<F>, +core::ops::Fn<F, (T,)>[Output: U]`; `Fn`, not `FnOnce`, since `Tie` calls it
   twice): plan §4.4 left "function pointer or closure" to LIB-04, which did not decide; this brief
   decides it (what would reverse it: a toolchain that refuses the bound — then escalate, do not
   fall back silently). `PartialEq<T> for DirectionWay<T>` has no Cairo form (`PartialEq` is
   homogeneous): its body is `contains`, which the parity table maps to it since M2-T0.
4. `direction/impls.cairo`: `Neg` for both types (`impls.rs:5, 13`), `mul_scalar(self, rhs: i32)
   -> Hex` for both (the counterparts of `Mul<i32>`, `:53-67`, calling `Hex::mul_scalar` of M2-T0).
   `Shl<u8>`/`Shr<u8>` have nothing to add (§4.4: `rotate_ccw`/`rotate_cw` are their bodies).
   Where Cairo needs the named methods on a trait in this file, name it `EdgeDirectionOpsTrait`
   and `VertexDirectionOpsTrait` (D-143); if the parity script does not attribute them to their
   type, that is an escalation, not a script edit.
5. `direction.cairo`: the `pub mod` lines of the three new files; `lib.cairo`: the re-exports of
   `VertexDirection` and `DirectionWay` (plan §2.4) **in the `direction` block only**.
6. Golden vectors: extend `tools/refgen/src/direction.rs` and `specs/direction.toml` with every
   item above, **exhaustive**: every direction, every rotation count `0..=11` and 255, every pair
   for `contains` and the `Tie` forms, `map` on both variants, `Debug` strings compared with
   `format!("{:?}")`; `gen direction` rewrites `crates/hexx/tests/golden_direction.cairo`.
7. Tests in their modules (D-167): unit tests and benches in each file's `#[cfg(test)] mod tests`.
   An oracle in the tests for each rotation: the index arithmetic written plainly (`(i + n) % 6`)
   against the method, on every index and count `0..=255`.
8. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_directions.cairo` (contract `HexxDirections`); the generated
   documents and snapshots regenerated.

**Targets** (not budgets; derived from the L-M1 measurements in `gas/hexx.snap` at your base, per
call by the method of `src/tests/bench_mirror.cairo`; if LIB-04f re-measured them, use those and
say so): `EdgeDirection::into_hex` 1,411, `clockwise` 1,460, `counter_clockwise` 1,868,
`rotate_ccw` at 255 steps 2,217, 1,030 per `i32`/`u32` operation (`Hex::z`), `Hex::mul_scalar` as
measured by M2-T0. `U = ceil(1.25 × L)`. An item not listed: its `L` and `U` by the same rule in its
bench's doc comment before its first measurement; constants, `index`, `iter` need no bench.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `VertexDirection::into_hex` | any | 1,411 (one lookup, as `EdgeDirection`) | [1,411, 1,764] |
| `VertexDirection::{const_neg, clockwise, counter_clockwise}`, `direction_cw/ccw`, `edge_cw/ccw`, `EdgeDirection::{diagonal_cw/ccw, vertex_cw/ccw}` | any | 1,868 (as `counter_clockwise`) | [1,868, 2,335] |
| `VertexDirection::rotate_cw`, `rotate_ccw` | `steps = 255` | 2,217 | [2,217, 2,772] |
| `mul_scalar` (both types) | any | 1,411 + M2-T0's `Hex::mul_scalar` (2,930 if not yet measured) = 4,341 | [4,341, 5,427] |
| `DirectionWay::contains` | `Tie`, absent | 2,060 (2 comparisons) | [2,060, 2,575] |
| `way_from` | `Tie` | 1,785 (`const_neg`) + 1,868 + 1,030 = 4,683 | [4,683, 5,854] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4). Between
`U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the operations
that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle is a stop.

**Out**: `Hex::way_to`, `diagonal_way_to` and every other `Hex` item (M2-T2, M2-T3); `GridEdge`,
`GridVertex` (M2-T7); the board's `Direction` and its conversions (unchanged); any change of an
L-M1 item's results; `scripts/**`; `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/direction.cairo`, `crates/hexx/src/direction/edge_direction.cairo`
(Scope 2), new files `crates/hexx/src/direction/{vertex_direction,way,impls}.cairo`;
`crates/hexx/src/lib.cairo` (the `direction` block, Scope 5); `crates/hexx/tests/golden_direction.cairo`;
`tools/refgen/src/direction.rs`, `tools/refgen/specs/direction.toml`;
`crates/consumer/src/mirror_directions.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Provided: `VertexDirection` and `VertexDirectionTrait` with the items of Scope 1;
`EdgeDirectionTrait::{diagonal_cw, diagonal_ccw, vertex_cw, vertex_ccw, vertex_directions}`;
`DirectionWay<T>` with `unwrap`, `contains`, `map`, and `way_from` (crate) for both types; `Neg` and
`mul_scalar(self, rhs: i32) -> Hex` for both types. Consumed by M2-T2 (`way_to`, `diagonal_way_to`,
`all_diagonals`, `rectiline_to`), M2-T3 (`add_diagonal`), M2-T4 (`custom_ring`, the wedges),
M2-T5 (`corners`), M2-T7 (`GridEdge`, `GridVertex`).

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 to 4 exists with its `hexx` name and passes its exhaustive golden
      vectors; `cargo run -- check` is green; the rotation oracles pass on their whole domain.
- [ ] AC-2 `--check-release L-M2 --report-only` lists no item of `VertexDirection`, `DirectionWay`,
      nor the L-M2 items of `EdgeDirection`; `api_parity.py --check` and `deviations.py --check`
      pass.
- [ ] AC-3 Scoped (D-143), tests in their modules (D-167), no free function.
- [ ] AC-4 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-5 Nothing outside the allowlist was written.

## Measurements (programme rule, 2026-10-02)

Every committed pin — `gas/hexx.snap`, `gas/bytecode.size`, and any class hash — is generated and
checked **on Linux only** (the VPS or CI), never on the Mac, with the single-thread build of D-176
that the scripts apply. A heavy build may run tests on the Mac; a Mac/Linux difference is reported
with both figures, never as a regression. **Never state a class hash as reproducible across
machines.**

## Shared generated files

`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`
and `gas/bytecode.size` are regenerated, never edited or merged by hand. If `main` moves under your
open pull request and they conflict, merge `origin/main` into your branch (a merge commit; never a
rebase), regenerate them with their scripts on Linux, and push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx direction::`;
`cd tools/refgen && cargo run -- gen direction && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

Each item against `hexx` 0.25.0 in the source (the 36 constants and their indices, the sense of
every rotation, `edge_directions` order, `way_from`'s tie order); the vectors regenerated from the
pinned crate equal the committed ones and are exhaustive; `map`'s closure bound; the north-up note;
the organisation lens (D-143, D-167).

## Report

As COMMON.md §7, with the targets table beside the measurements.
