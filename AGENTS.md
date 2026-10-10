# AGENTS.md — canonical agent instructions

## Mission

Port [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 to Cairo at feature parity wherever
that makes sense on-chain, extended with what Cairo and Starknet require beyond it: a bitmap
board engine (boards in one `felt252`, generation, floods, assembly), taken over from
[`origami_hexmap`](https://github.com/dojoengine/origami/tree/main/crates/hexmap) 1.8.0. The
library is the map layer of **Grim World** (`bal7hazar/grimworld`), an on-chain game; the game
consumes this repository by published version, never by git revision.

Read [`docs/research/LIB-03-porting-plan.md`](docs/research/LIB-03-porting-plan.md) (the plan)
before writing any code, and its §14 first: "the plan may be wrong" and §14 wins over the body.
Every function's contract (signature, domain, semantics, tie-breaks, oracle, worst case,
regression cases) is normative; its design sketch is not — prove the sketch against the oracle
over the whole stated domain before keeping any optimisation, and may replace it (plan §1.4).

## Repository map

| Path | Content |
|---|---|
| `crates/hexx` | the `hexx` port: published. One module per `hexx` source file, same names (plan §2.2) |
| `crates/takeover_tests` | unpublished: equality tests of `board` against the published `origami_hexmap` 1.8.0 it takes over (`origami_hexmap` dependency, plan §5.4) |
| `crates/golden_*` | unpublished: the golden tests of `tools/refgen` (`tests/golden_<module>.cairo`), one test target per package, `hexx` by path (see *Golden tests* below) |
| `crates/consumer` | unpublished: a minimal Starknet contract fixture, class size tracked in `gas/bytecode.size` |
| `gas/*.snap` | committed gas snapshots, one file per package (`scripts/bench.py`) |
| `gas/bytecode.size` | committed class-size snapshot of `crates/consumer` (`scripts/bytecode_size.py`) |
| `tools/refgen` | Rust, depends on `hexx = "=0.25.0"`: golden Cairo vectors from the real crate (plan §4.3, `tools/refgen/README.md`) |
| `scripts/` | `api_parity.py`, `deviations.py`, `bench.py`, `gas_tables.py`, `bytecode_size.py`, `check.sh` — the full local gate; `scripts/tests/` are their own unit tests |
| `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md` | generated; never hand-edited (regenerate, do not patch) |
| `docs/research/LIB-03-porting-plan.md` | the plan: module tree, types, the take-over, extensions, gas targets, releases |
| `docs/decisions/` | the owner's decisions (`L-G1`, `L-G2`, ...) |
| `docs/briefs/COMMON.md` | the rules every task brief inherits: one worktree per task, evidence, the report format |
| `PLAN.md`, `STATUS.md` | track LIB: tasks, gates, milestone state — owned by the orchestrator |

## Commands

| Task | Command |
|---|---|
| Full local gate (CI runs it on every pull request) | `scripts/check.sh` |
| Format | `scarb fmt --check --workspace` |
| Build / test one package | `scarb build -p hexx` (the build only); `snforge test -p <package>` for the other packages. The test targets of `hexx` are CI-only on the VPS (D-212, *Gas pins from CI*) |
| Parity table (`docs/API_PARITY.md`, `docs/EXTENSIONS.md`) | `python3 scripts/api_parity.py --check`; `--refresh --hexx /path/to/hexx` to regenerate the embedded `hexx` inventory from a pinned checkout; `--extensions` for `docs/EXTENSIONS.md` |
| Deviations (`docs/DEVIATIONS.md`) | `python3 scripts/deviations.py --check` |
| Gas budgets and snapshots | `python3 scripts/bench.py check`; `snapshot` to rewrite `gas/*.snap` after a deliberate change |
| README gas table (`docs/GAS.md`) | `python3 scripts/gas_tables.py --check` |
| Class size of `crates/consumer` | `python3 scripts/bytecode_size.py check`; `snapshot` to rewrite `gas/bytecode.size` |
| Golden vectors from `hexx` 0.25.0 | `cd tools/refgen && cargo run -- gen <module>` / `-- check` |
| Heavy commands (build, test) | Through the build lock, `scripts/lock.sh scarb build`, `scripts/lock.sh snforge test <filter>` (`COMMON.md` §3) |

Toolchain versions live in `.tool-versions` only (Scarb 2.20.1, starknet-foundry 0.64.0).

### Golden tests

Scarb compiles every file under a package's `tests/` into one target, whose peak memory follows its
line count (LIB-04h, measured on the VPS, single-threaded, capped at 8 GB: 3,241 lines 1.6 GB,
5,119 lines 2.0 GB, 11,156 lines 5.0 GB, 13,765 lines 6.0 GB). So the golden files live in the
unpublished packages `crates/golden_*`, never in `crates/hexx/tests/` (`scripts/takeover_check.py`
rejects one there): `golden_hex` (hex), `golden_impls` (impls), `golden_lm1` (conversions,
direction, line; closed), `golden_lm2` (euclidean, swizzle, convert), `golden_hex_t2` (the M2-T2 vectors of `hex`).
Budget: the `tests/` of a package holds at most 8,000 lines, for a peak under ~4 GB; one generated file above that takes a
package of its own and never exceeds 14,000 lines (split its generator's output first). A new
golden file goes into `golden_lm2` while its total stays within 8,000 lines (room for about 4,700
lines of M2-T4 to M2-T7), else into a new package `crates/golden_<module>`. Its spec's
`package` names the package (`tools/refgen`). A new package is added to the root `Scarb.toml`,
the `test` and `gas` matrices of `.github/workflows/ci.yml`, `gas/<package>.snap` and the
package-list test of `scripts/tests/test_bench_gate_split.py`, in the same change. A new build is
measured under `prlimit --as=8589934592` only (8 GiB, a runaway stopper: if that run aborts, measure on the Mac), never uncapped.
The packages already measured have their caps in the table of *How tests are scoped* (`golden_lm2` 9 GiB, `golden_lm1` and `golden_impls` 12 GiB, `golden_hex` 14 GiB).

### Gas pins from CI

The unit and integration test targets of `hexx` (`scarb build --test -p hexx`, `snforge test -p hexx`)
are built only by CI, and by the Mac when it is offered and its billing allowed; VPS threads never
build them (the target needs more than the VPS's ~8 GB, and fails there under the cap), so the pins
of `hexx` (`gas/hexx.snap`, its budgets) come from CI's Linux run (LIB-04i), never from a local build.
D-212 (project manager, 2026-10-05): D-167 stays, tests live beside the code, and rule (c) of LIB-04i
is permanent for `hexx`; VPS threads keep the in-module tests. Measured need (Mac, uncapped,
single-threaded, 2026-10-05): 9,471,639,552 B peak RSS (8.82 GiB) at `a045239` (hexx 0.2.0),
8,301,543,424 B at `v0.1.0-rc.2`. What would reverse it: the measured need falling well under 8 GB,
or a task that cannot proceed without a local `hexx` test build (then a cfg split of the tests goes
to the project manager). Every CI run that
measures gas publishes the artefact `gas-pins-<head sha>` (job `Gas completeness hexx regular`),
even when the gas check failed: the regenerated `gas/*.snap` of every package measured completely,
`gas/bytecode.size`, `budgets.json` (each test whose `#[available_gas(l2_gas: N)]` is missing or
outside the rule, with `ceil(1.05 × measured)`) and `manifest.json` (head, merge commit and base
measured; packages not assembled; tests that failed or ran with no measurement). Push the change with no
budget on a new test (or a generous one: a budget too low fails the test before it is measured),
then `gh run download <run-id> -n gas-pins-<head sha> -D <scratch dir>`, `python3 scripts/bench.py
apply-pins <scratch dir>` (writes `gas/` and the budgets; prints those of the generated
`crates/golden_*` files for the spec of `tools/refgen`, and exits 1 on anything left to do),
`python3 scripts/gas_tables.py`, `scarb fmt --workspace`, commit and push: CI then confirms. The
figures are of the merge of the head into the base named in the manifest: `apply-pins` refuses
pins of another head than `HEAD`, and prints a `WARNING` line when that base is not `origin/main`;
read it, and on a stale base re-run CI on the head before applying.

## How tests are scoped

A thread runs locally only the tests of the parts it touched, never the whole suite at every step.
The whole suite is CI's on the pull request, gated by changed paths (`scripts/ci_changes.py`).
Peaks are the ones recorded in this file ("Golden tests", "Gas pins from CI"); any other part is
**measure first**. `prlimit --as` is a runaway stopper, not a measure: address space exceeds resident
memory (a real peak of 7.3 GB aborted under `--as=8 GiB`). So:

1. Every build or test run's peak is measured first: on the Mac, or on the VPS under
   `prlimit --as=8589934592 -- /usr/bin/time -v …` (8 GiB) while the peak is unknown. If that capped
   run aborts, the peak is measured on the Mac. Never measure an unknown peak on the VPS under a
   16 GiB cap, nor uncapped.
2. The peak that sizes a `prlimit --as` cap is the run's VmPeak (address space): `grep VmPeak
   /proc/<pid>/status` during the run. It is not "Maximum resident set size", which is RSS. RSS decides
   where the run goes (rule 3). A run whose RSS is under about 8 GB may run on the VPS under `prlimit --as`
   set to 1.5 × its VmPeak, rounded up to whole GiB, never below 8 GiB (8589934592) and at most 16 GiB
   (17179869184); below 8 GiB zstd fails to allocate (`scarb package -p hexx` aborted at 2 GiB, passed at 8 GiB).
3. A run whose RSS is above about 8 GB runs on the Mac, never on the VPS.
4. A capped run that makes no progress for 15 minutes is stopped by its own pid and moved: to the Mac, or
   under a cap from its VmPeak. It is never left holding the heavy lock.
5. A part with a known peak below has its cap next to it (1.5 × VmPeak, rounded up to whole GiB, never below 8 GiB).

Rules 2 to 4: D-251 (2026-10-10), the organisation's rule. The peak figures of this file are RSS
(`/usr/bin/time -v`) unless labelled VmPeak.

| Part | Local test command | Known memory peak (VmPeak and RSS, labelled) |
|---|---|---|
| `crates/hexx` | `scarb build -p hexx` (library alone, ~0.7 GB; cap `--as=8589934592`, 8 GiB) is the only hexx build on the VPS (VPS: VmPeak 2,857,064 kB, RSS 829,288 kB; cap `--as=8589934592`, 8 GiB). `scarb package -p hexx`: VmPeak 2,988,036 kB, RSS 822,400 kB; cap `--as=8589934592`, 8 GiB. `snforge test -p hexx <filter>` still compiles the whole test target (unit + integration), so a filter scopes nothing: CI or the Mac only (D-212) | 9,471,639,552 B (8.82 GiB) RSS, Mac, 2026-10-05, `a045239`: over 8 GB, Mac only, no VPS cap |
| `crates/hexx_glam` | `scarb build -p hexx_glam` | VmPeak 5,161,128 kB (4.92 GiB), RSS 1,318,564 kB; cap `--as=8589934592` (8 GiB) |
| `crates/takeover_tests`, `crates/consumer` | `snforge test -p <package>` | not recorded: measure first |
| `crates/golden_lm2` / `golden_impls` / `golden_hex` | `snforge test -p <package>` | `golden_lm2` (3,241 lines): VmPeak 5,686,056 kB, RSS 2,166,684 kB, cap `--as=9663676416` (9 GiB) / `golden_impls` (11,156): VmPeak 7,783,528 kB, RSS 5,070,740 kB, cap `--as=12884901888` (12 GiB) / `golden_hex` (13,765): VmPeak 9,225,512 kB, RSS 6,040,644 kB, cap `--as=15032385536` (14 GiB) |
| `crates/golden_lm1` | `snforge test -p golden_lm1` | VmPeak 8,290,220 kB, RSS 3,453,972 kB (5,119 lines; now 5,188); cap `--as=12884901888` (12 GiB) |
| `crates/golden_bounds`, `golden_grid`, `golden_hex_t2`, `golden_rings`, `golden_shapes` | `snforge test -p <package>` | not recorded; the 8,000-line budget gives under ~4 GB: measure first (rule 1) |
| `tools/refgen` (golden vectors) | `cargo run --manifest-path tools/refgen/Cargo.toml -- check` | not recorded: measure first |
| `tools/consumer_check` | `tools/consumer_check/run.sh [version]` (builds and tests against the registry) | not recorded: measure first |
| `scripts/`, generated docs | `python3 -m unittest discover -s scripts/tests`; `python3 scripts/{api_parity,deviations,gas_tables}.py --check` | not recorded: measure first |

VmPeak and RSS figures above, except the Mac row: thread t-0127, VPS, 2026-10-10, `origin/main` 9618d35, cold `target/`, `RAYON_NUM_THREADS=1`, under `--as=16 GiB`, VmPeak and VmHWM sampled every 0.5 s from `/proc` over every descendant (kB are KiB, as `/proc` reports). A 0.5 s sample can miss a short spike: the true VmPeak may be slightly higher. Cap = ceil(1.5 × VmPeak) in whole GiB, floor 8 GiB, at most 16 GiB (rule 2).

There is no Node package in this repository. Each golden package stays under 8,000 lines and is run
alone (`snforge test -p golden_<x>`) for the one a change touches. The `hexx` gas pins come from
CI's artefact (`gas-pins-<head sha>`, `bench.py apply-pins`, "Gas pins from CI"), never from a local
run; pins and `gas/bytecode.size` are Linux-only (D-182). Builds run single-threaded
(`RAYON_NUM_THREADS=1`, D-176). The pre-push hook stays minimal (2026-10-02 rule): it checks only
the changed set, skips its Cairo compile after 90 s of build lock, skips its class-size step off
Linux (D-182), and is not a substitute for the scoped tests above.

## Before you push

| When | Run |
|---|---|
| Before every push (the hook `.githooks/pre-push` does it once `git config core.hooksPath .githooks` is set) | `scripts/prepush.sh`: format, the unit tests of the scripts, a build of the packages the push touches, and each generated-artefact check whose inputs changed. Aim: under two minutes. |
| Before asking for a review of a change that touches measured code (gas, class size) or pins | `scripts/check.sh`, the full gate |

Never push red and never skip the hook (`--no-verify`): a push that fails `scripts/prepush.sh` would
have failed CI. The hook checks the working tree of the current branch, not the refs being pushed:
commit your fix before pushing. It does not replace `scripts/check.sh` (every test, gas budgets and snapshots) or CI.

On a pull request, each job of `.github/workflows/ci.yml` runs only when a path that concerns it
changed (`scripts/ci_changes.py`, run by the job `changes`; a documents-only pull request runs no
test). Groups: `links` (job `links`: any `*.md`, `LICENSE*`), `shell` (`scripts`: `scripts/*.sh`, `.githooks/**`),
`docs_checks` (`fmt`: Cairo sources, manifests, `.tool-versions`, `scripts/**`, the generated
documents, `gas/**`), `takeover` (`crates/hexx/**`, `scripts/takeover_check.py`), `cairo` (`test`,
`package`, `gas`, `gas-complete`, `determinism`: `crates/**`, manifests, `.gitignore`, `gas/**`, `scripts/bench.py`,
`scripts/bytecode_size.py`), `golden` (`tools/refgen/**`, the golden tests and their sources). A change
to `ci.yml` or to `scripts/ci_changes.py`, an empty list, and any push to `main` select everything.
`all-checks` always runs and treats a skipped job as a pass. A new job, or a new input of a job, must
be added to `scripts/ci_changes.py` (and its test) in the same change, or it is skipped when only that
input changes.

## Principles (the game's `docs/CAIRO.md`, in full at `grimworld:docs/CAIRO.md`; in short)

1. Test-driven: tests first, from the brief's acceptance criteria.
2. Gas is a test result: `#[available_gas(l2_gas: N)]` on every test, `N = ceil(1.05 * measured)`;
   `scripts/bench.py check` enforces it. Benchmarks on the worst case; figures in `docs/GAS.md`
   and in the task's report. No figure of the plan is a budget — only a measurement is.
3. Execution cost first, over contract size; tables over run-time computation.
4. Order of preference: plain arithmetic, then bitwise operations, then loops as a last resort,
   bounded.
5. No `u256` without a written reason; `u252` (package `uint252` on scarbs.xyz,
   `bal7hazar/types-cairo`) for bitmaps and packed values; the smallest integer that holds the
   value.
6. An optimised algorithm is tested against a plain, obviously correct oracle kept in the tests.
7. Determinism: fixed iteration and tie-break orders (lowest tile index); no block data.
8. Same names as `hexx`, always, where a port or a counterpart exists (COMMON.md §5). Deviations
   are documented (`Mirrors ...` / `#### Panics` / `#### Deviations` on the item), never silent.
9. No stubbed success: an unported function does not exist.
10. Numeric results are API: a changed result for the same input is a versioned change
    (`CHANGELOG.md`, plan §9.4's "Results changed").
11b. Functions are scoped (owner's rule D-143): traits and impls with short names, never free
    functions in a file; a free function needs a written reason next to it (a table of
    constants is one). The mirror of `hexx` is methods on types and stays so; the engine taken
    over and the extensions of L-M1 follow the same rule. Checks live in an `...Assert` impl
    with an `errors` module (`docs/briefs/COMMON.md` §4).
11. `crates/consumer`'s class-size fixture only tracks what it calls: each task of milestone L-M1
    (LIB-05) that ships a public item adds at least one call site of it to `crates/consumer`
    (`HexxSink`, or a further contract in that crate once one fixture needs to stay small),
    committing the resulting `gas/bytecode.size` snapshot with its own change — otherwise a
    removed or dead-code-eliminated item goes on shrinking the tracked class size unnoticed
    (fix loop 1 of LIB-04, finding 9). **M1-T1**, the first task of L-M1 to land public items in
    `crates/hexx` (the take-over of `board/map.cairo` and the rest of §5), is the first task that
    adds call sites of them to `crates/consumer`: LIB-04 ships only the placeholder, on nothing
    else to call yet (fix loop 2 of LIB-04, decision D).

## Roles

| Role | Owns | Does not own |
|---|---|---|
| Orchestrator | sequencing, briefs, review, merges, `Scarb.toml`, `scripts/**`, `.github/**`, `PLAN.md`, `STATUS.md`, `docs/decisions/`, `docs/briefs/`, `CHANGELOG.md` releases | large implementations |
| Porter (LIB-05 on) | one module of the plan's tree: `crates/hexx/src/<module>.cairo`, its tests, its `tools/refgen` spec, its `gas/*.snap` entries | the shared files above; a shared file must change → escalate, do not edit it |
| Auditor | correctness against the plan's contracts and oracles, gas deltas, determinism | implementation |

## Escalation (COMMON.md §1: "ambiguity stops you")

When the plan and the source disagree, when an API cannot be expressed in Cairo, when a shared
file must change, or when a design sketch fails its own oracle: stop that part, write the
question under *Escalations* in the task's `REPORT.md`. Do not invent a rule and do not widen the
scope.
