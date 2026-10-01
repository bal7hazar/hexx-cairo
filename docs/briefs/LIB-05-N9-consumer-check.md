# LIB-05 M1-N9 — N-9: the consumer check against the published package

## Agent

Title: `[Sonnet 5.5] LIB-05 M1-N9 consumer check` · Profile: implement · Model: Sonnet 5.5 (two
small consumer packages, a workflow, and an investigation with a written answer). Audit:
`[GPT-6-Sol]`, quality (`nexus audit --model gpt-6-sol`), when Codex has budget again.

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. **Foreground only; your turn ends when
`REPORT.md` is written.** You never publish, tag or release anything. You delete and kill only
what you created, named exactly.

## Goal

After this task it is proved, on the artifact scarbs.xyz serves, that a consumer of `hexx` does not
inherit its test dependency: a package that depends on `hexx` resolves and builds with no
`snforge_std` at all, and a package with its own test setup on another `snforge_std` resolves,
builds and runs its tests. The proof runs against every published version, in CI. And the cause of
1.8.0's defect is found and written down. It is need N-9 of milestone L-M1 (exit criterion 8).

## Context — read, in this order

1. [The plan](../research/LIB-03-porting-plan.md): §2.1 (the manifest, the row "Need N-9"), §8 (L-M1
   exit (8), the row of M1-N9), §11 (R-17).
2. The game's account of the defect: `bal7hazar/grimworld`, `docs/needs/hexmap.md`, § "N-9 in
   detail" (failure 1: next to `dojo_snf_test` 1.8.0 on Scarb 2.13.1, *"origami_hexmap 1.8.0
   depends on snforge_std >=0.61.0, <0.62.0"*). Read only; never write in that repository.
3. What the orchestrator observed on 2026-10-01: the registry's index entry of `origami_hexmap`
   1.8.0 (`https://scarbs.xyz/api/v1/index/or/ig/origami_hexmap.json`) lists `snforge_std` `^0.61.0`
   with `"kind": "test"`, **the same form** as `hexx` 0.1.0-rc.1's
   (`https://scarbs.xyz/api/v1/index/he/xx/hexx.json`). So the defect may lie in how a Scarb version
   resolves a dependency's test dependencies, not in the artifact. That is a lead, not a finding.
4. [`docs/RELEASING.md`](../RELEASING.md) § "After publication: need N-9";
   [`docs/decisions/D-132-publish-hexx-0.1.0-rc.1.md`](../decisions/D-132-publish-hexx-0.1.0-rc.1.md).

## Scope

**In**

1. `tools/consumer_check/`, two Scarb packages outside the workspace, each depending on
   `hexx = "=<version>"` **from the registry** (never a path):
   - `plain`: no `snforge_std` anywhere; `scarb build` succeeds and its resolved `Scarb.lock` has no
     `snforge_std`; one function calls at least one public item of `hexx` (the build must compile
     it).
   - `with_tests`: its own `[dev-dependencies]` `snforge_std` pinned to a version **outside**
     `^0.61.0` that Scarb 2.19.4 can use (say which, and why); `scarb build` and `snforge test`
     succeed with one test that calls `hexx`.
   The version under test is a parameter (default: the latest published), not hard-coded twice.
2. `.github/workflows/consumer_check.yml`: runs both packages against a version given as input
   (`workflow_dispatch`) and against every published version listed by the index on a schedule or
   on a tag push of `v*`; read-only permissions, actions pinned by SHA as in `ci.yml`, the toolchain
   of `.tool-versions`. Run it once against `0.1.0-rc.1` and link the green run in the report.
3. **The cause of 1.8.0's defect**, found and written down in
   `docs/research/N-9-cause.md`: reproduce failure 1 (Scarb 2.13.1, a consumer that pins
   `snforge_std` 0.51.x next to `origami_hexmap` 1.8.0) and the same consumer on Scarb 2.19.4;
   compare the index entries; say which component turned the test dependency into a constraint
   and from which Scarb version it no longer does, with the commands and their real output. If a
   reproduction needs a toolchain this machine lacks, install it only under the agent's own
   worktree or the ignored `work/`, and say so. Stop the investigation at a written, evidenced
   answer or at four hours of work, whichever comes first, and report what is known.
4. The manifest: `crates/hexx/Scarb.toml` already declares `snforge_std` under
   `[dev-dependencies]`; if the investigation shows a line is missing, **propose** it in the report;
   the manifest is the orchestrator's.

**Out**: any change of `crates/**`, `scripts/**`, `ci.yml` or `release-check.yml`; any
publication; any write in `bal7hazar/grimworld`.

**Allowlist**: `tools/consumer_check/**`, `.github/workflows/consumer_check.yml` (new),
`docs/research/N-9-cause.md` (new), `REPORT.md`.

## Acceptance criteria

- [ ] AC-1 Both consumer packages resolve and build against `hexx` 0.1.0-rc.1 from the registry;
      `plain`'s lock has no `snforge_std`; `with_tests` runs its test on its own `snforge_std`.
- [ ] AC-2 The workflow ran green against `0.1.0-rc.1`; it can be run against any published
      version.
- [ ] AC-3 `docs/research/N-9-cause.md` names the cause with reproduced evidence, or states exactly
      what remains unknown and why.
- [ ] AC-4 `scripts/check.sh` passes; CI green.
- [ ] AC-5 Nothing outside the allowlist was written.

## Report

`REPORT.md` as in [COMMON.md](COMMON.md) §7, with the link to the green run of the workflow.
