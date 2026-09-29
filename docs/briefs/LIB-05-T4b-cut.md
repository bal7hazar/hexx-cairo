# LIB-05 M1-T4b — N-4: the cut of a board by a mask

## Agent

Title: `[Sonnet 5.5] LIB-05 M1-T4b cut` · Profile: implement · Model: Sonnet 5.5 (a small,
fully specified function). Audit: `[GPT-6-Sol]`.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task `hexx` cuts a board by a mask — need N-4, the outlines of the game's zones — with
the game's semantics, and the conversion `local` of N-3 is tested exhaustively.

## Context

- [The plan](../research/LIB-03-porting-plan.md) **§14 first**: its row D-23 **reverses** §6.5.
  For the game, `cut` keeps the ring tiles that are inside the mask: **`cut(grid, mask) = grid &
  mask`**, bits at or above `W·H` cleared. The ring of a chunk holds the openings to its
  neighbours, and the game opens edges before it cuts by the outline. Then §6.5 for the rest
  (module, domain, oracle); its regression cases R-N4-1 to R-N4-3 are **rewritten** for `grid &
  mask`, each expected value recomputed in the report.
- `crates/hexx/src/board/assembly.cairo` and its tests (`test_assembly.cairo`), from M1-T4a; the
  audit of M1-T4a, `docs/audits/LIB-05-M1-T4a-audit-gpt-6-astra.md`, finding 2.

## Scope

**In**

1. **`cut`**, scoped (D-143): in `board/cut.cairo`, a trait with a short name (for example
   `CutTrait::cut(map, mask) -> HexMap`, or a method on the map through that trait); a free
   function needs a written reason. Semantics: every tile keeps its state iff its bit is set in
   the mask; nothing else changes (dimensions, seed); bits of the mask at or above `W·H` have no
   effect. No per-tile loop.
2. **Tests first**: the per-tile oracle on every tile of 7 × 7, 15 × 15 and 15 × 16 on 32 seeded
   pairs (map, mask); R-N4-1 to R-N4-3 rewritten for `grid & mask` (an open edge tile inside the
   mask stays open; the property `cut(m, mask) == cut(m, mask & board)`; a mask of high bits only
   gives an empty grid); a cut board is still a valid board for the finders (a search on it
   agrees with the scalar BFS of the tests).
3. **The deferred coverage of `local`** (audit of M1-T4a, finding 2): an exhaustive check of
   `AssemblyTrait::local` on every tile of the window for every origin the contract allows, or a
   documented Cartesian argument with separate sweeps of the columns and the rows that covers the
   same set, and its test.
4. Budgets at `ceil(1.05 × measured)`, attribute included; a call site in `crates/consumer`;
   generated documents and snapshots regenerated.

**Stop condition — every measured figure.** Above the upper bound of its range in §7: stop and
report, do not optimise or set its budget.

**Out**: any change of the engine taken over or of `assembly.cairo`'s functions; the facade
`board/map.cairo` (the orchestrator's); `scripts/**`, `.github/**` (a new file the move proof must
know: say so, the orchestrator adds it); any publication.

**Allowlist**: `crates/hexx/src/board/cut.cairo` (new), the line declaring it;
`crates/hexx/src/tests/test_cut.cairo` (new), the line declaring it; additions to
`crates/hexx/src/tests/test_assembly.cairo`; `crates/consumer/**`; `docs/EXTENSIONS.md`,
`docs/API_PARITY.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`; `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 The oracle equals `cut` on every case of Scope 2; R-N4-1 to R-N4-3 pass with the values
      recomputed in the report.
- [ ] AC-2 The coverage of `local` of Scope 3 exists and passes.
- [ ] AC-3 Scoped, no per-tile loop, no free function without a written reason.
- [ ] AC-4 `scripts/check.sh` passes; CI green (a gas-only or class-size mismatch on code reaching
      `Digger::dig` is the compile drift of D-154: say so; the orchestrator re-runs).
- [ ] AC-5 Nothing outside the allowlist was written.

## What the auditor will check

The semantics against §14 (not against the body of §6.5), the oracle and the rewritten regression
cases, the coverage of `local`, the budgets, and the organisation lens (COMMON §4).

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7.
