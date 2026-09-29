# [GPT-6-Astra] Audit — M1-T1b — take-over, the proof of equality (pass 2)

## Verdict

**FAIL**

The six pass-1 findings are addressed. One additional result-changing BFS mutation still escapes the equality comparisons; finding 7 blocks relying on this package for N-8’s changes to BFS. It does not directly block N-3 or N-7 and the three renames.

All 586 committed test budgets satisfy the required formula against the committed snapshot. No engine file changed.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | note | `crates/takeover_tests/src/common.cairo:284`, `crates/takeover_tests/src/bfs.cairo:209`, `crates/takeover_tests/src/dial.cairo:166`, `crates/takeover_tests/src/map.cairo:323` | **Pass-1 finding 1 closed.** Distinct entrances now receive live, whole-result comparisons through both libraries. No remaining block from the original finding. | `common.cairo:289` selects `if from != to`. BFS calls `O::search` and `H::search` on identical arguments, then executes `assert(lhs == rhs, 'search');` at `bfs.cairo:221`. Dial does the same at `dial.cairo:183`; facade comparisons cover complete unweighted and weighted paths and distances. Independent decoding gives **178 ordered distinct pairs: 142 joined, 36 disconnected**. The original early-return mutation now fails `test_bfs_audit_scenario`: grid `0x9f3e7cf9f02`, dimensions `7×7`, `1 → 43`, expected `[43,36,29,22,15,8]`, mutant `[]`. The equality assertion is at `bfs.cairo:283`; the exact path assertion follows at line 284. `test_map_audit_scenario` also detects it. | Retain these regressions. Add the separate flood case in finding 7. |
| 2 | note | `crates/takeover_tests/src/map.cairo:2184`, `crates/takeover_tests/src/map.cairo:2202` | **Pass-1 finding 2 closed.** Both overflow panic pairs are present. No downstream block. | Radius 127 is tested separately through `O::new_hexagon` and `H::new_hexagon`, both with `#[should_panic(expected: 'u8_add Overflow')]`; radius 128 similarly expects `'u8_mul Overflow'`. This matches `crates/hexx/src/board/map.cairo:170`: `let width = 2 * radius + 3;`. At 127 multiplication succeeds and addition overflows; at 128 multiplication overflows. The short-string expectations are exact: changing one character changes the expected felt and fails the test. | None. |
| 3 | note | `crates/takeover_tests/src/rng.cairo:36`, `crates/takeover_tests/src/rng.cairo:61`, `crates/takeover_tests/src/rng.cairo:94` | **Pass-1 finding 3 closed.** Constructor and mixing inputs now include the prescribed seeded values and felt boundaries. New pool tests compare returned values and complete state. No downstream block. | `test_rng_new` executes `assert_rngs(@O::new(seed), @H::new(seed));` at line 63 over **262 inputs**. `test_rng_mix` compares **256 seeded pairs plus 36 boundary pairs**. The literals represent `0`, `1`, `2^128−1`, `2^128`, `2^250`, and `−1`. Pool tests use valid `u128` boundaries, nonzero draw bounds, and compare both `seed` and `pool` after each operation. Their actual pool assignment is `let pool = *pools.span().at(index % 5);` at line 100; see finding 8 concerning the report. | None for the original coverage requirement; correct the report’s count description. |
| 4 | note | `crates/takeover_tests/src/spreader.cairo:163`, `crates/takeover_tests/src/map.cairo:1302`, `crates/takeover_tests/src/spreader.cairo:266` | **Pass-1 finding 4 closed.** Exactly-128-tile boards and invalid high limbs are covered directly and through the facade. No downstream block. | Both orientations, `16×8` and `8×16`, receive **220 whole-result comparisons per test**: 11 masks × 10 counts × 2 orientations. Masks include zero, all 128 bits, the interior, and eight caves. `spreader.cairo:185` executes `assert(lhs == rhs, 'generate');`. Removing `size == 128` from the guard at `crates/hexx/src/generators/spreader.cairo:439` now causes an out-of-bounds `POW128[128]` access on these tests. Four additional panic pairs cover bit 128 on `7×7` and `16×8`, directly and through `compute_distribution`, expecting exactly `'Spreader: invalid grid'`. | None. |
| 5 | note | `REPORT.md:399`, `REPORT.md:420`, `REPORT.md:425`, `gas/takeover_tests.snap:65` | **Pass-1 finding 5 closed.** The fixed “about 900 gas” explanation is withdrawn; the budget rule is correctly applied to attributed tests. No downstream block. | The correction says “That is **not** a fixed surcharge” at `REPORT.md:421`, and specifies measurement “attribute included” at line 426. This is consistent with the inspected snforge 0.61.0 macro, which introduces configuration control flow; it does not establish a universal 900-gas tariff. The snapshot retains `test_bits_constants: 14220 14931`, and `ceil(14220 × 1.05) = 14931`. All 586 source budgets match their snapshot budgets and the exact integer ceiling. The reported with/without-attribute experiment was not independently rerun. | Keep measuring the final attributed tests; do not infer a surcharge. |
| 6 | note | `crates/takeover_tests/src/gas.cairo:6`, `crates/takeover_tests/src/gas.cairo:629`, `crates/takeover_tests/src/gas.cairo:983` | **Pass-1 finding 6 closed.** The vacuous path and boolean checks have been replaced by exact expectations. The gas claim is now appropriately limited to measured call sites. No downstream block. | Search checks now compare the complete span with `EXPECTED_SEARCH_PATH.span()`; walkability checks use `assert(result == EXPECTED_IS_WALKABLE, 'result');`. All 88 gas tests check an exact expected value; constructor/mutator checks observe the grid, while the equality tests separately compare complete maps. All 44 cross-library once/twice bodies match after normalizing library names. Snapshot subtraction confirms **zero library difference at all 22 call sites**, including long corridor and maze measurements of **1,996,274** and **3,242,771** gas. These differences include repeated argument helpers and result checks, as the module now states. | None for the original finding. Correct the long-dig tile counts in finding 8. |
| 7 | major | `crates/hexx/src/finders/bfs.cairo:283`; finder inputs in `crates/takeover_tests/src/fixtures.cairo` | **A surviving flood mutation remains.** The corpus does not distinguish direct reachability between adjacent edge tiles from reachability supplied by the interior component. **Blocks N-8’s reliance on this package when changing BFS; no direct block on N-3 or N-7/the renames.** | Replace the single line `let near = Bits::or(next, centre.around.into());` with `let near = next;`. On the valid input **`Bfs::reachable(6, 15, 16, 1)`**, only edge tiles 1 and 2 are open. The interior flood and `next` are zero; `whole` is bit 1, value `2`. Origami adds adjacent tile 2 through `centre.around`, returning **`6`**. The mutant returns **`2`**. The same witness works on `7×7` and `16×8`. My independent scalar reconstruction found **no difference for any of the 4,536 walkable source positions across all 57 finder boards**, a superset of their tested sources. Other facade component inputs have closed edges; the gas fixture does too. Thus no current equality assertion detects this mutation. | Add paired whole-result tests for adjacent edge tiles with no interior connection, on both limb paths and `15×16`, directly through `Bfs::reachable` and through facade `reachable`/`keep_component`. Include range and weighted-field variants to protect the corresponding boundary behavior. |
| 8 | minor | `REPORT.md:329`, `REPORT.md:379`, `REPORT.md:439`, `crates/takeover_tests/src/fixtures.cairo:217` | **Several revised coverage claims remain inaccurate.** Documentation only; blocks none of N-3, N-8, or N-7/the renames. | The report lists `8×16` under “Two limbs”, although `8×16 = 128` and BFS dispatches on `width * height <= SMALL_SIZE` with `SMALL_SIZE = 128`. “It crosses those pools with the 262 seeds” overstates the RNG test: line 100 selects one pool per seed, giving **262 states**, not 1,310. The long-dig constants contain **59 and 90 set bits**, retaining the original single tile 202: they add **58 and 89 tiles**, rather than the reported 57 and 88. The fixture comment also says three `15×16` boards; there are five. | Correct these descriptions and counts. No enlargement of the RNG test is required merely to match the erroneous Cartesian-product claim. |

## Coverage

Reviewed commits `06c99fa` and `a105c02` against pass-1 head `f933d34`, the full fix-loop diff, the previous audit, and the complete “Fix loop 1” report. Rechecked the brief and relevant plan provisions, including §14’s precedence.

**Every new or changed test was read in full**, together with its input and comparison helpers: 54 added tests and 100 existing tests with changed bodies or attributes. This includes the complete revised gas module, new provenance tests, entrance comparisons, overflow/high-limb panic pairs, RNG additions, and 128-tile distribution tests. The walker change only corrects its comment.

The independent entrance decoding below uses indices in `ENTRANCE_BOARDS` at `crates/takeover_tests/src/fixtures.cairo:298`. Within each braced group, every distinct pair is joined; pairs across groups are disconnected. Counts include both directions. Adjacent pairs are listed once.

| Board | Dimensions / limb path | Entrances grouped by connectivity | Joined / disconnected ordered pairs | Adjacent pairs |
|---|---|---|---:|---|
| 0, audit | 7×7 / single | `{1,43}` | 2 / 0 | — |
| 1, adjacent | 7×7 / single | `{1,2,7,14}` | 12 / 0 | 1–2, 1–7, 7–14 |
| 2, split | 7×7 / single | `{1,43}`; `{5,47}` | 4 / 8 | — |
| 3 | 16×8 / single | `{1,14,31,113,126}` | 20 / 0 | — |
| 4, split | 8×16 / single | `{2,3,32}`; `{103,122}` | 8 / 12 | 2–3 |
| 5 | 17×14 / two | `{1,2,85,101,229}` | 20 / 0 | 1–2 |
| 6 | 15×16 / two | `{1,2,13,105,119,232}` | 30 / 0 | 1–2 |
| 7, split | 15×16 / two | `{3,228}`; `{11,236}` | 4 / 8 | — |
| 8 | 19×13 / two | `{5,114,237}` | 6 / 0 | — |
| 9, generated cave | 15×16 / two | `{7,120,232}` | 6 / 0 | — |
| 10, generated maze | 15×16 / two | `{7,134,232}` | 6 / 0 | — |
| 11, generated cave | 11×11 / single | `{5,55,65,115}` | 12 / 0 | — |
| 12, generated sparse maze | 17×14 / two | `{8,229}` | 2 / 0 | — |
| 13, generated walk | 25×10 / two | `{12,125,237}` | 6 / 0 | — |
| 14, generated raw cave | 15×16 / two | `{7,134}`; `{120,232}` | 4 / 8 | — |

The new entrance families execute **472 endpoint comparisons per search/distance function** and use **147 flood sources**, each with nine radii/budgets where applicable. Separate identical-endpoint tests execute 127 cases across all 57 boards. Those early-return cases are intentional and no longer substitute for distinct-entrance coverage.

The reviewed equality tests call different libraries on identical inputs and compare complete results. No new equality test compares a library with itself, substitutes a length/hash for the available result, or passes through an empty input loop. Length checks in the entrance helpers count joined pairs **after** whole-path equality. Provenance tests intentionally validate stored inputs against origami; gas tests intentionally validate each library against constants. All new inputs are literal or derived from written tags and bounded indices; valid calls stay within their domains.

Both finder implementations were reread through their production code, including edge handling, limb dispatch, BFS layering/backtracking, and Dial classes, buckets and backtracking. Finding 7 is the established surviving mutation; no separate Dial escape was established. Mutations were reasoned about and modeled in memory, never applied to the engine.

The prior full reading of all 18 test files and public-surface inventory remains applicable to unchanged tests. Unchanged test bodies and unrelated engine modules were not all reread in full in this pass; relevant call sites were sampled and traced. No public-function equality test was removed.

Static verification established:

- **586 tests:** 291 equality, 204 panic, 88 gas, three provenance; no ignored/fuzzer tests.
- All **102 panic pairs** have identical expected messages and matching inputs after library-name normalization.
- All 586 budgets equal `(105 × measured + 99) // 100`, with no missing or extra snapshot rows. Total measured gas is **49,503,989,794**.
- `python3 -B scripts/gas_tables.py --check` and `git diff --check origin/main...HEAD` pass.
- Registry resolution remains origami_hexmap 1.8.0; hexx remains a path dependency.
- The complete lot stays within the allowlist; `crates/hexx` is unchanged and the worktree remains clean.

No Cairo build, snforge run, or full gate was executed during this read-only pass because those commands create artifacts. Consequently, the implementer’s fresh-run results, attribute experiment and CI timings remain reported evidence rather than independently reproduced results.