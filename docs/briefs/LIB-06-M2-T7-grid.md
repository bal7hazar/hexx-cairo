# LIB-06 M2-T7 — `GridEdge` and `GridVertex`

## Agent

Title: `[Sonnet 5.5] LIB-06 M2-T7 grid` · Profile: `impl-sonnet` (two small types, a `Hex` and a
direction each, ported against the crate's vectors). Review: `review-opus`. Audit: **none** (D-177:
no value, access control or randomness; the release M2-R carries the one audit of the published
interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M2-T1 is merged** (and so after M2-T0). The plan's edges let it start as soon as
M2-T1 is merged; **it is scheduled with M2-T4, M2-T5 and M2-T6**, after M2-T2 and M2-T3, so that no
more than two tasks of L-M2 write `hexx` at once while M2-T2 and M2-T3 run (the orchestrator may
start it earlier: its files are disjoint from M2-T2's and M2-T3's). `lib.cairo` is shared with
M2-T5 at line level only: your re-exports go in the `hex` block, M2-T5's in the `bounds` block.

## Goal

After this task the library has `hexx`'s grid edges and vertices: an edge or a vertex of a hex
given by the hex and an edge or vertex direction, with their equivalence across neighbouring hexes,
their endpoints, rotations and negation, and `Hex::all_edges`, `Hex::all_vertices`. It is the task
M2-T7 of plan §8, L-M2 (`hexx`'s feature `grid`, which `tools/refgen` already enables).

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §8 L-M2 (row "Tasks…": M2-T7),
   §4.4 (the rows of `hex::grid`), §2.3 (`hex::grid` kept).
2. What exists: `hex.cairo` after M2-T0 (`add_dir`), `direction/*` after M2-T1 (`vertex_cw`,
   `vertex_ccw`, `VertexDirection` and its rotations, `direction_cw/ccw`, `edge_cw/ccw`), the
   scaffolded `hex/grid.cairo`, `hex/grid/{edge,vertex}.cairo`, `tools/refgen/src/grid.rs`,
   `crates/consumer/src/mirror_grid.cairo`.
3. The pinned `hexx` 0.25.0: `src/hex/grid/{edge,vertex}.rs`.

## Scope

**In**

1. `hex/grid/edge.cairo`: `GridEdge { pub origin: Hex, pub direction: EdgeDirection }` (derives as
   `hexx`'s, within what Cairo has), trait `GridEdgeTrait`: `equivalent`, `destination`, `vertices`
   (`[GridVertex; 2]`, ccw then cw), `flipped`, `const_neg`, `clockwise`, `counter_clockwise`,
   `rotate_cw(offset: u8)`, `rotate_ccw(offset: u8)`; `Neg`; `Into<EdgeDirection, GridEdge>`
   (origin `ZERO`); and `Hex::all_edges(self) -> [GridEdge; 6]` (`ALL_DIRECTIONS` order) on a trait
   of this file (D-143; name it `HexEdgesTrait`: the parity script attributes every trait of this
   module to `GridEdge` since M2-T0, as `hexx`'s table does).
2. `hex/grid/vertex.cairo`: `GridVertex { pub origin: Hex, pub direction: VertexDirection }`, trait
   `GridVertexTrait`: `equivalent` (the three forms of `vertex.rs:24-42`, in `hexx`'s order),
   `coordinates` (`[Hex; 3]`), `destinations` (`[Hex; 2]`), `side_edges` (`[GridEdge; 2]`),
   `const_neg`, `clockwise`, `counter_clockwise`, `rotate_cw`, `rotate_ccw`; `Neg`;
   `Into<VertexDirection, GridVertex>`; and `Hex::all_vertices(self) -> [GridVertex; 6]` on a trait
   `HexVerticesTrait`. `origin + direction` is `add_dir` of M2-T0, not M2-T3's operator.
3. `lib.cairo`: the re-exports of `GridEdge` and `GridVertex` (plan §2.4) **in the `hex` block
   only**.
4. Golden vectors: `tools/refgen/src/grid.rs` (replace M2-T0's placeholder body) and
   `specs/grid.toml`: every item for every direction around 8 seeded origins, rotations at offsets
   `0..=12` and 255, `equivalent` on every pair of edges (and of vertices) among the 6 × 7 that a
   hex and its six neighbours carry (true and false cases, both clauses). Golden file
   `crates/hexx/tests/golden_grid.cairo`.
5. Oracles in the tests (D-167, in each module): `equivalent` against its geometric definition (two
   edges are equivalent when they separate the same two hexes: `{origin, destination}` as a set;
   two vertices when their `coordinates` are the same set of three hexes), on every pair of Scope 4.
   The crate is the reference: if an oracle and the vectors disagree, the port follows the vectors
   and the report names the pairs under *Escalations*.
6. Budgets at `ceil(1.05 × measured)`; benches of the targets below; call sites of each new public
   item in `crates/consumer/src/mirror_grid.cairo` (contract `HexxGrid`); the generated documents
   and snapshots regenerated.

**Targets** (not budgets; from the L-M1 measurements in `gas/hexx.snap` at your base by the method
of `src/tests/bench_mirror.cairo`, and M2-T0's and M2-T1's measurements where they exist — use those
first; if LIB-04f re-measured them, say so): 1,030 per `i32`/`u32` operation or comparison,
`add_dir` 4,341 (`into_hex` 1,411 + `const_add` 2,930), direction rotations by one 1,868, by `n`
2,217, `const_neg` 1,785. `U = ceil(1.25 × L)`. An item not listed: its `L` and `U` by the same rule
in its bench's doc comment before its first measurement; field reads and `Into` need no bench.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `GridEdge::destination` | any | 4,341 | [4,341, 5,427] |
| `GridEdge::flipped` | any | 4,341 + 1,785 = 6,126 | [6,126, 7,658] |
| `GridEdge::equivalent` | the second clause | 4,341 + 1,785 + 4 comparisons (4,120) = 10,246 | [10,246, 12,808] |
| `GridEdge::vertices` | any | 2 × 1,868 = 3,736 | [3,736, 4,670] |
| `GridVertex::equivalent` | the third clause | 2 × (4,341 + 1,868 + 2,217) + 6 comparisons (6,180) = 23,032 | [23,032, 28,790] |
| `GridVertex::coordinates` | any | 2 × (4,341 + 1,868) = 12,418 | [12,418, 15,523] |
| `rotate_cw`, `rotate_ccw` (both types) | `offset = 255` | 2,217 | [2,217, 2,772] |
| `Hex::all_edges`, `all_vertices` | any | 6 × 1,030 = 6,180 | [6,180, 7,725] |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M2 is on the tick's path. A failed golden vector or oracle
is a stop.

**Out**: the board's seams (`SeamTrait`, extensions, unchanged); the direction types (M2-T1); any
change of an L-M1 or earlier L-M2 result; `scripts/**` (a parity row the script cannot match: an
escalation); `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/hex/grid.cairo` (doc comment only, if it needs one more line),
`crates/hexx/src/hex/grid/{edge,vertex}.cairo`; `crates/hexx/src/lib.cairo` (the `hex` block,
Scope 3); `crates/hexx/tests/golden_grid.cairo`; `tools/refgen/src/grid.rs`,
`tools/refgen/specs/grid.toml`; `crates/consumer/src/mirror_grid.cairo`; `docs/API_PARITY.md`,
`docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`.

## Interfaces

Consumed: M2-T0 (`add_dir`, `ZERO` of L-M1), M2-T1 (`VertexDirection` and its methods,
`EdgeDirection::{vertex_cw, vertex_ccw}`), L-M1 (`EdgeDirection::{const_neg, clockwise,
counter_clockwise, rotate_cw, rotate_ccw, ALL_DIRECTIONS}`). Provided: `GridEdge`, `GridVertex`,
their traits, `HexEdgesTrait::all_edges`, `HexVerticesTrait::all_vertices`; nothing of L-M2
consumes them.

## Acceptance criteria

- [ ] AC-1 Every item of Scopes 1 and 2 exists with its `hexx` name and passes its golden vectors;
      `cargo run -- check` is green.
- [ ] AC-2 The oracles of Scope 5 pass on every pair of Scope 4.
- [ ] AC-3 `--check-release L-M2 --report-only` lists no item of `GridEdge` nor `GridVertex`;
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
open pull request and they conflict (M2-T4, M2-T5 and M2-T6 run beside you), merge `origin/main`
into your branch (a merge commit; never a rebase), regenerate them with their scripts on Linux, and
push.

## Verification

`scripts/lock.sh scarb build -p hexx`; `scripts/lock.sh snforge test -p hexx hex::grid`;
`cd tools/refgen && cargo run -- gen grid && cargo run -- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M2 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`; then
`scripts/check.sh`.

## What the reviewer will check

Each item against `hexx` 0.25.0 (the ccw/cw order of `vertices`, `coordinates`, `side_edges`; the
clauses of both `equivalent`); the vectors regenerated from the pinned crate equal the committed
ones; the oracles; the organisation lens.

## Report

As COMMON.md §7, with the targets table beside the measurements.
