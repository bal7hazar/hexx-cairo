# Plan — track LIB, the map library

Copied from `PLAN.md` § *Track LIB* of [`bal7hazar/grimworld`](https://github.com/bal7hazar/grimworld)
on 2026-09-28 and **owned here from now on**. The game's needs stay in the game's
`docs/needs/hexmap.md`; this file answers them.

| | |
|---|---|
| Repository | `bal7hazar/hexx-cairo`: the library lives here ([L-G1](docs/decisions/L-G1-hexx-port.md), owner, 2026-09-28) |
| Scope | **`hexx` is the reference**: feature parity wherever it makes sense on-chain, **extended** with the features tied to Cairo and to the network (bitmap boards, generation, floods, assembly). The engine of `origami_hexmap` is taken over here |
| `origami_hexmap` | **Decommissioned once the port is complete** |
| `u252` | From the package `uint252` (scarbs.xyz, 0.1.0 published on 2026-09-28; repository `bal7hazar/types-cairo`), by published version |
| Compiler | **Cairo 2.19** (Scarb 2.19.4, snforge 0.61), the compiler of the game since it dropped Dojo (its ADR-0007, 2026-09-28) and of the owner's other libraries. `BoundedInt` stays |
| Meanwhile | The game's spikes use `origami_hexmap` 1.8.0 on Cairo 2.19; the game then consumes this library by published version |
| Subject | `origami_hexmap` (`dojoengine/origami`, `crates/hexmap`) and the Rust crate [`hexx`](https://github.com/ManevilleF/hexx) |
| Rules | The game's `OPERATIONS.md` and `docs/CAIRO.md` in full: test-driven, gas budget on every test, execution cost first, arithmetic then bitwise then loops, `u252`, oracles |
| Convention | Mirror the Rust crate, same names, same API where it makes sense on-chain, deviations documented; a generated parity table checked in CI; numeric results are API |
| Interface with the game | Releases on scarbs.xyz and a changelog. The game never consumes a git revision |
| Budget | 1 agent at a time in wave 1 |

## Tasks

| ID | Task | Depends on | Executor | Audits | Status |
|---|---|---|---|---|---|
| LIB-01 | Repository setup: README, plan, status, folders, link check in CI | — | Orchestrator | — | done |
| LIB-02 | **Analysis of `hexx`** and of its intersection with `origami_hexmap`, against needs N-1 to N-8 and milestone L-M1. Brief: [LIB-02](docs/briefs/LIB-02-hexx-analysis.md). Report: `docs/research/LIB-02-hexx-analysis.md` | LIB-01 | Opus 5.5, research | GPT-6-Sol | **done** (2026-09-28, pull request #2) |
| **Gate L-G1** | **Is a port relevant, and where does it land?** | LIB-02 | Owner | — | **decided** 2026-09-28: [L-G1](docs/decisions/L-G1-hexx-port.md) |
| LIB-03 | **Porting plan**: module tree mirroring `hexx`, exclusions and integer counterparts, extensions, take-over of the engine of `origami_hexmap`, parity-table method, milestones with API and gas targets, release plan, migration of the game, decommissioning. First milestone = L-M1. Brief: [LIB-03](docs/briefs/LIB-03-porting-plan.md) | L-G1 | Fable 5.1, research | GPT-6-Astra | **done** (2026-09-28, pull request #9); open points in §14 of the plan |
| LIB-03b | ~~Compiler target (need N-9)~~: **cancelled** before launch, the game dropped Dojo and is on Cairo 2.19 (its ADR-0007). Brief kept: [LIB-03b](docs/briefs/LIB-03b-compiler-target.md) | — | — | — | cancelled |
| **Gate L-G2** | **Is the plan accepted?** Owner's decision | LIB-03 | Owner | — | **decided** 2026-09-28: accepted. [L-G2](docs/decisions/L-G2-porting-plan.md) |
| LIB-04 | Workspace, CI, parity table, gas tooling, reference generator, release check (no workflow publishes). Brief: [LIB-04](docs/briefs/LIB-04-repository-tooling.md) | L-G2 | Sonnet 5, implement | GPT-6-Sol, four passes | **done** (2026-09-28, pull request #18), merged with three findings open by [decision](docs/decisions/LIB-04-fix-loops.md) |
| LIB-04b | The three findings left open by the audit of LIB-04 (re-exports in chain and under two names; hyphen in build metadata; list of missing items of a pre-release). Brief: [LIB-04b](docs/briefs/LIB-04b-tooling-findings.md). **Condition of the first publication** | LIB-04 | Sonnet 5.5, implement | GPT-6-Sol, limited | **done** (2026-09-29, pull request #26); audit PASS, no finding. The condition of the first publication is met |
| LIB-04c | CI under 10 minutes again: `bench.py check --partition`, a completeness job, `hexx` tests and gas in three partitions (`Gas hexx` took 9 min 4 s on `main` at `295ff3d`, before M1-T6's oracles). Brief: [LIB-04c](docs/briefs/LIB-04c-ci-partitions.md) | M1-T6 (it runs after, on the one slot of the track) | Sonnet 5.5, implement | Codex review | **done** (2026-10-01, pull request #58): `hexx` tests in 5 partitions, regular gas in 4, ignored gas in 2, two completeness jobs; slowest job 5 m 43 s; Codex review two passes (one finding: the report archived) |
| LIB-04d | The gas gate accepts the exact second observed build of a row (D-164 extended by the project manager, 2026-10-01): `gas/takeover_tests.builds`. Brief: [LIB-04d](docs/briefs/LIB-04d-gas-builds.md) | LIB-04c | Sonnet 5.5, implement | Codex review (or its fallback) | **done** (2026-10-01, pull request #76); review PASS (Opus, fallback) |
| LIB-04e | One build: `RAYON_NUM_THREADS=1` on every measured or declared build (D-154's cause found by the game's SPK-13; the project manager's D-176 of 2026-10-01), both `.builds` files dropped, snapshots re-taken, a determinism check in CI. Brief: [LIB-04e](docs/briefs/LIB-04e-single-thread-builds.md) | LIB-04d | Sonnet 5.5, implement | review (Codex or its fallback) | next |
| LIB-05 | **Milestone L-M1**: the 11 tasks of §8 of the plan, test-driven, at minimal cost. After the take-over, **N-3 (assembly) and N-8 (flood and selection) first**, measured on their worst cases. **Released on scarbs.xyz only on the owner's go** | LIB-04 | Opus 5.5, Fable 5.1 for the hardest algorithms | GPT-6-Astra (determinism, cost) | in progress: tasks below |
| LIB-06 | Milestones L-M2 and following, each ending with a release | LIB-05 | As above | As above | todo |
| LIB-07 | **Final release**: parity reached or exclusions closed and documented; **`origami_hexmap` decommissioned** | LIB-06 | — | GPT-6-Astra | todo |

## LIB-05 — the tasks of milestone L-M1

Cut from the 11 tasks of §8 of [the plan](docs/research/LIB-03-porting-plan.md) so that one
audit pass can read a lot in full: one function of L-M1, with its oracle and its benchmarks,
per task; each brief states what the auditor will check. Order: the take-over, then what the
assembly and the flood need, **N-3 and N-8 first among the extensions** (condition of gate
L-G2), then the rest. A measurement above the upper bound of its range stops the track until
it is reported.

| Task | Content | Plan | Runs after | Executor | Audit | Status |
|---|---|---|---|---|---|---|
| M1-T1a | Take-over, the move: the engine of `origami_hexmap` 1.8.0 under `board`, `finders`, `generators`, unchanged, proved by a script. Brief: [M1-T1a](docs/briefs/LIB-05-T1a-takeover-move.md) | §5, M1-T1 | LIB-04 | Sonnet 5.5 | GPT-6-Sol | **done** (2026-09-29, pull request #28); two audit passes, PASS WITH FINDINGS; minors deferred to M1-T1c |
| M1-T1c | **The gas gate**: one gas job per package; the drift instrumented (raw output and artefact hashes kept, `Digger` tests run twice); the 702 inherited budgets made conformant and the baseline removed. Brief: [M1-T1c](docs/briefs/LIB-05-T1c-gas-gate.md) | §5.4 | M1-T1b | Sonnet 5.5 | GPT-6-Sol | **done** (2026-09-29, pull request #37); two audit passes by GPT-6-Sol, PASS WITH FINDINGS (one minor, fixed before merge) |
| M1-T1b | Take-over, the proof: `crates/takeover_tests`, equality against the published 1.8.0, function by function, panics included. Brief: [M1-T1b](docs/briefs/LIB-05-T1b-takeover-equality.md) | §5.4, M1-T1 | M1-T1a | Opus 5.5 | GPT-6-Astra (determinism) | **done** (2026-09-29, pull request #34); three audit passes by GPT-6-Astra, PASS WITH FINDINGS (one minor, documentation) |
| M1-T4a | **N-3**: band tables, `origin`, `local`, `assemble`, `window`; **void chunks assembled as wall without a read, the window never clamped (D-134)**; oracle; bench of 4 chunks and two layers | §6.4, M1-T4 | M1-T1c | Opus 5.5 | GPT-6-Astra (cost) | **done** (2026-09-29, pull request #39): `window` 64,234 (SPK-7: 65,224; plan range 98,762 to 123,453); audit PASS WITH FINDINGS |
| M1-T4b | Brief: [M1-T4b](docs/briefs/LIB-05-T4b-cut.md). N-4: `cut` as `grid & mask` (§14 of the plan); and the exhaustive sweep of `local` deferred from M1-T4a | §6.5, M1-T4 | M1-T4a | Sonnet 5.5 | GPT-6-Sol | **done** (2026-09-30, pull request #46): `cut` = `grid & mask`, 10,122 L2 gas; audit PASS, Codex review PASS |
| M1-T2 | Mirror items of L-M1 except `line_to`: `Hex`, `EdgeDirection`, offset conversions, `HexOrientation`; reference vectors. Brief: [M1-T2](docs/briefs/LIB-05-T2-mirror.md) | §8, M1-T2 | M1-T1a | Sonnet 5.5 (the quota of the sub-agents' account; vectors from the crate as oracle) | GPT-6-Astra (parity) | **done** (2026-09-30, pull request #49); audit two passes, Codex review two passes (one finding dismissed) |
| M1-T3 | N-7 and the board's coordinates: `rotate`, `arc`, `Arc`, the conversions with `EdgeDirection`; `distance_between`, `chunk_of`, `neighbor_direction`; `to_hex`, `from_hex`, `index_to_hex`, `hex_to_index`; the three renames; tests in their modules (D-167). `new_odd` deferred to N-1 and N-2 (SPK-14). Brief: [M1-T3](docs/briefs/LIB-05-T3-directions.md) | §6.1, §6.8, §3.5 | M1-T2 | Opus 5.5 | GPT-6-Astra (determinism) | **done** (2026-09-30, pull request #54); one stop on the gas condition, decided in its brief; audit (GPT-6-Sol, `--model` omitted) and Codex review: PASS, PASS |
| M1-T9a | **N-8**: `Bfs::flood`, `Flood`, `depth`; the serpentine fixture; benches at 10, 15, 20 layers and without a limit (D-127). Brief: [M1-T9a](docs/briefs/LIB-05-T9a-flood.md) | §6.9, M1-T9 | M1-T4a (condition of L-G2: N-3 and N-8 first; the three renames of M1-T3 come after and update its calls) | Opus 5.5 | GPT-6-Astra (cost) | **done** (2026-09-29, pull request #41): serpentine at 15 layers 364,878 (SPK-7: 456,160), 22,746 per layer; audit PASS WITH FINDINGS |
| M1-T9b | **N-8**: `next_step`, `next_step_away`, `distance`, their oracles; the bench of the tick with the window of M1-T4a. Brief: [M1-T9b](docs/briefs/LIB-05-T9b-steps.md) | §6.9, M1-T9 | M1-T9a, M1-T4a | Opus 5.5 | GPT-6-Astra (cost) | **done** (2026-09-29, pull request #43): the tick at 1,064,209 (cave) to 1,106,666 (serpentine); audit PASS after two fix loops |
| M1-T6 | N-5: `line_to`, `line`, `line_of_sight`, `approach`; the exhaustive comparison with `hexx`. Brief: [M1-T6](docs/briefs/LIB-05-T6-line.md) | §6.6, M1-T6 | M1-T3 | Opus 5.5 | GPT-6-Astra | **done** (2026-10-01, pull request #57); one stop on the table figure of `line`, decided in its brief; audit GPT-6-Astra PASS WITH FINDINGS (one minor, fixed by the orchestrator), Codex review PASS |
| M1-T5 | N-6: `hexagon`, `hexagon_ring`, tables. Brief: [M1-T5](docs/briefs/LIB-05-T5-hexagon.md); moved before M1-T7 and M1-T8, which wait for SPK-14 (orchestrator, 2026-10-01) | §6.7, M1-T5 | M1-T4a | Opus 5.5 | GPT-6-Astra | done, pull request #65 green; review PASS WITH FINDINGS (Fable), fix loop 1 running; **audit waits for Codex** |
| M1-T7 | N-2: sides and openings, **never on a corner (D-134)**; the four seam formulas, the oracle on global coordinates; `new_odd` (deferred from M1-T3). Chunks stay 15 × 15: D-165 closed by the owner on 2026-10-01. Brief: [M1-T7](docs/briefs/LIB-05-T7-seams.md) | §6.3, M1-T7 | M1-T3 | Opus 5.5 | GPT-6-Astra | done, pull request #74 green; review fixes applied (fix loop 1); **audit waits for Codex** |
| M1-T8 | N-1: `generate_with_margins`, `smooth`; planes and masks; pinned streams; **the four corners of a chunk always wall (D-134)**. Brief: [M1-T8](docs/briefs/LIB-05-T8-margins.md); starts after M1-T7 is merged (`new_odd`) | §6.2, M1-T8 | M1-T3 | Fable 5.1 or Opus 5.5 | GPT-6-Astra | next, after M1-T7 is merged |
| M1-N9 | N-9: consumer check against the published package; the cause of 1.8.0's defect. Brief: [M1-N9](docs/briefs/LIB-05-N9-consumer-check.md) | §8, M1-N9 | first release candidate | Sonnet 5.5 | GPT-6-Sol | **done** (2026-10-01, pull request #70; follow-up #72); reviews three passes (Opus, Fable); quality audit waits for Codex |
| M1-R | Release 0.1.0 and its candidates: asked by a pending file, published by the orchestrator's session after a go (game's `OPERATIONS.md` §7). LIB-04b is merged | §9, M1-R | all | Orchestrator | — | todo |

## Milestone L-M1 — what the game needs first

| Need | # | For | Source (game repository) |
|---|---|---|---|
| Generation of a board **given its margins** | N-1 | Chunks that join without seams | ADR-0006 |
| Edges and openings between boards | N-2 | Reachability of all chunks; emerging outlines | ADR-0006 |
| **Assembly of a board of 15 columns × 16 rows from 2 or 4 chunks of 15 × 15**, at each tick (the window is not stored), without a loop over rows; the origin on an even global row is an explicit constraint and an odd origin is refused | N-3 | The simulation window (D-120) | ADR-0006 §4, `docs/needs/hexmap.md` § *N-3 in detail*; [check](docs/research/window-parity-check.md) |
| Cutting a board by a mask | N-4 | Zone outlines | ADR-0006 |
| **Line of sight** between two tiles; takes the local position or the row parity as input (the adventurer is on local `(7, 7)` or `(7, 8)`) | N-5 | Ranged attacks, spells, goblin perception | design/04 |
| Range and ring as **geometry**, ignoring walls; same input | N-6 | Sight of radius 6, areas of effect | design/04, ADR-0006 |
| Directions, opposite, rotation by steps of 60°; the arc of a tile relative to a facing | N-7 | Facing, flank, back | design/04 |
| One flood giving every goblin its next step, on a board with extra obstacles | N-8 | The tick | design/02 |
| Distance, neighbours | — | Everywhere | — |
| `snforge_std` declared as a **dev-dependency**; nothing in the library depends on Dojo; tests and examples use snforge only | N-9 (reduced) | The library resolves next to any test setup of its consumer, which is a set of plain Starknet contracts | `docs/needs/hexmap.md`, ADR-0007 of the game |

The parity flag of the layout serves generation and seams of the chunks that start on an odd
global row (N-1, N-2) only; the window does not use it. Fallback if the game's spike SPK-7
asks for it: sight 5 on a window of 13 × 14, a later option, not designed now.

What is already in `origami_hexmap` (shortest path, weighted path, field of movement, range
and ring by movement, generators, distribution) is checked against these needs by LIB-02, not
assumed.

## Releases

| Version | Content | Consumed by the game at |
|---|---|---|
| Intermediate, one per milestone | L-M1 first | SPK-7 uses a pre-release of L-M1; ENG-05 needs its release |
| Final | Parity or documented exclusions | Version 1 of the game |

Generator outputs are API: a change in what a seed produces is a minor version and moves the
game's test vectors.
