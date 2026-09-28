# LIB-03 — Porting plan of `hexx` to Cairo

## Agent

Title: `[Fable 5.1] LIB-03 porting plan` · Profile: research · Model: **Fable 5.1**. Why Fable:
the plan arbitrates an API between a Rust crate built on unbounded signed axial coordinates and
an engine built on bitmaps in one felt, under gas budgets, and what it freezes (names, numeric
results, generator streams) becomes API at the first release.

Inherits [COMMON.md](COMMON.md). Audit: `[GPT-6-Astra]` (a contested design decision).

## Goal

After this task the repository holds `docs/research/LIB-03-porting-plan.md`: the plan the owner
accepts or amends at gate L-G2, precise enough that LIB-04 (repository, CI, tooling) and LIB-05
(milestone L-M1) can be briefed from it without a new design step.

## Context

Decisions that bind the plan — read them first:

1. [L-G1](../decisions/L-G1-hexx-port.md), § *Answer*: `hexx` is the reference; **feature
   parity wherever it makes sense on-chain**; the scope is **extended** with what Cairo and
   the network require; the library lives in `bal7hazar/hexx-cairo`; the bitmap engine of
   `origami_hexmap` is taken over here; **`origami_hexmap` is decommissioned once the port is
   complete**; `u252` comes from the crate `u252` of `bal7hazar/types-cairo`.
2. The same file, § *Points for the game*: the project manager's answers (margins inside the
   chunk; parity flag, chunks stay 15 × 15; the library's axis convention is kept; one flood
   per tick on frozen occupancy; the game's tie rule for the line, a documented deviation;
   `hexx`'s names and semantics kept in the mirror). Point 4 (sight beyond the window) is
   open with the owner: plan for both outcomes where it matters.
3. [LIB-02](../research/LIB-02-hexx-analysis.md): the inventory of both libraries, the
   conventions compared, the needs N-1 to N-8. Its recommendation is superseded by L-G1; its
   facts stand. Do not redo its inventory: build on it, and correct it where you find it wrong.
4. [PLAN.md](../../PLAN.md): tasks, milestone L-M1, releases.

In the worktree, under `sources/` (read-only, ignored by git; versions in
`sources/VERSIONS.md`):

| Path | What |
|---|---|
| `sources/hexx/` | `hexx` at tag 0.25.0 |
| `sources/origami/crates/hexmap/` | `origami_hexmap` 1.8.0: `src/`, tests, `GAS.md`, `README.md` |
| `sources/grimworld/` | The game's documents at `origin/main`: `docs/CAIRO.md`, `PLAN.md`, `docs/needs/hexmap.md`, `docs/decisions/PENDING-L-G1.md`, ADR-0006, design 02, 04, 18 |
| `sources/house-style/glam-cairo/` | `AGENTS.md`, `docs/DESIGN.md`, `scripts/api_parity.py`, `scripts/deviations.py`, `scripts/gas_tables.py`, and the first 200 lines of `docs/API_PARITY.md`: how the owner's ports mirror a crate and generate their parity table |
| `sources/house-style/nalgebra-cairo/` | `docs/DESIGN.md`, `docs/PLAN.md`: the most recent port |

Depends on: LIB-02, gate L-G1.

## Scope

**In** — the plan, with these parts:

1. **Principles**: what "parity where it makes sense" means as a rule that can be applied
   function by function (ported as is / ported with an integer counterpart / excluded), and
   what qualifies as an extension.
2. **Package and module tree**: the Scarb package name for scarbs.xyz, the modules mirroring
   `hexx` (`hex`, `direction`, `conversions`, `bounds`, `shapes`, `algorithms`, `storage`,
   `layout`, `orientation`, `mesh`…, each kept, adapted or excluded), and the modules of the
   extensions (boards, finders, generators, assembly, line of sight…). Where the names of
   `origami_hexmap` and of `hexx` clash (`range`, `ring`, `distance_to`), which module owns
   which meaning.
3. **Types**: the coordinate type of the mirror (`Hex` with signed components: which integer
   type, at what cost, with what range), directions, the board and its index, the conversion
   between a `Hex` and a board index (LIB-02 §3.1), `u252`. One paragraph per choice, with
   the alternative rejected.
4. **The parity table**: every public item of `hexx` 0.25.0, grouped by module, with its
   status (port, integer counterpart, excluded + reason) and the milestone that delivers it.
   A generated table will replace it; here it is the plan's inventory. Say how the table is
   generated and checked in CI (from `rustdoc` JSON or from the source, against the Cairo
   source), how reference vectors are produced from `hexx` 0.25.0 off-chain, and how
   deviations (line ties) are recorded. Follow the house style unless you give a reason.
5. **The take-over of the engine of `origami_hexmap`**: what is taken as is, what is renamed
   to follow `hexx`, what changes visibility; how results are proved identical to 1.8.0
   (its tests and pinned streams brought over); licence and attribution (MIT).
6. **Extensions for Grim World**: for each of N-1 to N-8 plus distance and neighbours, the
   function signatures proposed, the module, the algorithm retained (arithmetic, bitwise,
   table or loop, with the reason), the oracle, the worst case to benchmark.
7. **Gas targets per function**: a target for every function of L-M1, each marked
   *measured* (from `GAS.md` of `origami_hexmap`) or *estimate*, and the class-size cost of
   every table proposed.
8. **Milestones**: L-M1 (what Grim World needs first, unchanged), then L-M2 and following
   up to parity; for each, its content, its dependencies, its exit criterion, a size
   estimate in tasks, and which tasks can run in parallel (allowlists that do not overlap).
9. **Release plan**: versions, pre-releases for the game's spike SPK-7, the dependency on
   the crate `u252` (not yet published: say what L-M1 does if it is late), what is API from
   which version, the changelog.
10. **Migration of the game and decommissioning of `origami_hexmap`**: the steps, the
    condition for each, what existing users of `origami_hexmap` are told, and the final state
    of the crate in `dojoengine/origami`.
11. **Risks and open questions**, each with who decides.
12. **"Recommendation for gate L-G2"** — a section with exactly this title: what the owner is
    asked to accept, in one page; the decisions the plan takes that the owner may want to
    reverse, each in one line with its alternative.

**Out**

- Any Cairo or Rust code, any `Scarb.toml`, CI, prototype or measurement. Signatures and
  short snippets inside the plan are fine.
- The briefs of LIB-04 and LIB-05: the orchestrator writes them from the plan.
- Reopening the decisions of L-G1. If you think one of them leads to a real problem, say so
  under *Risks*, with the evidence, and plan as decided.
- Anything under `sources/`, anything outside this repository.

**Allowlist** (files this task may write)

- `docs/research/LIB-03-porting-plan.md`
- `REPORT.md` at the worktree root (ignored by git)

You do not commit (profile `research`): the orchestrator commits the plan and opens the pull
request.

## Interfaces

None created. The plan proposes the public API of the library.

## Acceptance criteria

- [ ] AC-1 The plan states the versions and commits it relies on (`sources/VERSIONS.md`).
- [ ] AC-2 Every public module of `hexx` 0.25.0 has a status, and every public item within a
      kept module has a row in the parity inventory with status and milestone.
- [ ] AC-3 Every exclusion has a reason; every integer counterpart names the function it
      replaces.
- [ ] AC-4 Each of N-1 to N-8, distance and neighbours has signatures, a module, an
      algorithm, an oracle, a benchmark case and a gas target marked measured or estimate.
- [ ] AC-5 The plan honours each decision of L-G1 and each answer of the project manager,
      and says where (a table decision → section).
- [ ] AC-6 Every public function of `origami_hexmap` 1.8.0 (LIB-02 §2.1) has a destination:
      module and name in the new library, or dropped with a reason.
- [ ] AC-7 Milestones have exit criteria that can be demonstrated; L-M1 contains nothing the
      game does not need first, and lacks nothing it needs.
- [ ] AC-8 The section "Recommendation for gate L-G2" exists under that exact title.
- [ ] AC-9 Paths into `sources/` are written as code, not as Markdown links; every relative
      link resolves.

## Verification

```
git status --short        # only docs/research/LIB-03-porting-plan.md, untracked
```

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §6; under *Summary*, the recommendation for L-G2 in
five lines; under *Open questions*, what you need from the owner or the game.
