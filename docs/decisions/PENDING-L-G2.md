# PENDING — Gate L-G2: is the porting plan accepted?

| | |
|---|---|
| Asked by | `[Fable 5.1]` Orchestrateur hexmap (lib), 2026-09-28 |
| Decides | The owner |
| Based on | [LIB-03, the porting plan](../research/LIB-03-porting-plan.md) (`[Fable 5.1]`), audited five times by `[GPT-6-Astra]` ([1](../audits/LIB-03-audit-gpt-6-astra-pass-1.md), [2](../audits/LIB-03-audit-gpt-6-astra-pass-2.md), [3](../audits/LIB-03-audit-gpt-6-astra-pass-3.md), [4](../audits/LIB-03-audit-gpt-6-astra-pass-4.md), [5](../audits/LIB-03-audit-gpt-6-astra-pass-5.md)) |
| Blocks | LIB-04 (repository, CI, tooling), LIB-05 (milestone L-M1), and through them the game's ENG-02 and ENG-05 |
| State | **Open.** No agent is running. Nothing is launched until the answer |

## Read this first

### 1. The tick is estimated at 1.34M to 1.67M gas, and nothing was measured

| | |
|---|---|
| Estimate | **1,337,678 to 1,672,098** for one tick in the plan's worst case (with the correction of §14 of the plan: 1,337,778 to 1,672,223) |
| First draft of the same plan | 740,000. **The estimate roughly doubled under audit, and may move again** |
| What it covers | The assembly of the 15 × 16 window from 4 chunks and two layers (about 99k), one flood of 25 layers on a cave (about 538k), and 8 goblins each choosing its step (about 88k each) |
| What it does not cover | Storage reads and writes, the game's own logic, any line of sight, a board more winding than the cave |
| Its conditions | Unit costs measured on `origami_hexmap` 1.8.0 (Scarb 2.19.4, snforge 0.61.0); the design sketches of the plan taken as the algorithms; a flood depth of 25 layers; 8 walkers scanning 15 layers each; upper bound = 1.25 × lower bound |
| **No figure of the plan is a budget** | Budgets are set from measurements, in LIB-05 and in the game's spike SPK-7. The game should plan on the upper bound |

### 2. The flood has no small bound: a question for the game

On a winding board a goblin can be 45 layers from the adventurer (a fixture of the plan);
the analytic bound on 15 × 16 is 182 layers. One layer costs about 19.3k (measured on 1.8.0).

| | Flood | A goblin beyond the limit |
|---|---|---|
| Flood to the end | 538k on the cave, 924k on the serpentine fixture | None: every reachable goblin has a distance |
| Truncate at 15 layers | At most 345k | Gets no move: **the game must say what it does** (waits, walks by straight distance, is frozen) |
| Truncate at 30 layers | At most 634k | Same |

This is a rule of the game and a numeric result of the tick, frozen at the first release. The
plan decides nothing. **To be answered by the game before 0.1.0** (plan, Q-5).

### 3. The plan is merged with four findings open

Five audit passes, four fix loops (one more than the rule allows, authorised by the project
manager: [LIB-03 fix loops](LIB-03-fix-loops.md)). The last pass is still a FAIL on one major
finding, which concerns milestone L-M2 only. The four open findings are listed in §14 of the
plan and carried into the briefs. The auditor states that LIB-04 and LIB-05 can start
correctly.

From the second fix loop the plan separates, for each function, a **normative contract**
(signature, domain, semantics against a scalar oracle, tie-breaks, worst case, 45 regression
cases) from a **design sketch** (masks, shifts, tables) that LIB-05 must prove against the
oracle and may replace. What the owner accepts at this gate is the contracts, the scope and
the order, not the sketches.

## What the owner is asked to accept

| | |
|---|---|
| Package | A Cairo package named **`hexx`**, in this repository, published on scarbs.xyz (the name was free on 2026-09-28) |
| Mirror | `hexx` 0.25.0 name for name on `Hex { x: i32, y: i32 }`, with a generated parity table checked in CI. Departures by category: floating point, host and allocator items absent; iterators become spans, callbacks become bitmaps; exact rational counterparts where `f32` has an exact meaning; overflow panics; `line_to` is the exact integer line with the game's tie rule |
| Extension | The engine of `origami_hexmap` 1.8.0 moved here unchanged, results proved identical by a test package that compares with the published 1.8.0; plus the ten functions of L-M1 |
| Compiler | Cairo 2.19 (Scarb 2.19.4, snforge 0.61); `snforge_std` as a dev-dependency, checked on the published package; no dependency on Dojo |
| `u252` | Not re-exported; L-M1 does not depend on `uint252`. The game takes the type from `uint252` directly |
| Milestones | **L-M1 = 0.1.0**: the game's needs N-1 to N-9 and the part of the mirror they rest on. **L-M2 = 0.2.0**: the mirror completed. **L-M3 = 0.3.0**: algorithms, `glam` interop, the table closed. **L-M4 = 1.0.0**: final release and decommissioning of `origami_hexmap` in four steps |

## Decisions of the plan that the owner may want to reverse

The full list is §12 of the plan (D-1 to D-32, each with its alternative). Those the
orchestrator thinks the owner should look at:

| # | Decision | Alternative | Note |
|---|---|---|---|
| D-1 | The package is named `hexx` | `hexx_cairo` | The name is what consumers write; it cannot change after the first release. R-4 proposes to reserve it by publishing an empty `0.0.1`: **needs the owner's go**, a publication cannot be undone |
| D-4 | Boards stay `felt252` in the API; no dependency on `uint252` in L-M1 | Boards typed `u252` from 0.1.0 | The owner created `uint252` so that the type is shared. The plan keeps `felt252` because the engine of 1.8.0 does, and changing every signature would break "results and API identical to 1.8.0" |
| D-5 | L-M1 carries only the mirror items its extensions depend on | Narrower (extensions only) or wider (the whole foundation of the mirror) | L-G1 says "L-M1 unchanged"; the mirror part was not in it |
| D-3 | Two direction types: `EdgeDirection` (mirror, `hexx` names) and `Direction` (board, compass names), same indices | One type | |
| D-6 | `Hex::line_to` carries the game's tie rule, a documented deviation | A separate `line_between`, `line_to` not ported | `hexx`'s own result depends on `f32` rounding and cannot be reproduced exactly |
| D-17 | `origami_hexmap` is removed from `origami` `main` at the end, kept on the registry and in a tag | Kept on `main` as deprecated | |

## Questions for the game, to be answered before 0.1.0

They do not block the gate. They go to the project manager.

| # | Question | Plan |
|---|---|---|
| Q-5 / D-25 | Does the tick truncate the flood, and what does a goblin beyond do? | Above, §2 |
| D-24 | Does a wall tile at the **end** of a line block sight? The plan proposes no: only the tiles strictly between are tested | §6.6 |
| D-22 | Ring tiles of a chunk that face no generated neighbour: drawn from the seed and frozen (plan), or wall until a neighbour exists? | §6.2 |
| D-23 | `cut` clears the ring as well as what is outside the mask | §6.5 |
| D-32 | A goblin next to an adventurer standing on an open edge tile may step onto that tile | §6.9 |
| Q-1 | Earshot (radius 8) reaches beyond the window: a distance test on global coordinates, without a board? | §11 |
| Q-4 | Does SPK-7 consume the release candidates, or stay on 1.8.0 until 0.1.0? | §11 |

## Options

| | Option | Consequence |
|---|---|---|
| **A** | **Accept the plan**, with or without reversing decisions of the list | LIB-04 is briefed and launched (`[Sonnet 5]`, audit `[GPT-6-Luna]`), then LIB-05 task by task. The briefs carry §14 of the plan and the rule that no figure is a budget |
| B | Accept the scope and the milestones, and ask for a measurement before L-M1 is committed: a spike that implements the assembly and the flood selection against their oracles and measures the tick | One task of a few days before LIB-05; the tick figure is then a measurement. The game's SPK-7 may already give it |
| C | Reject or amend: say what changes | LIB-03 is resumed with the amendments |

## Recommendation of the orchestrator

**A, with two conditions.**

1. **The first tasks of LIB-05 are the ones that decide the tick**: the assembly (N-3) and
   the flood with its selection (N-8), each proved against its oracle and measured on its
   worst cases, before the rest of L-M1. If a measurement exceeds the upper bound of its
   range, the orchestrator stops and reports before any budget is set. This gives what
   option B asks without a separate spike.
2. **The name `hexx` is reserved only on the owner's explicit go** (D-1, R-4).

Why not B: the contracts and oracles of the plan are what a spike would need anyway, and the
engine taken over is already measured; a spike would write N-3 and N-8 twice.

What would change the recommendation: if the game's budget for a tick is far below 1.3M, the
question is no longer the plan but the window and the flood themselves (the ADR's fallback of
sight 5, a truncated flood), and that is a decision of the game before L-M1 starts.

## Answer

*To be filled by the project manager with the owner's decision and its date.*
