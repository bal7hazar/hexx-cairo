# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Stopped: LIB-03 escalated.** Three fix loops used, audit pass 4 still FAIL (6 findings, 3 major) |
| Pending decisions | [PENDING-LIB-03-fix-loops](docs/decisions/PENDING-LIB-03-fix-loops.md): a fourth fix loop limited to the six findings (recommended), merge as is, or restructure |
| Lot | Pull request #9 (the porting plan), open, CI green, not merged |
| Running agents | None |
| Gate L-G1 | Decided by the owner on 2026-09-28: [L-G1](docs/decisions/L-G1-hexx-port.md) |
| Gate L-G2 | Not reached: it opens when the plan is merged |
| Inputs received since L-G1 | Window of 15 × 16, recomputed at each tick (D-120); `uint252` 0.1.0 published; the game dropped Dojo and is on Cairo 2.19 (its ADR-0007); N-9 reduced to `snforge_std` as a dev-dependency; LIB-03b cancelled before launch. All are in the plan |
| Estimate to remember | The tick, worst case of the plan: 1.34M to 1.67M, against 740k in the first draft. Estimates; nothing was measured |

## Done

| Date | What |
|---|---|
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
| 2026-09-28 | LIB-03: plan written by `[Fable 5.1]`, four audit passes by `[GPT-6-Astra]`, three fix loops; escalated |
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
