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
| LIB-04 | Workspace, CI, parity table, gas tooling, reference generator, publication pipeline rehearsed and not run. Brief: [LIB-04](docs/briefs/LIB-04-repository-tooling.md) | L-G2 | Sonnet 5, implement | GPT-6-Sol (security of the workflows and quality: a stronger model than the GPT-6-Luna first planned) | **escalated** after three fix loops: [pending](docs/decisions/PENDING-LIB-04-fix-loops.md); pull request #18 open |
| LIB-05 | **Milestone L-M1**: the 11 tasks of §8 of the plan, test-driven, at minimal cost. After the take-over, **N-3 (assembly) and N-8 (flood and selection) first**, measured on their worst cases. **Released on scarbs.xyz only on the owner's go** | LIB-04 | Opus 5.5, Fable 5.1 for the hardest algorithms | GPT-6-Astra (determinism, cost) | todo |
| LIB-06 | Milestones L-M2 and following, each ending with a release | LIB-05 | As above | As above | todo |
| LIB-07 | **Final release**: parity reached or exclusions closed and documented; **`origami_hexmap` decommissioned** | LIB-06 | — | GPT-6-Astra | todo |

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
