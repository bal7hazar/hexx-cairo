# LIB-05 M1-T4a — N-3: the assembly of the window

## Agent

Title: `[Opus 5.5] LIB-05 M1-T4a assembly of the window` · Profile: implement · Model: Opus 5.5
(an algorithm under a gas budget, on the game's critical path). Audit: `[GPT-6-Astra]`, cost
and determinism.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly; temporary directories under your worktree.

## Goal

After this task `hexx` assembles the game's simulation window: a board of **15 columns ×
16 rows** from the **2 or 4 chunks of 15 × 15** it overlaps, at each tick, without a loop over
rows, the origin always on an even global row. It is need N-3 of the game, the first extension
of milestone L-M1, and the first of the two functions (with N-8) that decide the cost of a
tick.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md) **§14 first** (it wins over the body: D-120,
   D-134, D-143 rows), then **§6.4** (N-3: contract, design sketch, regression cases R-N3-*),
   §6.4b (the fallback, not designed), §7 (the rows of `assemble` and `window`: target ranges),
   §1.4 (contract normative, sketch not).
2. The game's needs, `bal7hazar/grimworld` `docs/needs/hexmap.md` § *N-3 in detail* and
   § *Chunk borders* (D-134): copied in the worktree under `sources/grimworld/`.
3. [window-parity-check](../research/window-parity-check.md): why the origin must be even.
4. The game's spike SPK-7, `sources/grimworld/docs/research/SPK-7-chunked-maps.md`: it measured
   an assembly of 15 × 16 from 4 chunks on `origami_hexmap` 1.8.0 at **65,224** L2 gas in
   memory (its §2.1 and table), with the same method (a mask from two tables, one shift per
   chunk and layer). Your measurement is compared with it.

## Scope

**In**

1. **The functions of §6.4**, scoped (D-143, COMMON §4), with the contract of the plan as
   normative: `origin` (the Euclidean split of the adventurer's location coordinates into chunk
   index and offset, never an odd origin), `local` (a location tile to a window tile, or
   `None`), `assemble` (one layer: up to 4 chunks into one board of 15 × 16), `window` (both
   layers, the ring of the window imposed as wall). Names and signatures as §6.4 gives them,
   inside a trait of a module `board/assembly.cairo` (for example `AssemblyTrait::{origin,
   local, assemble, window}`); the band tables in `board/tables.cairo`, a table of constants
   being a written reason for a free constant. An odd origin panics with the named message of
   the plan (`'Assembly: odd origin'`), in an `AssemblyAssert` impl with an `errors` module.
2. **Void chunks (D-134)**: a chunk the window overlaps may be void (beyond the edge of the
   location, or outside a zone's outline): the caller passes a flag or an absent chunk, and it
   is assembled as **wall, without a read**; the window is **never clamped**. Say in the
   signature how a void chunk is passed (for example `Option<felt252>`), with the reason.
3. **Tests first, from the contract**: the scalar oracle of §6.4 (tile by tile, on global
   coordinates), compared with `assemble` and `window` over **all 225 offsets** of the origin
   within a chunk × both row parities of the chunk row × 2 and 4 chunks; every regression case
   R-N3-* of the plan, with its input and expected output; a window with 1, 2 and 3 void
   chunks (D-134); an odd origin refused; the adventurer on local `(7, 7)` or `(7, 8)`
   (D-120). Every test carries its budget (COMMON §4).
4. **Benchmarks on the worst case**: `assemble` of one layer from 4 chunks, and `window` of two
   layers from 4 chunks, measured as the difference between a test that calls twice and one
   that calls once, as SPK-7 does. Report both figures next to SPK-7's 65,224 and to the target
   range of §7.
5. **`crates/consumer`**: a call site of each public function (AGENTS.md principle 11), the
   class-size snapshot updated.
6. `docs/EXTENSIONS.md`, `docs/GAS.md`, `gas/*.snap` regenerated.

**Stop condition (gate L-G2, condition 1).** If a measured figure is **above the upper bound of
its target range in §7** (after the §14 correction of the window: `window` at most 123,453),
stop, do not optimise blindly and do not set a budget on it: report the figure, the breakdown
you can measure, and what you would try.

**Out**

- Any change of the engine taken over (`board/map.cairo` and the other moved files, except
  adding `pub mod` lines where a new module must be declared), of the finders, of the
  generators; N-4 (`cut`, M1-T4b); the fallback of 13 × 14.
- `scripts/**`, `.github/**`, `gas/takeover*`: not yours.
- Any publication.

**Allowlist**

- `crates/hexx/src/board/assembly.cairo`, `crates/hexx/src/board/tables.cairo` (new)
- `crates/hexx/src/board.cairo` or `crates/hexx/src/lib.cairo`: only the lines declaring the
  new modules and, if the plan says so, their re-export
- `crates/hexx/src/tests/test_assembly.cairo`, `crates/hexx/src/tests/bench_assembly.cairo`
  (new) and the line declaring them
- `crates/consumer/**`
- `docs/EXTENSIONS.md`, `docs/API_PARITY.md`, `docs/GAS.md`, `gas/hexx.snap`,
  `gas/consumer.snap`, `gas/bytecode.size`
- `REPORT.md` (ignored by git)

## Acceptance criteria

- [ ] AC-1 The oracle equals `assemble` and `window` on the 225 offsets × both parities × 2 and
      4 chunks, and on the void-chunk cases; every R-N3-* case passes with the expected output
      of the plan (or the report shows the plan's expected value is wrong, with the arithmetic).
- [ ] AC-2 An odd origin panics with the named message; `origin` never returns an odd one
      (tested over the location coordinates of §6.4, including `(0, 0)` → chunk −1).
- [ ] AC-3 The two benchmarks are measured, compared with SPK-7 and §7, and within the upper
      bound, or the stop condition was applied.
- [ ] AC-4 No loop over rows in `assemble`; functions scoped; no free function without a
      written reason.
- [ ] AC-5 `python3 scripts/takeover_check.py` still proves the move; `crates/takeover_tests`
      untouched and green.
- [ ] AC-6 `scripts/check.sh` passes; CI is green (a gas-only mismatch on a test reaching
      `Digger::dig` is the known compile drift: re-run once and say so in the report, D-154).
- [ ] AC-7 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]` re-derives the masks and the shift of each of the four chunk roles, checks the
exactness of every field multiplication or division (no bit wrapping between rows, no bit at or
above 240), runs its own oracle over the 225 offsets, checks the void-chunk path reads nothing,
checks the regression cases against the plan, re-measures nothing but reads the benchmark
method and compares the figures with SPK-7 and §7, and applies the organisation lens (COMMON
§4: traits, short names, no unjustified free function).

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the table: function → measured → SPK-7 →
target range of §7.
