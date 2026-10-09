# LIB-06b M3-T2 — `algorithms::fov`: `range_fov`, `directional_fov`

## Agent

Title: `[Opus 5.5] LIB-06b M3-T2 fov` · Profile: `impl-opus` (the design is open: `hexx` takes, on
each line to the ring, the prefix up to the first blocking tile, an ordered notion that the board's
bitmaps do not carry, and lines that leave the board have no board form). Review: `review`
(Sonnet). Audit: **none** (D-177: no value, access control or randomness; the ties are the game's
fixed rule; the release M3-R carries the one audit of the published interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M3-T1 is merged** (its scaffold: `algorithms.cairo`, `algorithms/fov.cairo`, the
`refgen` arm `fov`, `mirror_fov.cairo`). **Runs in parallel with M3-T3** (disjoint files).

## Goal

After this task `hexx::algorithms::range_fov` and `hexx::algorithms::directional_fov` exist, the
counterparts of `hexx` 0.25.0's `src/algorithms/fov.rs` on a `HexMap`: the tiles seen from a tile
up to a range, walls blocking, as a bitmap. It is the task "`algorithms/fov.cairo`" of plan §8,
L-M3.

## Context — read, in this order

1. [The index](LIB-06b-L-M3.md): **Decisions needed 1 and 2** (this brief follows their
   recommendations: (b) the whole ring with off-board tiles blocking, and the game's tie rule; if
   the orchestrator rules otherwise before you start, its ruling replaces Scope 1).
2. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §4.4 (`algorithms`: the rows
   `range_fov`, `directional_fov`), §6.6 (N-5: the line, its tie rule, D-27, R-N5-1), §6.7 (N-6:
   `hexagon_ring`), §1.4 (the contract is normative, the sketch is not).
3. What exists: `crates/hexx/src/board/line.cairo` (the table and loop paths of `line`, the tie
   rule, `LineInternal::walk`), `crates/hexx/src/board/hexagon.cairo` (`hexagon`, `hexagon_ring`),
   `crates/hexx/src/board/geometry.cairo:221-280` (`index_to_hex`, `hex_to_index`: `None` off the
   board), `crates/hexx/src/hex/rings.cairo` (`HexRingsTrait::ring`), `HexTrait::diagonal_way_to`,
   `EdgeDirection::vertex_directions`, `DirectionWay::contains` (the Cairo form of `hexx`'s
   `PartialEq<T> for DirectionWay<T>`, `way.rs:42-46`), `tools/refgen/src/line.rs` (`rule`, `walk`,
   `to_hex`, `from_hex`, `board_line`: the game's rule in Rust), `docs/deviations/line_ties.md`.
4. The pinned `hexx` 0.25.0: `src/algorithms/fov.rs` (76 lines), `src/hex/mod.rs` (`line_to`).

## Scope

**In**

1. **`range_fov(map: HexMap, from: u8, range: u8) -> felt252`** in `algorithms/fov.cairo`.
   Contract (normative). Let `c = Geometry::index_to_hex(width, from)`. For every hex `t` of
   `c.ring(range)` (the whole ring, `6 × range` hexes, on the board or not; `[c]` for range 0), let
   `L(c, t)` be the line from `c` to `t` **with the game's tie rule** (plan §6.6; `refgen`'s
   `line::rule` for any two hexes, which the board's `LineTrait::line` equals on the board, M1-T6),
   both ends included, in order from `c` (each step one hex further). Its visible part is its
   longest prefix whose hexes all lie on the board and are walkable. The result is the bitmap of
   the board indices of the union of the visible parts. Hence: `from` a wall gives 0; range 0 gives
   `2^from` (`from` walkable); a wall is never in the result, as in `hexx` (`take_while`,
   `fov.rs:32`). This is `hexx`'s `range_fov(c, range, blocking)` (`fov.rs:29-34`) with
   `blocking(h) = h off the board or a wall`, but for the tie rule of the lines. Panics: `from`
   outside the board (`'Asserter: position not inside'`).
2. **`directional_fov(map: HexMap, from: u8, range: u8, direction: EdgeDirection) -> felt252`**.
   Contract: as Scope 1 over the ring hexes `t` with `c.diagonal_way_to(t).contains(a) ||
   ….contains(b)` for `[a, b] = direction.vertex_directions()` (`fov.rs:67-73`; a `Tie` way that
   contains either counts, as `hexx`'s `PartialEq<T>`). The facing is an `EdgeDirection`, as
   upstream (plan §4.4, audit finding 11).
3. Both are **free functions**, re-exported by `algorithms.cairo` (your one line: `pub use
   fov::{directional_fov, range_fov};`), each with the written reason D-143 asks for next to it (it
   mirrors the free function of `hexx::algorithms` at the same path, as M3-T1's). Doc comments:
   `Mirrors ...`, `#### Panics`, `#### Deviations` — the tie rule (the game's, against `hexx`'s
   `line_to`; the vectors list where they differ), the board (off-board hexes block; the result is
   a bitmap of board indices, not a `HashSet<Hex>`), `range: u8` against `u32`, and a note that
   `range_fov` is not `line_of_sight` tile by tile (a tile in the fov is on a line to a ring hex,
   not necessarily visible on its own line, as in `hexx`).
4. **The design is yours** (plan §1.4), proved against the oracle of Scope 5 over the whole domain
   before any optimisation is kept. Two sketches, neither normative: (A) for each ring hex, walk
   the line from `c` with the game's rule (the accumulators of `LineInternal::walk`, extended past
   the board's edge or stopped at it) and stop at the first blocking hex; (B) for ring hexes on the
   board, the bitmap `LineTrait::line` (table path on the width 15) plus both ends, its prefix as
   `line & hexagon(from, d − 1)` where `d` is the distance of its nearest wall, with (A) for the
   ring hexes off the board. Ring hexes whose lines coincide may be walked once.
5. **Oracles** in the tests (D-167, in the module): a plain version kept in the tests — for every
   ring hex `t` on the board, the bitmap of `LineTrait::line(from, t)` plus both ends, its tiles
   sorted by `hex_distance` from `from`, cut at the first wall — equal to `range_fov` on every
   start of the 15 × 16 window (empty, `SERPENTINE_15X16`, two seeded caves) at the ranges whose
   ring lies within the board, and on every start of a 7 × 7 at ranges `0..=3`; properties on the
   whole domain of the fixtures (every start, ranges `0..=16`): `range_fov ⊆ hexagon(from, range)
   & grid`; adding a wall never adds a tile; `directional_fov ⊆ range_fov`; **the union of
   `directional_fov` over the six `EdgeDirection`s equals `range_fov`** (every ring hex has a
   diagonal way, and each `VertexDirection` is one of the two of some `EdgeDirection`). The cases
   whose lines leave the board are covered by the golden vectors (Scope 6).
6. **Golden vectors**: `tools/refgen/src/fov.rs` (replace M3-T1's placeholder) and
   `specs/fov.toml` (`package = "golden_lm2"`), golden file
   `crates/golden_lm2/tests/golden_fov.cairo`, **at most 2,000 lines**. The reference is Scope 1
   computed in Rust (`line::rule`, the board frame of `line::to_hex` / `from_hex`), on the 15 × 16
   window (empty and two seeded caves) and a 7 × 7, from 8 starts each (the centre `(7, 7)` and
   `(7, 8)`, starts next to the ring, a ring tile), ranges `0..=8` and 15, `directional_fov` for the
   six `EdgeDirection`s at ranges 3 and 6. `refgen` also runs `hexx`'s own `range_fov` and
   `directional_fov` with the closure `blocking(h) = off the board or a wall` on the same inputs
   and writes every input where they differ from the reference to
   `docs/deviations/fov_ties.md`, each with the line and the tie that explains it; **a difference
   that no tie explains fails `refgen`** (a stop). If the orchestrator reverses Decision 2 (exact
   parity), the reference becomes `hexx` itself and the file is empty.
7. Budgets at `ceil(1.05 × measured)` (the `hexx` pins from CI's artefact); benches of the targets
   below; call sites of both functions in `crates/consumer/src/mirror_fov.cairo` (contract
   `HexxFov`); the generated documents and snapshots regenerated.

**Targets** (not budgets; from `gas/hexx.snap` at `f82f1cb`, marginal figures, `twice − once` or
per repetition, as `bench_assembly`'s method): `HexagonTrait::hexagon_ring` sight 16,430
(`bench_hexagon_ring_sight`); `LineTrait::line` table path 11,150 (`bench_line_table`); the loop
path of `line` 181,590 for 19 steps, **9,557 per step** (`bench_line_loop_interior`);
`HexRingsTrait::ring(6)` 173,822 (`(bench_hex_ring − bench_hex_rings_baseline) / 10`);
`diagonal_way_to` at most 19,059 (`bench_hex_diagonal_way_to / 100`, the bench's loop included).
`U = ceil(1.25 × L)`. The derivation below is sketch (A)'s, the upper one; write the `L` of the
design you keep in its bench's doc comment before its first measurement (sketch (B) on the sight:
16,430 + 36 × 11,150 = 417,830 plus the prefixes).

| Function | Case | `L` (derivation, sketch (A)) | Range |
|---|---|---|---|
| `range_fov` | the sight: 15 × 16 empty window, from `(7, 7)`, range 6 (36 ring hexes, all on the board) | 173,822 + 36 × 6 × 9,557 = 2,238,134 | [2,238,134, 2,797,668] |
| `directional_fov` | same, `EdgeDirection` 0 (about 13 ring hexes: count them in the test) | 173,822 + 36 × 19,059 + 13 × 6 × 9,557 = 1,605,392 | [1,605,392, 2,006,740] |

Also bench and report, with no target: `range_fov` from a start next to the ring at range 15 (most
lines leave the board), and at range 255 once (the cost of the domain's end).

**Stop condition.** Above **twice** `U` of the design you keep: stop and report at that
measurement (COMMON.md §4). Between `U` and `2U`: budget on the measurement, go on, list it under
*Escalations* with the operations that explain it. No item of L-M3 is on the tick's path. A failed
golden vector or oracle is a stop; so is a `hexx` difference that no tie explains.

**Out**: `field_of_movement`, `a_star`, the scaffold (M3-T1); `hexx_glam` (M3-T3); any change of
`LineTrait`, `HexagonTrait` or any result of 0.2.0 (a faster `line` is a separate lot);
`scripts/**`; `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/algorithms/fov.cairo`; `crates/hexx/src/algorithms.cairo` (your
one `pub use` line); `tools/refgen/src/fov.rs`, `tools/refgen/specs/fov.toml`;
`crates/golden_lm2/tests/golden_fov.cairo`; `docs/deviations/fov_ties.md` (generated by `refgen`);
`crates/consumer/src/mirror_fov.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/golden_lm2.snap`, `gas/bytecode.size`.
A `refgen` arm, a `ci_changes.py` input (the `golden` group lists the board sources its vectors
read) or any other shared file you need: an escalation.

## Interfaces

Consumed (all on `main`): L-M1 `LineTrait::{line, line_of_sight}` and its internals as you need
them, `HexagonTrait::{hexagon, hexagon_ring}`, `Geometry::{index_to_hex, hex_to_index}`,
`HexMapTrait::{is_walkable, hex_distance}`, `Bits`; L-M2 `HexRingsTrait::ring`,
`HexTrait::diagonal_way_to`, `EdgeDirection::vertex_directions`, `DirectionWay::contains`; M3-T1's
scaffold. Provided: `hexx::algorithms::{range_fov, directional_fov}`; nothing of L-M3 consumes
them.

## Acceptance criteria

- [ ] AC-1 `range_fov` and `directional_fov` exist at `hexx::algorithms::*` with the contracts of
      Scopes 1 and 2, and pass their golden vectors (`cargo run -- check` green, every `hexx`
      difference explained by a tie in `docs/deviations/fov_ties.md`).
- [ ] AC-2 The oracle and the properties of Scope 5 pass on their stated domains.
- [ ] AC-3 `api_parity.py --check` shows both `ported`; `--check-release L-M3 --report-only` lists
      no item of `fov`; `deviations.py --check` passes.
- [ ] AC-4 Tests in the module (D-167); the two free functions each with its written reason
      (D-143).
- [ ] AC-5 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-6 Nothing outside the allowlist was written.

## Measurements (programme rule, 2026-10-02) and memory (AGENTS.md, "How tests are scoped")

Every committed pin — `gas/hexx.snap`, `gas/golden_lm2.snap`, `gas/bytecode.size`, and any class
hash — is generated and checked **on Linux only** (the VPS or CI), never on the Mac, with the
single-thread build of D-176 that the scripts apply. The `hexx` pins come from CI's artefact
`gas-pins-<head sha>` (`bench.py apply-pins`). A Mac/Linux difference is reported with both
figures, never as a regression. **Never state a class hash as reproducible across machines.**

The `hexx` test target (~9.5 GB) is built by CI or the Mac only (D-212), never on the VPS: iterate
on the oracles on the Mac when it is offered, else through CI. `golden_lm2` with M3-T1's and your
files has an **unknown peak: measure it first** (on the Mac, or on the VPS under
`prlimit --as=8589934592 -- /usr/bin/time -v`, and on the Mac if that aborts), then run it under
`--as` = 1.5 × the measured peak, rounded up to whole GiB.

## Shared generated files

`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/*.snap` and
`gas/bytecode.size` are regenerated, never edited or merged by hand. If `main` moves under your
open pull request and they conflict (M3-T3 runs beside you), merge `origin/main` into your branch
(a merge commit; never a rebase), regenerate them with their scripts on Linux, and push.

## Verification

Scoped to the parts touched (AGENTS.md): `scripts/lock.sh scarb build -p hexx` (VPS, under
`prlimit --as=2147483648`); the `hexx` tests (`snforge test -p hexx algorithms::fov`) on CI or the
Mac only; `scripts/lock.sh snforge test -p golden_lm2` (peak measured first, above);
`cargo run --manifest-path tools/refgen/Cargo.toml -- gen fov` and `-- check`;
`python3 scripts/api_parity.py --check` and `--check-release L-M3 --report-only`;
`python3 scripts/deviations.py --check`; `python3 scripts/bench.py check`;
`python3 scripts/gas_tables.py --check`; `python3 scripts/bytecode_size.py check`;
`scripts/prepush.sh` before every push; `scripts/check.sh` before asking for the review.

## What the reviewer will check

The contract against `hexx` 0.25.0 (the whole ring, off-board hexes blocking, walls excluded, the
start, range 0, the `Tie` ways of `directional_fov`); the tie rule of every line equal to
`LineTrait::line`'s where both apply; the oracle plain and independent of the design; the union
property; `fov_ties.md` regenerated from the pinned crate, every entry a tie; the cost of the
design kept against its stated `L`; the organisation lens (D-143 reasons).

## Report

As COMMON.md §7, with the targets table beside the measurements and the design kept, with the
designs tried and dropped and their figures.
