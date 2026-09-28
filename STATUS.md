# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Milestone L-M1, tooling: LIB-04** |
| Gate L-G2 | **Decided by the owner on 2026-09-28**: the plan is accepted with two conditions; the package is named `hexx`. [L-G2](docs/decisions/L-G2-porting-plan.md) |
| Running agents | `[Sonnet 5]` LIB-04, profile implement, launched once this pull request is merged |
| Publication | **Not granted.** The owner declined the reservation of the name: no `hexx` 0.0.1. The first publication is 0.1.0 (release candidates included), each on the owner's go through the project manager. The agents' profile refuses `scarb publish`, tags and releases |
| Next | Audit of LIB-04 by `[GPT-6-Luna]`; then LIB-05, starting with M1-T1 (take-over), then what N-3 and N-8 need, **N-3 and N-8 first among the extensions**, measured on their worst cases |
| Stop condition | A measurement above the upper bound of its range: stop and report before any budget is set |
| Game's rule for the flood (D-127) | 15 layers; a goblin not reached holds its position. `depth` stays a parameter; benches at 10, 15, 20 layers and without a limit |
| The plan | [LIB-03](docs/research/LIB-03-porting-plan.md), with five open points in its §14, which wins over the body |
| Estimate to remember | One tick, worst case of the plan: 1.34M to 1.67M gas with a flood of 25 layers. Estimates: nothing was measured, and no figure of the plan is a budget |

## Done

| Date | What |
|---|---|
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
| 2026-09-28 | Gate L-G2 decided by the owner; brief of LIB-04; profile `implement` extended with `cargo` and closed to publication |
| 2026-09-28 | LIB-03: plan written by `[Fable 5.1]`; five audit passes by `[GPT-6-Astra]`, four fix loops (the fourth authorised by the project manager); merged with four open findings; [report](docs/reports/LIB-03-REPORT.md) archived |
| 2026-09-28 | Gate L-G1 decided by the owner; launcher of the game adopted; brief of LIB-03 |
| 2026-09-28 | LIB-02: [analysis of `hexx` and `origami_hexmap`](docs/research/LIB-02-hexx-analysis.md) by `[Opus 5.5]` (pull request #2); audit by `[GPT-6-Sol]` in two passes, 4 then 2 findings, all fixed by the resumed agent in two fix loops; [report](docs/reports/LIB-02-REPORT.md) archived |

## What the orchestrator had recommended at L-G1 (not followed)

Port `hexx` **partly** (its integer geometry: directions and rotation, line, range and ring),
landing in **`origami_hexmap` extended in place**; this repository keeps the track and the
parity harness.

`u252` moves to its own crate in `bal7hazar/types-cairo` (owner's decision, 2026-09-28),
extracted and published by a separate session; the library will depend on it by published
version.

## Notes

- **Model policy (game's `OPERATIONS.md` §2, `e67a66b`).** Sonnet 5.5 (`claude-sonnet-5-5`, title
  `[Sonnet 5.5]`) replaces Sonnet 5 for every new launch of a mechanical task; the launcher
  knows it as `sonnet-5.5`. LIB-04 keeps Sonnet 5 until it closes.
- **Restart of the desktop app, 2026-09-28 around 19:00 UTC.** The agent of LIB-04 (a systemd
  user unit) went on; the orchestrator's background wait was re-armed.

- **Launcher adopted.** `scripts/agent.sh`, `scripts/lock.sh` and `scripts/profiles/` are
  copied from `bal7hazar/grimworld` (`6c2351e`); only the unit prefix (`hexmap-`) and the
  lock name differ. It detaches `codex` with `setsid`, where the read-only sandbox is
  starts: confirmed by the audits of LIB-03, where the auditor read the sources itself.
- **`u252`.** Delivered: package `uint252` 0.1.0 on scarbs.xyz (owner, 2026-09-28; checked in
  the registry index and in `bal7hazar/types-cairo` at `35f74d5`). The first version of the
  LIB-03 plan calls it `u252`: corrected at its next resume.
- **Sources.** `hexx` 0.25.0 and `origami` `main` at `04ab30c` (workspace 1.8.0), pinned in
  [LIB-02-sources](docs/research/LIB-02-sources.md). The owner's checkout
  `/home/claude/git/origami` is at the same commit.
- **Game documents** are read from `origin/main` of `bal7hazar/grimworld` (pull request #6
  merged). LIB-02 read them at the branch commit `da2a30e`; the documents it used are
  identical on `main`.
- Machine on 2026-09-28: `claude` CLI logged in as `claude-b7r`; 2 to 3 agents of other
  programmes running; 23 GB available.
