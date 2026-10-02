# LIB-06 M2-T6 — `shapes`: parallelogram, triangle, hexagon, rombus, the two rectangles

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T6 shapes` · Profile: `impl-sonnet` (six small shapes, each a struct
with `coords` and a free function, ported against the crate's vectors). Review: `review-opus`.
Audit: **none** (D-177: no value, access control or randomness; the release M2-R carries the one
audit of the published interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T2 is merged** (and so after M2-T0 and M2-T1). **Runs in parallel with M2-T4,
M2-T5 and M2-T7** (disjoint files).

## Goal

After this task `hexx::shapes` gives the coordinates of the six shapes of `hexx`, each as a struct
whose `coords` returns a `Span<Hex>` and as a free function of the same module. It is the task
M2-T6 of plan §8, L-M2. `shapes::hexagon` is the coordinate form of the board's bitmap
`HexagonTrait::hexagon` (§2.4, §6.7): same geometric meaning, different types.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-143), then §8 L-M2 (row
   "Tasks…": M2-T6), §4.4 (the rows of `shapes`), §2.4 (the three forms of `hexagon`), §4.3
   (`shapes`: radii `0..=6` around 8 centres, spans compared element by element).
2. What exists: `hex.cairo` after M2-T0 and M2-T2 (`range`, `const_add`, `wedge_count`), the
   scaffolded `shapes.cairo`, `tools/refgen/src/shapes.rs`, `crates/consumer/src/mirror_shapes.cairo`,
   `crates/hexx/src/board/hexagon.cairo` (the board's `HexagonTrait`, untouched).
3. The pinned `hexx` 0.25.0: `src/shapes.rs`.

## Scope

**In**

1. `shapes.cairo`, the six structs with their public fields and `hexx`'s `Default` values (manual
   `Default` impls where `hexx`'s are not the zero value): `Parallelogram { min, max }`,
   `Triangle { size }`, `Hexagon { center, radius }`, `Rombus { origin, rows, columns }`,
   `PointyRectangle { left, right, top, bottom }`, `FlatRectangle { left, right, top, bottom }`;
   their methods in one trait each, **named `<Struct>Trait`** (`ParallelogramTrait`, …,
   `HexagonTrait`: the parity script scopes a method by its trait's name minus `Trait`, so another
   name would read `missing`): `new` where `hexx` has one (`Parallelogram`, `Triangle`, `Hexagon`)
   and `coords(self) -> Span<Hex>` on all six, in `hexx`'s order and length, empty shapes
   included. `shapes::HexagonTrait` and `board::hexagon::HexagonTrait` live in different modules
   and are not re-exported at the root: say so in both doc comments.
2. The six free functions `parallelogram`, `triangle`, `hexagon`, `rombus`, `pointy_rectangle`,
   `flat_rectangle`, with `hexx`'s parameters (`flat_rectangle([left, right, top, bottom]: [i32;
   4])` as `hexx` takes an array), each returning `Span<Hex>`. **They are free functions by
   decision of this brief**, each with the written reason D-143 asks for next to it: it mirrors the
   free function of `hexx::shapes` at the same path (the mirror keeps `hexx`'s names and paths,
   AGENTS.md principle 8). What would reverse it: the orchestrator ruling that D-143 wants them on a
   trait; then they move to a `ShapesTrait` and the parity map needs an entry (an escalation).
3. Golden vectors: `tools/refgen/src/shapes.rs` (replace M2-T0's placeholder body) and
   `specs/shapes.toml`: each shape at sizes `0..=6` around 8 centres or origins (§4.3), negative
   bounds for the rectangles, `rows`/`columns` of 0 for the rombus, the `Default` of each struct;
   spans compared element by element. Golden file `crates/hexx/tests/golden_shapes.cairo`.
4. Oracles in the tests (D-167, in the module): each `coords` as a set against its per-hex
   definition (`hexagon`: `distance_to ≤ radius`, equal to `Hex::range` element by element;
   `parallelogram`: the box `min ≤ (x, y) ≤ max`; `triangle`: `x ≥ 0`, `y ≥ 0`, `x + y ≤ size`; the rectangles: the offset bounds through `to_offset_coordinates` of L-M1,
   `OffsetHexMode::Odd` with `Pointy` or `Flat` — `hexx` shifts by `y >> 1` and `x >> 1`, which is
   `floor(v / 2)`, the `Odd` offset), with the count of each shape checked against its closed form.
   **Regression case**: `hexx`'s `y >> 1` floors on a negative odd `y` (`-3 >> 1 = -2`) where
   Cairo's `i32` division truncates (`-3 / 2 = -1`); a rectangle with `top = -3` and one with
   `left = -3` are in the vectors and must match. A rectangle or parallelogram whose bounds cross
   (`right < left`) is the empty span.
5. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_shapes.cairo` (contract `HexxShapes`); the generated
   documents and snapshots regenerated.

**Targets** (not budgets; from the L-M1 measurements in `gas/hexx.snap` at your base by the method
of `src/tests/bench_mirror.cairo`; if LIB-04f re-measured them, use those and say so): **7,358 per
element of a span built by a loop** (`line_to` at `N = 22`: 169,230 for 23 elements). `U = ceil(1.25
× L)`. An item not listed: its `L` and `U` by the same rule in its bench's doc comment before its
first measurement; `new` and `Default` need no bench.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `hexagon`, `Hexagon::coords` | radius 6 (127 hexes) | 127 × 7,358 = 934,466 | [934,466, 1,168,083] |
| `parallelogram`, `rombus`, `pointy_rectangle`, `flat_rectangle` and their `coords` | 7 × 7 (49 hexes) | 49 × 7,358 = 360,542 | [360,542, 450,678] |
| `triangle`, `Triangle::coords` | size 6 (28 hexes) | 28 × 7,358 = 206,024 | [206,024, 257,530] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle
is a stop.

**Out**: the board's `HexagonTrait` and `LayoutTrait::hexagon` (extensions, unchanged); `range`
(M2-T2); any change of an L-M1 or earlier L-M2 result; `scripts/**` (a parity row the script cannot
match: an escalation); `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/shapes.cairo`; `crates/hexx/tests/golden_shapes.cairo`;
`tools/refgen/src/shapes.rs`, `tools/refgen/specs/shapes.toml`;
`crates/consumer/src/mirror_shapes.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Consumed: L-M1 (`HexTrait::new`, `x`, `y`, `to_offset_coordinates` in the tests), M2-T0
(`const_add`, `wedge_count`), M2-T2 (`range`). Provided: `hexx::shapes::{Parallelogram, Triangle,
Hexagon, Rombus, PointyRectangle, FlatRectangle}`, their traits, and the six free functions;
nothing of L-M2 consumes them.

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 and 2 exists with its `hexx` name and passes its golden vectors
      element by element; `cargo run -- check` is green.
- [ ] AC-2 The oracles of Scope 4 pass on their stated domains.
- [ ] AC-3 `--check-release L-M2 --report-only` lists no item of `shapes`; `api_parity.py --check`
      and `deviations.py --check` pass.
- [ ] AC-4 Scoped (D-143) but for the six free functions, each with its written reason; tests in
      the module (D-167).
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
open pull request and they conflict (M2-T4, M2-T5 and M2-T7 run beside you), merge `origin/main`
into your branch (a merge commit; never a rebase), regenerate them with their scripts on Linux, and
push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx shapes::`;
`cd tools/refgen && cargo run -- gen shapes && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

Each shape against `hexx` 0.25.0 (iteration order, inclusive bounds, empty shapes, the `Default`
values); the free functions' written reasons; the trait names; the vectors regenerated from the
pinned crate equal the committed ones; the oracles; the organisation lens.

## Report

As COMMON.md §7, with the targets table beside the measurements.
