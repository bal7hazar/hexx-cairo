# [Sonnet 5.5] LIB-05 M1-T4b — N-4: the cut of a board by a mask

## Summary

`CutTrait::cut(map, mask) -> HexMap` (`board/cut.cairo`) with the semantics of plan §14 (D-23 reverses §6.5): `grid & mask`, bits at or above `W·H` cleared, ring kept, dimensions and seed unchanged. No loop: `LayoutTrait::board(W, H)` as `u256`, two `Bits::and`, one `to_felt`. Scoped (trait + impl, no free function in `cut.cairo`). The exhaustive coverage of `AssemblyTrait::local` (audit of M1-T4a, finding 2) is added. Model: Sonnet 5.5, as the brief names.

Pull request: https://github.com/bal7hazar/hexx-cairo/pull/46. CI: every job green except **"Take-over of origami_hexmap is a move"** (and the aggregate "All checks passed" that depends on it) — see Escalations. No figure is above its §7 range, so the stop condition did not fire.

Tests (AC-1): the per-tile oracle on every tile of 7 × 7, 15 × 15 and 15 × 16 on 32 seeded pairs (Poseidon noise over the whole felt, bits above `W·H` included) plus the extremes (mask 0, the board, `2^251 − 1`); R-N4-1 to R-N4-3 rewritten; four finder tests (a cave opened on edge tile 7, cut by `hexagon(6) + 2^7`; `distance_to` from the edge tile and from an interior tile, seeds 30 and 31, against a scalar BFS on every walkable tile).

Recomputed regression cases (`grid & mask`):

- **R-N4-1**: 7 × 7, `new_cave(7, 7, 3, 'CUT')` then `open_with_corridor(3, 0)`: `m.grid = 0xc38f0c08` (bit 3 set, the ring holds bit 3 only). `mask = 2^49 − 1` gives `0xc38f0c08`, the identity: the open edge tile stays open (the plan's §6.5 gave `m.grid − 2^3`). `mask = 2^49 − 1 − 2^3` gives `0xc38f0c00` (= `m.grid − 2^3`). `mask = 2^3` gives `2^3`.
- **R-N4-2**: `cut(m, mask)` and `cut(m, mask & (2^(W·H) − 1))` have equal grids, dimensions and seed, on 3 × 3, 7 × 7, 15 × 15, 15 × 16, 16 × 15, 8 noise pairs each.
- **R-N4-3**: 7 × 7, single tile 24, `mask = 2^49` gives 0 (also `2^250` and `2^251 − 2^49`); `2^24` and `2^24 + 2^49` give `2^24`; a stray grid bit 49 is cleared.

Coverage of `local` (AC-2), by the documented Cartesian argument: `local` decides each axis alone, so the columns `(cx, ox, x)` and the rows `(cy, oy, y)` are swept separately: every `cx` in `-1..=16` × every `ox` in `0..15` × every tile of a margin of 2 around the window plus 0 and 255, on a row inside the window (`Some(15·y + dx)`) and on one outside (`None`); the same for every `cy`, `oy`. The four in/out combinations are the two checks of each sweep. Plus the extremes of `i8` (`-128, -127, 126, 127`). The existing `test_assembly_local` keeps the 2D margins.

## Files changed

- `crates/hexx/src/board/cut.cairo` (new): `CutTrait::cut`.
- `crates/hexx/src/board.cairo`: `pub mod cut;`.
- `crates/hexx/src/tests/test_cut.cairo` (new): oracle, R-N4-1..3, finders, benches.
- `crates/hexx/src/tests.cairo`: `pub mod test_cut;`.
- `crates/hexx/src/tests/test_assembly.cairo`: `LocalOracle` and two tests (additions only).
- `crates/consumer/src/lib.cairo`: contract `HexxCut` (one call site of `cut`).
- `gas/hexx.snap`, `gas/bytecode.size`, `docs/GAS.md`, `docs/EXTENSIONS.md`: regenerated. `docs/API_PARITY.md`, `docs/DEVIATIONS.md` unchanged (up to date).

## Commands run

- `scarb fmt --check --workspace`: ok.
- `python3 scripts/bench.py run --package hexx`, then `snapshot --package hexx`; `gas_tables.py`; `api_parity.py` (+ `--extensions`); `bytecode_size.py snapshot`: written.
- `scripts/check.sh`: build and every `snforge test` pass; bench check and `gas_tables --check` pass; **`bytecode_size.py check` failed on `HexxGenerators` sierra felts 27092 → 27101 and 997126 → 997304 CASM bytes** although this task changes nothing reaching `Digger::dig`: the compile drift of D-154 (not a change of mine; `HexxCut`, `HexxAssembly`, `HexxFlood`, `HexxDial`, `HexxSink` matched). The committed `gas/bytecode.size` keeps the `HexxGenerators` line of `main`. CI's "Gas consumer" passed on the same tree. The rest of the gate (unit tests of scripts, parity, extensions, deviations) run by hand: pass. `takeover_check` skipped locally (no `sources/origami`).
- `gh pr checks 46 --watch`: all pass but the take-over job.

## Cost

Measured by the once/twice difference (opaque inputs, 15 × 16), `bench_cut_once` 27,442 and `bench_cut_twice` 37,564: **`cut` ≈ 10,122 l2 gas**, below the plan's §7 range [16,905, 21,132] (the range priced the interior mask too, which §14 drops); no upper bound exceeded. Budgets are `ceil(1.05 × measured)`:

| Test | Measured | Budget |
|---|--:|--:|
| `bench_cut_once` / `bench_cut_twice` | 27,442 / 37,564 | 28,815 / 39,443 |
| `test_cut_oracle_7x7` / `_15x15` / `_15x16` | 35,323,983 / 168,109,581 / 179,453,086 | 37,090,183 / 176,515,061 / 188,425,741 |
| `test_cut_r_n4_1` / `_2` / `_3` | 1,082,946 / 1,221,400 / 80,172 | 1,137,094 / 1,282,470 / 84,181 |
| `test_cut_finders_*` (4) | 26.2M – 38.2M | 27.5M – 40.1M |
| `test_assembly_local_exhaustive` / `_extreme_origins` | 186,380,370 / 2,051,970 | 195,699,389 / 2,154,569 |

`HexxCut`: 843 Sierra felts, 752 CASM felts (1.0 % of the limit).

## Deviations

- The bench is in `test_cut.cairo` (the allowlist has no `bench_cut.cairo`).
- A new contract `HexxCut` in the consumer rather than a method on `HexxAssembly`, following the header of that file (one contract per extension).
- No dimension validation in `cut`: `LayoutTrait::board` computes `W·H` in `u8` and panics on overflow; the domain is valid dimensions (documented on the item).

## Escalations

1. **`scripts/takeover_check.py`**: `OWN_FILES` must list `src/board/cut.cairo` and `src/tests/test_cut.cairo`, otherwise the job "Take-over of origami_hexmap is a move" fails ("a file with no source") and so does "All checks passed". Out of my allowlist; the orchestrator adds them.
2. `HexxGenerators` drift (D-154) in the local gate above: the orchestrator re-runs if the snapshot shows it.

## Open questions

None.
