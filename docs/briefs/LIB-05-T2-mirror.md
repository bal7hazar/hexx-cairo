# LIB-05 M1-T2 — The mirror items of L-M1

## Agent

Title: `[Sonnet 5.5] LIB-05 M1-T2 mirror items` · Profile: implement · Model: Sonnet 5.5 (a port
item by item, each checked against vectors generated from the real crate; the quota of the
sub-agents' account is at 94 % of its week). Audit: `[GPT-6-Astra]`, parity.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task `hexx` holds the part of the mirror of `hexx` 0.25.0 that milestone L-M1 rests on:
`Hex` and its distances, `EdgeDirection` and its rotations, the offset coordinates and their
modes, `HexOrientation`. Each item has the name, the signature (as close as Cairo allows) and
the numeric results of `hexx` 0.25.0, proved by golden vectors generated from the crate itself.
It is what N-7 (rotation, arcs) and N-5 (the line) are specified against, for the game's ENG-02.

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md): **§14 first**; §8, the row **"The mirror items
   of L-M1 (the canonical list)"** — exactly those items, `line_to` excepted (it is M1-T6);
   §3.1 (`Hex` on `i32`, overflow panics), §3.2 (two direction types: `EdgeDirection` here, the
   board's `Direction` unchanged), §3.5 (the conversion between `Hex` and a board index: **not**
   this task), §4.2 to §4.4 (the parity table, `refgen`, the inventory), §1.1 (what "port" means).
2. `tools/refgen/` and its README: specs, `cargo run -- gen <module>`, `-- check`; the staged
   golden file `tools/refgen/generated/golden_hex.cairo` (it moves into `crates/hexx/tests/` now
   that the mirror exists, as its README says).
3. `docs/API_PARITY.md`: `python3 scripts/api_parity.py --check-release L-M1 --report-only` lists
   the 66 items L-M1 still misses; after this task only `line_to` remains.
4. The pinned source `hexx` 0.25.0: under `sources/hexx` in the worktree (read-only).

## Scope

**In**

1. The items of the canonical list, as methods on their types (D-143, the mirror is methods on
   types): `crates/hexx/src/hex.cairo` (`Hex`, `HexTrait`), `crates/hexx/src/direction/
   edge_direction.cairo` (`EdgeDirection` and its trait), `crates/hexx/src/conversions.cairo`
   (`OffsetHexMode`, `from_offset_coordinates`, `to_offset_coordinates`),
   `crates/hexx/src/orientation.cairo` (`HexOrientation`), with the module declarations and the
   root re-exports of §2.4 of the plan for these items. Every public item carries the doc
   template `Mirrors …` / `#### Panics` / `#### Deviations` (`scripts/deviations.py`).
2. **Golden vectors from the crate**: `tools/refgen` specs for `hex`, `direction`, `conversions`
   (§4.3: the inputs it lists), generated with `cargo run -- gen`, committed under
   `crates/hexx/tests/`, and `-- check` green. Every item of the list is covered by at least one
   vector, including `i32` values near the bounds where `hexx` wraps and this port panics
   (§3.1: a documented deviation, tested with `#[should_panic]`).
3. Budgets at `ceil(1.05 × measured)`, attribute included; a call site of each new public item in
   `crates/consumer`; `docs/API_PARITY.md`, `docs/DEVIATIONS.md`, `docs/EXTENSIONS.md`,
   `docs/GAS.md`, the snapshots regenerated; `--check-release L-M1 --report-only` shows only
   `line_to` missing.

**Stop condition — every measured figure.** Above the upper bound of its range in §7 (the row of
the mirror foundation): stop and report; do not optimise or set its budget.

**Out**: `line_to` (M1-T6); `Direction` of the board, `rotate`, `arc`, the conversions `to_hex`,
`from_hex`, `index_to_hex`, `hex_to_index` and the three renames (M1-T3); every other mirror item
(L-M2); any change of the engine taken over or of the extensions; the facade `board/map.cairo`;
`scripts/**`, `.github/**` (a new file the move proof must know, or a parity rule to change: say
so, the orchestrator does it); any publication.

**Allowlist**: `crates/hexx/src/hex.cairo`, `crates/hexx/src/direction.cairo` and
`crates/hexx/src/direction/edge_direction.cairo`, `crates/hexx/src/conversions.cairo`,
`crates/hexx/src/orientation.cairo` (new); `crates/hexx/src/lib.cairo` (module declarations and
re-exports of these items only); `crates/hexx/tests/golden_*.cairo` and the test files of these
modules; `tools/refgen/**`; `crates/consumer/**`; `docs/API_PARITY.md`, `docs/DEVIATIONS.md`,
`docs/EXTENSIONS.md`, `docs/GAS.md`, `gas/hexx.snap`, `gas/bytecode.size`; `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 Every item of the canonical list except `line_to` exists with its name and passes its
      golden vectors; `tools/refgen` `-- check` is green.
- [ ] AC-2 `api_parity.py --check` passes; `--check-release L-M1 --report-only` lists only
      `line_to`; `deviations.py --check` passes, every deviation (overflow panics, iterators as
      spans) written on its item.
- [ ] AC-3 Methods on types; no free function without a written reason.
- [ ] AC-4 `crates/takeover_tests` untouched and green; `scripts/check.sh` passes; CI green (a
      class-size mismatch of `HexxGenerators` is the compile drift of D-154: say so).
- [ ] AC-5 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]` compares each item with `hexx` 0.25.0 in the source (name, signature, semantics,
edge cases), regenerates the vectors from the pinned crate and checks they match the committed
ones, looks for inputs the vectors miss (bounds, negative coordinates, every direction and every
rotation count), checks the deviations are written and tested, and applies the organisation lens.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7.
