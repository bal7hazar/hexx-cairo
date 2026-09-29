
## Verdict

**PASS WITH FINDINGS.**

Findings 7 and 8 are closed. The new comparisons are live, compare complete results from the two libraries, and cover the previously missed adjacent-edge behaviour. All 630 test budgets match `ceil(1.05 × measured)` against the committed snapshot.

The remaining finding concerns the completeness and precision of the mutation table. Its omissions are covered by existing tests. I found no remaining blocker for N-3, N-8, or N-7 with the three renames.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 7 — closed | note | `crates/takeover_tests/src/bfs.cairo:201–204`; `crates/hexx/src/finders/bfs.cairo:283` | The adjacent-edge flood blind spot is fixed. **No block for N-3, N-8 or N-7.** | The witness calls `O::reachable(6, 15, 16, 1)`, asserts `lhs == 6`, then asserts `lhs == H::reachable(6, 15, 16, 1)`. Replacing `let near = Bits::or(next, centre.around.into());` with `let near = next;` produces **2 instead of 6**, failing `bfs::test_bfs_reachable_audit_witness`. The new `bfs::test_bfs_floods_edges_15x16`, on `EDGES_15X16` from tile 1, also exposes it. | None. Retain the witness and edge-board families. |
| 8 — closed | note | `crates/takeover_tests/src/fixtures.cairo:219–223`; `crates/takeover_tests/src/rng.cairo:88–90`; `crates/takeover_tests/src/gas.cairo:13–14` | The previously incorrect corpus and gas-work descriptions are corrected. **No block for N-3, N-8 or N-7.** | The fixture comment now includes both exactly-128-tile boards and says “five 15x16”; the RNG comment says “262 states” and “one pool per seed, not every pool with every seed”; the gas comment distinguishes adding **58/89** tiles from resulting populations **59/90**. These agree with the fixtures and loops. | None. |
| 9 | minor | `REPORT.md:597–599`; `crates/hexx/src/finders/bfs.cairo:312–317,345`; `crates/hexx/src/finders/dial.cairo:247–248`; `REPORT.md:698` | The table claims to list “every branch and every expression that treats an edge endpoint”, but omits separate result-changing expressions in range and movement-field handling. D04’s equivalence explanation also gives the wrong rescheduling time. **Documentation finding only; no block for N-3, N-8 or N-7.** | **Range first layer:** change `centre.around + power` to `centre.around` at BFS line 313. `bfs::test_bfs_floods_edges_7x7`, `EDGES_POCKET_7X7`, from 9, radius 1, changes **`0x3020c` → `0x3000c`**. **Range edge mask:** replace `let reach = Bits::and(near, edges.into());` with `let reach = near;` at line 345. `bfs::test_bfs_floods_edges_15x16`, `EDGES_15X16`, from 1, radius 1, changes **6 → `0x18007`**. **Movement-field start exclusion:** replace `grid - from_bit` with `grid` at Dial line 248. `dial::test_dial_field_of_movement_edges_15x16`, `EDGES_POCKET_15X16`, from 2, budget 3, empty cost classes, changes **`0x38002000e` → `0x380020012`**. B26/B32 concern `reachable`; D04 concerns `search`; they do not enumerate these separate sites. For D04, an interior start can be rediscovered after visiting a neighbour: with unit costs that is time **2**, not `cost(start) = 1`. | Add the omitted sites, literal replacements, and concrete witnesses. Correct D04’s timing explanation while retaining its result-equivalence conclusion. |

## Coverage

I compared the revised head, `b77667f`, with the pass-2 head, `a105c02`, and inspected the intervening commits. `b77667f` is an empty rerun commit. The revisions change tests, comments, the takeover snapshot and generated gas documentation; **nothing under `crates/hexx` changed**. The full lot remains within the brief’s allowlist.

I read the pass-2 audit, the complete “Fix loop 2” report, every new or changed test and helper, the relevant BFS/Dial code line by line, the facade’s ring implementation, and `generators/digger.cairo` in full. I checked its RNG and carving dependencies. Unchanged tests outside these paths were not all reread in this pass; their earlier audit stands.

Verification was read-only: source inspection, reconstruction of fixed inputs, and in-memory scalar calculations for mutation witnesses. I did **not** modify or execute a mutated Cairo engine, rebuild the package, or rerun snforge. The implementer’s deleted mutation harness and raw CI logs were unavailable, so the reported exact numbers of failing tests and historical CI measurements remain unverified execution claims.

**New and changed tests.** There are 44 additions: 13 BFS tests, 12 Dial tests, 18 facade tests, and one fixture-provenance test. Existing gas and RNG changes are comments, not weakened assertions.

The new edge corpus has two boards at each of these dimensions:

| Dimensions | Execution path | First board | Second board |
|---|---|---|---|
| 7×7 | Single limb | 10 open edge tiles | Same edges plus 4 interior tiles |
| 16×8 | Single limb, exactly 128 tiles | 10 open edge tiles | Same edges plus 4 interior tiles |
| 8×16 | Single limb, exactly 128 tiles | 10 open edge tiles | Same edges plus 4 interior tiles |
| 15×16 | Two limbs; game window | 10 open edge tiles | Same edges plus 4 interior tiles |
| 17×14 | Two limbs | 10 open edge tiles | Same edges plus 4 interior tiles |
| 19×13 | Two limbs | 10 open edge tiles | Same edges plus 4 interior tiles |

Each first board has five unordered adjacent-edge pairs, including the chain `1–2–3`, and an isolated edge tile. A path may terminate at tile 2 but cannot cross it: from 1, reachable tiles are precisely `{1, 2}`, even on the pocket variant. The pocket joins additional entrances through interior tiles.

`common::open_pairs` enumerates distinct open endpoints. Per dimension, the two boards supply `90 + 182 = 272` ordered pairs, giving **1,632 pairs per path function** across the six dimensions. They include both successful and unreachable paths: 432 successful and 1,200 unreachable ordered pairs. Flood and movement-field helpers visit all 144 open source positions and all nine written radii/budgets, giving **1,296 comparisons per such operation**.

The comparisons call separate origami and hexx implementations with identical arguments and compare entire paths, options, bitmaps, or map state. They do not merely compare lengths or hashes. No new equality loop is empty, no comparison is skipped by an early return, and the corpus does not reduce to uniformly empty results. The provenance test intentionally validates fixture construction rather than library parity.

Inputs are literal boards or derived from written indices and seeds. Positions are open and in bounds, dimensions are valid, and cost inputs contain zero through three classes. Both row parities, both limb paths, exactly 128 tiles, adjacent edges, disconnected targets and interior-connected entrances occur.

**Verification of the report’s branch table.** I checked all 77 rows against the code and the referenced test bodies. Below, `F[k]` denotes `fixtures::boards()[k]`, `E[k]` denotes `ENTRANCE_BOARDS[k]`, and `X[k]` denotes `EDGE_BOARDS[k]`; indices are zero-based. `C(n)` means `common::costs(n, width, height)`. Test names below are within `crates/takeover_tests/src/{bfs,dial,map}.cairo`.

For the result-changing rows, these are concrete live witnesses. The consequences are independently reasoned or calculated, not claims of fresh snforge mutation runs.

| Report rows | Live test and input | Consequence of the indicated wrong form |
|---|---|---|
| B01 | `bfs::test_bfs_identical_endpoints`, `F[0]`, 116→116 | Removing the equality return changes `[]` to a nonempty path. |
| B02 | `bfs::test_bfs_distance_boards`, `F[19]`, 43→43 | `Some(0)` becomes `Some(2)`. |
| B03, B05 | `bfs::test_bfs_audit_scenario`, `E[0]`, 1→43 | Treating the edge as interior reaches an invalid conversion; zeroing its neighbourhood removes the path. |
| B04 | `bfs::test_bfs_distance_entrances_generated`, `E[13]`, 125→237 | Removing the top-row condition changes distance 16 to 14. |
| B06, B07 | `bfs::test_bfs_search_boards_2` / `bfs::test_bfs_distance_boards`, `F[39]`, 21→22 | Removing adjacency handling changes `[22]` to `[22,15]`, and distance 1 to 2. |
| B08, B09 | `bfs::test_bfs_distance_boards` / `bfs::test_bfs_search_boards_0`, `F[10]`, 159→143 | The direct path gains an extra step. |
| B10 | `bfs::test_bfs_search_boards_2`, `F[36]`, 73→84 | `[84]` becomes `[84,73]`. |
| B11 | `bfs::test_bfs_search_entrances_hand`, `E[5]`, 229→85 | Treating the target as interior changes the selected path, including its entry neighbour. Whole-path comparison detects it. |
| B12 | `bfs::test_bfs_search_boards_2`, `F[39]`, 19→21 | `[21,22,16,17,18]` becomes `[21,15,16,17,18]`. |
| B13 | `bfs::test_bfs_search_boards_0`, `F[11]`, 140→2 | Omitting the entry tile drops tile 16 from the returned path. |
| B14, B15 | `bfs::test_bfs_audit_scenario`, `E[0]`, 1→43 | Omitting entry drops tile 36; ignoring the layer selects the wrong neighbour, 42. |
| B18, B24 | `bfs::test_bfs_distance_boards`, `F[10]`, 19→37 | Using the target bit as the goal, or skipping an extra layer, changes distance 3 to 4. |
| B19, B25 | `bfs::test_bfs_audit_scenario`, `E[0]`, 1→43 | The edge-target route is lost or reconstructed incorrectly. |
| B20 | `bfs::test_bfs_distance_boards`, `F[10]`, 53→146 | Forcing the low-limb goal handler changes `Some(8)` to `None`. |
| B22 | `bfs::test_bfs_search_boards_0`, `F[19]`, 65→82 | Omitting the interior start changes `[82]` to `[82,65,48]`. |
| B23 | `bfs::test_bfs_search_fixtures`, `F[7]`, 38→37 | `[37]` becomes `[37,36,37]`. |
| B26 | `map::test_map_keep_component_3x3`, generated input 1, grid 16, from 4 | Omitting the centre changes its component from 16 to 0. |
| B27, B31, B32 | `bfs::test_bfs_reachable_audit_witness`, `(6,15,16,1)` | Respectively, 6 becomes 4, 2, or `0x18007`. |
| B29 | `bfs::test_bfs_reachable_boards`, `F[36]`, from 84 | Omitting dilation loses edge tile 109. |
| B30 | `bfs::test_bfs_reachable_boards`, `F[11]`, from 112 | Omitting dilation loses edge tile 2. |
| B33 | `bfs::test_bfs_floods_entrances_hand`, `E[0]`, from 1, radius 0 | Removing the zero-radius return reaches `range - 1` underflow. |
| B34 | Same test, `E[0]`, from 1, radius 1 | Omitting the edge centre changes `0x102` to `0x100`. |
| B37 | `bfs::test_bfs_floods_edges_7x7`, `X[0]`, from 1, radius 2 | Removing the centre’s neighbours changes 6 to 2. |
| B38 | `bfs::test_bfs_floods_edges_15x16`, `X[6]`, from 1, radius 2 | The same omission on the two-limb path changes 6 to 2. |
| B39 | `bfs::test_bfs_tiles_within_range_boards_1`, `F[36]`, from 84, radius 3 | Dilating the outer rather than inner ball includes edge tile 109 too early. |
| B40 | `bfs::test_bfs_tiles_within_range_boards_0`, `F[11]`, from 46, radius 2 | The corresponding wide mutation includes edge tile 2 too early. |
| R01, R03 | `map::test_map_floods_entrances_generated_0`, `E[9]`, from 77, radii 0 and 1 | Removing the respective returns reaches unsigned subtraction underflow. |
| R02 | `map::test_map_floods_entrances_hand_0`, `E[0]`, from 1, radius 2 | Forcing the interior-centre route fails instead of returning the ring. |
| R04 | Same test, `E[0]`, from 40, radius 2 | Omitting the centre from the initial ball incorrectly includes it in the ring. |
| R05 | `map::test_map_floods_entrances_hand_1`, `E[3]`, from 30, radius 2 | Wrong radius-two inner handling adds edge tiles 14 and 31. |
| R06 | `map::test_map_floods_entrances_generated_0`, `E[10]`, from 21, radius 2 | The wide counterpart wrongly adds edge tile 7. |
| R09, R11 | Same generated test, `E[11]`, from 72, radii 6 and 4 respectively | Failing to subtract inner edge tiles, or omitting outer edge tiles, changes the complete ring bitmap. |
| R10, R12 | Same generated test, `E[9]`, from 77, radii 6 and 4 respectively | The corresponding two-limb expressions also change the ring bitmap. |
| D01 | `dial::test_dial_identical_endpoints`, `E[0]`, 1→1, `C(400056)` | Removing the equality return changes `[]` to `[1,8]`. |
| D02, D10 | `dial::test_dial_search_boards_0`, `F[11]`, 2→140, `C(11012)` | Seeding an edge as an interior tile changes the 34-tile result to an incorrect short path. |
| D03, D05 | Same test, `F[11]`, 140→2, `C(11013)` | Excluding the edge target removes an existing path. |
| D06 | `dial::test_dial_search_boards_2`, `F[39]`, 21→22, `C(39012)` | Removing the direct-adjacency return changes `[22]` to `[]`. |
| D08 | `dial::test_dial_field_of_movement_boards_0`, `F[11]`, from 2, budget 2, `C(11556)` | Unrestricted edge seeds change `0x80010004` to `0x80088014`. |
| D09 | Same test, `F[11]`, from 2, budget 1, `C(11555)` | Zeroing the edge neighbourhood changes `0x10004` to 4. |
| D11, D12 | `dial::test_dial_fixture_endpoints`, empty 17×14 fixture, 129→77, `C(100001)` / `C(100000)` | Removing the weighted/unit arrival target test loses the successful result or fails during reconstruction. |
| D13 | `dial::test_dial_search_boards_2`, `F[39]`, 15→21, `C(39007)` | Removing the time-zero backtracking return fails while reconstructing `[21]`. |
| D14–D16 | `dial::test_dial_search_boards_0`, `F[11]`, 140→2, `C(11013)` | Treating the edge as interior fails conversion; omitting entry drops tile 16; ignoring the predecessor layer selects an invalid neighbour. |
| D17 | `dial::test_dial_field_of_movement_boards_0`, `F[10]`, from 140, budget 0, `C(10500)` | Removing the zero-budget return includes tiles beyond the start. |
| D18, D19 | Same test, `F[11]`, from 112, budget 40, `C(11508)` | Excluding open edge tiles loses tile 2. |
| D21 | Same test, `F[11]`, from 2, budget 2, `C(11556)` | Interior-style dilation of the edge start adds spurious tiles. |
| D22 | Same test, `F[11]`, from 46, budget 6, `C(11550)` | Expanding settled edges in weighted search adds spurious tiles. |
| D23 | Same test, `F[11]`, from 46, budget 14, `C(11552)` | The unit-cost counterpart also changes the field. |

The remaining rows require a different conclusion: reaching a branch does not mean removing it changes the result.

| Report rows | Independent assessment |
|---|---|
| B16, B17 | Removing the empty-goal early return is result-equivalent: no frontier can intersect an empty goal, and exhaustion still returns false. The new disconnected edge pairs reach this case on both limb paths. |
| B21 | Adding the edge start to the first layer is neutral because intersection with the interior-only `free` mask removes it. |
| B28, B35, R07, R08 | With no open edges, the masked edge contributions are zero. Removing these early returns preserves the result. The reported gas-only failures for B35/R08 were not independently rerun. |
| B36 | At radius 1, the inner ball is zero; its dilation OR the centre’s neighbourhood equals the shortcut result. |
| B41, B42 | On exhaustion, `inner == ball`; changing the returned second component therefore preserves the result. |
| D04 | Retaining an interior start as unvisited does not improve the already seeded neighbours or change the reconstructed path. The report’s rescheduling-time explanation needs the correction in finding 9. |
| D07 | Without the adjacency shortcut, the target remains among the seeds; the time-zero reconstruction still returns `[to]`. |
| D20 | **Unreachable on valid inputs.** A walkable edge start implies `open != inside`, hence `edges == true`. Execution cannot reach `else if from_edge`. No test can provide a valid witness for this branch. |

Thus the table’s substantive result-equivalence classifications hold, subject to its documentary omissions. I found no additional escaping result-changing mutation among these forms and the three omitted forms examined in finding 9. This is bounded mutation evidence, not exhaustive proof over all possible edits.

**Budgets.** I matched all **630** declared tests to all **630** committed snapshot rows and checked the ceiling using integer arithmetic, `(105 × measured + 99) // 100`. There are no missing attributes, missing rows, extra rows, or mismatched budgets. For example, the witness’s measured **232,336** gives exactly **243,953**, matching `crates/takeover_tests/src/bfs.cairo:200`. The snapshot adds the 44 new tests without changing existing measurements. The generated gas-document check and `git diff --check` passed.

**Digger gas observation — information only.** I found nothing in this code path that can make the same call consume different Sierra gas between executions with identical compiled artifacts and accounting. `crates/hexx/src/generators/digger.cairo:99` constructs `RngTrait::new(seed)` locally. Inward selection, carving, recursive traversal and stopping conditions depend on explicit arguments and that deterministic RNG state. RNG refill uses a fixed-input Poseidon permutation; it does not consult block data, time, external state or nondeterministic randomness.

Consequently, the reported 0.5–1.3% variation is not explained by the algorithm’s seeded choices. Identical source trees alone do not establish identical compiled artifacts or measurement conditions. Artifact hashes, compiler configuration and runner gas accounting would be the next evidence to compare; the cause cannot be established from the committed report. This is **not a finding of this lot**.
[exited with code 0]
