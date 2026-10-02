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
| Build / test one package | `scarb build -p hexx`, `snforge test -p hexx` |
| Parity table (`docs/API_PARITY.md`, `docs/EXTENSIONS.md`) | `python3 scripts/api_parity.py --check`; `--refresh --hexx /path/to/hexx` to regenerate the embedded `hexx` inventory from a pinned checkout; `--extensions` for `docs/EXTENSIONS.md` |
| Deviations (`docs/DEVIATIONS.md`) | `python3 scripts/deviations.py --check` |
| Gas budgets and snapshots | `python3 scripts/bench.py check`; `snapshot` to rewrite `gas/*.snap` after a deliberate change |
| README gas table (`docs/GAS.md`) | `python3 scripts/gas_tables.py --check` |
| Class size of `crates/consumer` | `python3 scripts/bytecode_size.py check`; `snapshot` to rewrite `gas/bytecode.size` |
| Golden vectors from `hexx` 0.25.0 | `cd tools/refgen && cargo run -- gen <module>` / `-- check` |
| Heavy commands (build, test) | Through the build lock, `scripts/lock.sh scarb build`, `scripts/lock.sh snforge test <filter>` (`COMMON.md` §3) |

Toolchain versions live in `.tool-versions` only (Scarb 2.20.1, starknet-foundry 0.64.0).

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
test). Groups: `links` (job `links`: any `*.md`), `shell` (`scripts`: `scripts/*.sh`, `.githooks/**`),
`docs_checks` (`fmt`: Cairo sources, manifests, `.tool-versions`, `scripts/**`, the generated
documents, `gas/**`), `takeover` (`crates/hexx/**`, `scripts/takeover_check.py`), `cairo` (`test`,
`package`, `gas`, `gas-complete`, `determinism`: `crates/**`, manifests, `gas/**`, `scripts/bench.py`,
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
