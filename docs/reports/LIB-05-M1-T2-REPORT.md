# [Sonnet 5.5] LIB-05 M1-T2 — The mirror items of L-M1

**STOPPED on the stop condition of the brief: six measured figures are above the upper bound of
their range in §7 of the plan.** No budget was set, nothing was optimised, no snapshot or
generated doc was regenerated, **nothing was pushed and no pull request was opened** (CI could not
be green without budgets). The work is committed locally on `feat/lib-05-m1-t2-mirror`
(`73d05a7`, a `wip(...)` commit) so that it survives. The model is Sonnet 5.5, as the brief names.

## Summary

What exists in the worktree (compiles, all tests pass with placeholder budgets of 1,000,000,000):

- `crates/hexx/src/hex.cairo`: `Hex`, `HexTrait` (`ZERO`, `NEIGHBORS_COORDS`, `new`, `x`, `y`,
  `z`, `const_sub`, `length`, `ulength`, `distance_to`, `unsigned_distance_to`), doc template on
  every public item.
- `crates/hexx/src/direction.cairo`, `direction/edge_direction.cairo`: `EdgeDirection` (private
  `index: u8`), `EdgeDirectionTrait` with the 30 compass constants, `ALL_DIRECTIONS`, `iter`,
  `index`, `into_hex`, `const_neg`, `clockwise`, `counter_clockwise`, `rotate_cw`, `rotate_ccw`,
  and `Into<EdgeDirection, Hex>`.
- `crates/hexx/src/conversions.cairo`: `OffsetHexMode`, `HexConversionsTrait::{to_offset_coordinates,
  from_offset_coordinates}` (methods on `Hex`, D-143).
- `crates/hexx/src/orientation.cairo`: `HexOrientation` (`Default` = `Flat`, `Not`).
- `lib.cairo`: module declarations and root re-exports of these items.
- `tools/refgen`: specs and generators for `hex`, `direction`, `conversions`; the goldens are
  generated into `crates/hexx/tests/golden_{hex,direction,conversions}.cairo` (the staged
  `tools/refgen/generated/golden_hex.cairo` is removed). The generator runs `hexx` with
  `overflow-checks = true` in both profiles and records with `catch_unwind` where it panics:
  every `i32` value near the bounds either becomes a golden value or a `#[should_panic]` test.
  77 golden tests, 4,096 ordered pairs of 64 seeded points, all 6 directions × all 256 rotation
  counts, the 4 (mode, orientation) pairs. **All pass on the first run: the port agrees with
  `hexx` on every vector, panics included.**
- Hand-written tests against plain oracles (`tests/test_hex`, `test_edge_direction`,
  `test_conversions`) and `tests/bench_mirror`; `HexxMirror` in `crates/consumer` with a call site
  of every public item (30 constants included; it builds, `gas/bytecode.size` not rewritten).

## Stop condition: figures above the upper bound of §7

Method: `bench_mirror`, 100 iterations, two calls per iteration (worst-case operands: `(-n, -n)`
and `(n, n)`, so `z` is the largest component and `unsigned_abs` takes its negative branch),
per call = (test − `bench_mirror_baseline_operands` 453,990) / 200. Sierra gas, Scarb 2.19.4,
snforge 0.61.0, `snforge test --include-ignored` through `scripts/bench.py run --package hexx`.

| Function | Measured per call | Range in §7 | Over the upper bound |
|---|---:|---|---|
| `HexTrait::length` | 7,257 | [1,500, 1,875] | 3.9× |
| `HexTrait::ulength` | 9,579 | [1,500, 1,875] | 5.1× |
| `HexTrait::distance_to` | 8,722 | [1,500, 1,875] | 4.7× |
| `HexTrait::unsigned_distance_to` | 11,043 | [1,500, 1,875] | 5.9× |
| `to_offset_coordinates` (Even Pointy / Odd Flat) | 7,183 | [1,500, 1,875] | 3.8× |
| `from_offset_coordinates` (Even Pointy / Odd Flat) | 7,183 | [1,500, 1,875] | 3.8× |

Within range: `z` 1,030, `const_sub` 1,465 (2 calls and 2 field additions per iteration in the
figure, so an upper estimate), `x`, `y` 0 (inlined: the test equals its baseline).

Not validly measured: **the `EdgeDirection` benches** (`index`, `into_hex`, `const_neg`,
`clockwise`, `counter_clockwise`, `rotate_*`) use constant operands, which the compiler folds:
`bench_edge_direction_clockwise` equals its baseline to the gas. They must be rewritten with
runtime operands (loop over `iter()`, a varying offset) before any figure of §7 is claimed for
them. `Hex::new` is a struct construction not isolated by a baseline (test 370,830, below the
operands baseline). No figure is claimed for these.

Operations that explain the overage (**inferred from the code, not measured per operation**):

- `length` / `ulength` / distances: three branching `abs` (or `unsigned_abs`, which adds a
  `try_into` to `u32` per component) and the three-way maximum, about ten `i32` comparisons and
  negations at several hundred gas each; the plan's "at most 5 `i32` operations at 300" undercounts
  them. `z` alone is 1,030.
- offset conversions: `shove` does an `i32` `/ 2` and an `i32` `% 2` separately, two signed
  divisions; a signed division is the dominant cost (the plan counted 3 `i32` operations).

I did not try any of the obvious variants (a single `DivRem`, `u32` magnitudes, table lookups):
the brief forbids optimising or setting a budget once a figure is over. Whether the plan's range
or the implementation moves is the orchestrator's call.

## Files changed

- `crates/hexx/src/{hex,orientation,conversions,direction}.cairo`, `direction/edge_direction.cairo`: new.
- `crates/hexx/src/lib.cairo`: modules and re-exports.
- `crates/hexx/src/tests.cairo`: `pub mod` lines of the four new test files (see Deviations).
- `crates/hexx/src/tests/{test_hex,test_edge_direction,test_conversions,bench_mirror}.cairo`: new.
- `crates/hexx/tests/golden_{hex,direction,conversions}.cairo`: generated.
- `tools/refgen/`: `Cargo.toml` (overflow checks), `src/{main,spec}.rs` rewritten, `src/{cairo,hex,direction,conversions}.rs`, `specs/{hex,direction,conversions}.toml`; `generated/golden_hex.cairo` removed. `README.md` **not** updated (its "staged" section is now obsolete; `README.md` of the tool is under `tools/refgen/**`, left for when the task resumes).
- `crates/consumer/src/lib.cairo`: contract `HexxMirror`.

## Commands run

- `scarb build -p hexx`, `scarb fmt -p hexx`, `scarb build -p consumer`: green.
- `cargo run --locked --manifest-path tools/refgen/Cargo.toml -- gen`: wrote the three goldens.
- `snforge test -p hexx golden_`: 77 passed, 0 failed (placeholder budgets).
- `snforge test -p hexx tests::test_`: all green after fixing one wrong expectation of my own test
  (`X_NEG_Y.rotate_cw(255)` is `NEG_X_Y`, not `NEG_Y`).
- `python3 scripts/bench.py run --package hexx`: 7 min 30 s, the figures above.
- `python3 scripts/api_parity.py --check-release L-M1 --report-only`: 9 missing, see Escalations.
- **Not run**: `scripts/check.sh`, `bench.py snapshot/check`, `gas_tables.py`, `bytecode_size.py`,
  `deviations.py`, `api_parity.py --check`, `refgen -- check` (stopped first; nothing regenerated).

## Cost

Only the figures of the stop condition above are measured and valid. Budgets, `gas/hexx.snap`,
`docs/GAS.md` and `gas/bytecode.size` are **not** produced. Golden and oracle tests cost, for the
record: `golden_hex_pairs_N` 432,281,550 each (512 pairs), `golden_edge_direction_rotations_N`
about 41.6M each (256 rotations), `golden_offset_*` 8.3M to 9.4M, `test_hex_distance_matches_the_oracle`
339,305,520; every `#[should_panic]` test 15,320.

## Deviations

- **Stopped**: PR not opened, CI not awaited, budgets and snapshots not set (stop condition).
- `crates/hexx/src/tests.cairo` (module list) is not in the allowlist, but the four new test files
  cannot be compiled without their `pub mod` lines. Say so; the orchestrator may prefer another
  way.
- `refgen`'s spec format changed (flat `key = value`, no `[[function]]` blocks, `gas.<test>` keys
  for budgets) and the golden files moved from `tools/refgen/generated/` to `crates/hexx/tests/`,
  as the tool's README foresaw.
- Panic tests are `#[should_panic]` without an `expected` message: a Cairo overflow message names
  the operation (`i32_add`, `i32_sub`...), which differs between `hexx` and this port.
- Plan §7 gives the 30 constants and `ALL_DIRECTIONS` "no cost"; they are `const`s of the trait,
  read through `EdgeDirectionTrait::NAME`.
- Ported behaviour deviating from `hexx`, all written on the items: overflow panics (`Hex::z`,
  `const_sub`, `length`, `ulength`, distances, both offset conversions); `EdgeDirection` field
  named `index` (no tuple structs); `Into` for `From`; `iter` is a `Span`. `OffsetHexMode` derives no `Default`.

## Escalations

1. **Stop condition** (above): six figures over §7. Decision needed: revise the §7 ranges (they
   count 300 gas per `i32` operation, and branching `abs`, division and `u32` conversion cost
   more), or reopen the implementations, or both, before budgets are set.
2. **`scripts/api_parity.py` cannot see 8 of the 9 items it still lists** (`scripts/**` is the
   orchestrator's): with the Cairo written to the plan, `--check-release L-M1 --report-only`
   reports missing `HexOrientation::Default`, `HexOrientation::Not`,
   `EdgeDirection::From<EdgeDirection> for Hex`, `conversions::{OffsetHexMode, Even, Odd,
   from_offset_coordinates, to_offset_coordinates}` (plus `line_to`, expected). Cause, by reading
   `scan_cairo_tree` and `parse_cairo`: (a) the Cairo scan never emits `impl` items (a derived or
   written `Default`, `Not`, `Into<EdgeDirection, Hex>`), and no `COUNTERPARTS` or `RULES`
   entry maps them; (b) `owner_of` returns an owner only when the declared name is in `OWNERS`, so
   `pub enum OffsetHexMode` and a trait named after `conversions` never map to the owner
   `conversions` (`HexConversionsTrait` maps to `HexConversions`, not an owner). AC-2 needs a
   change of the script (an owner mapping by module path for `conversions`, and Cairo `impl`
   items or counterpart entries), or a decision on another shape of the Cairo API.
3. `iter`, the 30 constants and the `EdgeDirection` methods are found by the script (they are
   not in the missing list).

## Open questions

- Should `to_offset_coordinates` / `from_offset_coordinates` be methods of `Hex` (as written,
  `HexConversionsTrait`, one trait per `hexx` source file, plan §8 L-M2) or would the parity
  script rather expect a trait named `conversionsTrait`? (Only the script decides.)
- After the ranges of §7 are settled: the goldens of the pairs cost 432M gas each; if CI time
  matters, the 8 chunks can become 16 by editing `chunks` in `specs/hex.toml`.

## Follow-up 1

**STOPPED again on the stop condition, before budgets, snapshots, push and pull request.** Two
`EdgeDirection` figures, measured with runtime operands as decision (2) asks, are over their §7
range. The rest of the follow-up that does not depend on a figure is done and committed locally
(no push).

### Decision (1): the six figures of the first stop, recorded as the orchestrator's decision

The §7 ranges assumed about 300 gas per `i32` operation and were wrong; the measurements replace
them (not rewritten here, per the decision). Per call, Sierra gas, worst-case operands:
`length` 7,257; `ulength` 9,579; `distance_to` 8,722; `unsigned_distance_to` 11,043;
`to_offset_coordinates` 7,183; `from_offset_coordinates` 7,183. `z` 1,030 and `const_sub` 1,465
stay within their range.

### Decision (2): EdgeDirection benches with runtime operands

`bench_mirror` now iterates the six directions of `iter()` 17 times (102 calls per test) with an
offset `255 - rep` for the rotations; per call = (test − baseline) / 102. Baselines: 520,482
(index read and xor), 504,496 for `into_hex` (its own, same `try_into`).

| Function | Test | Per call | Range in §7 | |
|---|---:|---:|---|---|
| `into_hex` | 645,636 | 1,384 | [1,269, 1,587] | in range |
| `clockwise` | 666,512 | 1,432 | [1,398, 1,748] | in range |
| `const_neg` | 702,552 | **1,785** | [1,398, 1,748] | **over by 37** |
| `counter_clockwise` | 711,052 | **1,868** | [1,398, 1,748] | **over by 120** |
| `rotate_cw` (offset 238..255) | 689,206 | 1,654 | [2,496, 3,120] | in range |
| `rotate_ccw` (offset 238..255) | 742,146 | 2,173 | [2,496, 3,120] | in range |

Explanation (inferred): the cost of `wrap` depends on the mix of directions: the subtraction of 6
is taken for 1 direction in 6 after `+ 1`, 3 in 6 after `+ 3`, 5 in 6 after `+ 5`, each about 350
gas, which is why `clockwise` is cheapest and `counter_clockwise` dearest. The plan's sketch
(one addition, one `DivRem`) has no branch. **Decision needed** for these two: accept the
measurements (as for the six) or ask for a variant. No budget was set.

### Decision (3): `crates/hexx/src/tests.cairo`

The four `pub mod` lines are kept, as allowed.

### Decision (4): `scripts/api_parity.py` and `scripts/tests/test_api_parity.py` — done

- The Cairo scan emits `impl` items: a derived `Default` on a struct or enum (as the Rust side
  does, only `Default`), and `pub impl X of Trait<...>` of a corelib trait: `Default`, `Not`,
  `Neg` (no argument), `Add`, `Sub`, `Mul`, `Div`, `Rem` and their `*Assign` (with the operand),
  and `Into<A, B>` as `From<A> for B` (Cairo has no `From`). The owner is the first type argument.
  An impl of any other trait whose owner is a **mirror** owner raises `SystemExit` with file and
  line; on an extension module (`board`, ...) it is skipped, as before.
- `CAIRO_MODULE_OWNER = {("conversions",): "conversions"}`: every declaration of `conversions.cairo`
  is owned by `conversions`, with bare member names (`scan_cairo_tree(..., bare_owners=...)`), so
  `OffsetHexMode`, `Even`, `Odd` and the two conversions are seen.
- Effect: `--check-release L-M1 --report-only` lists only `Hex::line_to`. `docs/API_PARITY.md`,
  `docs/EXTENSIONS.md` and `docs/DEVIATIONS.md` regenerated. One side effect the brief did not
  name: `docs/EXTENSIONS.md` gains the item `impl From<Direction> for u8` (the board's
  `DirectionIntoU8`), because the extension scan shares the impl scan.
- Tests (`CairoImplItemsAndConversionsOwner`, `RealTreeMirrorOfL_M1`): derived `Default`; no
  `Default` without derive; `Not`; `Into` as `From`; a binary operator with its operand; an unknown
  trait on a mirror owner raises with file and line; a foreign-type impl is not a mirror item; the
  `conversions` owner with bare names; the real tree lists only `line_to`. `python3 -m unittest
  discover -s scripts/tests`: 171 tests OK (1 skipped: the origami checkout).

### Not done (blocked by the stop condition)

Budgets at `ceil(1.05 x measured)` (every test still has `1000000000`), `gas/hexx.snap`,
`docs/GAS.md`, `gas/bytecode.size`, `scripts/check.sh`, push, pull request, CI. Commits on
`feat/lib-05-m1-t2-mirror`: `73d05a7` (wip) and the one after it. The orchestrator's answer on
`const_neg` and `counter_clockwise` is all that is needed to resume.

## Follow-up 2

**Orchestrator decision (recorded as given):** `const_neg` (1,785) and `counter_clockwise` (1,868)
are 2 % and 7 % over ranges of §7 that were estimates; the measurements replace them, no rewrite.
Together with the six figures of Follow-up 1 this closes the stop condition for M1-T2.

### Done

- Budgets `#[available_gas(l2_gas: N)]`, `N = ceil(1.05 x measured)`, on every new test: the
  hand-written ones in place, the generated ones through `gas.<test>` keys of
  `tools/refgen/specs/{hex,direction,conversions}.toml` (budgets cannot live in a generated file
  otherwise; `refgen -- check` covers them).
- The generated golden files are now stable under `scarb fmt --check` (arrays packed as `scarb fmt`
  packs them, short lines, wrapped header); `scarb fmt --check --workspace` was failing on them.
- `gas/hexx.snap`, `docs/GAS.md` regenerated; `gas/bytecode.size` gains `HexxMirror: 2153 6012
  112610 148475` (7.3 % of the CASM limit); no other contract moved, `HexxGenerators` included (no
  D-154 drift).
- `scripts/check.sh`: **all checks passed** locally (the take-over proof skipped there: no
  `sources/origami` checkout).
- Pushed, pull request **#49** "[Sonnet 5.5] LIB-05 M1-T2 mirror items".

### CI on #49

All jobs green except one:

- **Take-over of origami_hexmap is a move: FAIL**, and therefore the aggregate "All checks
  passed". `scripts/takeover_check.py` reports `DESTINATION WITHOUT SOURCE` for the seven new files
  it does not know: `src/tests/{bench_mirror,test_conversions,test_edge_direction,test_hex}.cairo`
  and `tests/golden_{conversions,direction,hex}.cairo`. Every moved file of the take-over itself is
  `same`. `scripts/**` is not in this task's allowlist beyond `api_parity.py`: **the orchestrator
  must add these files to the script's list of files that are not part of the move.** I did not
  touch it.
- Everything else passes: build and test of `hexx` (9 m 50 s), `takeover_tests`, `consumer`, gas of
  the three packages (and the ignored tests), golden vectors up to date, format and docs, package
  rehearsal, links, shell scripts.

### State

My turn ends here with CI not fully green for the one reason above, which only the orchestrator can
fix (a one-line change in `scripts/takeover_check.py`); the new commit that does so needs no change
of mine.

## Orchestrator's note (`[Opus 5.5]`, 2026-09-30): the class size of HexxGenerators

CI always built `HexxGenerators` of `crates/consumer` at **27,101** Sierra felts (1,396,211
bytes, CASM 49,375) on this branch, attempts 1 and 2 of run 36749625318; two clean local rebuilds
of the same commit gave **27,092** (1,395,788 bytes), the committed snapshot. The difference
follows the environment, not the sources: the lead for the game's SPK-13. By decision D-164 of
the project manager, `gas/bytecode.builds` records the second build, exact, with its commits and
runs; any third value fails; it is removed when SPK-13 explains the cause.

## Fix loop 1

Audit `[gpt-6-sol]` pass 1 (`sources/audits/M1-T2-audit-pass-1.md`), verdict FAIL, two findings.
Both verified, both fixed in commit `bb457cc`. The orchestrator's commits `d76c289` and `2379a74`
(move proof, `gas/bytecode.builds`, D-164) were not touched.

1. **(major) `scripts/api_parity.py` skipped a public impl of an unrecognised `...Trait`.**
   Verified: the branch `if trait.endswith("Trait"): continue` skipped before any ownership check,
   so the auditor's `pub impl FooImpl of CustomTrait<HexOrientation>` produced no item and no
   error. Fix: `scan_cairo_tree` now first collects the traits it knows (`pub trait X` anywhere in
   the tree, and the trait of every `#[generate_trait]` impl); only an impl of a *known* trait is
   left to the trait-based block. Any other public impl goes through the classification of the
   corelib traits (`Default`, `Not`, `Neg`, the operators, `Into`), and one on a mirror owner that
   it cannot classify raises `SystemExit` with file and line (an impl on an extension module is
   skipped, as before). Tests: the auditor's scenario raises with `orientation.cairo:6` and the
   trait name; impls of a declared trait and of a generated trait (two impls of one trait) are
   not errors; the real tree still passes (`--check`, `--extensions --check`, the real-tree test,
   `--check-release L-M1` lists only `line_to`; docs unchanged). 105 tests in `test_api_parity`
   OK.
2. **(minor) four free test helpers.** Verified (`oracle_distance`, `oracle_shove`,
   `oracle_to_offset`, `check`). Now `OracleTrait::distance` (`test_hex.cairo`) and
   `OffsetOracleTrait::{shove, to_offset, check}` (`test_conversions.cairo`), each a
   `#[generate_trait]` impl in its test module. Gas of the affected tests is unchanged to the unit
   (339,305,520; 25,277,140; 9,645,760; 9,343,000), so their budgets stand.

Also: the `# budgets` comment of the three refgen specs was written twice by my budget script;
cleaned (generated files unaffected, `refgen -- check` green).

`scripts/check.sh`: all checks passed. Pushed; PR #49: **every CI check green**, including
"Take-over of origami_hexmap is a move" (the orchestrator's commit knows the seven files) and
"All checks passed". No class-size mismatch occurred (no D-154 drift).

## Follow-up 4

Codex review. **Finding 1** (budgets above the ranges of §7): dismissed by the orchestrator, the
figures were accepted in Follow-ups 1 and 2. **Finding 2** (minor): verified and fixed (commit
`b1509d4`).

- **The gap.** `EdgeDirection` derived `Serde`, so a value read from calldata could hold any `u8`
  index; `rotate_cw` on index 6 or more then returned an index above 5 and `into_hex` read past the
  six-element array, against the documented "None" of `#### Panics`.
- **The fix.** `Serde` of `EdgeDirection` is written by hand (`direction/edge_direction.cairo`):
  `serialize` is unchanged (one felt, the index, as the derive wrote it); `deserialize` reads a
  `u8` (so a felt that is no `u8` is refused too) and returns `None` for an index above 5. The impl
  is private, like a derived one: Cairo resolves it all the same, and `api_parity.py` (which
  raises on a public impl of an unknown trait on a mirror owner, fix loop 1) stays quiet. The
  deviation is written on the type.
- **Tests** (budgets `ceil(1.05 x measured)`): `test_edge_direction_serde_round_trip` (the six
  directions, one felt each, the index, all consumed; 53,739),
  `test_edge_direction_serde_refuses_an_index_above_five` (every index 6..=255, then 256 and the
  felt `-1`; 1,085,522).
- **The other types of the lot have no such gap** (`test_derived_serde_refuses_what_is_not_a_value`,
  29,516):
  - `OffsetHexMode`: derived `Serde` of an enum refuses an unknown variant index (2 refused, 0 read
    as `Even`). No gap.
  - `HexOrientation`: same (2 refused, 1 read as `Flat`). No gap.
  - `Hex`: two `i32`; every pair of `i32` is a valid coordinate (nothing to refuse), and `i32`'s
    own `Serde` refuses a felt out of range (`2^32` as `x`, `2^31` as `y` refused). No gap.
- Regenerated: `gas/hexx.snap`, `docs/GAS.md`, `docs/DEVIATIONS.md` (line numbers and the new
  text); `gas/bytecode.size`: `HexxMirror` 2212 6148 115513 151857 (7.5 % of the CASM limit, from
  2153 6012 112610 148475). **`HexxGenerators`: my local build gave 27101 49375 1396211 997304,
  the second build recorded in `gas/bytecode.builds` (the compile drift of D-154, D-164); I kept
  the snapshot line at 27092 49375 1395788 997126 and did not touch `gas/bytecode.builds`.**
- Also removed from the repository two scratch files (`tmp/scope.py`, `tmp/t.txt`) that my last
  commit (`bb457cc`) had committed by mistake.
- `scripts/check.sh`: all checks passed. Pushed; PR #49: **every CI check green**, including the
  move proof and "All checks passed".

## Disposition of the orchestrator (`[Opus 5.5]`, 2026-09-30)

- Audit (the lens determinism, model that ran GPT-6-Sol): pass 1 FAIL (an unknown public impl
  silently skipped by the parity tool; free test helpers), fixed; pass 2 PASS WITH FINDINGS (a note
  on D-164, fixed by the orchestrator).
- Codex review: pass 1 FAIL, finding 2 (a deserialised `EdgeDirection` could hold any index) fixed;
  its finding 1, repeated in pass 2 as the only one, is **dismissed**: the budgets set above the
  ranges of §7 follow the orchestrator's decisions of Follow-ups 1 and 2 (the ranges assumed about
  300 per `i32` operation), which the reviewer, reading the code and the brief only, could not see.
  From now on such decisions are also written in §14 of the plan, on the branch, so that a review
  reads them.
- CI: the tests of `hexx` run in two partitions of snforge (the job neared its 10 minutes). The
  class size of `HexxGenerators`: its second build recorded under D-164; a local build gave it once
  too, so the second value is not CI-only.
