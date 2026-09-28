# PENDING — Gate L-G1: is a port of `hexx` relevant, and where does it land?

| | |
|---|---|
| Asked by | `[Fable 5.1]` Orchestrateur hexmap (lib), 2026-09-28 |
| Decides | The owner |
| Based on | [LIB-02 report](../research/LIB-02-hexx-analysis.md) (`[Opus 5.5]`), audited by `[GPT-6-Sol]`: [pass 1](../audits/LIB-02-audit-gpt-6-sol-pass-1.md), [pass 2](../audits/LIB-02-audit-gpt-6-sol-pass-2.md) (PASS WITH FINDINGS, all fixed) |
| Blocks | LIB-03 (porting analysis), and through it L-M1, SPK-7 and ENG-05 of the game |
| State | **Open.** Nothing is launched until the answer |

## Question 1 — Is a port of `hexx` relevant?

What LIB-02 found:

| | |
|---|---|
| Most of `hexx` 0.25.0 has no place on-chain | Floating point (layout, angles, the line), meshes, Bevy and serde integrations, heap-allocated sets |
| `hexx` has none of the board-level needs | No bitmap board, no generator, no flood with layers, no rectangular chunks: N-1, N-2, N-3, N-4 and N-8 are absent from it |
| A small integer subset is useful | Directions and rotation (N-7), the line (N-5), range and ring as geometry (N-6), distance and neighbours |
| `origami_hexmap` 1.8.0 has the engine | Bit-parallel boards in one felt, gas budgets, oracles. It has the primitives of every need, and the finished function of none except distance and neighbours |

| Option | |
|---|---|
| **Partly** (recommended) | Carry the integer geometric subset of `hexx`, with its names and a parity table against `hexx` 0.25.0. Everything else of L-M1 is an extension, documented as such |
| Fully | Mirror every integer function of `hexx` (wedges, shapes, reflections, resolution, grid edges and vertices…). Nothing in the game asks for them |
| No | No `hexx` names, no parity table: the needs are written as plain additions |

**Recommendation: partly.** A full mirror can be reconsidered for a later milestone; it costs
nothing to defer.

## Question 2 — Where does the work land?

| | A. `hexx-cairo` on its own | B. `origami_hexmap` extended in place | C. Both | D. No library work |
|---|---|---|---|---|
| The game depends on | `hexx-cairo` **and** `origami_hexmap` | `origami_hexmap` only | Both, maybe one later | `origami_hexmap` 1.8.0 |
| Fit with N-1 to N-8 | Poor: 5 of 8 needs are board operations that `hexx` does not have and that need the engine of `origami_hexmap` | Good: the needs reuse its automaton, its flood layers, its masks and tables, which are private to that crate | As A for the mirror, as B for the rest | The hard algorithms are written outside the library that owns their internals |
| Parity table against `hexx` | Natural | Covers the `hexx`-named subset only | Complete | None |
| Existing users of `origami_hexmap` | Unaffected | Unaffected: additions only; existing results cannot change | Affected when the dependency flips | Unaffected |
| Releases | Own cadence, this repository | Through the `origami` workspace release | Two cadences, a dependency across organisations | None |
| Maintenance | Two libraries with overlapping geometry | One engine, one `GAS.md` | The most | Game-side code, no reuse |
| ADR-0006: "generation with margins is added to the map library by its author" | — | Matches | — | Contradicts it for N-1 |

**Recommendation: B**, with two conditions that I would put in the brief of LIB-03:

1. The `hexx`-named subset lives in **its own module** of `origami_hexmap`, so that `range`,
   `ring` and `distance_to` can keep the meaning of `hexx` there (geometry) without clashing
   with the facade, where walls block.
2. `bal7hazar/hexx-cairo` stays the home of the track: plan, research, decisions, and the
   off-chain harness that generates the parity vectors from `hexx` 0.25.0.

What would change my recommendation: if releases through the `origami` workspace cannot follow
the pace the game needs (pre-releases for SPK-7), option A or C becomes the way to keep a
cadence of our own, at the price of a second dependency and of making public the internals of
`origami_hexmap` that the new functions need.

## Question 3 — A dedicated package for `u252`? (raised by the owner on 2026-09-28)

| | |
|---|---|
| Today | `u252` is in `origami_hexmap` (`src/types/u252.cairo`, 810 lines), re-exported at the root. It imports the crate's bit helpers and tables (`helpers/bits.cairo`). The library's algorithms do not use it; the game does |
| Under B or D | One home, no duplication: **no extraction needed** |
| Under A or C | Both libraries need it: **extract it**, together with the bit helpers, into one package that both depend on by published version; `origami_hexmap` keeps re-exporting `u252` |
| Name, if extracted | Suggested: repository and package `u252`. Not `types-cairo`: `<name>-cairo` reads as a port of a Rust crate, and "types" invites a grab bag. Availability on scarbs.xyz not checked |

**Recommendation: follow question 2** (no under B). To decide otherwise if the owner's other
ports are expected to need a packed one-felt integer.

## Points for the game, found by LIB-02

They do not block L-G1. They must be answered before or during LIB-03, by the project manager
or the owner, since they are design questions of the game:

| # | Point | Why it matters |
|---|---|---|
| 1 | **Margins (N-1)**: the chunk's own outer ring copied from its neighbours, or the neighbours' tiles outside the chunk? | The second needs 17 × 17 = 289 bits and does not fit one felt |
| 2 | **Chunks on odd rows**: chunks are 15 rows high, so every other row of chunks starts on an odd global row | The library derives neighbours from local row parity: generation and seams of those chunks need a parity flag, or a chunk height that is even |
| 3 | **Global axis**: does `+x` point East? | The index of `origami_hexmap` has `+x` West |
| 4 | **Sight beyond the window**: the window re-centres only within 3 tiles of its edge, so sight of radius 6 and ranged lines can leave it | Interplay of ADR-0006 §4 and design/04 |
| 5 | **Flood and occupancy (N-8)**: one flood per tick on the occupancy frozen at the start of the tick, current occupancy only filtering each goblin's step? | The alternative costs up to 8 floods per tick (about 2.1–2.5M against 300–450k, estimates); moves are numeric API |
| 6 | **Line of sight**: `hexx` has no tie rule (float rounding decides, and the result changes under translation). The game's rule (lower tile index) is symmetric | It is a documented deviation from `hexx`, not a port of `line_to` |
| 7 | **"Clockwise"**: `hexx`'s `clockwise` turns counter-clockwise on a north-up map | Keep the name as-is and document it, or rename as a deviation |

## Answer

*To be filled by the project manager with the owner's decision and its date.*
