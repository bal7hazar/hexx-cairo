# LIB-06b M3-T1 — `algorithms`: `field_of_movement`, `a_star`, and the scaffold of L-M3

## Agent

Title: `[Sonnet 5.5] LIB-06b M3-T1 algorithms` · Profile: `impl-sonnet` (two counterparts that
forward to the board's `Dial`, whose contracts this brief writes in full, and a scaffold).
Review: `review-opus`. Audit: **none** (D-177: no value, access control or randomness; ties are
the board's fixed lowest-index rule; the release M3-R carries the one audit of the published
interface).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts on `main` after 0.2.0** (published, D-211). **M3-T2 and M3-T3 start after this task is
merged** (they share files with it: the index, *Shared files*).

## Goal

After this task `hexx::algorithms::field_of_movement` and `hexx::algorithms::a_star` exist, the
counterparts of `hexx` 0.25.0's `src/algorithms/field_of_movement.rs` and `pathfinding.rs` on a
`HexMap`, each forwarding to the one implementation of the board (`Dial`, plan §2.4: "one
implementation"); and the module `algorithms` is laid out for M3-T2. It is the task
"`algorithms/{field_of_movement,pathfinding}.cairo`" of plan §8, L-M3.

## Context — read, in this order

1. [The index](LIB-06b-L-M3.md), its *Decisions needed* and *Decided in these briefs*.
2. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §4.4 (`algorithms`: the rows
   `field_of_movement` and `a_star`), §2.2 (the module tree: `algorithms/`), §2.4 (the name clash
   of `field_of_movement`), §3.3 and §3.5 (the board and its index).
3. What exists: `crates/hexx/src/board/map.cairo:243-277` (`search_path_weighted`,
   `field_of_movement`, their doc of `costs`), `crates/hexx/src/finders/dial.cairo` in full (entry
   costs 1 to 4, open edge tiles entered and never crossed, the backtracking's lowest bit),
   `crates/hexx/src/tests/bench_dial.cairo` (the oracles `dijkstra`, `check_path`, `field_oracle`,
   the fixtures and their benches), `crates/hexx/src/board/geometry.cairo:221-280` (`to_hex`,
   `from_hex`, `index_to_hex`, `hex_to_index`), and, as the model of a scaffold,
   [M2-T0](LIB-06-M2-T0-bootstrap.md) (its `refgen` arms, consumer files, `CAIRO_MODULE_OWNER`).
4. The pinned `hexx` 0.25.0: `src/algorithms/field_of_movement.rs`, `src/algorithms/pathfinding.rs`,
   `src/algorithms/mod.rs`.

## Scope

**In**

1. **`field_of_movement(map: HexMap, from: u8, budget: u8, costs: Span<felt252>) -> felt252`**
   in `algorithms/field_of_movement.cairo`. Contract (normative): on a board whose ring is all
   wall, the bitmap equals the set `hexx`'s `field_of_movement(index_to_hex(from), budget, cost)`
   returns (`field_of_movement.rs:63-101`), mapped to board indices, with the closure
   `cost(h) = None` if `h` is off the board or a wall, `Some(k + 1)` if `h` is in the class `k`
   of `costs` (the highest class wins, as `Dial`), `Some(0)` for any other walkable tile — so that
   `hexx`'s entry cost `1 + cost(h)` (`:90`) is the board's `k + 2`, or 1. On a board with open
   edge tiles, it is the board's rule (an open edge tile is reached and never crossed): the
   oracle of Scope 5, a deviation. `from` is always in the result, and the field expands from it
   **even when `from` is a wall** (`hexx` never pays the cost of the start, `:69`): set the bit of
   `from` in a copy of the grid before forwarding to `HexMapTrait::field_of_movement`, never
   changing the caller's map. Panics: `from` outside the board (`'Asserter: position not inside'`,
   no counterpart in `hexx`), more than 3 classes (`'Dial: too many costs'`).
2. **`a_star(map: HexMap, from: u8, to: u8, costs: Span<felt252>) -> Option<Span<u8>>`** in
   `algorithms/pathfinding.cairo`. Contract (normative): `None` exactly when `hexx`'s
   `a_star(index_to_hex(from), index_to_hex(to), cost)` (`pathfinding.rs:110-146`) is `None`, with
   the closure `cost(_, b) = None` if `b` is off the board, a wall, or an edge tile other than `to`
   (the board's paths never cross an edge tile, `dial.cairo:17-19`), else `Some(c)` with `c` the
   board's entry cost of `b`: 1, or `k + 2` for the class `k`. **This is not the mapping of
   Scope 1**: `hexx`'s `a_star` adds the cost as given (`:134`). Otherwise `Some(path)`: the path
   from `from` to `to`, **both included**, each step to a neighbour, of total entry cost equal to
   `hexx`'s (optimal: every cost is at least 1 and the heuristic `unsigned_distance_to` is then
   consistent, prove it in a test comment); the path itself is the board's (backtracking on the
   lowest bit), which may differ from `hexx`'s heap order at ties (deviation, the plan's row).
   `from == to`, walkable: `Some([from])` (`hexx`: `reconstruct_path` of the start alone).
   An endpoint that is a wall or outside the board: `None`, not a panic (`hexx`'s `cost(end,
   end)?` and `cost(start, start)?`, `:114, 117`; `HexMapTrait::is_walkable` tests both at once).
   Forwards to `HexMapTrait::search_path_weighted` and reverses its result (target first, start
   excluded, `map.cairo:239`); an empty result of a search with `from != to` is `None`. Panics:
   more than 3 classes.
3. Both are **free functions**, re-exported by `algorithms.cairo` (`pub use
   field_of_movement::field_of_movement; pub use pathfinding::a_star;`) so that the paths are
   `hexx::algorithms::field_of_movement` and `hexx::algorithms::a_star`, as `hexx`'s
   (`algorithms/mod.rs`). Each carries the written reason D-143 asks for next to it: it mirrors the
   free function of `hexx::algorithms` at the same path (as `shapes`, M2-T6). Doc comments:
   `Mirrors ...`, `#### Panics`, `#### Deviations` (the `u8` budget against `u32`; per-tile entry
   costs only, no directed `cost(a, b)`; at most 3 classes, entry costs 1 to 4; a bounded board
   whose open edge tiles are endpoints only; ties; the bitmap and the `Span<u8>` of board indices
   against `HashSet<Hex>` and `Vec<Hex>`), and the name clash with `HexMapTrait::field_of_movement`
   (plan §2.4: the extension is the implementation, the counterpart forwards).
4. **The scaffold of L-M3** (the index, *Shared files*): `crates/hexx/src/lib.cairo`, one block
   `pub mod algorithms;`; `crates/hexx/src/algorithms.cairo` with `pub mod fov; pub mod
   field_of_movement; pub mod pathfinding;` and your two `pub use` lines; `algorithms/fov.cairo`
   with its module doc only (M3-T2 fills it); in `scripts/api_parity.py`, the
   `CAIRO_MODULE_OWNER` entries `("algorithms", "fov")`, `("algorithms", "field_of_movement")`,
   `("algorithms", "pathfinding")` → `"algorithms"`, with a unit test in
   `scripts/tests/test_api_parity.py`; in `tools/refgen/src/main.rs`, the arms `algorithms` (yours)
   and `fov` (a placeholder body in `tools/refgen/src/fov.rs` that M3-T2 replaces, as M2-T0 did);
   in `crates/consumer/src/lib.cairo`, `pub mod mirror_algorithms;` and `pub mod mirror_fov;`, with
   `mirror_fov.cairo` holding its module doc only. Nothing else of M3-T2 or M3-T3.
5. **Oracles** in the tests (D-167, in each module, `#[cfg(test)] mod tests`): `field_of_movement`
   against `field_oracle(dijkstra(...), budget)` of `bench_dial.cairo` on every start of
   `EMPTY_7X7` and on the fixtures `CAVE_17X14`, `MAZE_17X14` with 0 to 3 classes and budgets
   `0..=8` and 255, open edge tiles included, and from a wall; `a_star` against `check_path` and
   `dijkstra` (cost equal, path valid, both ends included, `None` iff unreachable) on every ordered
   pair of `EMPTY_7X7` and of one cave of 7 × 7, and the far pairs of the 17 × 14 fixtures, with 0
   to 3 classes, endpoints on open edge tiles, walls and `from == to` included.
6. **Golden vectors**: `tools/refgen/src/algorithms.rs` and `specs/algorithms.toml` (`package =
   "golden_lm2"`), golden file `crates/golden_lm2/tests/golden_algorithms.cairo`, **at most 2,000
   lines** (golden_lm2 holds 3,241 at `main`, its budget 8,000; M3-T2 adds up to 2,000). `hexx`
   0.25.0's own `field_of_movement` and `a_star`, run with the closures of Scopes 1 and 2 on boards
   in the board frame (`refgen`'s `line::to_hex` / `from_hex` or their equivalent): 7 × 7 and 15 ×
   16 boards with a closed ring (empty, and two seeded caves), 0 to 3 classes, budgets `0..=8`
   from 8 starts; `a_star` on 32 seeded pairs per board, compared by **total cost and validity**
   (`None` equal; the cost of the Cairo path equal to the cost of `hexx`'s), never element by
   element, because of ties. A divergence between `hexx` and the board's oracle is a stop.
7. Budgets at `ceil(1.05 × measured)` (the `hexx` pins from CI's artefact, AGENTS.md "Gas pins from
   CI"); benches of the targets below; call sites of both functions in
   `crates/consumer/src/mirror_algorithms.cairo` (contract `HexxAlgorithms`); the generated
   documents and snapshots regenerated.

**Targets** (not budgets; from `gas/hexx.snap` at `f82f1cb`, same fixtures as the engine's benches
in `src/tests/bench_dial.cairo`, so that the counterpart's cost is the engine's plus its own):
the call taking a `HexMap` by value about 2,100 (plan §14, accepted figures of M1-T6); 7,358 per
element of a span built by a loop (`line_to`, M1-T6). `U = ceil(1.25 × L)`. An item not listed: its
`L` and `U` by the same rule in its bench's doc comment before its first measurement.

| Function | Case | `L` (derivation) | Range |
|---|---|---|---|
| `field_of_movement` | `CAVE_17X14` from `CAVE_17X14_FAR_FROM`, budget 8, 2 classes | `bench_dial_field_cave_17x14_budget_8` 319,285 + 2,100 = 321,385 | [321,385, 401,732] |
| `field_of_movement` | `EMPTY_17X14`, 110, budget 8, no class | `bench_dial_field_empty_17x14_classes_0_budget_8` 232,217 + 2,100 = 234,317 | [234,317, 292,897] |
| `a_star` | `CAVE_17X14`, far pair, 2 classes, path of `n` tiles | `bench_dial_cave_17x14` 1,399,134 + 2,100 + 7,358 × (`n` + 1) | `L` with the `n` measured, then `[L, ceil(1.25 L)]` |

**Stop condition.** Above **twice** `U`: stop and report at that measurement (COMMON.md §4).
Between `U` and `2U`: budget on the measurement, go on, list it under *Escalations* with the
operations that explain it. No item of L-M3 is on the tick's path. A failed golden vector or oracle
is a stop; so is a `hexx` result the contract of Scope 1 or 2 does not reproduce.

**Out**: `range_fov`, `directional_fov` (M3-T2); `hexx_glam` (M3-T3); any change of `Dial`,
`HexMapTrait` or any result of 0.2.0; `.github/**`; `CHANGELOG.md`; any publication.

**Allowlist**: `crates/hexx/src/lib.cairo` (the one block), `crates/hexx/src/algorithms.cairo`,
`crates/hexx/src/algorithms/{field_of_movement,pathfinding,fov}.cairo` (`fov`: its module doc
only); `scripts/api_parity.py` (the three `CAIRO_MODULE_OWNER` entries only),
`scripts/tests/test_api_parity.py`; `tools/refgen/src/main.rs`, `tools/refgen/src/algorithms.rs`,
`tools/refgen/src/fov.rs` (placeholder), `tools/refgen/specs/algorithms.toml`;
`crates/golden_lm2/tests/golden_algorithms.cairo`; `crates/consumer/src/lib.cairo` (two `mod`
lines), `crates/consumer/src/mirror_algorithms.cairo`, `crates/consumer/src/mirror_fov.cairo`
(module doc only); `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`,
`docs/GAS.md`, `gas/hexx.snap`, `gas/golden_lm2.snap`, `gas/bytecode.size`.

## Interfaces

Consumed (all on `main`): L-M1 `HexMapTrait::{field_of_movement, search_path_weighted,
is_walkable}`, `Geometry::{index_to_hex, hex_to_index}`, `Bits::pow`; in the tests `Dial`, and
`dijkstra`, `check_path`, `field_oracle` and the fixtures of `src/tests/`. Provided:
`hexx::algorithms::{field_of_movement, a_star}`, the module `algorithms` and its scaffold. M3-T2
consumes the scaffold.

## Acceptance criteria

- [ ] AC-1 `field_of_movement` and `a_star` exist at `hexx::algorithms::*` with the contracts of
      Scopes 1 and 2, and pass their golden vectors (`cargo run -- check` green).
- [ ] AC-2 The oracles of Scope 5 pass on their stated domains.
- [ ] AC-3 `api_parity.py --check` shows `field_of_movement` and `a_star` `ported`;
      `--check-release L-M3 --report-only` lists only M3-T2's and M3-T3's items;
      `deviations.py --check` passes.
- [ ] AC-4 Tests in the modules (D-167); the two free functions each with its written reason
      (D-143); the scaffold of Scope 4 exactly.
- [ ] AC-5 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-6 Nothing outside the allowlist was written.

## Measurements (programme rule, 2026-10-02) and memory (AGENTS.md, "How tests are scoped")

Every committed pin — `gas/hexx.snap`, `gas/golden_lm2.snap`, `gas/bytecode.size`, and any class
hash — is generated and checked **on Linux only** (the VPS or CI), never on the Mac, with the
single-thread build of D-176 that the scripts apply. The `hexx` pins come from CI's artefact
`gas-pins-<head sha>` (`bench.py apply-pins`). A Mac/Linux difference is reported with both
figures, never as a regression. **Never state a class hash as reproducible across machines.**

The `hexx` test target (~9.5 GB) is built by CI or the Mac only (D-212), never on the VPS: push
with no budget (or a generous one) on a new test and take the figure from the artefact.
`golden_lm2` peaked at 1.6 GB at 3,241 lines; at up to 5,241 its peak is **unknown: measure it
first** (on the Mac, or on the VPS under `prlimit --as=8589934592 -- /usr/bin/time -v`, and on the
Mac if that aborts), then run it under `--as` = 1.5 × the measured peak, rounded up to whole GiB.

## Shared generated files

`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/*.snap` and
`gas/bytecode.size` are regenerated, never edited or merged by hand. If `main` moves under your
open pull request and they conflict, merge `origin/main` into your branch (a merge commit; never a
rebase), regenerate them with their scripts on Linux, and push.

## Verification

Scoped to the parts touched (AGENTS.md): `scripts/lock.sh scarb build -p hexx` (VPS, under
`prlimit --as=2147483648`); the `hexx` tests (`snforge test -p hexx algorithms::`) on CI or the
Mac only; `scripts/lock.sh snforge test -p golden_lm2` (peak measured first, above);
`cargo run --manifest-path tools/refgen/Cargo.toml -- gen algorithms` and `-- check`;
`python3 -m unittest discover -s scripts/tests`; `python3 scripts/api_parity.py --check` and
`--check-release L-M3 --report-only`; `python3 scripts/deviations.py --check`;
`python3 scripts/bench.py check`; `python3 scripts/gas_tables.py --check`;
`python3 scripts/bytecode_size.py check`; `scripts/prepush.sh` before every push; `scripts/check.sh`
before asking for the review.

## What the reviewer will check

Each contract against `hexx` 0.25.0 (the two cost mappings, `+1` or not; the start always in the
field, from a wall too; `None` for a wall or outside endpoint; both ends of the path; `from ==
to`); the forwarding (one implementation, the caller's map unchanged); the refgen closures equal to
the board's rules (edge tiles, highest class); vectors regenerated from the pinned crate equal the
committed ones; the oracles; the scaffold limited to Scope 4; the organisation lens (D-143 reasons).

## Report

As COMMON.md §7, with the targets table beside the measurements.
