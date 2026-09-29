# LIB-05 M1-T9a — N-8: the flood

## Agent

Title: `[Opus 5.5] LIB-05 M1-T9a flood` · Profile: implement · Model: Opus 5.5 (the plan allows
Fable 5.1 for this task; no Fable agent is started before the quota reset of 2026-09-30).
Audit: `[GPT-6-Astra]`, cost and determinism.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task `hexx` computes the **one flood per tick** the game shares between all its
goblins: from the adventurer's tile, on a board with the obstacles of the tick, the layers of
distance up to a parameter `depth`. It is the first half of need N-8; the selection of each
walker's step and the benchmark of the tick are M1-T9b.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (it wins: D-127, D-32, D-143
   rows), then **§6.9** (N-8: the contract, the design sketch, the regression cases R-N8-*,
   the fixture `SERPENTINE_15X16`), §7 (the rows of the flood), §1.4.
2. The game's rules, under `sources/grimworld/`: `docs/needs/hexmap.md` (answers to LIB-03, point
   5: one flood per tick on the occupancy frozen at the start of the tick) and the decision
   D-127: **the game's flood stops at 15 layers; a goblin not reached holds its position;
   `depth` stays a parameter of the library**.
3. The game's spike SPK-7, `sources/grimworld/docs/research/SPK-7-chunked-maps.md`: on
   `origami_hexmap` 1.8.0 it measured **26,452 L2 gas per layer** on the window, 59,380 fixed;
   on a deep board 323,900 (10 layers), 456,160 (15), 588,420 (20), 2,407,277 (unlimited, 83
   layers). Your measurements are compared with these.
4. The engine: `crates/hexx/src/finders/bfs.cairo` (its layered flood, `BfsInternal`,
   `pub(crate)`), taken over unchanged and proved equal to 1.8.0 by `crates/takeover_tests`.

## Scope

**In**

1. **The flood of §6.9**, with its contract normative: `Bfs::flood` (or the signature §6.9 gives)
   returning a `Flood` value that holds the layers up to `depth`, `depth()` the largest defined
   distance, and nothing else of the selection (M1-T9b). Scoped (D-143): a `Flood` struct with
   its `FloodTrait` impl in `finders/flood.cairo`, the entry on `Bfs`; checks in an `Assert`
   impl with an `errors` module. The layers hold interior tiles only, layer 0 being the source
   even when it is an open edge tile (D-32, §14).
2. **Built on the existing layered flood** of `bfs.cairo`, not a second implementation: expose
   what `BfsInternal` already computes. **Nothing that the take-over tests cover may change
   result** (`crates/takeover_tests` stays green, untouched): a new public entry point may be
   added to `bfs.cairo`; an existing function may not change behaviour.
3. **Tests first**: the scalar oracle of §6.9 (a plain breadth-first flood tile by tile) compared
   with the layers on every regression case R-N8-* of the plan and on the fixtures, both limb
   paths, 15 × 16 included; `depth` 0, 1, 15 and larger than the board's reach; an obstacle set
   that disconnects the source; the open-edge source of D-32.
4. **Benchmarks on the worst cases**: the flood on `SERPENTINE_15X16` at `depth` 10, 15, 20 and
   without a limit (D-127), and on a cave window of 15 × 16 at 15 layers; the cost per layer and
   the fixed cost, each measured as a difference of two tests (as SPK-7 does). Report them
   beside SPK-7's figures and the target ranges of §7.
5. `crates/consumer`: a call site of each new public function; snapshots and generated
   documents regenerated.

**Stop condition — every measured figure.** If any measured figure is above the upper bound of
its target range in §7, **stop at once**: do not optimise, do not rewrite, do not set its budget.
Report the figure, what you can measure of its breakdown, and what you would try. (In M1-T4a the
condition was read as covering only some figures; it covers all.)

**Out**

- The selection functions (`next_step`, `next_step_away`, `distance`) and the tick benchmark
  (M1-T9b); N-7 and the three renames (M1-T3): call the helpers by their present names.
- Any change of behaviour of the engine taken over; `crates/takeover_tests`; `scripts/**`,
  `.github/**` (if a script needs a change, say so; do not edit it).
- Any publication.

**Allowlist**

- `crates/hexx/src/finders/flood.cairo` (new), `crates/hexx/src/finders/bfs.cairo` (only a new
  public entry point and what it needs; no change of an existing function's behaviour)
- the lines declaring the new module, and its re-export if §2.4 of the plan asks for it
- `crates/hexx/src/tests/test_flood.cairo`, `crates/hexx/src/tests/bench_flood.cairo` (new), the
  fixture `SERPENTINE_15X16` in `crates/hexx/src/tests/fixtures.cairo` (an addition only), and
  the lines declaring them
- `crates/consumer/**`
- `docs/EXTENSIONS.md`, `docs/API_PARITY.md`, `docs/GAS.md`, `gas/hexx.snap`,
  `gas/consumer.snap`, `gas/bytecode.size`
- `REPORT.md` (ignored by git)

If `scripts/takeover_check.py` fails because a new file is not in its `OWN_FILES`, say so: the
orchestrator adds it.

## Acceptance criteria

- [ ] AC-1 The oracle equals the layers on every case of Scope 3; every R-N8-* case of the plan
      passes with its expected output (or the report shows the plan wrong, with the arithmetic).
- [ ] AC-2 `crates/takeover_tests` unchanged and green; `takeover_check.py` proves the move except
      for the added entry point, which the report shows as the only diff of `bfs.cairo`.
- [ ] AC-3 The benchmarks of Scope 4 measured, compared with SPK-7 and §7, all within their upper
      bounds, or the stop condition applied.
- [ ] AC-4 Functions scoped; no free function without a written reason.
- [ ] AC-5 `scripts/check.sh` passes; CI green (a gas-only mismatch on a test reaching
      `Digger::dig` is the known compile drift, D-154: re-run once and say so).
- [ ] AC-6 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]` checks that the flood reuses the engine's layered flood and changes no existing
behaviour (by its own diff of `bfs.cairo`), runs its own scalar oracle on the regression cases
and on boards of its choice (both limb paths, 15 × 16, open-edge source, disconnected source),
checks `depth` at its boundaries, reads the benchmark method and compares the figures with SPK-7
and §7, and applies the organisation lens (COMMON §4).

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the table: benchmark → measured → SPK-7 →
target range of §7.
