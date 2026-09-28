# LIB-05 M1-T1a — Take-over of the engine: the move

## Agent

Title: `[Sonnet 5.5] LIB-05 M1-T1a take-over move` · Profile: implement · Model: Sonnet 5.5
(a mechanical move with a mechanical proof). Audit: `[GPT-6-Sol]`.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything.

## Goal

After this task the package `hexx` contains the board engine of `origami_hexmap` 1.8.0,
moved into the module tree of the plan, **unchanged**: same code, same tests, same gas
budgets. Nothing is added, nothing is improved, nothing is renamed. The proof is mechanical:
a script shows that every moved file equals its source after a fixed list of rewrites.

This is the first half of task M1-T1 of [the plan](../research/LIB-03-porting-plan.md) (§5,
§8). The second half, M1-T1b, writes the equality tests against the published 1.8.0.

## Context

- The plan, §2.2 (module tree), §2.4 (root re-exports), §5.1 to §5.6 (the take-over), and
  **§14, which wins over the body**.
- The source, read-only in the worktree: `sources/origami/crates/hexmap/` at the commit of
  `sources/VERSIONS.md` (`04ab30c`, workspace version 1.8.0).
- Depends on: LIB-04 (merged).

## Scope

**In**

1. **The move**, file by file:

   | Source (`sources/origami/crates/hexmap/`) | Destination (`crates/hexx/`) |
   |---|---|
   | `src/map.cairo` | `src/board/map.cairo` |
   | `src/types/direction.cairo` | `src/board/direction.cairo` |
   | `src/helpers/{layout,geometry,asserter,bits,rng,printer}.cairo` | `src/board/{layout,geometry,asserter,bits,rng,printer}.cairo` |
   | `src/finders/{bfs,dial}.cairo` | `src/finders/{bfs,dial}.cairo` |
   | `src/generators/{caver,digger,mazer,spreader,walker}.cairo` | `src/generators/{caver,digger,mazer,spreader,walker}.cairo` |
   | `src/tests/*.cairo` except `bench_u252.cairo` | `src/tests/*.cairo` |
   | `tests/readme.cairo` minus `test_readme_u252` | `tests/readme.cairo` |
   | `GAS.md` | `crates/hexx/GAS-origami-1.8.0.md`, as the record of the measurements of 1.8.0 |
   | `.scarbignore` | `crates/hexx/.scarbignore`, adapted to the new paths |

   Not taken: `src/types/u252.cairo`, `src/tests/bench_u252.cairo`, `test_readme_u252`
   (the type lives in the package `uint252`), and the README of 1.8.0.

2. **The rewrites**, and nothing else. The complete list lives in one place,
   `scripts/takeover_check.py`, as data:
   - import paths: `origami_hexmap::helpers::X` → `hexx::board::X`,
     `origami_hexmap::types::direction` → `hexx::board::direction`,
     `origami_hexmap::map` → `hexx::board::map`, `origami_hexmap::` → `hexx::` for the rest;
   - what the removal of `u252` forces, if anything in a moved file names it: list each
     occurrence in the report with the line removed;
   - nothing else. **The three British-spelt helpers keep their names here**
     (`edge_neighbours`, `neighbour_in`, `neighbour_mask`): their renaming is another task.
   If a file cannot build with these rewrites alone, **stop on that file and escalate** in
   the report: do not edit it by hand.

3. **`scripts/takeover_check.py`**: for every pair of the table, applies the rewrites to the
   source and compares with the destination, byte for byte; prints each pair with `same` or
   the diff; exits non-zero on any difference, on a destination file without a source, and
   on a source file of the table without a destination. Subcommand `--source <path>` for the
   pinned checkout. Unit tests in `scripts/tests/`. It runs in `scripts/check.sh` and in CI
   when the source is available, and says so when it is skipped (CI has no checkout of
   origami: add a step that clones `dojoengine/origami` at the pinned commit, read-only).

4. **`crates/hexx/src/lib.cairo`**: the module declarations of the tree of the plan (flat
   declarations, `pub mod board;` with `src/board.cairo` declaring its children, or the
   directory form the parity tool supports: check with `python3 scripts/api_parity.py
   --extensions`), `#[cfg(test)]` for `printer` and `tests`, and the three root re-exports
   `HexMap`, `HexMapTrait`, `Direction`. The placeholder `mirrored_hexx_version` and its test
   are removed.

5. **Gas**: every moved test keeps its `#[available_gas]` **unchanged**. Run
   `python3 scripts/bench.py snapshot`, then `check`. A test whose measurement is above its
   budget, or more than 5 % below it, is **reported, not adjusted**: list it in the report
   with both figures. If `bench.py check` cannot pass without changing a budget, leave the
   budget, record the list, and escalate.

6. **`crates/consumer`**: one call site per public function of `HexMapTrait` (the 20 of the
   facade), so that the class-size fixture tracks the engine; `gas/bytecode.size` committed.

7. **Licence**: `LICENSE-origami` at the root with the MIT notice of `origami`; module
   headers kept; one sentence in `crates/hexx/README.md` (plan §5.6).

8. Generated documents regenerated: `docs/EXTENSIONS.md`, `docs/API_PARITY.md`,
   `docs/GAS.md`, `gas/*.snap`.

**Out**

- **Any change to the code moved**: no rename, no formatting beyond what `scarb fmt` of the
  pinned toolchain imposes (if it changes a moved file, report which and why; the check
  compares after formatting both sides), no fix of something that looks wrong.
- The equality tests of `crates/takeover_tests` (M1-T1b). The extensions N-1 to N-8. The
  mirror. The three renames.
- `scripts/api_parity.py`, `.github/workflows/release-check.yml`, `docs/RELEASING.md`:
  another task (LIB-04b) is fixing them at the same time. If the parity tool raises on a
  form of the engine, **escalate**, do not patch the tool.
- Any publication, tag or release.

**Allowlist** (files this task may write)

- `crates/hexx/**`, `crates/consumer/**`
- `scripts/takeover_check.py`, `scripts/tests/test_takeover_check.py`, `scripts/check.sh`
- `.github/workflows/ci.yml`
- `LICENSE-origami`
- `docs/EXTENSIONS.md`, `docs/API_PARITY.md`, `docs/GAS.md`, `gas/**`
- `Scarb.lock`
- `REPORT.md` (ignored by git)

If `main` moves while you work, merge `origin/main` into your branch and regenerate the
generated documents.

## Acceptance criteria

- [ ] AC-1 `python3 scripts/takeover_check.py --source sources/origami/crates/hexmap` prints
      `same` for every pair and exits 0. The list of rewrites in the script is the list of
      this brief, no more.
- [ ] AC-2 `scripts/lock.sh snforge test -p hexx` passes; the number of tests equals the
      number of tests of the source minus those of `u252`, and the report gives both counts
      and how they were counted.
- [ ] AC-3 No `#[available_gas]` differs from its source (the check of AC-1 proves it);
      `bench.py check` passes, or the report lists every test that prevents it, with figures.
- [ ] AC-4 `python3 scripts/api_parity.py --extensions --check` passes and
      `docs/EXTENSIONS.md` lists the 20 functions of `HexMapTrait` and the public items of
      every moved module.
- [ ] AC-5 `crates/hexx/Scarb.toml` still has no dependency but `snforge_std` under
      `[dev-dependencies]`; no `starknet` dependency, no Dojo dependency.
- [ ] AC-6 `scripts/check.sh` passes; CI is green and under 10 minutes. If the tests of the
      engine take longer, report the timing and propose the split; do not remove tests.
- [ ] AC-7 Nothing outside the allowlist was written.

## What the auditor will check

It will not read 22,000 moved lines: it reads `scripts/takeover_check.py` and its list of
rewrites, runs it against the pinned source, and reads in full only what the script does not
cover: `lib.cairo`, the manifests, `crates/consumer`, the CI change, the report. It checks
that no budget changed, that the test counts agree, that nothing of `u252` remains, and that
no dependency was added.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7. Under *Cost*: the number of tests, the total
time of `snforge test -p hexx`, and the list of tests whose measurement is not within 5 % of
its unchanged budget (expected: none, same toolchain as 1.8.0).
