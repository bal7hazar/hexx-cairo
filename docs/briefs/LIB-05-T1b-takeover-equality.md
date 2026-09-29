# LIB-05 M1-T1b — Take-over of the engine: the proof of equality

## Agent

Title: `[Opus 5.5] LIB-05 M1-T1b take-over equality` · Profile: implement · Model: Opus 5.5
(the tests decide what "identical to 1.8.0" means for every later task). Audit:
`[GPT-6-Astra]`, determinism and parity.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill
only what you created, named exactly; temporary directories under your worktree.

## Goal

After this task the unpublished package `crates/takeover_tests` proves, in CI, that every
public function of the engine in `hexx` returns **the same value as the published
`origami_hexmap` 1.8.0 on the same inputs**, and panics with the same message where 1.8.0
panics. It is the second layer of the proof of §5.4 of
[the plan](../research/LIB-03-porting-plan.md): M1-T1a proved that the files are the same;
this task proves that what a consumer gets from the registry and what it gets from `hexx` are
the same. Every later task that touches the engine (N-1, N-7, N-8, the three renames) keeps
this package green.

## Context

- The plan, §5.1 (every public function of 1.8.0 and its destination), §5.4 (the three
  layers), **§14, which wins over the body**.
- `crates/takeover_tests/Scarb.toml` already depends on `origami_hexmap = "1.8.0"` from the
  registry and on `hexx` by path. The package is never published.
- The engine is in `crates/hexx/src/{board,finders,generators}` since M1-T1a. The three
  British-spelt helpers still have their names of 1.8.0.
- Depends on: M1-T1a (merged).

## Scope

**In**

1. **One equality test per public function of 1.8.0**, by module, in
   `crates/takeover_tests/src/` (one file per module of the engine: `map`, `direction`,
   `layout`, `geometry`, `asserter`, `bits`, `rng`, `bfs`, `dial`, `caver`, `digger`,
   `mazer`, `spreader`, `walker`). The list of functions is the table of §5.1 of the plan,
   checked against `docs/EXTENSIONS.md`; `HexPrinter` (test only) is out. Each test calls the
   function of `origami_hexmap` and the function of `hexx` on the same inputs and asserts
   equality of the whole result (the grid, the path as a span, the option, the tuple).

2. **The inputs**, fixed and written in the tests, never drawn at run time from anything but a
   seed written in the test:

   | Family | Inputs |
   |---|---|
   | Generators (`new_maze`, `new_cave`, `new_random_walk`, `new_hexagon`, `Caver`, `Digger`, `Mazer`, `Spreader`, `Walker`, `open_with_*`, `keep_component`, `compute_distribution`) | 64 seeds, on the dimensions `3x3`, `7x7`, `15x15`, `15x16`, `17x14`, `19x13`, `25x10`, `83x3`, `3x83`, where the function accepts them; every `order` the function accepts up to 5 |
   | Finders (`search_path`, `search_path_weighted`, `field_of_movement`, `distance_to`, `reachable`, `range`, `ring`, `Bfs`, `Dial`) | The fixtures of 1.8.0 (`CAVE_17X14`, `MAZE_17X14`, `SERPENTINE_17X14`, `UNREACHABLE_17X14` and their `7x7` forms), and 32 boards generated from written seeds, **among them `15x16`**, the size of the game's window |
   | Queries (`hex_distance`, `neighbor`, `is_walkable`, `Geometry`, `LayoutTrait`, `DirectionTrait`, `Asserter`) | Every position of a `7x7`, and 512 seeded positions of a `17x14` and of a `15x16`; every direction |
   | `Bits`, `Set`, `Rng`, the tables `POW`, `INV`, `POW128`, `PERMUTATIONS` | Every index of each table; the functions on 256 seeded values and on the boundary values (0, 1, `2^128 − 1`, `2^128`, `2^250`) |

   The fixtures of 1.8.0 are `#[cfg(test)]` items of its crate and are not visible from
   another package: copy their **values** into `crates/takeover_tests/src/fixtures.cairo`,
   with the file and line they come from.

3. **Panics**: for every panic listed in the README of 1.8.0 (§ *Panics*) and every `errors`
   constant of the engine, one test per side with `#[should_panic(expected: …)]` on the same
   input and the same message.

4. **Gas**: every test carries `#[available_gas(l2_gas: N)]`, `N = ceil(1.05 × measured)`;
   these are new tests, so the rule applies in full (they are not in the baseline).
   `gas/takeover_tests.snap` committed. A test that loops over many inputs states its bound.
   Report the total time of `snforge test -p takeover_tests`; the CI job must stay under 10
   minutes: if it does not, split the package's tests by module into several CI jobs
   (`.github/workflows/ci.yml` is in your allowlist for that only) and say so.

5. **A gas comparison, reported and not enforced**: for the 20 functions of the facade, on
   one input each, the gas of the call through `origami_hexmap` and through `hexx`
   (measured as a test that calls twice minus a test that calls once, as the game's spike
   SPK-7 does). They are expected equal; list every difference. This answers layer 3 of §5.4
   from the consumer's side.

**Out**

- Any change under `crates/hexx/`: if a test shows a difference, **you have found what this
  task exists to find**. Stop on it, do not fix the engine, and report the function, the
  input, both results.
- The extensions N-1 to N-8, the mirror, the three renames, the budgets of the inherited
  tests (M1-T1c).
- `scripts/**` except nothing: no script changes. `gas/takeover-baseline.txt` and
  `gas/takeover-tests.txt` are not touched.
- Any publication, tag or release.

**Allowlist** (files this task may write)

- `crates/takeover_tests/**`
- `gas/takeover_tests.snap`, `docs/GAS.md` (regenerated)
- `.github/workflows/ci.yml`, only to split the job of this package if its time requires it
- `Scarb.lock`, if the resolution changes
- `REPORT.md` (ignored by git)

## Acceptance criteria

- [ ] AC-1 Every public function of the table of §5.1 of the plan (except `u252`, dropped,
      and `HexPrinter`) has an equality test; the report gives the table function → test →
      number of inputs, and lists any function without a test, with its reason.
- [ ] AC-2 Every panic of the engine has its pair of tests, same input, same message.
- [ ] AC-3 `scripts/lock.sh snforge test -p takeover_tests` passes;
      `python3 scripts/bench.py check` passes with no test of this package in the baseline.
- [ ] AC-4 No file under `crates/hexx/` changed; `python3 scripts/takeover_check.py` still
      prints `same` for the 29 pairs.
- [ ] AC-5 `scripts/check.sh` passes; CI is green; every job under 10 minutes.
- [ ] AC-6 The gas comparison of Scope 5 is in the report, measured, with the commands.
- [ ] AC-7 Nothing outside the allowlist was written.

## What the auditor will check

`[GPT-6-Astra]` reads the tests in full: that each one really compares the two libraries
(not `hexx` with itself, not a constant with itself); that the inputs are fixed and cover
what the brief lists, the `15x16` window included; that no function of §5.1 is missing; that
the panic tests would fail if a message changed; that a deliberate change of one line of the
engine (the auditor names it) would be caught by at least one test of this package; the gas
comparison of Scope 5.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7. Under *Cost*: the number of tests, the time of
the package's tests locally and in CI, and the table of Scope 5.
