# LIB-05 M1-T5 — N-6: range and ring as geometry

## Agent

Title: `[Opus 5.5] LIB-05 M1-T5 hexagon` · Profile: implement · Model: Opus 5.5 (a clip that must
come before the shift, two paths that must agree bit for bit, tables, the ring of the board).
Audit: `[GPT-6-Astra]`, determinism (`nexus audit --model gpt-6-astra`).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task the board answers "which tiles lie within `r` of this one" and "which lie at
exactly `r`", walls ignored, clipped to the board with its ring: the adventurer's sight of radius
6 and the area of an effect around a target. It is need N-6 of milestone L-M1. It runs before N-1
and N-2, which wait for the game's study of hexagonal chunks (SPK-14).

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-143, D-167, the accepted
   figures), then **§6.7** (N-6: the contract, R-N6-1 to R-N6-7, the design sketch), §6.4 (the band
   tables of `board/tables.cairo`), §7 (the rows of `hexagon` and `hexagon_ring`), §8 (the row of
   M1-T5).
2. What exists: `crates/hexx/src/board/{tables,layout,geometry,map}.cairo`, `LayoutTrait::hexagon`
   of the engine (the extent formula of the loop path), the `refgen` generators of M1-T6
   (`tools/refgen/src/line.rs`: how a table is written into a marked region of a Cairo file),
   `gas/accepted.md`.

## Scope

**In**

1. `board/hexagon.cairo`: a trait `HexagonTrait` (D-143) with the plan's two signatures and
   contracts, `self: HexMap` as the plan writes them: `hexagon(self, position: u8, radius: u8) ->
   felt252`, `hexagon_ring(self, position: u8, radius: u8) -> felt252`. Radius 0 returns
   `2^position` before any dispatch; the **table path serves `width == 15` and `1 ≤ radius ≤ 7`
   only**; the row loop serves every other case. The result never depends on the path.
2. **The tables** `HEXAGONS` and `HEXAGON_RINGS` (or a layout of your own that you prove equal),
   and any new band table (`ROW_FROM_16`, `ROW_TO_16`, added to `board/tables.cairo`): produced by
   a committed, re-runnable generator under `tools/refgen`, never typed by hand; the report gives
   the command. **The clip comes before the shift** (§6.7: a shift first reduces modulo the field).
3. **Tests in the module (D-167)**: in `hexagon.cairo`'s `#[cfg(test)] mod tests`. Oracles, all of
   §6.7's "Oracle" row: the per-tile definition (`hex_distance`) on every position of 15 × 16 and
   of 7 × 7 for every radius `0..=9`, on every position of 3 × 83 for radius 41 and 255, on 32
   seeded positions of every other dimension class; the two paths against each other on every
   position of 15 × 16 for radius `1..=7`; the secondary equality with `tiles_within_range` only
   on the centres whose hexagon is all interior; R-N6-1 to R-N6-7 with their expected values.
   Split a test that exceeds the step limit into as many as it needs; never sample an oracle the
   plan states exhaustively.
4. The **per-position variant** of §6.7 ("Why not the flood"), measured in the benchmarks only, not
   shipped.
5. Budgets at `ceil(1.05 × measured)`, benchmarks on the worst cases of §6.7; a call site of each
   new public item in `crates/consumer`; the generated documents and `gas/hexx.snap` regenerated.
6. `scripts/takeover_check.py`: an `OWN_FILES` entry for `src/board/hexagon.cairo` with the comment
   `M1-T5, N-6`; if `board/tables.cairo` gains tables, it is already an own file. Nothing else of
   that script.

**Ranges** (§7, unchanged):

| Function | Case | Range |
|---|---|---|
| `hexagon`, `hexagon_ring`, table | radius 7, centre `(1, 1)`, odd row (maximal clipping); radius 6 from `(7, 8)` | [31,627, 39,534] each |
| `hexagon`, loop | radius 8 at `(7, 8)` on 15 × 16 (16 rows); radius 255 at `(1, 41)` on 3 × 83 (83 rows) | 16: [72,064, 90,080]; 83: [373,832, 467,290] |
| `hexagon_ring`, loop | same | 16: [123,808, 154,760]; 83: [642,254, 802,818] |

**Stop condition — every measured figure.** The **table** path of `hexagon` at radius 6 from
`(7, 8)` (the sight, once per tick): above the upper bound of its range, stop and report; do not
optimise or set its budget. Every other figure: above **twice** the upper bound of its range, stop
and report; between the upper bound and twice it, set the budget on the measurement, go on, and
list the figure under *Escalations* with the operations that explain it (the orchestrator accepts
it at the close). A failed oracle, or a table path that differs from the loop on any case, is a
stop as well.

**Out**: N-1, N-2 and `new_odd` (they wait for SPK-14); any change of behaviour of the engine or of
the functions of M1-T3 to M1-T6; the other methods of the facade `board/map.cairo`; `scripts/**`
beyond Scope 6; `.github/**`; any publication.

**Allowlist**: `crates/hexx/src/board/hexagon.cairo` (new), `crates/hexx/src/board/tables.cairo`
(new tables only), `crates/hexx/src/board.cairo` and `crates/hexx/src/lib.cairo` (module
declaration and root re-exports of the new items only), `tools/refgen/**`,
`scripts/takeover_check.py` (Scope 6 only), `crates/consumer/**`; `docs/API_PARITY.md`,
`docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`;
`REPORT.md`. `gas/takeover_tests.snap` is not in it: this task changes no function of the engine,
so a row of `takeover_tests` that moves is the D-154 drift (`COMMON.md` §4): keep `main`'s and
report it.

## Acceptance criteria

- [ ] AC-1 Every oracle of Scope 3 equals its function on its whole case set; R-N6-1 to R-N6-7
      pass with their expected values (or the report shows the plan wrong).
- [ ] AC-2 The tables come from a committed generator; the table path equals the loop path.
- [ ] AC-3 Scoped (D-143), tests in their module (D-167), no free function without a written
      reason (a table of constants is one).
- [ ] AC-4 `scripts/check.sh` passes; CI green, every job under its timeout (report the slowest).
- [ ] AC-5 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]`: its own per-tile hexagon and ring against `hexagon` and `hexagon_ring` on every
position of 15 × 16, 7 × 7 and 3 × 83 for the radii of Scope 3, and on other dimensions; the
clipping at the edges and the ring of the board; radius 0; table against loop; the tables
regenerated; the placement of tests (D-167); the organisation lens.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the figures of the ranges table beside their
measurements.

## Decisions of the orchestrator at the close (2026-10-01)

By `[Opus 5.5]`, the orchestrator, on the agent's report (pull request #65, head `07ae87d`). They
amend this brief; a review or an audit reads them as part of it.

1. **The stop condition was crossed and not reported as a stop.** The first loop path of `hexagon`
   measured 940,040 at 83 rows, above twice its upper bound (934,580); the agent rewrote the loop
   instead of stopping. The rule holds from the first measurement: a rewrite after a crossing is the
   optimisation the stop forbids. The work is **kept**, since the rewrite is proven by every oracle
   of Scope 3 and measures under twice the bound, and the breach is recorded here and in
   `STATUS.md`.
2. **Accepted as measured**, under twice their upper bound as the stop allows: `hexagon` on the loop
   path, 128,670 at 16 rows ([72,064, 90,080]) and 519,840 at 83 rows ([373,832, 467,290]). About
   5,840 per row against the sketch's 4,504: comparisons and `u16` additions measured at several
   hundred each. The tick reads the sight on the table path (16,430, below its range), so neither
   figure is on it. The orchestrator writes them in §14 of the plan and in `gas/accepted.md`.
3. The deviations from the sketch (only `ROW_FROM_16`, the ring by the two ends of each row, no clip
   when the shape fits, the radius of the loop capped at 100 since no board of the engine has a
   distance above 85: both dimensions above 2 and at most `MAX_SIZE` tiles) are accepted: each is
   proved against the oracles.
4. `gas/hexx.snap`'s new rows were measured on the `board::` tests, then confirmed by CI's gas
   jobs, which check every row: accepted.
