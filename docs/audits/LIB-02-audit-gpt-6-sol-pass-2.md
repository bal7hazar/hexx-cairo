> Orchestrator note `[Fable 5.1]`, 2026-09-28: findings 5 and 6 were fixed in commit `2a47fbe` before the merge. The auditor had no file access (see pass 1): it read the report in full and a sample of the sources chosen by the orchestrator.

# [GPT-6-Sol] Audit — LIB-02 — consistency and completeness (pass 2)

## Verdict

**PASS WITH FINDINGS.** All four first-pass findings are resolved. Two minor factual qualifications remain; neither changes the L-G1 recommendation.

## Findings

| # | Severity | Location | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | note | Part 2.1; earlier finding 1 | **Resolved.** The public-function inventory now names the previously grouped `u252` methods. | `docs/research/LIB-02-hexx-analysis.md:235-236`: “`U252CheckedAdd::checked_add` (`:320`)... `U252Zero`: `zero` (`:492`), `is_zero` (`:497`), `is_non_zero` (`:502`).” | None. |
| 2 | note | §5.9, §6, recommendation; earlier finding 2 | **Resolved.** Frozen occupancy, its stale-distance consequences, the alternative with fresh floods, and both costs are now explicit and consistent across the report. | `docs/research/LIB-02-hexx-analysis.md:627-629`: “One flood per tick, on frozen occupancy. The distance layers are computed once per tick on the occupancy frozen at the start of the tick.” `:761-763` carries that rule into L-M1. | None. |
| 3 | note | §5.8; earlier finding 3 | **Resolved.** The arc table now has all six entries in the game’s order. | `docs/research/LIB-02-hexx-analysis.md:595-598`: “front, front-side, rear-side, back, rear-side and front-side.” | None. |
| 4 | note | §1.10; earlier finding 4 | **Resolved.** Mesh families now cite individual files and public symbols. | `docs/research/LIB-02-hexx-analysis.md:147-152`: entries cite `src/mesh/mod.rs`, `column_builder.rs`, `plane_builder.rs`, `heightmap_builder.rs`, `uv_mapping.rs`, and `face.rs`. | None. |
| 5 | minor | §3.1 | “Default pointy layout” is incorrect: `hexx` defaults to flat orientation. The mapping itself is valid when pointy orientation is selected. | `docs/research/LIB-02-hexx-analysis.md:293-294`: “with `hexx`’s default pointy layout”. `sources/hexx/src/orientation.rs:127-129`: “`#[default]`” precedes “`Flat = 0x01`”. | Say “with a pointy `hexx` layout and y up.” |
| 6 | minor | Recommendation, “What stays out” | Saying `search_path_weighted` covers `a_star` overstates the API match. The former accepts up to three tile cost classes; the latter accepts an arbitrary cost for each directed step, including zero. | `docs/research/LIB-02-hexx-analysis.md:771`: “`a_star`, which `search_path_weighted` covers.” `sources/hexx/src/algorithms/pathfinding.rs:110`: “`cost: impl Fn(Hex, Hex) -> Option<u32>`”. `sources/origami/crates/hexmap/src/map.cairo:252-253`: “`costs[k]` is the bitmap of the tiles of cost `k + 2`, at most 3 items, the other walkable tiles cost 1”. | Qualify this as coverage of the game’s bounded, tile-cost pathfinding needs, not full `a_star` semantics. |

## Coverage

Reviewed AC-1–AC-8 against the supplied brief, revised report, excerpts, and listings. The versions match `sources/VERSIONS.md`; feature families, public facade functions, N-1–N-8 sections and table, options A–D, and the exact L-G1 heading are present. Estimates and inferences are generally marked. The orchestrator reports a one-file PR and green Markdown-link CI, satisfying the available checks for AC-7 and AC-8.

The repaired excerpts confirm that `line_to` performs a direct float lerp and round with no nudge. From `Hex::round`, `(0.5, 0.5)` first rounds to `(1, 1)`, then the `>=` branch adds `round(-0.75) = -1` to x, yielding `(0, 1)`. At `(-1.5, -1.5)`, it first rounds to `(-2, -2)`, then adds `round(0.75) = 1` to x, yielding `(-1, -2)`. The translated lines therefore choose different relative midpoint tiles.

The coordinate conversion also checks out: origami’s axial `q = x − floor(y/2), r = y` gives cube `s = −x − ceil(y/2)`. Using `(s, r)` as hexx axial coordinates makes pointy `Even` offset column `−x`, or `C − x` after translation. The supplied neighbour tables establish identical direction indices; hexx’s `(i + 1) % 6` rotation appears counter-clockwise on its default north-up axes. Origami’s local row-parity calculation confirms why an odd global window origin reverses diagonal neighbours, and 15-row chunks alternate their starting parity. The BFS internals are `pub(crate)`; the cave automaton internals are private. Sampled gas figures match `GAS.md` and `README.md`.

Parts 5, 6, 7, and the recommendation now use the same N-8 assumption and cost range. Options A–D receive a fair comparison for the game’s stated needs, subject to finding 6. The excerpts remain a sample; unprovided source code was not independently checked.