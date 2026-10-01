# LIB-04f — Migration to Scarb 2.20.1 and starknet-foundry 0.64.0 (D-180)

## Agent

Title: `[Sonnet 5.5] LIB-04f Scarb 2.20` · Profile: implement · Model: Sonnet 5.5 (pins, CI and
re-measurement; no library logic changes). Review: `nexus review` only (no audit, D-177).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

**Starts when three conditions hold**, checked by the orchestrator before the launch: the game's
SPK-13 has reported whether the compile drift (D-154) exists on Scarb 2.20.1; M1-T8 is merged, so
that its figures are measured once, on the new compiler; and **the owner has installed Scarb
2.20.1 and starknet-foundry 0.64.0 on the VPS** (`asdf list scarb`, `asdf list
starknet-foundry`). Installing a toolchain is the owner's act, never an agent's.

## Goal

After this task the repository builds, tests, measures and packages on the latest toolchain, Scarb
2.20.1 and starknet-foundry 0.64.0 (the owner's rule D-180: every repository on the latest Scarb),
and every figure the gates hold is a measurement on that toolchain. The published `hexx`
0.1.0-rc.1 is not rebuilt; release candidate 0.1.0-rc.2 is the first on the new compiler, and its
changelog says so.

## Context — read, in this order

1. `.tool-versions`, the workspace `Scarb.toml` (`cairo-version`, `snforge_std`), `Scarb.lock`,
   `.github/workflows/{ci,release-check,consumer_check}.yml`, `scripts/check.sh`.
2. `docs/briefs/LIB-04e-single-thread-builds.md` and its report: the pin `RAYON_NUM_THREADS=1`
   (D-176) and why. **SPK-13's result on 2.20.1** decides it: the orchestrator gives it to you at
   the launch (kept, or dropped with the reason).
3. `tools/consumer_check/` (its `with_tests` package pins a `snforge_std` outside the library's
   range: on 0.64 that range moves), `docs/RELEASING.md`, `CHANGELOG.md`.

## Scope

**In**

1. **The pins**: `.tool-versions` (Scarb 2.20.1, starknet-foundry 0.64.0), `cairo-version`,
   `snforge_std` in `[workspace.dependencies]` and every package that names it, `Scarb.lock`
   regenerated. Every action pinned by SHA keeps its pin; the toolchain comes from
   `.tool-versions`.
2. **Builds and tests**: the whole workspace builds and every test passes on the new toolchain.
   A compile error or a changed test result is reported with its cause; a change of the library's
   code that is not a mechanical consequence of the compiler (a renamed core item, a new lint) is
   an escalation, not a fix.
3. **Re-measured and written down**: `gas/*.snap` and `gas/bytecode.size` re-taken on the new
   toolchain; every budget by the rule `ceil(1.05 × measured)`; `docs/GAS.md` regenerated. Report
   every row whose value changed (test, old, new, %), grouped by module, and say for every figure
   of `gas/accepted.md` and plan §14 whether it moved by more than 5 % (the orchestrator then
   updates those records). `docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`
   regenerated and checked.
4. **The pin of D-176**, as the orchestrator states it at the launch from SPK-13's result: kept on
   every measured or declared build, or removed everywhere with the reason written in the CI
   comments.
5. **The release check and the consumer check** on the new toolchain: `release-check.yml` and
   `consumer_check.yml` read `.tool-versions`; `with_tests` pins a `snforge_std` outside the new
   range that 0.64.0 can run, and says which and why. Run the consumer check on the pull request
   against `0.1.0-rc.1` (published on 2.19.4) and report whether a 2.20.1 consumer resolves and
   builds it.
6. **The changelog**: under `[Unreleased]`, a line that the next release candidate is built with
   Scarb 2.20.1 and starknet-foundry 0.64.0, and that 0.1.0-rc.1 stays as published.

**Out**: any change of a function's behaviour; any new feature; any publication or tag.

**Allowlist**: `.tool-versions`, `Scarb.toml`, `crates/*/Scarb.toml`, `Scarb.lock`,
`.github/workflows/*.yml`, `scripts/check.sh`, `tools/consumer_check/**`, `gas/*.snap`,
`gas/bytecode.size`, `docs/GAS.md`, `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `CHANGELOG.md` (`[Unreleased]` only), `REPORT.md`. A Cairo file only for a
mechanical compiler consequence, each listed in the report.

## Acceptance criteria

- [ ] AC-1 The toolchain is Scarb 2.20.1 and starknet-foundry 0.64.0 everywhere it is named.
- [ ] AC-2 Every test passes; every snapshot and budget is a measurement on the new toolchain; the
      changed rows are reported.
- [ ] AC-3 The pin of D-176 is as stated at the launch.
- [ ] AC-4 `scripts/check.sh` passes; CI green, the slowest job reported; the consumer check green.
- [ ] AC-5 Nothing outside the allowlist was written.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the changed rows and the figures of
`gas/accepted.md` and §14 that moved by more than 5 %.
