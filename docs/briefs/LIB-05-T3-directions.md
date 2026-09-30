# LIB-05 M1-T3 — N-7 and the board's coordinates: rotation, arcs, distance, conversions, renames

## Agent

Title: `[Opus 5.5] LIB-05 M1-T3 directions and coordinates` · Profile: implement · Model: Opus 5.5
(the conversions between `Hex` and a board index fix numeric results the game depends on).
Audit: `[GPT-6-Astra]`, determinism.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task the board speaks the game's geometry: the facing of an actor turns by steps of
60° and says in which arc a neighbour stands (front, front-side, rear-side, back: the game's
flank and critical rules), the distance between two tiles of a location is computed on global
coordinates, and a board index converts to and from a mirror `Hex`. It is need N-7 and the
"distance, neighbours" of milestone L-M1, for the game's ENG-02, and it renames the three
British-spelt helpers taken over.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-143, D-167, the accepted
   figures), then **§6.8** (N-7: `rotate`, `arc`, `Arc`, the conversions with `EdgeDirection`;
   regression cases), **§6.1** (`distance_between`, `chunk_of`, `neighbor_direction`), **§3.5**
   (`to_hex`, `from_hex`, `index_to_hex`, `hex_to_index`), §5.2 (the three renames), §7 (ranges).
2. What exists: `crates/hexx/src/board/{direction,layout,geometry}.cairo` (taken over),
   `crates/hexx/src/hex.cairo` and `direction/edge_direction.cairo` (M1-T2).

## Scope

**In**

1. The functions of §6.8 and §6.1 and §3.5, scoped (D-143) on the traits of their modules, with the
   contracts as normative: `DirectionTrait::{rotate, arc}`, the `Arc` enum, the conversions
   between `Direction` and `EdgeDirection` (index identity); `distance_between` on `u16`, the
   scalar `chunk_of`, `neighbor_direction` validated through coordinates (§6.1); `to_hex`,
   `from_hex`, `index_to_hex`, `hex_to_index` (§3.5).
2. **The three renames** of §5.2 in the engine taken over: `edge_neighbours` → `edge_neighbors`,
   `neighbour_in` → `neighbor_in`, `neighbour_mask` → `neighbor_mask`, and every call site in the
   repository (the finders, `flood.cairo`, `crates/takeover_tests`, which calls the 1.8.0 names on
   the `origami_hexmap` side and the new names on the `hexx` side). The move proof learns them as
   three rewrites of `scripts/takeover_check.py` (`REWRITES`), and nothing else of that script
   changes: it must still print `same` or `same after scarb fmt` for the 29 pairs, and additions
   only for the extended files.
3. **Tests in the module (D-167, `docs/briefs/COMMON.md` §4)**: the unit tests of each module you
   touch live in that module's file under `#[cfg(test)] mod tests`; the tests you add for
   `direction.cairo`, `geometry.cairo`, `layout.cairo` go there, and the existing tests of those
   three files that live in `src/tests/` move with them when you touch them. Confirm that
   `scripts/bench.py` discovers and budgets tests in `src/` module files (it should: say how you
   checked). Oracles: the scalar definitions of §6.1 and §6.8 on every direction and every
   `steps` in `0..=255`, every pair of a 7 × 7 and 512 seeded pairs of location coordinates, and
   the round trip `hex_to_index(index_to_hex(i)) = i` on every tile of the boards of the plan.
4. Budgets at `ceil(1.05 × measured)`; call sites in `crates/consumer`; generated documents and
   snapshots regenerated.

**Stop condition — every measured figure.** Above the upper bound of its range in §7: stop and
report; do not optimise or set its budget. `distance_between` is on the game's hot path (the
nearest goblins): report its figure beside `hex_distance` of the engine.

**Out**: `new_odd` (the parity flag of chunks: deferred to the tasks of N-1 and N-2, which wait for
the game's study of hexagonal chunks, SPK-14); N-5 (`line_to`, M1-T6); any change of behaviour of
the engine beyond the three renames; the facade `board/map.cairo`; any publication.

**Allowlist**: `crates/hexx/src/board/{direction,layout,geometry}.cairo`, `crates/hexx/src/
finders/{bfs,dial,flood}.cairo` and other call sites of the three helpers (renames only), the test
files of `src/tests/` whose tests move into their modules (removal of what moved), the lines
declaring modules; `crates/takeover_tests/**` (the renamed calls only); `scripts/takeover_check.py`
(the three rewrites only); `crates/consumer/**`; `docs/EXTENSIONS.md`, `docs/API_PARITY.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/*.snap`, `gas/bytecode.size`; `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 Every oracle equals its function on the cases of Scope 3; every regression case of
      §6.1 and §6.8 passes with its expected value (or the report shows the plan wrong).
- [ ] AC-2 The renames are complete (no old name left outside the `origami_hexmap` side of
      `crates/takeover_tests`); the move proof passes with the three rewrites; the equality tests
      of `crates/takeover_tests` pass unchanged in what they compare.
- [ ] AC-3 The tests of the modules touched are in their module files; the gas gate budgets them.
- [ ] AC-4 Scoped, no free function without a written reason.
- [ ] AC-5 `scripts/check.sh` passes; CI green (a class-size value of `gas/bytecode.builds` is the
      recorded second build of D-164, not a failure).
- [ ] AC-6 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]`: its own oracle for `rotate`, `arc`, `distance_between`, `neighbor_direction` and the
four conversions on the whole domain the contracts state; that `arc` gives the game's arcs for a
facing (design/04 of the game: front `d`, front-side `d ± 1`, rear-side `d ± 2`, back `d + 3`); that
the renames change no result (the move proof and the equality tests); the placement of tests
(D-167); the organisation lens.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7.
