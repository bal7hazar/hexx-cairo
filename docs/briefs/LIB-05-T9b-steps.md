# LIB-05 M1-T9b — N-8: the steps of the walkers, and the tick

## Agent

Title: `[Opus 5.5] LIB-05 M1-T9b steps and tick` · Profile: implement · Model: Opus 5.5.
Audit: `[GPT-6-Astra]`, cost and determinism.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task `hexx` gives every walker of the tick its step from the one shared flood, and a
benchmark measures **the worst tick of the game as the library sees it**: the window assembled
from 4 chunks, the flood capped at 15 layers (D-127), and 8 walkers choosing their steps in
ascending id order with the occupancy updated after each move. It closes need N-8 and gives the
game the figure it plans its budget on.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-127, D-32, D-143; the
   decision on `FloodTrait::depth`), then **§6.9** (the selection functions `next_step`,
   `next_step_away`, `distance`: contract, sketch, regression cases R-N8-*, the fixture
   `SERPENTINE_15X16`, the eight-walker fixture), §7 (their rows and the tick), §1.4.
2. What exists: `crates/hexx/src/finders/flood.cairo` (`Flood`, `FloodTrait`, from M1-T9a) and
   `crates/hexx/src/board/assembly.cairo` (`AssemblyTrait::window`, from M1-T4a), with their
   reports in `docs/reports/`.
3. The game's rules under `sources/grimworld/`: `docs/needs/hexmap.md` (answers to LIB-03,
   point 5: frozen occupancy for the flood, current occupancy filtering each walker's
   candidates, ascending id order, fallback to the same layer) and D-127 (15 layers; a goblin
   not reached holds its position).
4. The game's spike, `sources/grimworld/docs/research/SPK-7-chunked-maps.md`: the capped flood
   with 8 goblins measured **634,655**, and with their 8 steps **1,150,737**; the chunked map adds
   about 720,000 per tick. Your tick is compared with these.

## Scope

**In**

1. **The selection functions of §6.9** on `FloodTrait` (D-143: scoped, short names), with the
   contract as normative: `next_step` (towards the source: the neighbour in the lowest layer,
   ties by lowest tile index, filtered by the current occupancy, `None` when no candidate or
   when the walker is beyond `depth`), `next_step_away` (the kiting profiles), `distance` (the
   inferred distance of a tile outside the layers, D-26), and whatever else §6.9 lists for them.
   The open-edge source of D-32: a walker next to it may step onto it.
2. **Tests first**: a scalar oracle for each function; every regression case R-N8-* (the
   winding corridor, its layer counts, the one- and two-obstacle variants, the all-blocked
   reverse scan, the eight-walker fixture with its expected moves); both limb paths; 15 × 16.
3. **The tick benchmark**, the figure of this task: `window` from 4 chunks (two layers) → flood
   capped at 15 on the window with the occupancy frozen → 8 walkers in ascending id order, each
   `next_step` filtered by the occupancy updated after the previous moves. On two boards: a cave
   assembled from 4 chunks, and the serpentine. Measured as the difference of two tests. Also
   each selection function alone, on its worst case of §6.9.
4. `crates/consumer`: a call site of each new public function; snapshots and generated
   documents regenerated.

**Stop condition — every measured figure.** If any measured figure is above the upper bound of
its target range in §7, stop at once: do not optimise, rewrite or set its budget; report it.
The tick of §7 was estimated with a flood of 25 layers; with the game's cap of 15 its range is
to be derived from §7's own formula, stated in the report before the measurement.

**Out**

- Any change of behaviour of the engine taken over, of `flood.cairo`'s existing functions, of
  `assembly.cairo`; the facade `board/map.cairo` (the orchestrator's); N-7, N-5, N-6, N-1, N-2.
- `scripts/**`, `.github/**` (a new file of yours that the move proof must know: say so in the
  report; the orchestrator adds it).
- Any publication.

**Allowlist**

- `crates/hexx/src/finders/flood.cairo` (additions: the selection functions)
- `crates/hexx/src/tests/test_steps.cairo`, `crates/hexx/src/tests/bench_tick.cairo` (new), and
  fixtures added to `crates/hexx/src/tests/fixtures.cairo` (additions only), with the lines
  declaring them
- `crates/consumer/**`
- `docs/EXTENSIONS.md`, `docs/API_PARITY.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`
- `REPORT.md` (ignored by git)

## Acceptance criteria

- [ ] AC-1 Every oracle equals its function on the cases of Scope 2; every R-N8-* case passes
      with its expected output (or the report shows the plan wrong, with the arithmetic).
- [ ] AC-2 The tick benchmark measured on both boards, with its breakdown (window, flood,
      8 steps), compared with SPK-7 and with the range derived from §7; the stop condition
      applied if needed.
- [ ] AC-3 `crates/takeover_tests` green and untouched; the move proof passes in CI.
- [ ] AC-4 Functions scoped; no free function without a written reason.
- [ ] AC-5 `scripts/check.sh` passes; CI green (a gas-only mismatch on a test reaching
      `Digger::dig` is the known compile drift, D-154: re-run once and say so).
- [ ] AC-6 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]` runs its own oracle for each selection function on the regression cases and on
boards of its choice, checks the id order and the occupancy update in the tick benchmark (that
it models the game's rule, not a simpler one), checks the tie-break (lowest tile index) and the
`None` cases, reads the benchmark method and compares the tick with SPK-7, and applies the
organisation lens (COMMON §4).

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the table: benchmark → measured → SPK-7 →
range derived from §7, and the breakdown of the tick.
