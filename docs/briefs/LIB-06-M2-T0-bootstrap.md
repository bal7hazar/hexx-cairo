# LIB-06 M2-T0 — The bootstrap of L-M2: shared `Hex` items and the module tree

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T0 bootstrap` · Profile: `impl-sonnet` (a port item by item, each
checked against vectors generated from the crate, plus a scaffold whose every line this brief
states). Review: `review-opus` (another model than the one that wrote it). Audit: **none** (D-177:
no value, access control or randomness; no published interface yet, the one audit of L-M2 is the
release's, M2-R).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after** `0.1.0` is released (plan §8, L-M2 "Depends on") and LIB-04f is merged (the
toolchain of `.tool-versions` at your base is the one you use). **Runs alone**: every other task of
L-M2 starts after this one is merged.

## Goal

After this task `Hex` has the constants, constructors and small helpers that every other task of
milestone L-M2 calls, and the repository has the empty module tree of L-M2, so that the seven
following tasks each own whole files and the four that run together never edit the same line of a
shared file. It is the task "M2-T0, the bootstrap" of plan §8, L-M2, plus the scaffold that makes the
plan's parallel groups possible.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (#43, D-143, D-167, the accepted
   figures of M1-T2), then §8 L-M2 (the row "Tasks, exclusive files, dependency edges": M2-T0, and
   the file split), §4.4 (the rows of `hex` — struct, constants, constructors; the rows this task
   ports), §3.1 (`i32`, overflow panics), §2.2 (the module tree), §2.4 (root re-exports), §4.2 and
   §4.3 (parity table, `refgen`), §1.1.
2. What exists: `crates/hexx/src/hex.cairo` (`HexTrait`, `HexImpl`, `NEIGHBORS_COORDS`, the private
   `HexMathTrait`), `crates/hexx/src/direction/edge_direction.cairo` (`into_hex`), `crates/hexx/
   src/lib.cairo`, `tools/refgen/` (README, `src/main.rs`, `src/hex.rs`, `specs/hex.toml`),
   `crates/consumer/src/lib.cairo` (`HexxMirror`), `src/tests/bench_mirror.cairo` (the method of
   the per-call figures), `scripts/api_parity.py` (`CAIRO_MODULE_OWNER`, `owner_of` in
   `parse_cairo`), `scripts/takeover_check.py` (`OWN_FILES`, `COVERED_DIRS`).
3. `python3 scripts/api_parity.py --check-release L-M2 --report-only`: 298 items of L-M2 missing at
   the writing of this brief.
4. The pinned source `hexx` 0.25.0 (the crate `tools/refgen` builds against; read-only).

## Scope

**In — the items** (all in `hex.cairo`, on `HexTrait` unless said otherwise; every public item with
the doc template `Mirrors …` / `#### Panics` / `#### Deviations`):

1. The constants `ORIGIN`, `ONE`, `NEG_ONE`, `X`, `NEG_X`, `Y`, `NEG_Y` (`src/hex/mod.rs:95-110`),
   `INCR_X`, `INCR_Y`, `INCR_Z`, `DECR_X`, `DECR_Y`, `DECR_Z` (`:113-124`, `[Hex; 2]`),
   `DIAGONAL_COORDS` (`:186`, `[Hex; 6]`).
2. `hex(x, y)` (`:89`) as a **free function** `hexx::hex::hex`, with the written reason next to it:
   it mirrors `hexx`'s free function at the same path (D-143 allows a free function with a written
   reason; plan §4.4 "imported from its module, as the house does for `vec3`"). Re-exported at the
   root as §2.4 says.
3. `splat`, `new_cubic` (panics `'Hex: cubic sum'` when `x + y + z != 0`), `from_array`,
   `to_array`, `to_cubic_array`, `const_neg`, `const_add`, `abs`, `min`, `max`, `dot`, `signum`.
4. `range_count` (public, `u32`) and `shift` (crate-private in `hexx`, `:1168`: `pub(crate)` here,
   not in the parity table), `ring_count` and `wedge_count` (`src/hex/rings.rs:540, 285`: pure
   arithmetic, kept on `HexTrait` here so that `hex/rings.cairo` of M2-T4 calls them; if the parity
   script attributes them to `Hex` from either file, they stay here).
5. `mul_scalar(self, rhs: i32) -> Hex`: the counterpart of `Mul<i32> for Hex` (`src/hex/impls.rs:
   174`), two `i32` products.
6. `neighbor_coord`, `add_dir`, `neighbor`, `all_neighbors` (`src/hex/mod.rs:633-666, 760`), on
   `EdgeDirection` and `NEIGHBORS_COORDS` of L-M1.

**In — the scaffold** (no function in it: a module of the scaffold holds its doc comment only,
which names the task that fills it; "no stubbed success" holds — nothing callable is written that
does not work):

7. `hex.cairo` declares `pub mod impls; pub mod rings; pub mod swizzle; pub mod euclidean; pub mod
   convert; pub mod iter; pub mod grid;` and creates those files; `hex/grid.cairo` declares `pub mod
   edge; pub mod vertex;` and creates them. `lib.cairo` declares `pub mod bounds;` and `pub mod
   shapes;` and creates `bounds.cairo` and `shapes.cairo`. **`lib.cairo` is laid out in one block
   per module, separated by a blank line** (`board`, `bounds`, `conversions`, `direction`,
   `finders`, `generators`, `hex`, `orientation`, `shapes`, `tests`), so that the re-export lines
   of M2-T1 (`direction` block), M2-T3 (`conversions` block), M2-T5 (`bounds` block) and M2-T7
   (`hex` block) never touch the same or adjacent lines. The `direction/` modules are M2-T1's, which
   runs alone: not scaffolded here.
8. `tools/refgen/src/main.rs`: the `mod` line and the dispatch arm of every generator of L-M2 that
   does not exist yet — `impls`, `swizzle`, `euclidean`, `convert` (M2-T3), `rings` (M2-T4),
   `bounds`, `iter` (M2-T5), `shapes` (M2-T6), `grid` (M2-T7) — each arm calling `<module>::emit`,
   and each `tools/refgen/src/<module>.rs` created with an `emit` of the **multi-file signature**
   of `line` and `hexagon` (`emit(spec, root) -> Result<Vec<(PathBuf, String)>, String>`, so that
   M2-T3 can write `docs/deviations/div_scalar.md` beside its golden file without touching
   `main.rs`) that returns `Err("<module>: written by M2-Tn")`. No spec file is added for them, so no `gen` or
   `check` run reaches that error; the owning task replaces the body and adds its spec. `hex` and
   `direction` already have their generators (M2-T2 extends `hex` after you; M2-T1 `direction`).
9. `crates/consumer`: the files `src/mirror_directions.cairo` (M2-T1), `src/mirror_hex.cairo`
   (M2-T2), `src/mirror_ops.cairo` (M2-T3), `src/mirror_rings.cairo` (M2-T4),
   `src/mirror_bounds.cairo` (M2-T5), `src/mirror_shapes.cairo` (M2-T6), `src/mirror_grid.cairo`
   (M2-T7), each with its doc comment only, and their `mod` lines in `src/lib.cairo`. Your own call
   sites go into `HexxMirror` in `src/lib.cairo`.
10. `scripts/takeover_check.py`: one `OWN_FILES` block, comment `L-M2 (LIB-06): golden vectors`,
    listing `tests/golden_{impls,swizzle,euclidean,convert,rings,bounds,iter,shapes,grid}.cairo`
    (a listed file that does not exist yet is harmless: the list is only read for files that do).
    Nothing else of that script.
11. `scripts/api_parity.py`, and only these changes, each with a unit test in
    `scripts/tests/test_api_parity.py`: (a) the `CAIRO_MODULE_OWNER` entries that attribute the
    Cairo modules of L-M2 to their owners — `("hex",)`, `("hex", "impls")`, `("hex", "rings")`,
    `("hex", "swizzle")`, `("hex", "euclidean")`, `("hex", "convert")` → `Hex`; `("hex", "iter")` →
    `HexSpanExt`; `("hex", "grid", "edge")` → `GridEdge`; `("hex", "grid", "vertex")` →
    `GridVertex`; `("bounds",)` → `HexBounds`; `("shapes",)` → `shapes` — so that a trait such as
    `HexRingsTrait` and the free functions `hex` and `shapes::*` count for their owner (today
    `owner_of` drops any trait whose name minus `Trait` is not an owner); (b) the two rows the
    generated table schedules for L-M2 although §4.4 excludes them: `Hex::Shl` (`Shl<Hex>`,
    `src/hex/impls.rs:528`) → `dropped`, reason as the other shifts; `Hex::lerp` (`:973`) →
    `dropped`, "`f32` parameter"; (c) `DirectionWay::PartialEq<T>` (`src/direction/way.rs:42`,
    whose body is `self.contains(other)`; Cairo's `PartialEq` is homogeneous) → `renamed`, with
    `contains` as its replacement, in the form of the `Shl<u8>` rule ("nothing to add"). **Every other row of `docs/API_PARITY.md` must be unchanged
    except the rows your items turn `ported`**: diff the table before and after and put the diff's
    summary in the report; a row that moves otherwise is a stop.

**In — tests and figures**

12. Golden vectors from the crate: extend `tools/refgen/src/hex.rs` and `specs/hex.toml` with every
    item of 1 to 6 on the inputs of §4.3 (the 64 seeded points, every pair where the item takes
    two; `range_count`, `ring_count`, `wedge_count` on `0..=64` and near the `u32` bound), the `i32`
    values near the bounds where `hexx` wraps and this port panics (`#[should_panic]`, §3.1); `gen`
    rewrites `crates/hexx/tests/golden_hex.cairo`, `-- check` is green.
13. Tests in the module (D-167): new unit tests in `hex.cairo`'s `#[cfg(test)] mod tests`; benches
    there too (no new file under `src/tests/`, no edit of `src/tests.cairo`). The existing
    `src/tests/test_hex.cairo` and `bench_mirror.cairo` stay where they are.
14. Budgets at `ceil(1.05 × measured)` on every test; benches of the targets below; call sites in
    `HexxMirror`; the generated documents, `gas/hexx.snap` and `gas/bytecode.size` regenerated.

**Targets** (not budgets). Plan §7 has none for L-M2; they are derived from the L-M1 measurements
of the mirror in `gas/hexx.snap` at your base (per call, `(test − baseline) / 100` of
`src/tests/bench_mirror.cairo`; if LIB-04f re-measured them, use those and say so): `Hex::z` 2,059
for two operations, hence **1,030 per `i32` or `u32` operation**; `const_sub` 2,930;
`EdgeDirection::into_hex` 1,411. `L` is the sum of the stated operations, `U = ceil(1.25 × L)`. An
item not in the table: write its `L` and `U` by the same rule in its bench's doc comment **before**
its first measurement; a constant, a field read or an item of at most two operations needs no
bench (its test still carries a budget).

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `const_add`, `mul_scalar` | any | 2,930 (as `const_sub`) | [2,930, 3,663] |
| `const_neg`, `to_cubic_array` | any | 2,059 (as `z`) | [2,059, 2,574] |
| `new_cubic`, `dot` | any | 3,090 (3 operations) | [3,090, 3,863] |
| `range_count`, `ring_count`, `wedge_count` | `range = 64` | 4,120 (4 operations) | [4,120, 5,150] |
| `neighbor` | any direction | 4,341 (`into_hex` 1,411 + `const_add` 2,930) | [4,341, 5,427] |
| `all_neighbors` | any | 26,046 (6 × `neighbor`) | [26,046, 32,558] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4: a stop
holds from the first measurement; a rewrite after it is the optimisation the stop forbids). Between
`U` and `2U`: set the budget on the measurement, go on, and list the figure under *Escalations*
with the operations that explain it; the orchestrator accepts it in `gas/accepted.md` and plan §14.
No item of L-M2 is on the tick's path. A failed golden vector is a stop as well; so is a row of the
parity table that moves outside Scope 11.

**Out**: every other item of L-M2 (M2-T1 to M2-T7); `Hex`'s `Debug` (M2-T2); any change of an L-M1
item's behaviour or results; moving the existing tests of `src/tests/` into their modules; the
board, finders, generators; `scripts/**` beyond Scopes 10 and 11; `.github/**`; `CHANGELOG.md`; any
publication.

**Allowlist**: `crates/hexx/src/hex.cairo`; new files `crates/hexx/src/hex/{impls,rings,swizzle,
euclidean,convert,iter,grid}.cairo`, `crates/hexx/src/hex/grid/{edge,vertex}.cairo`,
`crates/hexx/src/{bounds,shapes}.cairo` (doc comment only); `crates/hexx/src/lib.cairo` (Scope 7
and the root re-export of `hex`); `crates/hexx/tests/golden_hex.cairo`; `tools/refgen/src/main.rs`
(Scope 8), `tools/refgen/src/hex.rs`, `tools/refgen/specs/hex.toml`, new files
`tools/refgen/src/{impls,swizzle,euclidean,convert,rings,bounds,iter,shapes,grid}.rs` (Scope 8);
`crates/consumer/src/lib.cairo`, new files `crates/consumer/src/mirror_*.cairo` (Scope 9);
`scripts/takeover_check.py` (Scope 10), `scripts/api_parity.py` and
`scripts/tests/test_api_parity.py` (Scope 11); `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Provided to the later tasks (names and signatures are theirs to call, not to change): the constants
of Scope 1; `hex(x: i32, y: i32) -> Hex`; `HexTrait::{splat(v: i32), new_cubic(x, y, z: i32),
from_array([i32; 2]), to_array(self) -> [i32; 2], to_cubic_array(self) -> [i32; 3], const_neg(self),
const_add(self, rhs: Hex), abs(self), min(self, rhs), max(self, rhs), dot(self, rhs) -> i32,
signum(self), range_count(range: u32) -> u32, shift(range: u32) -> u32 (crate), ring_count(range:
u32) -> u32, wedge_count(range: u32) -> u32, mul_scalar(self, rhs: i32) -> Hex, neighbor_coord(
direction: EdgeDirection) -> Hex, add_dir(self, direction: EdgeDirection) -> Hex, neighbor(self,
direction: EdgeDirection) -> Hex, all_neighbors(self) -> [Hex; 6]}`. Where `hexx`'s exact return
type cannot be kept (a `u32` count used as `usize`), say so under `#### Deviations`.

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 to 6 exists with its `hexx` name and passes its golden vectors;
      `cargo run -- check` in `tools/refgen` is green.
- [ ] AC-2 `--check-release L-M2 --report-only` no longer lists any item of Scopes 1 to 6 nor
      `Hex::Shl` and `Hex::lerp` (`DirectionWay::PartialEq<T>` reads `renamed` once M2-T1 adds `contains`); the diff of `docs/API_PARITY.md` shows no other row moved;
      `python3 -m unittest discover -s scripts/tests`
      passes.
- [ ] AC-3 The scaffold of Scopes 7 to 9 builds (`scarb build` of `hexx` and of `consumer`), holds
      no function, and `cargo build` of `tools/refgen` passes; `takeover_check` prints
      `0 problem(s)`.
- [ ] AC-4 Scoped (D-143: `hex` is the only free function, with its reason), tests in their module
      (D-167), every benched figure beside its range in the report.
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
open pull request and they conflict, merge `origin/main` into your branch (a merge commit; never a
rebase), regenerate them with their scripts on Linux, and push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx hex::`;
`cd tools/refgen && cargo run -- gen hex && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/takeover_check.py`; `python3 scripts/deviations.py --check`;
`python3 scripts/bench.py check`; `python3 scripts/gas_tables.py --check`;
`python3 scripts/bytecode_size.py check`; then `scripts/check.sh`.

## What the reviewer will check

Each item against `hexx` 0.25.0 in the source (name, signature, semantics, overflow); the vectors
regenerated from the pinned crate equal the committed ones; the scaffold holds no function and
matches Scopes 7 to 10 line for line; the parity diff moves only the rows it should; the targets
written before the measurements; the organisation lens (D-143, D-167).

## Report

As COMMON.md §7, with the targets table beside the measurements and the list of the items of
Scopes 1 to 6 with their golden test names.
