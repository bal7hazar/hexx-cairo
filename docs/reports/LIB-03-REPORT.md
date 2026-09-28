# [Fable 5.1] LIB-03 — Porting plan of `hexx` to Cairo

Model read from the session: Fable 5.1, the one the brief names. Profile `research`: nothing
committed, no pull request; the orchestrator commits `docs/research/LIB-03-porting-plan.md`.

## Summary

What exists now: `docs/research/LIB-03-porting-plan.md` (1,122 lines), the plan the owner
accepts or amends at gate L-G2, with the twelve parts the brief lists plus a table of where
each decision of L-G1 and each answer of the project manager is honoured (§13), and a
destination for every public function of `origami_hexmap` 1.8.0 (§5.1).

Recommendation for L-G2, in five lines:

1. Publish a Cairo package named `hexx` (free on scarbs.xyz on 2026-09-28) from this
   repository, whose mirror follows `hexx` 0.25.0 name for name on `Hex { x: i32, y: i32 }`,
   with three kinds of departure only, all in a generated table: floating-point, host and
   allocator items absent; iterators as spans and callbacks as bitmaps; `line_to` with the
   game's tie rule, the differing pairs listed by an off-chain comparison.
2. Take over the engine of `origami_hexmap` 1.8.0 under `board`, `finders`, `generators`,
   every result and budget unchanged, proved by a test package that compares it with the
   registry package; add the ten functions of L-M1 on `u8` indices and `felt252` bitmaps,
   each with a scalar oracle, a worst case and a gas target (measured or estimate).
3. L-M1 (0.1.0, after `0.1.0-rc.N` for SPK-7) is the game's needs plus the mirror
   foundation N-5 and N-7 are specified against; L-M2 completes the mirror; L-M3 closes the
   algorithms and the table; 1.0.0 decommissions `origami_hexmap` in four conditioned steps.
4. L-M1 needs no `u252` crate: bitmaps stay `felt252` as in 1.8.0, so a late crate delays
   nothing; the board keeps its `Direction` enum next to the mirror's `EdgeDirection`, same
   indices, free conversions.
5. Eighteen decisions the owner may reverse are listed in §12 with their alternatives; the
   one open point that changes the library is the game's "sight beyond the window", and the
   plan covers both outcomes.

Corrections and refinements of LIB-02 recorded in the plan: the N-8 tick estimate is raised
to 450–650k (LIB-02: 300–450k) because the per-walker layer scans were not counted; the cost
models of `hexx::algorithms::field_of_movement` and `origami_hexmap`'s `field_of_movement` are
the same within the board's limits (LIB-02 called them "close"); the tie rule at column 0 can
prefer an off-board tile in the index frame, which the board form must clip.

## Files changed

- `docs/research/LIB-03-porting-plan.md` — new, untracked: the plan.
- `REPORT.md` — this file, ignored by git.

## Commands run

```
$ git status --short
?? docs/research/LIB-03-porting-plan.md
```

```
$ ls -1 docs/briefs/LIB-03-porting-plan.md docs/briefs/COMMON.md PLAN.md docs/decisions/L-G1-hexx-port.md docs/research/LIB-02-hexx-analysis.md
PLAN.md
docs/briefs/COMMON.md
docs/briefs/LIB-03-porting-plan.md
docs/decisions/L-G1-hexx-port.md
docs/research/LIB-02-hexx-analysis.md
```
(the five relative links of the plan; it contains no fragment link and no Markdown link into
`sources/`, which are written as code)

```
$ which lychee
lychee not installed
```
(the CI link check could not be replayed locally; the targets were checked by hand above)

```
$ wc -l docs/research/LIB-03-porting-plan.md
1122 docs/research/LIB-03-porting-plan.md
```

Read-only fetches of two registry pages (to state the package name and the publication of
1.8.0): `https://scarbs.xyz/packages/hexx` returned 404; `https://scarbs.xyz/packages/origami_hexmap`
lists one version, 1.8.0.

Greps and reads over `sources/` (every `pub` item of `hexx` with its line, the headings and
the measured tables of `GAS.md`, the module headers of `origami_hexmap`): read-only, not
reproduced here.

## Cost

—

## Deviations

- **Two registry pages were fetched** (read-only) to verify that `hexx` is free on scarbs.xyz
  and that `origami_hexmap` 1.8.0 is published there. The brief's *Out* names "anything
  outside this repository" as out of scope for writing; nothing outside was written. If the
  orchestrator considers the fetches out of bounds, the two sentences that rely on them (§0,
  §2.1, risk R-4) are marked as "checked on 2026-09-28" and can be cut without changing the
  plan.
- **The inventory groups the compass alias constants** of `EdgeDirection` (30) and
  `VertexDirection` (36) into one row each, all names listed, because their status is
  identical; every other item has its own row. Modules excluded as a whole (`layout`,
  `storage`, `mesh`) have a module-level row with their item lists, as AC-2 allows for
  modules that are not kept.
- **The LOS derivation of §6.6 is reasoned, not run** (no code, no measurement, per the
  brief): the off-board tie at column 0 is marked *(inferred)* and handed to LIB-05 as risk R-7.

## Escalations

None on the content. Two shell commands that used a loop variable were refused by the
sandbox ("Contains simple_expansion"); the same checks were run as plain listings, shown
above. No file outside the allowlist was written.

## Open questions

For the owner:

1. **Sight beyond the window** (L-G1 point 4, game's `docs/decisions/PENDING-L-G1.md` §3): the
   plan covers both outcomes (risk R-1); with the hysteresis kept, the game would test lines
   that leave the window tile by tile through `Hex::line_to`, at ~4.9k per tile, and a
   cross-window extension would be one task of L-M3 if asked.
2. The eighteen reversible decisions of §12, in particular D-3 (two direction types), D-4
   (`felt252` bitmaps, no `u252` in L-M1), D-5 (mirror foundation inside L-M1), D-6
   (`line_to` carries the game's tie rule as a deviation).
3. Whether LIB-04 may publish an empty `0.0.1` to reserve the name `hexx` (risk R-4).
4. Which toolchain LIB-04 pins: `origami_hexmap`'s (scarb 2.19.4, snforge 0.61.0, the basis
   of every measured figure) or the game's SPK-5 pin (Q-3).

For the game:

5. Is `hexagon(8)` (earshot) needed on the window, whose centre is 7 tiles from the ring, or
   is earshot a distance test on global coordinates (Q-1)?
6. Are goblins standing on the window's ring (wall tiles, 7 tiles out) valid endpoints of
   `line_of_sight`? The plan says yes, endpoints are not tested (Q-2).
7. Should SPK-7 switch to `0.1.0-rc.1` (the take-over alone, identical results) or stay on
   1.8.0 until 0.1.0 (Q-4)?

For LIB-04:

8. Whether scarbs.xyz accepts pre-release identifiers (`0.1.0-rc.N`); fallback `0.0.N` (R-3).

## Follow-up 1 (D-120)

The owner decided the open point "sight beyond the window" (D-120, 2026-09-28): the window
follows the adventurer, is 15 columns × 16 rows (240 tiles), is recomputed at each tick and
is not stored; chunks stay 15 × 15. Read, in this order: `grimworld:docs/needs/hexmap.md`
§ "N-3 in detail", `grimworld:docs/architecture/ADR-0006-chunked-maps.md` §4,
`sources/hexx-cairo-main/window-parity-check.md`, `sources/hexx-cairo-main/PLAN.md` § L-M1
(byte-identical to the worktree's `PLAN.md`), and the refreshed `sources/VERSIONS.md`
(grimworld at `0a3d85e`, hexx-cairo `main` at `2af2b88`). The game's decisions directory in
the refreshed sources is empty, so D-120 is cited through the needs file and the ADR.

What changed in `docs/research/LIB-03-porting-plan.md` (1,122 → 1,177 lines), and nothing else:

1. **§6.4, N-3 rewritten**: the assembly of a 15 × 16 board from 2 or 4 chunks of 15 × 15,
   called at each tick, without a loop over rows. Signatures: `origin(x, y)` on `i16` global
   coordinates (never produces an odd origin: row `y − 7` when `y` is odd, `y − 8` when even),
   `local`, `assemble(chunks, ox, oy, odd_chunk_row)`, `window(terrain, occupied, origin, seed)`.
   The rectangle mask of each chunk is the product of two 15-entry band tables; one exact shift
   per chunk (the four shift formulas given); pieces added; ring imposed. **An odd origin is
   refused by a panic** `'Assembly: odd origin'`, not an `Option`: it is a caller's programming
   error, the library's convention for invalid inputs is a named panic, and an `Option` would
   put a branch in every tick and invite a silent wrong grid. Worst case: 4 chunks, two layers,
   at each tick. Gas estimate ~8k per chunk and layer, ~70k per tick, above the ADR's "about
   40k" (SPK-7 measures, with and without a stored window).
2. **§6.4b added**: the fallback (sight 5 on 13 × 14) noted as a later option, not designed,
   with the reason (its width differs from the chunk's, so the shift is no longer
   one-dimensional).
3. **§6.6 and §6.7**: N-5 and N-6 take the local position as input; the adventurer is on
   `(7, 7)` or `(7, 8)`; the canonical centres of the tables are those two tiles of the 15 × 16
   board; the board mask is `2^240 − 1`; oracles and worst cases on 15 × 16.
4. **Figures recomputed for 15 × 16**: the exhaustive line comparison is 57,360 ordered pairs
   (§4.3, §6.6); the loop fallback of the line is distance 14; the flood worst case is 15 layers
   (~345k), the tick 470–670k before assembly and ~740k with it (§6.9, §7); the per-position
   variant table is 240 felts per radius; the band tables of the assembly (60 felts) are added
   to the class-size table (§7).
5. **The parity flag** is stated to serve generation and seams only (§3.3, §5.3, §6.2, §6.3,
   D-18): the finders are taken over unchanged because 15 × 16 is a board the library already
   accepts.
6. **The other outcome removed**: the contingency sentences of §1.3 and §8 (why the mirror
   foundation is in L-M1), the former risk R-1 (both outcomes) replaced by the per-tick
   assembly cost risk, R-5 and R-6 updated, the former Q-2 (goblins on the ring as targets)
   closed by D-120, a new R-14 (origin before the location's first tile: `i16` coordinates,
   absent chunks as 0).
7. **§0, §11, §12, §13**: the sources table carries the refreshed commits and the
   `hexx-cairo` `main` row; §0 states the decision and that the point is no longer open; §12
   names the window in the acceptance summary and adds the reversible decisions D-19 (panic,
   not `Option`), D-20 (offsets and parity as inputs, `origin` helper on `i16`), D-21 (band
   tables); §13 maps point 4 / D-120 to the sections that honour it.

Verification after the follow-up: `git status --short` shows only the plan, untracked; the
five relative links are unchanged and resolve; no Markdown link into `sources/`. Not
committed, per the profile.

## Follow-up 2 (uint252)

The `u252` type was published on scarbs.xyz on 2026-09-28 as the package `uint252`,
version 0.1.0 (repository `bal7hazar/types-cairo`, `crates/u252`, commit `35f74d5`; the type
keeps the name `u252`; its only dependency is `snforge_std` for tests). Stated by the
orchestrator; not fetched.

What changed in `docs/research/LIB-03-porting-plan.md` (1,177 → 1,179 lines), and nothing else:

1. **The package is named `uint252`** wherever the plan said "the crate `u252`": §2.4 (the
   root re-export note), §3.3, §3.4 (retitled "`u252`, the package `uint252`", which now states
   the publication, the repository, the commit, the type's name and the single test
   dependency), §5.1 (the `u252` row of the take-over table), §8 L-M3, §9.3 (retitled "The
   dependency on `uint252`"), §10 (step 2 and the note to existing users), §13.
2. **Dependency lines** now read `uint252 = "0.1.0"` (§3.4, §9.3, §10 step 2); the game's
   import becomes `uint252::{U252Trait, u252}`.
3. **Stale wording removed**: "wait for a crate that is not published" (§3.3), "if the crate
   is late" (§9.3), "when it needs the type" replaced by "published; needed for the type"
   (§10), "waiting for the crate" in the alternative of D-4 (§12).
4. **Risk R-2 marked closed** in §11, with the publication as the reason and the note that
   L-M1 does not depend on the package anyway.
5. **Decision D-4 kept as it is**: bitmaps stay `felt252` in the board API and L-M1 carries no
   `uint252` dependency; its alternative (`u252`-typed bitmaps from 0.1.0, changing every
   signature) stays for the owner to confirm at L-G2.

Verification after the follow-up: `git status --short` shows only the plan, untracked; a
search for the stale wording finds none; the five relative links are unchanged and resolve.
Not committed, per the profile.

## Fix loop 1

Answers the audit `sources/audits/LIB-03-audit-gpt-6-astra-pass-1.md` (`[GPT-6-Astra]`,
verdict FAIL, 20 findings). Every finding was verified in the sources before the fix; **none
is disputed**. What was checked, per finding: 1 (`caver.cairo:180`, `west = felt * INV_2`, and
the domain of the up-shifts), 2 (`caver.cairo:155, 174-184`: complementing the parity split
alone gives the right planes; swapping the factors as well does not), 3 (the free ring is
random, so `fixed = 0` cannot reproduce `generate`), 4 (the row and column masks left bit 0 or
bit `W−1` before a division, and the contact sets overlap), 5 (450 tiles exceed 251 and `u8`),
6 (a product that overflows `2^251` reduces modulo the field; a radius-8 hexagon spans 17
columns), 7 (index translation is width-specific; the clipped tie), 8 (distances 22 and 19
computed by hand from the axial formula; `src/hex/mod.rs:906` converts the endpoints to `f32`),
9 (layers are disjoint non-empty subsets of the walkable interior: bound 182 on 15 × 16),
10 (382 exceeds `u8`; `src/direction/edge_direction.rs:314` reduces the offset first), 11
(`src/algorithms/fov.rs:64, 67`), 12 (`src/direction/mod.rs:11`, `src/hex/mod.rs:23`,
`src/shapes.rs:158-162` and the other public fields), 13 (the rules of §4.2 against the
counterpart rows), 14 (the sums recomputed: 9,401 per piece, 11,349 for the old line, 775k for
the old tick), 15 (the functions named have no row), 16 (`bits.cairo:791` is `[u128; 128]`,
`rng.cairo:199` is `[u32; 720]`, 300 + 40 + 70 = 410), 17 (`bench_u252.cairo:16-17`), 18
(L-G1 `:29`; `DoubledHexMode` was L-M1 while its conversions were L-M2), 19 (`hex.cairo` shared
by three L-M2 tasks; the facade in two allowlists; `as_ivec2` at L-M3 against the L-M2 exit),
20 (the four behaviours had no decision row).

| Finding | What changed | Section |
|---|---|---|
| 1 | Every field product of N-1 has its exactness condition: a domain `W·(H + 1) + 1 ≤ 251` for the up-shifts (17 × 14 refused, 15 × 15 accepted, panic `'Caver: dimensions too large'`), and a single mask `G_low = G & ~(ROW_0 \| 2^W)` for the three downward planes, `/2` included, with the proof that the cleared bits reach no interior tile | §6.2 (Domain, Exactness), D-30 |
| 2 | The six planes derived explicitly from the neighbour table for both global parities; the odd-origin rule is "complement the parity split, keep the factors"; the wrong "swap the constants" sentence removed; a parity oracle on impulses added; `new_odd` defined as the complemented `even` field only | §6.2 (The six planes, Oracle (4)), §7 |
| 3 | The equality oracle now fixes the whole ring to wall (`fixed = ring, values = 0`) and is bit-exact; `smooth` takes `held` (any tiles), restores `G & (ring \| held)` each generation, has its own oracle, worst case and target | §6.2, §7, D-28 |
| 4 | Four seam formulas, one per side and parity, each division preceded by the mask that makes it exact (`C & ~1`, `C & ~2^(W−1)`, `R & ~1`), contact sets combined with OR; the contact counts corrected (three on a vertical seam, two on a horizontal one); the worst case is an East seam with `odd = false` | §6.3 |
| 5 | The seam oracle is a scalar oracle on signed global coordinates with explicit parity; no `2W × H` board | §6.3 (Oracle), §11 R-6 |
| 6 | The hexagon tables are clipped **before** the shift with the band tables; the table path is restricted to `width == 15` and `radius ≤ 7`; the row loop is defined for every other case and benchmarked (radius 8, 16 rows); the cases of the finding are oracle cases; the tables shrink to 14 + 14 | §6.7, §7, D-8 |
| 7 | The line table is restricted to `width == 15`; `line` returns `Option<felt252>` and `None` when a tile leaves the board, decided by an extent test before the shift (a second table `LINE_SPANS`), with no clipping; `line_of_sight` treats `None` as blocked; `approach` returns `Option<Direction>` and `None` for `from == to`; the finding's two cases are oracle cases | §6.6, §7, D-27, R-7 |
| 8 | The bounds corrected: 22 on the board (`(0, 0) → (14, 15)`), 19 in the interior (`(1, 14) → (13, 1)`), both benchmarked; the deviation domain stated: identical to `hexx` for `\|x\|, \|y\| < 2^24` without a tie, the game's rule at ties, different beyond `2^24` because `hexx` rounds its endpoints (`src/hex/mod.rs:906`); the `line_to` row of the inventory says so | §6.6, §4.4 |
| 9 | The true bound of the flood stated (182 layers on 15 × 16, the walkable interior; the finding's 45-layer route; 84 layers on that corridor); two benchmarks (cave, serpentine); `next_step_away`, `distance`, absent layers and lowest-index ties specified with scalar oracles; the truncation is an open question for the game, Q-5, with the cost of both answers; the library decides nothing about a truncated walker | §6.9, §7, §11 Q-5 and R-15, D-25, D-26 |
| 10 | `distance_between` returns `u16` on `u16` arithmetic with the extreme pairs as oracle cases; `chunk_of` frozen to one signature; `neighbor_direction` validates adjacency through coordinates and takes `height`; `rotate` reduces the offset first (`steps % 6`), `arc` uses `+ 6 −`, both tested on every `u8` | §6.1, §6.8, §7, D-29 |
| 11 | `directional_fov` takes an `EdgeDirection` and selects the ring by its two `vertex_directions()`, as `fov.rs:64-67` | §4.4 |
| 12 | The inventory is on effective visibility: `Way` and `ExactSizeHexIterator` removed as crate-private (`pub(crate) mod way`, `pub(crate) use`); public fields of `Hex`, `HexBounds`, the six shapes, `GridEdge`, `GridVertex` and the variants of `DirectionWay`, `OffsetHexMode`, `DoubledHexMode`, `HexOrientation` inventoried; the counts paragraph rewritten; the parser rule for visibility added | §4.4, §4.2 |
| 13 | A curated per-item map `COUNTERPARTS` with precedence over the broad exclusion rules; unresolved items stay `missing` and fail `--check`; parser tests on the counterpart signatures, trait methods, visibility and re-exports | §4.2 |
| 14 | Every estimate is the sum of its listed operations: assembly 9,401 per piece, 40k per layer, 85k per window; line 6.1k (table), `line_of_sight` 13.3k, `approach` 28.4k, loop 62k/71k; `cut` 16.4k; `hexagon` 22.5k; N-1 192.7k; seams 31.6k; the tick 1.30M on the cave benchmark (window + flood + 8 walkers at distance 15) | §6.1 to §6.9, §7 |
| 15 | Every public function of L-M1 has a row or an explicit shared target: `new`, the taken-over helpers with their existing budgets, `neighbor_mask`, `edge_neighbors`, `neighbor_in`, `new_odd`, `to_hex`, `from_hex`, `index_to_hex`, `hex_to_index`, `new_cave_with_margins`, `smooth`, `is_open_across`, `origin`, `local`, `FloodTrait::distance`, `depth`, the `Into` conversions, every mirror item of L-M1; fixtures distinguished from worst cases | §7 |
| 16 | `POW128` is 128 entries; `PERMUTATIONS` (720) and the spreader tables inventoried; the new tables total 596 entries, ~665 felts; R-11 updated; entry counts distinguished from compiled size | §7, §11 R-11 |
| 17 | The take-over claim narrowed to the engine tests; `bench_u252.cairo` (`types::u252`, `starknet::storage_access::StorePacking`, `:16-17`), the `u252` module tests and `test_readme_u252` belong to `uint252` | §5.4 |
| 18 | Each mirror item of L-M1 traced to an extension it serves (`Hex` core and `line_to` for N-5 and the conversion; the offset conversions and enums for §3.5; `EdgeDirection` and its rotations for N-7's vectors); everything else moved to L-M2 in the inventory (constants, constructors, arrays, `neighbor`, `neighbor_direction`, the `Hex` rotations, `range_count`, operators, `mul_scalar`, `add_direction`, `DoubledHexMode`, `Neg`, `Debug`); the width of the set is D-5 for the owner, wider or narrower | §8, §4.4, §12 D-5, §13 |
| 19 | Exclusive allowlists per task, one file in one allowlist, with "runs after" and "can run with" columns; the facade, `lib.cairo`, `Scarb.toml`, scripts and docs are the orchestrator's only; `hex.cairo` passes from M1-T2 to M1-T6, `layout.cairo`, `caver.cairo` and `bfs.cairo` from M1-T1 to their tasks; new files `board/tables.cairo`, `board/cut.cairo`; the mirror split into one trait per `hexx` source file so that L-M2 tasks own whole files, with their order; the L-M2 exit distinguishes items scheduled for L-M3; the L-M3 tasks have exclusive files; M1-T7 and M1-T8 marked as design tasks with their oracles | §8, §2.2 |
| 20 | Nine behavioural decisions added with alternative, whether game-mandated or library policy, and who decides: D-22 (free ring tiles seeded and frozen), D-23 (`cut` clears the ring), D-24 (endpoints not tested, game-mandated), D-25 (flood depth, game), D-26 (`distance` of an obstacle tile), D-27 (a line leaving the board is `None`, blocked), D-28 (`smooth` holds `held` and the ring), D-29 (the numeric domains), D-30 (the N-1 domain) | §12 |

Kept as the audit found them correct: the assembly partition (now with the explicit half-open
rectangles), the board-to-`Hex` conversion, the symmetry of the tie rule, the measured figures.

Verification after the fix loop: `git status --short` shows only the plan, now as
` M docs/research/LIB-03-porting-plan.md` (the earlier version was committed on the branch
by the orchestrator between follow-ups; the fix loop's changes are uncommitted); the plan is
1,270 lines; the five relative links are unchanged and resolve; no Markdown link into
`sources/`. Not committed, per the profile.

## Follow-up 4 (ADR-0007)

The owner dropped Dojo (ADR-0007, D-123, 2026-09-28): the game is a set of plain Starknet
contracts on Cairo 2.19 (Scarb 2.19.4, snforge 0.61). Read: `grimworld:docs/architecture/ADR-0007-native-starknet.md`,
`grimworld:docs/needs/hexmap.md` (row N-9 and § "N-9 in detail"), the refreshed
`sources/VERSIONS.md` (grimworld at `a9f6e56`) and `sources/hexx-cairo-main/PLAN.md` (which
carries LIB-03b and the pre-ADR-0007 wording of N-9; the ADR supersedes D-122).

**A fact to note on N-9.** The orchestrator's message says that `origami_hexmap` 1.8.0
declares `snforge_std` as a regular dependency. In the pinned source (`04ab30c`) it does not:
`crates/hexmap/Scarb.toml:14-15` reads `[dev-dependencies] snforge_std.workspace = true`, with
the workspace pinning `0.61.0`. The game's needs file reports that the *published* 1.8.0 is
resolved by consumers as depending on `snforge_std >=0.61.0, <0.62.0`. So the defect is in
the published artefact, not in the manifest; the plan says so (§2.1, R-17) and makes the
exit criterion a check on the published package, not a reading of `Scarb.toml`. The cause
(packaging step, registry index or the Scarb that published 1.8.0) is for LIB-04 to find.

What changed in `docs/research/LIB-03-porting-plan.md` (1,270 → 1,292 lines), and nothing else:

1. **Compiler target stated** (§0): Cairo 2.19, Scarb 2.19.4, snforge 0.61; `BoundedInt`
   stays (with its three use sites in the engine); no floor at Cairo 2.13, one code base, no
   separate class; the game is on the same compiler; nothing depends on Dojo; the consumer is
   a Starknet contract or a storage-free library of rules; tests and examples use snforge only.
   Recorded as decision D-31 in §12 (alternative: a 2.13 floor, for which no consumer exists).
2. **N-9, reduced, in L-M1** (§2.1, §8): `snforge_std` under `[dev-dependencies]` only; the
   L-M1 content names it; exit criterion (8) is demonstrable: two consumer packages in
   `tools/consumer_check/` outside the workspace, one with `cairo_test` only and one with
   `snforge_std` of another version, resolve and build against the published release
   candidate and release, and the registry entry lists no `snforge_std` dependency; task
   M1-N9 added (the manifest line stays the orchestrator's); risk R-17 added.
3. **Dojo removed from what shapes the plan**: the manifest description and the keyword
   `dojo` of 1.8.0 are not taken over and replaced (§2.1 "Manifest metadata", §5.5); the
   README's "for Dojo-based games" paragraph is not carried (§5.5); "models" replaced by
   contract storage or storage structs (§2.3 `storage` row, §3.4, §9.3). The remaining
   occurrences of the word are the ADR reference, the removed wording quoted as removed, and
   the `dojoengine/origami` repository path.
4. **What the game does meanwhile** aligned with ADR-0007 (§9.1, §10 step 1): SPK-7 runs in
   the game's workspace on Cairo 2.19; the game can build 1.8.0 only while its `snforge_std`
   stays within `0.61.x`; `0.1.0-rc.1` removes the constraint. R-9 updated (same compiler,
   exact pins by SPK-5b); Q-3 closed.
5. **§13**: rows added for N-9 and for ADR-0007 / D-123, each with the sections that honour
   them. The refreshed grimworld commit is in the sources table of §0.

Verification: `git status --short` shows only the plan (` M`); a search for Dojo, sozo,
Torii, models and worlds finds only the deliberate mentions above; the five relative links
are unchanged and resolve. Not committed, per the profile.

## Fix loop 2

Answers the audit `sources/audits/LIB-03-audit-gpt-6-astra-pass-2.md` (`[GPT-6-Astra]`,
verdict FAIL: 12 of the 20 pass-1 fixes resolved, 6 partly, 10 new findings 21 to 30). Every
finding was verified in the sources or re-derived before the fix; **none is disputed**. What
was checked: 21 (re-derived the two operands of `P_S2`: `(14, 11)` from the odd rows shifted by
`W + 1` and `(1, 12)` from the even rows shifted by `W − 1` both land on `(0, 13)`, so their sum
carries into `(1, 13)`); 22 (`C · 2^W` on the West seam reaches bit `W·H + W − 1 = 254` on
15 × 16, above `2^251`); 23 (the band arrays were declared `[felt252; 15]` and `ROW_FROM` summed
through row 14, so `ROW_TO[15]`, `COL_TO[15]` and canonical row 15 did not exist); 24
(`hexmap:src/helpers/layout.cairo:269`: `neighbour_mask` takes "an interior tile"; the
predecessor of `(10, 15)` on the line from `(7, 9)` is `(10, 14)` by the axial formula); 25
(`src/hex/mod.rs:906-908`: the endpoints are converted with `as_vec2` and the samples come
from `a.lerp(b, step / dist)` in `f32`, so the interpolation itself rounds); 26 (recomputed
every sum: the line loop step is 4,067 before the 1,270 iteration overhead, the table path
needs a `POW`/`INV` lookup, the assembly converts two operands, the ring loop was budgeted as
one call, the East seam summed to 31,978, `side` to 3,032); 27 (the dependency edges); 28
(`chunk_of` is `u8 → (u8, u8)` and the origin of the adventurer at `(0, 0)` is `(−7, −8)`);
29 (`grimworld:docs/design/04-combat.md:40-41` and `README.md:63-66`); 30 (the stale
summaries); 4, 6, 8, 9, 14, 15, 19 as restated above. The corridor of finding 9 was
recounted by hand (45 steps from `(7, 8)` to `(2, 2)`, through the joints on the odd rows
that touch two tiles of each corridor) and pinned as the fixture `SERPENTINE_15X16`.

**The change of status (second instruction).** §1.4 states the principle: for every function
of §6 the contract (signature, domain, semantics over a scalar oracle, tie-breaks, oracle,
worst case, regression cases) is normative; the algorithm is a design sketch that LIB-05
proves against the oracle over the whole domain before keeping it and may replace. Every
subsection §6.1 to §6.9 is split into "Contract (normative)" and "Design sketch (not
normative)", with a "Regression cases" row and an "Operations, summed (lower bound of the
target)" row. §7 gives every non-measured figure as a range `[sum, sum + 25 %]`, states that
LIB-05 replaces every target by a measurement and reports any measurement above the upper
bound before the budget is set, and gives the tick as a range recomputed from the corrected
rows. §7, §11 (R-18) and §12 say that the tick estimate roughly doubled between the first
draft (740k) and the audited plan (a range starting at 1.31M) and may move again, and that
only LIB-05 and SPK-7 settle it. No contract was weakened or removed.

| Finding | What changed | Section |
|---|---|---|
| 4, 22 | West seam: the last-row bit `(W−1, H−1)` is cleared (`C & ~TOP_LAST`) before the upward product; East and North likewise clear their last-row bit; the domain lists every dimension class and the oracle runs on all of them; regression R-N2-2 (15 × 16, `far = {(0, 15)}`, `openings = {(14, 15)}`) | §6.3 |
| 6, 23 | The band tables have explicit terminal entries and two row domains: `COL_FROM`, `COL_TO: [felt252; 16]`, `ROW_FROM_15`, `ROW_TO_15: [felt252; 16]` (chunks), `ROW_FROM_16`, `ROW_TO_16: [felt252; 17]` (the 16-row canonical window); the assembly uses the 15-row bands, the hexagon clip the 16-row bands; class and gas recomputed; regressions R-N3-3 (`oy = 14`, `ox = 0`) and R-N6-3 (`(7, 15)` in the radius-7 shape around `(7, 8)`) | §6.4, §6.7, §7 |
| 8, 25 | No identity domain is claimed for `line_to`: endpoint rounding and interpolation rounding are named as two separate deviation sources; the parity claim is limited to the verified sets (the 15 × 16 window, the `[-40, 40]²` sample); `refgen` generates adversarial large-coordinate vectors; regressions R-N5-5 (`(8_000_000, 0) → (8_000_001, 6)`, sample 2 = `(8_000_000, 2)`) and R-N5-6 (`16_777_217`); the inventory row and the gate summary (four kinds of departure) say the same | §6.6, §4.4, §12 |
| 9 | The corridor is pinned (`SERPENTINE_15X16`: 83 open tiles, source `(7, 8)`, the hand-counted path of 45 steps to `(2, 2)`, 82 reachable tiles with `(1, 2)` frozen, `depth() = 45`); the three selection functions are defined as properties over the scalar BFS with lowest-index ties; `next_step_away` has its own worst case (a near walker on a deep flood, scan bounded by `depth() − dist`); regressions R-N8-1 to R-N8-5, including the two-walker variant where `(1, 2)` gets `None` at every depth | §6.9, §7 |
| 14, 26 | Every sum recomputed from its operations: assembly 11,210 per piece (two conversions), 46.5k per layer, 98.8k per window; line table 7.4k (three lookups), loop step 5,337 with the iteration overhead, 105.4k / 121.4k for 19 / 22 steps; `line_of_sight` 14.5k; `approach` 29.7k interior, 46.7k ring target; hexagon table 31.6k (band conversions), ring loop 123.5k in one loop of both extents; East seam 34.0k (with the `TOP` clear), horizontal 26.4k; `side` 3.0k; N-1 62.0k per generation (the column masks and the ORs), 234.7k at order 3; the tick 1,310.7k as the lower bound of `[1.31M, 1.64M]` | §6.2 to §6.9, §7 |
| 15 | `length` and `ulength` added to the L-M1 list, the mirror gas row and the trace; `EdgeDirection::iter` listed as a zero-cost counterpart; the `Set`, `WideSet`, `SmallSet` impls mapped to the Dial budgets; `HexPrinter` listed as test-only with no target; §8's list declared the canonical one | §7, §8 |
| 19, 27 | M1-T1 carries an explicit initial-ownership exception for `board/map.cairo`; M1-T3 runs after M1-T2; M1-T4 depends on M1-T1 only (no `chunk_of`) and may run with M1-T2 and M1-T3; M1-T9 runs after M1-T3 and M1-T4 (the tick bench needs `window`); M1-T6 after M1-T2 and M1-T3; L-M2 edges made explicit (M2-T2 after M2-T1 and M2-T3; M2-T4 after M2-T2 and M2-T3; M2-T5 after M2-T2 and M2-T3; M2-T6 after M2-T2; M2-T7 after M2-T1 and M2-T2) with the parallel groups that follow | §8 |
| 21 | The two diagonal operands of `P_S2` and `P_N2` are masked to remove the wrapping columns (`G_o' = G_o & ~COL_LAST`, `G_e' = G_e & ~COL_0`), shown disjoint afterwards, and combined with OR so that the disjointness proof is not load-bearing; the oracle adds direct plane tests on seeded grids; regression R-N1-3 (`(14, 11)`, `(1, 12)`, `(1, 13)`: `(1, 13)` dies, `P_S2` holds `(0, 13)` once); the per-generation sum rises to 62.0k | §6.2 |
| 24 | `approach` dispatches on the target: `neighbor_mask` for an interior target, `LayoutTrait::edge_neighbors` for a ring target; the contract states the result for every in-board `to`; regression R-N5-4 (`(7, 9) → (10, 15)` gives `SouthEast`, predecessor `(10, 14)`); its own gas row | §6.6, §7 |
| 28 | `origin(x: u8, y: u8) -> Origin { cx: i8, cy: i8, ox: u8, oy: u8 }` defined as the Euclidean split (`origin(0, 0) = (−1, −1, 8, 7)`), computed on `u16` by a shift of one chunk, independent of `chunk_of`; `local` on `u8`; the oracle covers all 65,536 inputs and the round trip; regressions R-N3-1 and R-N3-2; R-14 and D-20 reworded | §6.4, §11, §12 |
| 29 | D-24 is a proposed library policy for the game to confirm (the design sentence decides the tiles between, not the endpoints); D-23 is the chosen policy of `cut`, not a requirement of the finders, which accept open edge endpoints (`README.md:63-66`) | §12, §6.5 |
| 30 | §5.1 excludes the `u252` tests explicitly; R-1 quotes the window's range; the gate summary has four kinds of departure and names the precision deviations; `length`, `ulength` and `iter` are in the L-M1 list; every summary points at §7's ranges | §5.1, §11, §12, §8 |

**Regression cases added** (each with input and expected output in its subsection): R-D1 to
R-D3 (§6.1); R-N1-1 to R-N1-5 (§6.2), among them the three tiles of finding 21 and the
`{0, 190, 191}` case of pass 1; R-N2-1 to R-N2-4 (§6.3), among them the 15 × 16 West seam of
finding 22; R-N3-1 to R-N3-4 (§6.4), among them the adventurer at global `(0, 0)` of finding
28 and the `oy = 14` case of finding 23; R-N4-1, R-N4-2 (§6.5); R-N5-1 to R-N5-6 (§6.6), among
them the edge target of finding 24 and the float counterexample of finding 25; R-N6-1 to
R-N6-5 (§6.7); R-N7-1, R-N7-2 (§6.8); R-N8-1 to R-N8-5 (§6.9), the pinned winding corridor
with its real layer counts and the two-walker variant.

Disputed findings: none.

Verification after the fix loop: `git status --short` shows only the plan (` M`); the plan is
1,442 lines; a search for the superseded figures and wording (`~70k`, `target 85k`, `1.30M`,
`i16` origins, "three kinds of departure", the 15-entry band arrays) finds none; the five
relative links are unchanged and resolve. Not committed, per the profile.

## Fix loop 3

Answers the audit `sources/audits/LIB-03-audit-gpt-6-astra-pass-3.md` (`[GPT-6-Astra]`,
verdict FAIL: findings 4, 6, 8, 15, 21, 22, 23, 24, 25, 28, 29 resolved; 9, 14, 19, 26, 27,
30 partly resolved; 31 to 41 new). Every finding was verified in the sources or re-derived
before the fix; **none is disputed**. What was checked: 31 (`to_hex(0, 0) = (0, 0)`,
`to_hex(255, 255) = (−255 − 128, 255)`, so `dq = 128`, `dr = 255`, `dq + dr = 383`, above the
382 of the pair `(255, 0)`–`(0, 255)`; and `LayoutTrait::neighbor(15, 16, 0, East) = None`,
`hexmap:src/helpers/layout.cairo:338-342`); 32 (odd-r on the East seam: rows 4 and 6 are
globally even for an even origin, and their `NE` / `SE` across the seam is `(−1, 5)`); 33
(`bfs.cairo:1238-1242` records open edge destinations, and layer 0 of the signature was
`{from}` for any walkable source, including an edge tile; `BfsInternal::endpoint`, `:183-187`,
seeds an edge start by its open interior neighbours); 34 (on 7 × 7 the seven tiles around
`(1, 1)` include the ring tiles `(0, 1)`, `(1, 0)`, `(2, 0)`; `tiles_within_range` dilates on
the interior and returns 4); 35 (`P_W = G_low / 2` after the row-0 clear has no bit at `(0, 0)`
for the live tile `(1, 0)`); 36 (`(0 + 8) / 15 − 1` on `u16` underflows; `0 + 15 − 8 − 255`
likewise); 37 (every sum recomputed, below); 38 (the two-scan `distance` of the previous draft
scans 46 + 46 layers for `(1, 2)`; the reverse scan from `(4, 8)` with both open neighbours
blocked visits layers 45 down to 0, 46 scans); 39 (`order` is `u8`, so 255 generations are in
the domain; 3 × 83 is a legal board of 249 tiles whose row loop runs 83 rows at any radius
above 40); 40 (the tables hold radii 1 to 7 and the dispatch selected them for radius 0); 41
(`cut` is an AND, so `2^49` on a 7 × 7 board keeps no tile); 9, 14, 19, 26, 27, 30 as restated
in the table.

**The seven rules of the method, applied.** (1) Every expected value, count and sum of §6 and §7
was recomputed step by step; the arithmetic is reproduced below; every input that was not
pinned is now pinned (the eight walkers, their `blocked` bitmaps, the near bitmaps of the seam
cases, the cave `depth()`, the walkers' scan depth of the tick). (2) Every "Operations, summed"
row is an exact sum to the unit and is the lower bound `L` of its §7 range; `U = ceil(1.25 × L)`;
the tick's `U` is one global uplift of the exact total, and §7 says why it differs from the sum
of the component uppers; every call is charged at the figure of its own §7 row (the two
`index_to_hex` of the line loop at 4,194 each, `hex_to_index` at 2,998 per step,
`LayoutTrait::neighbor` at 3,696 inside `edge_neighbors`). (3) Every function of §6 has a
"Domain coverage" row that states one of: the worst case of the whole domain (fixed operation
sequences: seams, assembly, `cut`, `rotate`, `arc`, the line table path, the hexagon table
path), a restricted domain (none was needed), or a parameterised bound with the game-sized
fixture and the domain-wide worst case named and both benchmarked (`generate_with_margins` and
`smooth` in `order`, `line` in `N ≤ W + H − 2`, the hexagon loops in `rows ≤ H`, the flood in
`depth() ≤ (W − 2)(H − 2)`, the selections in the scanned layers `s`). (4) Every oracle decides
exactly the contract's property: the hexagon equality with `tiles_within_range` is restricted
to hexagons wholly interior, the per-tile oracle covers the ring-clipped cases; the flood's
`reference_all` is filtered to interior destinations and the open-edge policy is the
reversible decision D-32 (layers hold interior tiles only, layer 0 is `{from}` even for an
edge source; the alternative is stated); the N-1 plane property is asserted on interior
destinations. (5) Both dependency graphs are listed as edges, acyclic, with a topological
order for L-M2 and a bootstrap task M2-T0 owning the shared constants and constructors; every
file and every `impl` has one owner at any time (all direction impls, `Neg`, `mul_scalar`,
`Debug` of both types, to M2-T1, which owns `direction/edge_direction.cairo` in L-M2). (6) The
three sketch errors are fixed and kept as regression cases: R-N1-6 (finding 35), R-N3-1 with
`local(origin(255, 255), 0, 0) = None` (finding 36), R-N6-6 (finding 40). (7) Every summary,
risk, decision and gate figure was refreshed (R-1, R-11, R-15, R-18, D-21, D-32, the gate's
items 1 and 2, the tick history sentence).

| Finding | What changed | Section |
|---|---|---|
| 9 | The eight-walker benchmark is pinned as `SERPENTINE_15X16_8`: the positions `W1 (5, 2)` to `W8 (2, 12)`, `obstacles` = the eight tiles, `depth = 182`, `blocked` = the eight tiles updated after each move, the expected layers (`depth() = 41`, 73 reachable tiles), the expected move of each walker (`W1 → Some(36)`, `W5 → Some(186)`, the six others `None`) and the expected distances; each selection function is budgeted from its own scan count (`next_step` `17,747 + 4,662 × s`, `distance` `4,259 + 4,662 × s`, `next_step_away` `2,563 + 8,054 × s`) | §6.9, §7 |
| 14, 37 | One operation ledger with explicit unit costs; every sum exact (`side` 3,032, ring loop `7,738 × rows`, hexagon loop `4,504 × rows`, assembly 46,532, window 98,762, line loops 138,253 / 158,758 / 582,528 after the per-call reconciliation of finding 26); the rounding rule stated in §7 (`L` exact, `U = ceil(1.25 × L)`, no rounded endpoint); the tick's upper bound is one global uplift (1,672,098) and §7 shows the sum of the component uppers (1,672,104) that it replaces | §6.1 to §6.9, §7 |
| 19 | Every direction implementation has one owner: M2-T1 owns `direction/impls.cairo` and, in L-M2, `direction/edge_direction.cairo`, with `Neg`, `mul_scalar` and `Debug` for both direction types; M2-T2 keeps the `Hex` items only; the file split and the edges reconciled | §8 |
| 26 | Call counts consistent with per-call targets: the line loop charges 2 `index_to_hex` at 4,194 each (8,388) and `hex_to_index` at 2,998 per step; `to_hex`, `from_hex`, `index_to_hex`, `hex_to_index` have exact rows in §7 (1,998 / 2,198 / 4,194 / 2,998); `edge_neighbors` is `6 × (3,696 + 1,269 + 98) = 30,378` with `LayoutTrait::neighbor` itemised; `approach` on a ring target 57,481; the ring surcharge of `next_step` 27,815 | §6.6, §6.9, §7 |
| 27 | The bootstrap task M2-T0 (the shared constants and constructors of `Hex`: `ORIGIN`, the axis constants, `DIAGONAL_COORDS`, `hex()`, `splat`, `new_cubic`, `from_array`, `to_array`, `to_cubic_array`, `const_neg`, `const_add`, `abs`, `min`, `max`, `dot`, `signum`) runs first; the L-M2 graph is the edge list `T0 → T1, T0 → T3, T0 → T2, T1 → T2, T3 → T2, T2 → T4, T3 → T4, T2 → T5, T3 → T5, T2 → T6, T1 → T7, T2 → T7`, acyclic, topological order `T0, T1, T3, T2, T4, T5, T6, T7`; the L-M1 graph is listed as edges too | §8 |
| 30 | R-11 says 634 entries and ~705 felts; D-21 says 98 felts; the gate summary names the categories of departure that the body documents (precision at ties and at large coordinates, the overflow policy of §3, the integer counterparts, the renamed and excluded items) without claiming an exhaustive list | §11, §12 |
| 31 | R-D1 asserts `distance_between(0, 0, 255, 255) = 383` with the axial arithmetic shown; the worst case of `distance_between` is that pair; R-D3 is conditioned on `neighbor(from, d) = Some(to)` and asserts nothing for a boundary; R-D4 added; the "Domain coverage" row proves 383 is the maximum | §6.1, §7 |
| 32 | R-N2-3 pins `near = board` and expects `2^60 + 2^75 + 2^90` (`{(0, 4), (0, 5), (0, 6)}`) with the parity argument written out; R-N2-3b is the complementary parity (`odd = true`, expected `2^75`); every seam regression pins both bitmaps; R-N2-4 (North seam, 15 × 16, `odd = true`, `far = 2^7`, expected `2^232 + 2^233`) added | §6.3 |
| 33 | Decision D-32 (reversible, §12): the layers hold interior tiles only, layer 0 is `{from}` even when `from` is an open edge tile, an edge tile other than the source is never in a layer; the semantics define `dist` through interior tiles; the oracle `reference_all` is filtered to interior destinations, with an edge source seeded by its open interior neighbours; R-N8-7 pins both scenarios on the 7 × 7 board of the finding | §6.9, §12, §13 |
| 34 | The secondary equality `hexagon(p, r) == tiles_within_range(p, r)` on `new_empty` is asserted only when every tile of the geometric hexagon is interior; the per-tile oracle covers the ring-clipped cases; R-N6-7 pins the 7-versus-4 case of the finding with both bitmaps | §6.7 |
| 35 | The N-1 plane property is asserted on interior destinations (the sketch's planes are correct there and the frozen ring makes the ring destinations irrelevant to the output); R-N1-6 pins the impulse test of the finding (`(1, 0)` live, expected grid `2^1`, `P_S1` holds `(1, 1)` on the interior); R-N1-2 and R-N1-3 restated on the interior | §6.2 |
| 36 | `origin` computes the quotient on `u8` and subtracts one on `i8` (`cx = (qx as i8) − 1`); `local` computes its differences on `i16` and compares before any conversion; R-N3-1 shows the arithmetic of each case; R-N3-2 adds `local(origin(255, 255), 0, 0) = None`; sums 3,996 and 2,600 | §6.4 |
| 38 | `distance` is one pass (the layer-0 bit test, then the neighbour scan, `k + 1`), budgeted `4,259 + 4,662 × s` (218,711 at `s = 46`); `next_step_away` has the all-blocked case as its worst case (46 scans, `None`), budgeted `2,563 + 8,054 × s` plus 8,400 when found (373,047 at `s = 46`); R-N8-6 pins it | §6.9, §7 |
| 39 | Game-sized fixtures and domain-wide worst cases labelled everywhere: `generate_with_margins` and `smooth` at order 3 and order 255 (R-N1-7 runs order 255); the hexagon loops on 16 rows and on 83 rows (3 × 83, radius 255); the line loop at 19, 22 and 84 steps; the flood at 182 and 187 layers; parameterised bounds in §6 and §7 for each | §6.2, §6.6, §6.7, §6.9, §7 |
| 40 | Radius 0 returns `2^position` before any dispatch; the table path serves `1 ≤ radius ≤ 7` on width 15; R-N6-6 asserts radius 0 for both functions on every position | §6.7 |
| 41 | R-N4-2 states the property `cut(m, mask) == cut(m, mask & (2^(W·H) − 1))`; R-N4-3 adds the high-bits-only mask `2^49` on 7 × 7 with expected grid 0 | §6.5 |

**The arithmetic, step by step** (the first rule; unit costs: `DivRem` 1,098, lookup 1,269, felt
product 98, wide conversion 1,809, two-limb AND 3,392, one-limb AND 1,696, rebuild 197, loop
iteration 1,270, lowest-bit step 8,400, the layer 19,300 and the fixed 55,000 of `Bfs`, all
measured in `GAS.md`; an `i32`/`u16` operation 300, a comparison 100, a six-arm `match` 1,000,
estimates stated in §6.1).

- §6.1: `distance_between` `2 × 1,098 + 10 × 300 = 2,196 + 3,000 = 5,196`; `chunk_of` 2,196;
  `neighbor_direction` `2,196 + 1,098 + 1,000 = 4,294`; `neighbor_mask` `1,098 + 1,269 + 196 =
  2,563`. R-D1: `to_hex(255, 255) = (−255 − 128, 255)`, `to_hex(0, 0) = (0, 0)`, `dq = 128`,
  `dr = 255`, `dq + dr = 383`, `max(128, 255, 383) = 383`.
- §6.2: per generation `1,696 + 3,392 + 6,784 + 6,784 + 3,392 + 3,392 + 788 = 26,228`;
  `35,710 + 26,228 = 61,938`; `smooth` `61,938 + 3,392 = 65,330`; fixed `27,157 + (6,784 +
  1,809) + 12,900 = 48,650`; order 3: `48,650 + 185,814 = 234,464`; order 255: `61,938 × 255 =
  15,794,190`, `+ 48,650 = 15,842,840`; `smooth` order 3: `12,900 + 195,990 = 208,890`; order 255:
  `65,330 × 255 = 16,659,150`, `+ 12,900 = 16,672,050`. R-N1-6: `(1, 0)` is bit 1; `SE` of `(1, 1)`
  (bit 16, odd row) is `16 − 15 = 1`; `P_S1 = 2^1 · 2^15 = 2^16`.
- §6.3: East seam, 16 terms `1,809 + 3,392 + 197 + 98 + 1,809 + 3,392 + 394 + 196 + 3,618 + 3,392
  + 3,392 + 3,392 + 1,809 + 3,392 + 3,392 + 197 = 33,871`; horizontal `1,809 + 3,392 + 197 + 98 +
  1,809 + 1,696 + 197 + 98 + 1,809 + 3,392 + 1,809 + 3,392 + 3,392 + 197 = 23,287`; `side`
  `2,538 + 494 = 3,032`. R-N2-3: bits `4 × 15 = 60`, `5 × 15 = 75`, `6 × 15 = 90`; R-N2-4: bits
  `15 × 15 + 7 = 232` and 233.
- §6.4: piece `3,807 + 196 + 3,618 + 3,392 + 197 = 11,210`; `assemble` `44,840 + 294 + 1,098 +
  300 = 46,532`; `window` `93,064 + 5,398 + 300 = 98,762`; two chunks `2 × (22,420 + 98 + 1,398)
  + 5,698 = 47,832 + 5,698 = 53,530`; `origin` `2,196 + 1,200 + 600 = 3,996`; `local` `1,200 +
  600 + 400 + 400 = 2,600`. R-N3-1: `−7 = 15 × (−1) + 8`, `−8 = 15 × (−1) + 7`; `248 = 15 × 16 +
  8`. R-N3-2: `8 × 15 + 7 = 127`, `15 × 15 + 14 = 239`, `0 − 248 = −248`.
- §6.5: `cut` `1,809 + 1,809 + 3,392 + 4,497 + 1,809 + 3,392 + 197 = 16,905`.
- §6.6: table `2,196 + 3,807 + 1,098 + 200 + 98 = 7,399`; `line_of_sight` `7,399 + 1,809 + 1,809
  + 3,392 + 100 = 14,509`; `approach` `7,399 + 2,563 + 3,618 + 3,392 + 8,400 + 4,294 = 29,666`;
  `LayoutTrait::neighbor` `1,098 + 1,098 + 1,000 + 200 + 300 = 3,696`; `edge_neighbors` `6 ×
  (3,696 + 1,269 + 98) = 6 × 5,063 = 30,378`; ring target `29,666 − 2,563 + 30,378 = 57,481`;
  `hex_to_index` `2,198 + 200 + 600 = 2,998`; `index_to_hex` `2,196 + 1,998 = 4,194`; loop step
  `600 + 600 + 2,998 + 1,367 + 1,270 = 6,835`; `cost(N) = 8,388 + 6,835 × N`: `N = 19`
  `129,865 + 8,388 = 138,253`; `N = 22` `150,370 + 8,388 = 158,758`; `N = 84` `574,140 + 8,388 =
  582,528`; bound on 3 × 83: `(0, 0) → (2, 82)` has `dq = −39`, `dr = 82`, distance 82 ≤ 84.
- §6.7: table `2,196 + 1,269 + 5,076 + 7,236 + 6,784 + 394 + 98 + 1,809 + 1,809 + 3,392 + 197 +
  1,269 + 98 = 31,627`; loop row `500 + 2,538 + 196 + 1,270 = 4,504`, 16 rows 72,064, 83 rows
  373,832; ring row `1,000 + 5,076 + 392 + 1,270 = 7,738`, 16 rows 123,808, 83 rows 642,254.
  R-N6-7: centre bit `1 × 7 + 1 = 8`; odd row 1: `E = 7`, `W = 9`, `NE = 8 + 7 = 15`, `NW = 16`,
  `SE = 8 − 7 = 1`, `SW = 2`; the interior ones are 8, 9, 15, 16.
- §6.8: `rotate` `2,196 + 300 = 2,496`; `arc` `300 + 300 + 1,098 + 300 = 1,998`; `255 mod 6 = 3`.
- §6.9, distances on `SERPENTINE_15X16` from `(7, 8)`: east branch `(13, 8)` 6, `(13, 7)` 7,
  `(13, 6)` 8, `(x, 6) = 8 + (13 − x)`, `(2, 6)` 19, `(1, 6)` 20, `(1, 5)` 20, `(2, 4)` 21, `(x, 4)
  = 21 + (x − 2)`, `(13, 4)` 32, `(13, 3)` 33, `(13, 2)` 34, `(x, 2) = 34 + (13 − x)`, `(2, 2)` 45,
  `(1, 2)` 46; west branch `(2, 8)` 5, `(1, 9)` 6, `(1, 10)` and `(2, 10)` 7, `(x, 10) = 7 + (x −
  2)`, `(13, 10)` 18, `(13, 11)` 19, `(13, 12)` 20, `(x, 12) = 20 + (13 − x)`, `(6, 12)` 27,
  `(1, 12)` 32. Counts: `6 × 13 + 5 = 83` open tiles; one obstacle `83 − 1 = 82`, `depth() = 45`;
  two obstacles `83 − 3 = 80`, `depth() = 43` (`(4, 2)` at `34 + 9`). Eight walkers: farthest
  reachable `(6, 2)` at `34 + 7 = 41` and `(6, 12)` at 27, `depth() = 41`, `83 − 8 − 2 = 73`
  reachable; `W1 → 2 × 15 + 6 = 36`, `W5 → 12 × 15 + 6 = 186`; distances `41 + 1 = 42`, `27 + 1
  = 28`. Reverse case: `(4, 8)` at 3, neighbours `(3, 8)` at 4 and `(5, 8)` at 2, both blocked,
  layers 45 to 0 = 46 scans.
- §6.9, sums: flood `55,000 + 19,300 × depth()`: 25 layers `482,500 + 55,000 = 537,500`; 45
  layers `868,500 + 55,000 = 923,500`; 41 layers `791,300 + 55,000 = 846,300`; 182 layers
  `3,512,600 + 55,000 = 3,567,600`; 187 layers `3,609,100 + 55,000 = 3,664,100`. Per scanned
  layer `3,392 + 1,270 = 4,662`. `next_step` `2,563 + 3,392 + 3,392 + 8,400 = 17,747`, `+ 4,662 ×
  s`: `s = 15` `69,930 + 17,747 = 87,677`; `s = 46` `214,452 + 17,747 = 232,199`; ring
  `30,378 − 2,563 = 27,815`. `distance` `2,563 + 1,696 = 4,259`, `+ 4,662 × 46 = 218,711`.
  `next_step_away` per layer `3,392 + 3,392 + 1,270 = 8,054`; `2,563 + 8,054 × 46 = 2,563 +
  370,484 = 373,047`. Tick `98,762 + 537,500 + 8 × 87,677 = 98,762 + 537,500 + 701,416 =
  1,337,678`; eight `search_path` `8 × 706,135 = 5,649,080`.
- §7: `U = ceil(1.25 × L)` for every row, checked one by one (for example `1.25 × 98,762 =
  123,452.5 → 123,453`; `1.25 × 1,337,678 = 1,672,097.5 → 1,672,098`; the component uppers
  `123,453 + 671,875 + 8 × 109,597 = 123,453 + 671,875 + 876,776 = 1,672,104`); `line_to` per
  element `600 + 600 + 500 + 1,270 = 2,970`, `× 23 = 68,310`; tables `254 + 254 + 14 + 14 + 98 =
  634`, the bands `16 + 16 + 16 + 16 + 17 + 17 = 98`.

**Regression cases added or corrected in this loop**: R-D1 (383), R-D3 (conditioned), R-D4
(§6.1); R-N1-6, R-N1-7 (§6.2); R-N2-3 (corrected), R-N2-3b, R-N2-4, every seam case with both
bitmaps pinned (§6.3); R-N3-1 with its arithmetic, R-N3-2 with `local(origin(255, 255), 0, 0) =
None` (§6.4); R-N4-2 (restated), R-N4-3 (§6.5); R-N6-6, R-N6-7 (§6.7); R-N8-4 (the pinned
eight-walker benchmark), R-N8-6, R-N8-7 (§6.9).

**What the re-reading of §6, §7 and §8 against the seven rules changed** (done after the
fixes above, as instructed):

- §6.7 "Domain coverage" still gave the loop bounds as `4,508 × H` and `7,746 × H` while the
  ledger of the same subsection sums to 4,504 and 7,738 per row (rule 2): corrected to the
  ledger's figures, which §7 already used.
- §6.9: two inputs of the tick sum were not pinned (rule 1): the cave flood's `depth()` (now
  stated as the pinned input 25, one layer past the 24-step far path of the fixture, to be
  replaced by the pinned cave's own `depth()` in `GAS.md`) and the scan depth of the eight
  walkers (every walker charged at `s = 15`, the farthest of the pinned distances 3 to 15).
- §6.6 and §7: the line loop charged `hex_to_index` at 1,500 per step while §7 rowed the
  function at 4,000, and `edge_neighbors` charged `LayoutTrait::neighbor` at an unexplained
  2,000 while §7 rows the facade's `neighbor` at 6,959 measured (rule 2, the same defect as
  finding 26). Fixed by giving `to_hex`, `from_hex`, `index_to_hex` and `hex_to_index` exact
  rows (1,998 / 2,198 / 4,194 / 2,998; the previous rows rounded 1,998 up to 2,000 and 4,194
  down to 4,000) and `LayoutTrait::neighbor` an itemised sum (3,696, from the code at
  `layout.cairo:334-337`), then propagating: the line loop step 5,337 → 6,835, its fixed part
  8,000 → 8,388, its three instances 109,403 / 125,414 / 456,308 → 138,253 / 158,758 /
  582,528 (ranges in §7 accordingly); `edge_neighbors` 19,614 → 30,378; `approach` on a ring
  target 46,717 → 57,481; the ring surcharge of `next_step` 17,051 → 27,815. The tick is not
  affected (its walkers are interior and its line calls are on the table path).
- §8: nothing changed; the edge lists, the "Runs after" column, the "Can run with" pairs
  (disjoint allowlists checked pairwise) and the ownership transfers agree with each other.

Verification after the fix loop: `git status --short` shows only the plan (` M`; the
orchestrator committed the previous version, so the file is modified, not untracked); the
plan is 1,472 lines; a search for the superseded figures (`4,508`, `7,746`, `19,614`, `46,717`,
`17,051`, `5,337`, `109,403`, `125,414`, `456,308`, `1,310,838` outside the history sentence,
"15 layers" as a flood bound, the draft fragments left in table cells) finds none; the four
relative links of the plan (`../briefs/LIB-03-porting-plan.md`, `../briefs/COMMON.md`,
`../../PLAN.md`, `../decisions/L-G1-hexx-port.md`) resolve. Nothing under `sources/` and
nothing outside the two allowlisted files was written. Not committed, per the profile.

## Fix loop 4

Authorised by the project manager as an exception, limited to the six findings open after
`sources/audits/LIB-03-audit-gpt-6-astra-pass-4.md` (`[GPT-6-Astra]`, verdict FAIL: 9, 19,
26, 31, 32, 34, 35, 36, 37, 38, 40, 41 resolved; 14, 27, 30, 33, 39 partly; 42 new), plus
the statement accepted by the project manager that no figure of the plan is a budget. Nothing
else in the plan was touched. Every finding was verified in the sources before the fix;
**none is disputed**. What was checked: 42 (`hexmap:src/generators/digger.cairo:94-96` asserts
`inside`, `not_corner`, `on_edge` on the start of `Digger::corridor`, called by
`open_with_corridor`, `map.cairo:186-190`; `is_edge` and `is_corner`, `asserter.cairo:27-29,
40-42`; `8 = 1·7 + 1` is `(1, 1)`, interior); 33 (the semantics of `next_step` scan from layer
0 and layer 0 is `{from}` for any walkable source, so a walker adjacent to an edge source may
be sent onto it, which the oracle property "is interior" forbade); 27 (`src/hex/impls.rs:46-53,
125-132` take `VertexDirection`; `src/conversions.rs:92-95` calls `range_count` and `shift`;
`src/direction/impls.rs:53-67` call `Hex::mul`; `src/hex/euclidean.rs:115` calls `range`;
`src/shapes.rs:99` calls `wedge_count`; `src/hex/grid/{edge,vertex}.rs` call `add_dir`,
`vertex_cw`/`vertex_ccw`, `edge_cw`/`edge_ccw`, `direction_cw`/`direction_ccw`; `src/bounds.rs`
calls `div_scalar`'s counterpart (`(min + max) / 2`), `range_count`, `range`, `wrap_in_range`,
`splat`, `as_ivec3`; `src/hex/rings.rs` calls `way_to`, `diagonal_way_to`, `direction_cw`,
`direction_ccw`, the direction `Mul<i32>`; `src/hex/mod.rs:936-962` (`rectiline_to`) calls
`main_diagonal_to`, `edge_directions`, the direction `Mul<i32>`, `distance_to`, `+=` on a
direction); 14 (`map.cairo:90-92`: `new` builds the struct and asserts nothing; the direction
helpers cost 100, 1,269 or 1,398, not 1,500); 30 (D-9 and Q-5 quoted superseded models); 39
(the tie equation for `Δ = (3, 3)`, `N = 6`: `i/6 · 3 = i/2`, a half for odd `i`; the
diameters computed below).

| Finding | What changed | Section |
|---|---|---|
| 42 | R-N4-1 uses the entrance index 3 (`(3, 0)`, on the row-0 edge, not a corner; accepted by `Digger::corridor` at `digger.cairo:94-96`, which sets bit 3 at `:102-105`), on `new_cave(7, 7, 3, s)` then `open_with_corridor(3, 0)`; the expected result is recomputed from the contract: `cut(m, 2^49 − 1).grid = m.grid & INTERIOR(7, 7) = m.grid − 2^3`, the interior unchanged, `is_walkable(3)` true before and false after; the previous index 8 (`(1, 1)`, interior) is named as the error | §6.5 |
| 33 | The oracle property reads "a step is never a wall, never blocked, is adjacent, and is interior or equal to `from`"; the "Open edge tiles" row says the source is a step for a walker adjacent to it; R-N8-7 pins `depth = 25` and adds `next_step((1, 3), 0) = Some(21)` with source `(0, 3)`, with the neighbour arithmetic; D-32 says the same; every other sentence of §6.9 (Domain, Semantics, the sketch's scan from layer 0, R-N8-5) was read against the rule and agrees | §6.9, §12 |
| 27 | The L-M2 tasks were each checked against the upstream source, item by item, with the owner of every item they use named in the plan. Moved into the bootstrap M2-T0: `range_count`, `shift`, `ring_count`, `wedge_count` (pure arithmetic), `mul_scalar` (two products; the direction `Mul<i32>` of T1 and the operator of T3 forward to it), `neighbor_coord`, `add_dir`, `neighbor`, `all_neighbors` (they read L-M1 types only). T3 is now after T1 (its `Add`/`Sub<VertexDirection>` take T1's type and are implemented through `into_hex` and `const_add`/`const_sub`, not through T2's `add_diag_dir`); `to_hexmod_coordinates`/`from_hexmod_coordinates` use T0's `range_count`/`shift`; `circular_range_squared` moves from T3's euclidean file to T4's `hex/rings.cairo` because it calls `range` (T2). The edge `T3 → T2` is dropped (T2 calls named methods, never an operator impl, and `mul_scalar` is in T0). Edges relisted: `T0 → T1`, `T0 → T2`, `T1 → T2`, `T0 → T3`, `T1 → T3`, `T1 → T4`, `T2 → T4`, `T3 → T4`, `T1 → T5`, `T2 → T5`, `T3 → T5`, `T2 → T6`, `T1 → T7`; acyclic (every edge goes from a lower number to a higher one; topological order `T0, T1, T2, T3, T4, T5, T6, T7`); no task uses an item of a task that does not precede it. Parallel groups: `T0`; `T1`; `T2` with `T3`; `T4` to `T7` | §8 |
| 14 | `HexMapTrait::new`: [400, 500], four field moves at 100 (`map.cairo:90-92`, no assertion). The direction helpers split into three rows with their models: `index` [100, 125] (a field read); `into_hex` [1,269, 1,587] (one lookup); `const_neg`, `clockwise`, `counter_clockwise` [1,398, 1,748] each (one addition 300 and one `DivRem` 1,098); §6.8's operations row states the same sums | §7, §6.8 |
| 30 | D-9's alternative quotes the current model (`8,388 + 6,835 × N`, 138,253 on the 19-step interior fixture, against 7,399 on the table path). Q-5 quotes `55,000 + 19,300 × depth()` with the pinned instances, `17,747 + 4,662 × s` for a scan, `17,747 + 4,662 × (D + 1)` under truncation at `D` (the layers `0..=D` permit `D + 1` scans when no neighbour is found), describes full flooding as computing every reachable layer, and says that it does not guarantee a move (R-N8-4, R-N8-6) | §12, §11 |
| 39 | Conservative bounds are labelled as bounds, separate from executable fixtures: the line loop's `N ≤ W + H − 2 = 84` is a bound, the executable domain-wide fixture is `(0, 0) → (82, 2)` on 83 × 3 with `N = 83` (the diameter; 3 × 83 has diameter 82), summed to 575,693 with the range [575,693, 719,617], the bound at 84 (582,528) quoted as not benchmarked; the flood's 182 and 187 layers are cardinality bounds, not fixtures, in §6.9 (two rows), the sums row and the §7 row; the tie steps of `N = 6`, `Δ = (3, 3)` are 1, 3 and 5 | §6.6, §6.9, §7 |
| Statement | §7 opens with "**No figure of this plan is a budget**": budgets are set from measurements in LIB-05 by the game's `docs/CAIRO.md` §2; the tick range `[1,337,678, 1,672,098]` is conditional on four stated inputs (the unit costs measured on 1.8.0 with Scarb 2.19.4 and snforge 0.61.0; the sketches of §6.4 and §6.9 as the algorithms; the pinned cave depth of 25 layers and eight interior walkers each scanning 15 layers, `blocked` as pinned, no ring walker, no line call; the range rule `U = ceil(1.25 × L)`). §12 item 2 repeats it with the same list | §7, §12 |

**The arithmetic.**

- R-N4-1: entrance `3 = 0·7 + 3`, `(x, y) = (3, 0)`; `is_edge`: `y = 0`; `is_corner`: `x = 3`
  is neither 0 nor `7 − 1 = 6`, so false; the previous `8 = 1·7 + 1 = (1, 1)`, `1 ≤ x, y ≤ 5`,
  interior. `cut`: `m.grid & (2^49 − 1) & INTERIOR = m.grid & INTERIOR` (every bit of `m.grid`
  is below `2^49`); the ring of `m` holds bit 3 only, so `m.grid & INTERIOR = m.grid − 2^3`.
- R-N8-7, `next_step((1, 3), 0)` with source `(0, 3)`: `(1, 3)` is bit `3·7 + 1 = 22`, row 3
  odd: `E = 22 − 1 = 21`, `W = 23`, `NE = 22 + 7 = 29`, `NW = 30`, `SE = 22 − 7 = 15`, `SW = 16`;
  `layers[0] = {21}`, `layers[1] = {22}`; least `k` with a neighbour in the layer: `k = 0`;
  `{21} − ∅ = {21}`; `Some(21)`. `depth = 25 = (7 − 2)(7 − 2)`.
- Finding 39, diameters: `to_hex(x, y) = (−x − ceil(y/2), y)`. On 3 × 83, `(0, 0) → (2, 82)`:
  `to_hex(2, 82) = (−2 − 41, 82) = (−43, 82)`, `dq = −43`, `dr = 82`, `dq + dr = 39`, distance
  `max(43, 82, 39) = 82`; no pair exceeds it (`|dr| ≤ 82`, `|dq| ≤ 2 + 41 = 43`,
  `|dq + dr| ≤ 43`). On 83 × 3, `(0, 0) → (82, 2)`: `to_hex(82, 2) = (−82 − 1, 2) = (−83, 2)`,
  `dq = −83`, `dr = 2`, `dq + dr = −81`, distance 83 (`|dq| ≤ 82 + 1 = 83`, attained). Line
  loop at `N = 83`: `6,835 × 83 = 567,305`, `+ 8,388 = 575,693`; `U = 1.25 × 575,693 =
  719,616.25 → 719,617`. Bound `N = 84`: `6,835 × 84 = 574,140`, `+ 8,388 = 582,528`. Ties of
  `Δ = (3, 3)`, `N = 6`: the sample `i` is `(i/2, i/2)` in axial, a half-integer pair for
  `i = 1, 3, 5` and an exact tile for `i = 2, 4`.
- Finding 14: `new` `4 × 100 = 400`, `U = 500`; `index` 100, `U = 125`; `into_hex` 1,269,
  `U = 1.25 × 1,269 = 1,586.25 → 1,587`; `const_neg`, `clockwise`, `counter_clockwise`
  `300 + 1,098 = 1,398`, `U = 1,747.5 → 1,748`.
- Finding 30: Q-5 instances `55,000 + 19,300 × 25 = 537,500`, `55,000 + 19,300 × 45 =
  923,500`, `55,000 + 19,300 × 182 = 3,567,600`; a truncated scan `17,747 + 4,662 × (D + 1)`;
  D-9 `8,388 + 6,835 × 19 = 138,253`.
- The tick is unchanged: `98,762 + 537,500 + 8 × 87,677 = 1,337,678`, `U = 1,672,098`.

Verification: `git status --short` shows only the plan (` M`); the plan is 1,493 lines; the
superseded wording (`open_with_corridor(8`, "every even step", "84 steps" as a fixture, "every
reachable walker", `~105k`, `4.7k ×`, "is adjacent and is interior", the old `T3 → T2` edge
except where it is named as dropped) is gone; the four relative links resolve. Nothing under
`sources/` and nothing outside the two allowlisted files was written. Not committed, per the
profile.
