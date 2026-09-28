# LIB-02 — Analysis of `hexx` and of its intersection with `origami_hexmap`

## Agent

Title: `[Opus 5.5] LIB-02 hexx analysis` · Profile: research · Model: Opus 5.5 (design and
algorithms; nothing here needs Fable).

Inherits [COMMON.md](COMMON.md).

## Goal

After this task the repository holds one report, `docs/research/LIB-02-hexx-analysis.md`, that
lets the owner decide at gate L-G1 **whether a port of the Rust crate `hexx` to Cairo is
relevant for Grim World, and where that work should land**. It says what `hexx` offers, what
`origami_hexmap` 1.8.0 already covers, how the two differ in convention, what has no meaning
on-chain, and what each of the game's needs N-1 to N-8 would require.

## Context

Everything is in the worktree, under `sources/` (read-only clones, ignored by git):

| Path | What | Version |
|---|---|---|
| `sources/hexx/` | The Rust crate [`hexx`](https://github.com/ManevilleF/hexx) | Latest release, tag given in `sources/VERSIONS.md` |
| `sources/origami/crates/hexmap/` | `origami_hexmap`: `src/`, `tests/`, `GAS.md`, `README.md` | `main` of `dojoengine/origami`, workspace version 1.8.0, commit in `sources/VERSIONS.md` |
| `sources/grimworld/` | The game's documents, copied from its repository | Ref in `sources/VERSIONS.md` |

`sources/origami/crates/map` is the older square-grid library: **not the subject**.

Read in full, in this order, before the sources:

1. `sources/grimworld/docs/CAIRO.md`
2. `sources/grimworld/PLAN.md` § *Track LIB* and § *Milestone L-M1* (also in [PLAN.md](../../PLAN.md))
3. `sources/grimworld/docs/needs/hexmap.md`
4. `sources/grimworld/docs/architecture/ADR-0006-chunked-maps.md`
5. `sources/grimworld/docs/design/02-core-loop.md` § *Map*, § *Simulation budget*
6. `sources/grimworld/docs/design/04-combat.md` § *Ranges*, § *Facing and arcs*
7. `sources/grimworld/docs/design/18-rooms.md`

The house style of a port (mirror the crate, same names, deviations documented, generated
parity table) is shown by `glam-cairo`; you do not need to read it, the rules are in
[COMMON.md](COMMON.md) § *A port*.

Depends on: LIB-01 (merged).

## Scope

**In** — the report, with these parts:

1. **What `hexx` offers**, feature by feature, each with its module, main types and
   functions: coordinates (axial, cubic, offset, doubled, and conversions), directions
   (edge and vertex/diagonal), rotation and reflection, lines, rings, spirals, ranges,
   wedges, field of view, field of movement, pathfinding, layouts and orientation, chunks
   or wrapping (resolution, bounds wrapping), bounds, edges and vertices as grid objects,
   storage helpers, mesh and rendering helpers, optional features and integrations.
2. **What `origami_hexmap` 1.8.0 covers**, from its source **and its tests**: every public
   type and function, how it names things, its cost figures (`GAS.md`).
3. **Conventions compared**: coordinate system (offset rows with parity against axial),
   orientation (pointy or flat top), direction order and numbering, storage of a board as
   one felt and the bit index of a tile, `u252`, the single-limb path for boards of 128
   tiles or fewer, tie-breaks, the required wall ring at the edge of a board, signedness.
   State where `origami_hexmap` "already follows the names of `hexx`" and where it does not.
4. **What has no meaning on-chain**, and why (floating point, rendering, meshes, engine
   integrations, heap-allocated iterators of unbounded size, and whatever else you find).
   Say for each whether it is excluded outright or has an integer counterpart.
5. **The game's needs**: one section per need N-1 to N-8, plus "distance, neighbours", each
   answering: does `hexx` have it (where); does `origami_hexmap` have it (where); what a
   port would have to add or adapt. In particular:
   - N-1 generation of a board given its margins (smoothing with known neighbours' edges);
   - N-2 edges and openings between boards;
   - N-3 assembly of a 15 × 15 board from up to 4 chunks by shifts and masks, **row parity
     kept** (window origin on an even row): say what breaks with an odd origin and why;
   - N-4 cutting a board by a mask;
   - N-5 line of sight: the integer hex line; `hexx` interpolates in floating point, so
     state how its result can be reproduced exactly with integers, and how the game's
     tie-break ("when the line passes exactly between two tiles, the lower tile index is
     taken") compares with the nudge `hexx` uses;
   - N-6 range and ring as geometry, ignoring walls, as masks on a board;
   - N-7 directions, opposite, rotation by steps of 60°, the arc (front, front-side,
     rear-side, back) of a tile relative to a facing;
   - N-8 one flood from the adventurer giving every walker its next step, with extra
     obstacles (occupied tiles); compare with the existing shortest path and field of
     movement of `origami_hexmap`.
   End the part with **one table: need → `hexx` → `origami_hexmap` → work**.
6. **A first view of cost**: which algorithms fit the arithmetic-then-bitwise preference on
   a 15 × 15 board held in one felt (whole-board shifts, masks, bit-parallel floods), which
   look expensive (per-tile loops, signed arithmetic, divisions), and where a table of
   constants replaces computation. Figures from `GAS.md` where they exist; otherwise
   reasoned estimates, **marked as estimates**. No measurement is asked.
7. **Where the work should land, and under what name**. Assess at least these options, with
   the consequences for the game's dependency (by published version on scarbs.xyz), for the
   owner's port conventions (parity table against `hexx`), for existing users of
   `origami_hexmap`, and for maintenance:
   - A. `hexx-cairo`, a mirror of `hexx`, published on its own;
   - B. `origami_hexmap` extended in place, in `dojoengine/origami` (the owner has
     maintainer rights there);
   - C. both: a mirror published on scarbs.xyz on which `origami_hexmap` could later depend;
   - D. no port: the game writes its few helpers on top of `origami_hexmap`.
8. **"Recommendation for gate L-G1"** — a section with exactly this title: is a port
   relevant (yes, partly, no); where it lands; what milestone L-M1 would contain; what
   stays out; the main risks; what LIB-03 must settle. One recommendation, argued; the
   alternatives in one line each.

**Out**

- Any Cairo or Rust code, any `Scarb.toml`, any prototype or measurement. Short snippets
  inside the report to illustrate an algorithm are fine.
- The porting plan itself (milestones, API per milestone, gas targets): that is LIB-03.
- Changing anything under `sources/`, or anything outside this repository.
- `origami`'s other crates.

**Allowlist** (files this task may write)

- `docs/research/LIB-02-hexx-analysis.md`
- `REPORT.md` at the worktree root (ignored by git)

## Interfaces

None: the task produces a document.

## Acceptance criteria

- [ ] AC-1 The report states the exact versions and commits read (from `sources/VERSIONS.md`).
- [ ] AC-2 Every feature family of `hexx` listed in Scope 1 has an entry citing a file of
      `sources/hexx/`, or the statement that `hexx` does not have it.
- [ ] AC-3 Every public function of `origami_hexmap` appears in part 2, with its file.
- [ ] AC-4 Each of N-1 to N-8 has its own section and a row in the table
      need → `hexx` → `origami_hexmap` → work.
- [ ] AC-5 Every claim about a source cites a path (and a symbol or line); inferences and
      estimates are marked as such.
- [ ] AC-6 Options A to D are each assessed; the section "Recommendation for gate L-G1"
      exists under that exact title and gives one recommendation.
- [ ] AC-7 Every relative link in the report resolves (CI checks it); links to `sources/`
      are written as code paths, not as Markdown links, since `sources/` is not committed.
- [ ] AC-8 The pull request contains one file, the report; CI is green.

## Verification

```
git status --short                      # only docs/research/LIB-02-hexx-analysis.md
git diff --stat origin/main...HEAD      # one file
gh pr checks                            # green
```

## Report

`REPORT.md` at the worktree root, titled `[Opus 5.5] LIB-02 hexx analysis — report`: summary
in ten lines, what was read and what was not, the recommendation in three lines, deviations
from this brief, escalations, open questions for the orchestrator.

Pull request: branch `docs/lib-02-hexx-analysis`, title
`docs: [Opus 5.5] LIB-02 analysis of hexx and origami_hexmap`.
