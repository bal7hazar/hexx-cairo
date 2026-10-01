# LIB-05 M1-T7 — N-2: sides and openings between chunks

## Agent

Title: `[Opus 5.5] LIB-05 M1-T7 seams` · Profile: implement · Model: Opus 5.5 (four masked-shift
formulas whose exactness conditions are the whole difficulty, and the global row parity). Audit:
`[GPT-6-Astra]`, determinism (`nexus audit --model gpt-6-astra`, when Codex has budget). Review:
`nexus review --model fable` while Codex has none (the owner's rule of 2026-10-01).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task the game can ask, for two neighbouring chunks of 15 × 15, which tiles of one side
are open towards the other across the seam, with the global parity of the rows, and whether the
seam is passable at all. It is need N-2 of milestone L-M1, for the game's ENG-05 (release candidate
`0.1.0-rc.2`). The chunks stay 15 × 15 rectangles: the owner closed D-165 on 2026-10-01 (SPK-14,
"cost efficiency first").

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-134: the four corners of a chunk
   are always wall and openings are never on a corner; D-143; D-167; the accepted figures), then
   **§6.3** (N-2: the contract, R-N2-1 to R-N2-4 with R-N2-3b, the design sketch and its exactness
   conditions), §3.3 (the parity flag is a parameter, never a field of `HexMap`), §6.2 (what N-1
   will need from the same flag), §7 (the rows of `seams::*` and `LayoutTrait::new_odd`).
2. What exists: `crates/hexx/src/board/{layout,asserter,map,bits}.cairo` (`LayoutTrait::even`,
   `Asserter::is_edge`, `is_corner`), `Digger::corridor`, `gas/accepted.md`.

## Scope

**In**

1. `board/seams.cairo`: `Side { East, North, West, South }` and a trait `SeamTrait` (D-143) with
   the plan's three functions, contracts normative: `side(width, height, side) -> felt252`,
   `openings(width, height, near, far, side, odd) -> felt252`, `is_open_across(...) -> bool`.
   **Every union of contact sets is an OR** (they overlap, R-N2-1). Every product keeps its
   exactness condition of §6.3 (the bits cleared before a shift, so that nothing reaches `2^251`).
2. `LayoutTrait::new_odd` in `board/layout.cairo` (the layout of a chunk whose local row 0 is a
   global odd row, §7: `Layout::new` and one subtraction), deferred from M1-T3; the seams use it, and
   N-1 will. Nothing else of `layout.cairo` changes.
3. **D-134 on the seams**: a regression case asserts that when both chunks have their four corners
   as wall, no corner tile is ever in `openings` (every side, both parities, the seeded pairs of
   Scope 4). The contract itself is unchanged: a corner is tested like any other tile of its side.
4. **Tests in the module (D-167)**, in `seams.cairo`'s `#[cfg(test)] mod tests` (and `new_odd`'s in
   `layout.cairo`'s). Oracle, §6.3's "Oracle" row in full: the scalar definition on **signed global
   coordinates** (the six neighbours of each tile of `near`'s side with the global parity, looked up
   bit by bit in `far`; never a board of `2W × H`), on every side, both parities, 32 seeded pairs of
   boards and the four full/empty combinations, on **every dimension class of the domain** (15 × 15,
   15 × 16, 16 × 15, 17 × 14, 19 × 13, 25 × 10, 83 × 3, 3 × 83, 7 × 7, 3 × 3). R-N2-1 to R-N2-4 and
   R-N2-3b with their expected values. Split a test over the step limit; never sample an oracle the
   plan states exhaustively.
5. Budgets at `ceil(1.05 × measured)`, benchmarks on the worst cases of §6.3; a call site of each
   new public item in `crates/consumer`; the generated documents and `gas/hexx.snap` regenerated.
6. `scripts/takeover_check.py`: an `OWN_FILES` entry for `src/board/seams.cairo`, comment
   `M1-T7, N-2`; `src/board/layout.cairo` is already in `EXTENDED`. Nothing else of that script.

**Ranges** (§7, unchanged):

| Function | Case | Range |
|---|---|---|
| `SeamTrait::openings` | East seam, `odd = false`, both fully open, 15 × 16 | [33,871, 42,339] |
| `SeamTrait::openings` | a horizontal seam (South, odd) | [23,287, 29,109] |
| `SeamTrait::side` | any | [3,032, 3,790] |
| `SeamTrait::is_open_across` | as `openings` | `openings` plus about 100 |
| `LayoutTrait::new_odd` | any | [13,200, 16,500] |

**Stop condition — every measured figure.** `openings` on its worst case (the East seam): above
the upper bound of its range, stop and report; do not optimise or set its budget. Every other
figure: above **twice** the upper bound of its range, stop and report; between the upper bound and
twice it, set the budget on the measurement, go on, and list the figure under *Escalations* with
the operations that explain it. **A stop holds from the first measurement** (`COMMON.md` §4): a
rewrite after a crossing is the optimisation the stop forbids. A failed oracle is a stop as well.

**Out**: N-1 (`generate_with_margins`, `smooth`: M1-T8); any change of behaviour of the engine
or of the functions of M1-T3 to M1-T6; `Digger::corridor` (it stays as taken over); the facade
`board/map.cairo` beyond a forwarding method if §6.3 names one; `scripts/**` beyond Scope 6;
`.github/**`; any publication.

**Allowlist**: `crates/hexx/src/board/seams.cairo` (new), `crates/hexx/src/board/layout.cairo`
(`new_odd` and its tests only), `crates/hexx/src/board.cairo` and `crates/hexx/src/lib.cairo`
(module declaration and root re-exports of the new items only), `scripts/takeover_check.py` (Scope
6 only), `crates/consumer/**`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`,
`docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`; `REPORT.md`. `gas/takeover_tests.snap` is not
in it (`COMMON.md` §4, the D-154 drift).

## Acceptance criteria

- [ ] AC-1 The oracle of Scope 4 equals `openings` on its whole case set, every dimension class;
      R-N2-1 to R-N2-4 and R-N2-3b pass with their expected values (or the report shows the plan
      wrong); the D-134 case of Scope 3 passes.
- [ ] AC-2 No product of the four formulas can reach `2^251` on any board of the domain (say how
      the tests show it, the West lower diagonal of 15 × 16 included).
- [ ] AC-3 Scoped (D-143), tests in their modules (D-167), the parity a parameter (§3.3).
- [ ] AC-4 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-5 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]`: its own scalar seam on global coordinates against `openings` on every side, both
parities and every dimension class, seeded and extreme boards; the exactness of every shift; the
overlap of contact sets; corners (D-134); `new_odd` against its definition; the placement of tests
(D-167); the organisation lens.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the figures of the ranges table beside their
measurements.

## Decisions of the orchestrator at the close (2026-10-01)

By `[Opus 5.5]`, on the agent's report (pull request #74, no stop). They amend this brief.

1. **Accepted as measured**: `SeamTrait::side` 3,840 against [3,032, 3,790], under twice its bound;
   the sketch's sum leaves out the `NonZero` conversion, two products and the `match` on `Side`. Not
   on the tick. Written in §14 of the plan and in `gas/accepted.md` by the orchestrator.
2. **`openings` does not call `new_odd`** (the brief's "the seams use it"): accepted. A whole layout
   costs about 10,600 and the contract is unchanged; `new_odd` ships with its tests and a consumer
   call site for N-1.
3. No root re-export, as for the other extensions: accepted.
