# LIB-05 M1-T8 — N-1: generation of a chunk given its margins, and `smooth`

## Agent

Title: `[Fable 5.1] LIB-05 M1-T8 margins` · Profile: implement · Model: Fable 5.1 (the bit-sliced
automaton with masked planes, a global row parity, exactness of every field product, and a stream
that becomes API). Audit: `[GPT-6-Astra]`, determinism (`nexus audit --model gpt-6-astra`, when
Codex has budget). Review: `nexus review` (its fallback is Opus 5.5, another model).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

**Starts after M1-T7 is merged**: it uses `LayoutTrait::new_odd`, which M1-T7 adds.

## Goal

After this task the game can generate a chunk of 15 × 15 whose ring holds the tiles copied from
its already generated neighbours, with the global parity of its rows, and can smooth an existing
grid while holding chosen tiles. It is need N-1 of milestone L-M1, for the game's ENG-05 (release
candidate `0.1.0-rc.2`, with N-2). Chunks stay 15 × 15 rectangles (D-165 closed by the owner,
2026-10-01). The four corners of a chunk are always wall (D-134).

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (D-134, D-143, D-167, the accepted
   figures), then **§6.2** in full (N-1: the contract, R-N1-1 to R-N1-7, the design sketch: the six
   planes, the no-carry rule, the exactness of every product), §3.3 (the parity flag is a
   parameter), §7 (the rows of `generate_with_margins`, `new_cave_with_margins`, `smooth`).
2. What exists: `crates/hexx/src/generators/caver.cairo` (taken over: `CaverInternal::fill`,
   `step`, the bit-sliced B4/S2), `crates/hexx/src/board/{layout,map}.cairo` (`new_odd` from
   M1-T7), the scalar `reference` automaton of `src/tests/bench_caver.cairo`, `gas/accepted.md`.

## Scope

**In**

1. The plan's three signatures and contracts, normative: `generate_with_margins(width, height,
   order, seed, fixed, values, odd) -> felt252` on the `Caver` generator, its facade
   `HexMapTrait::new_cave_with_margins` (forwards), and `HexMapTrait::smooth(self, order, held,
   odd) -> HexMap`, scoped as the engine already scopes `Caver` and the facade (D-143). The domain
   check `W·(H + 1) + 1 ≤ 251`, else `'Caver: dimensions too large'` (D-30).
2. **D-134**: the four corner tiles of a generated chunk are wall, whatever `seed`, `fixed` and
   `values` say. Freezing the ring is not enough: a free ring tile, a corner included, is drawn from
   the seed. The implementation forces the four corners to wall; a corner set in `values` is either
   cleared or refused with an error, and the report says which and why (an escalation if the plan
   does not settle it). Asserted on every seeded case, both parities.
3. **Tests in the module (D-167)**: in `caver.cairo`'s and `map.cairo`'s `#[cfg(test)] mod tests`
   (additions only: the taken-over tests stay where they are). The oracle of §6.2 in full: (1) the
   scalar automaton extended with frozen tiles and the global parity of row 0, on 3 × 3 to 15 × 15,
   both parities, 64 seeds; (2) equality with `generate` when the whole ring is fixed to wall
   (R-N1-4, R-N1-7); (3) fixed and held tiles unchanged after any order, the free ring tiles equal
   to the fill; (4) the six planes on **interior destinations only**, against the scalar neighbour
   table, on every interior tile of 15 × 15 and 7 × 7, both parities, 256 seeded grids. R-N1-1 to
   R-N1-7 with their expected values. **The stream**: one test pins the grid of one seed per parity,
   all sides fixed and none fixed; it is API from 0.1.0. **`new_odd`**, first used here: a test of
   `expand` (and of any other method of `Layout` this task relies on) on a `new_odd` layout against
   the scalar neighbours with the global parity, on every interior tile of 15 × 15 and 7 × 7 (the
   review of M1-T7, note 3: no test runs them on such a layout yet).
4. Budgets at `ceil(1.05 × measured)`, benchmarks on the worst cases of §6.2 (order 3 and order
   255, 15 × 15, all four sides fixed, `odd = true`; order 5 for the per-generation figure); a call
   site of each new public item in `crates/consumer`; the generated documents and `gas/hexx.snap`
   regenerated.
5. `scripts/takeover_check.py`: `EXTENDED` entries for `src/generators/caver.cairo` and
   `src/board/map.cairo` (additions only), comment `M1-T8, N-1`. The move proof must print
   `0 problem(s)`; the existing functions of both files are unchanged byte for byte.

**Ranges** (§7, unchanged):

| Function | Case | Range |
|---|---|---|
| `generate_with_margins` | order 3, 15 × 15, all sides fixed, `odd = true` | [234,464, 293,080] |
| `generate_with_margins` | order 255, same | [15,842,840, 19,803,550] |
| `smooth` | order 3, ring + 20 held tiles, `odd = true` | [208,890, 261,113] |
| `smooth` | order 255 | [16,672,050, 20,840,063] |

**Stop condition — every measured figure.** `generate_with_margins` at order 3 (the game's
generation of a chunk): above the upper bound of its range, stop and report; do not optimise or
set its budget. Every other figure: above **twice** the upper bound of its range, stop and report;
between the upper bound and twice it, set the budget on the measurement, go on, and list the figure
under *Escalations* with the operations that explain it. **A stop holds from the first
measurement** (`COMMON.md` §4): a rewrite after a crossing is the optimisation the stop forbids. A
failed oracle is a stop as well.

**Out**: N-2 (M1-T7); any change of behaviour of `generate`, of the other generators, of the
finders or of the functions of M1-T3 to M1-T7; any change of the stream of `generate`;
`scripts/**` beyond Scope 5; `.github/**`; any publication.

**Allowlist**: `crates/hexx/src/generators/caver.cairo` and `crates/hexx/src/board/map.cairo`
(additions only), `crates/hexx/src/lib.cairo` (root re-exports of the new items only, if any),
`scripts/takeover_check.py` (Scope 5 only), `crates/consumer/**`; `docs/API_PARITY.md`,
`docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`;
`REPORT.md`. `gas/takeover_tests.snap` is not in it: a row that moves there, other than to the
second build of D-154 (`gas/takeover_tests.builds` once LIB-04d is merged, `COMMON.md` §4), means a
taken-over function changed, which is out of scope: stop and report.

## Acceptance criteria

- [ ] AC-1 Every oracle of Scope 3 equals its function on its whole case set; R-N1-1 to R-N1-7
      pass with their expected values (or the report shows the plan wrong); D-134 holds on every
      seeded case.
- [ ] AC-2 The move proof passes with the two `EXTENDED` entries; `crates/takeover_tests` passes
      unchanged.
- [ ] AC-3 Scoped (D-143), tests in their modules (D-167), the parity a parameter (§3.3).
- [ ] AC-4 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-5 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]`: its own scalar automaton with frozen tiles and global parity against
`generate_with_margins` and `smooth`, both parities, seeded and extreme cases; the six planes on
interior destinations; the no-carry rule and the exactness of every product; D-134; equality with
`generate`; the pinned stream; that nothing taken over changed; the placement of tests (D-167); the
organisation lens.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the figures of the ranges table beside their
measurements.
