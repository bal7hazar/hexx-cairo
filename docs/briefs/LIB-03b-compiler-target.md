# LIB-03b — Compiler target of the library (need N-9)

## Agent

Title: `[Opus 5.5] LIB-03b compiler target` · Profile: **audit** (read, search, web, build and
test commands; no commit) · Model: Opus 5.5 (toolchain and debugging).

Inherits [COMMON.md](COMMON.md). A study beside [LIB-03](LIB-03-porting-plan.md): its findings
enter the porting plan and the pending file of gate L-G2. Asked by the project manager on
2026-09-28 (`bal7hazar/grimworld`, `docs/decisions/2026-09-28-N-9-compiler-target.md`).

## Goal

After this task the repository holds `docs/research/LIB-03b-compiler-target.md`: the facts the
owner needs to choose, at gate L-G2, **which Cairo compiler the library targets**, and one
recommendation.

## Context

The fact that opens the question (need N-9): the game cannot build `origami_hexmap` 1.8.0.
Dojo 1.8 pins the game to **Cairo 2.13.1** and `snforge_std` 0.51.2; the library asks
`starknet ^2.19.4`, declares `snforge_std` 0.61.0 as a regular dependency, and alone on Scarb
2.13.1 fails on `core::internal::bounded_int::BoundedInt is not visible` (`map.cairo`,
`helpers/bits.cairo`, `helpers/rng.cairo`). Decided by the project manager: the library must
build with the compiler of its first consumer, with `snforge_std` as a dev-dependency; N-9 is
part of milestone L-M1.

In the worktree, under `sources/` (read-only, ignored by git; versions in
`sources/VERSIONS.md`):

| Path | What |
|---|---|
| `sources/grimworld/` | `docs/needs/hexmap.md` (§ *N-9 in detail*), `docs/decisions/2026-09-28-N-9-compiler-target.md`, `docs/research/SPK-5-toolchain.md`, `docs/CAIRO.md`, `.tool-versions` |
| `sources/origami/crates/hexmap/` | `origami_hexmap` 1.8.0 |
| `sources/types-cairo/` | The package `uint252` 0.1.0 (`crates/u252`) |
| `sources/corelib-2.13.1/`, `sources/corelib-2.19.4/` | The core library of each compiler, as installed on the machine |

Both toolchains are installed (asdf): scarb 2.13.1 with starknet-foundry 0.51.2, and scarb
2.19.4 with starknet-foundry 0.61.0. A directory selects its versions with a `.tool-versions`
file; **never change the global versions** (`asdf set -u` and the like are forbidden).

## Scope

**In** — experiments in `work/` at the worktree root (ignored by git): copies of the sources
that you may edit freely to find what builds. They are evidence, not deliverables, and are
never committed. And the report, with these parts:

1. **The floor today.** For `origami_hexmap` 1.8.0 and for `uint252` 0.1.0, on Scarb 2.13.1:
   the full list of what fails (every error, by file and item), not only the first. Say which
   failures are the manifest (`starknet`, `snforge_std`, `cairo-version`, edition) and which
   are the language or the core library.
2. **What replaces `BoundedInt` on 2.13**: every use of `core::internal::bounded_int` in the
   engine, what it computes, and the alternatives that compile on 2.13.1 (the public integer
   API, `DivRem`, `u128_safe_divmod`, felt arithmetic with range checks, tables…). For each
   use: the replacement, and whether the **result** is identical for every input.
3. **The cost in gas**, measured: build the engine (a copy in `work/`) on 2.13.1 with the
   replacements, run its benchmarks there and on 2.19.4 unchanged, and give per function the
   gas on 2.19 with `BoundedInt`, on 2.19 with the replacement, and on 2.13 with the
   replacement. State exactly what was measured, with which command and tool versions. If a
   part cannot be made to build in the time of the task, say which, why, and what remains;
   do not estimate what you could measure.
4. **One code base or two**: can one source build on both 2.13 and 2.19 (same results, which
   gas on each); conditional compilation or features if any exist in Scarb for this; what a
   CI on both compilers looks like; what a consumer on each compiler gets from scarbs.xyz
   (how `cairo-version` and the `starknet` requirement of a published package are resolved).
5. **What it implies for `uint252`** (published at 0.1.0, extracted by another session): does
   it build on 2.13.1, what would have to change, and is that a new version of the package.
   You do not change it: you report.
6. **The alternative, priced**: the engine declared as **its own class**, compiled with the
   newer Cairo, called by the game's systems through a **library call**. Cost of one call and
   of serialising its arguments and results (boards are one felt; paths and layers are
   spans), measured if you can build a minimal pair of contracts, estimated and marked as
   such otherwise; what it does to unit tests (the game on 2.13 testing a class built on
   2.19), to the deployment, to versioning, and to the parity of the client's simulation.
   Where the owner's other programmes use this pattern, cite it if you can read it.
7. **Dojo's horizon**: what is published about a Dojo release on a newer Cairo (facts with
   their source and date; no speculation).
8. **"Recommendation for gate L-G2"** — a section with exactly this title: the compiler floor,
   or the separate class, or a combination; with the figures that decide, and what would
   change the recommendation.

**Out**

- Any change to a published package, to `dojoengine/origami`, to `bal7hazar/types-cairo`, to
  the game. Any code in this repository outside `work/`.
- The design of the library (LIB-03).
- Changing the machine's toolchain, installing anything.

**Allowlist** (files this task may write)

- `docs/research/LIB-03b-compiler-target.md`
- `work/**` (ignored by git), `REPORT.md` (ignored by git)

You do not commit: the orchestrator commits the report and opens the pull request.

## Acceptance criteria

- [ ] AC-1 Every figure says whether it is measured or estimated; a measured figure gives its
      command, its tool versions and the function benchmarked.
- [ ] AC-2 Every use of `bounded_int` in the engine is listed with its replacement and with
      the statement "result identical" or the inputs where it differs.
- [ ] AC-3 The report says, for `origami_hexmap` 1.8.0 and for `uint252` 0.1.0, whether a copy
      was made to **build** on 2.13.1 and whether its **tests pass** there, with the output.
- [ ] AC-4 The alternative of the separate class has a cost per call, measured or estimated.
- [ ] AC-5 The section "Recommendation for gate L-G2" exists under that exact title and gives
      one recommendation.
- [ ] AC-6 Nothing outside the allowlist was written; the global toolchain is unchanged
      (`asdf current` before and after, in the report).

## Verification

```
git status --short        # only docs/research/LIB-03b-compiler-target.md, untracked
asdf current              # unchanged
```

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §6, with the commands run and their real output.
