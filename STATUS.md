# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Stopped: LIB-04 escalated.** Three fix loops used, audit pass 4 still FAIL (3 findings, all major, none blocking M1-T1) |
| Pending decisions | [PENDING-LIB-04-fix-loops](docs/decisions/PENDING-LIB-04-fix-loops.md), for the project manager: a fourth fix loop limited to the three findings (recommended), merge now with a follow-up task, or re-scope |
| Lot | Pull request #18 (workspace and tooling), open, CI green, not merged |
| Running agents | None of the library |
| Gates | L-G1 and L-G2 decided by the owner on 2026-09-28: [L-G1](docs/decisions/L-G1-hexx-port.md), [L-G2](docs/decisions/L-G2-porting-plan.md) |
| Publication | Nothing is published. No workflow of the repository publishes or holds a token (pull request #18). Rule D-132 (game's `OPERATIONS.md` §7): the orchestrator's session publishes, never an agent, after a go that names package, version and commit. **Before its first publication the orchestrator asks the owner, in its own session, to confirm the delegation of that decision to the project manager** |
| Next | After the decision and the merge: LIB-05, M1-T1 (take-over of the engine), then what N-3 and N-8 need, N-3 and N-8 first among the extensions |
| Stop condition of LIB-05 | A measurement above the upper bound of its range: stop and report before any budget is set |
| Estimate to remember | One tick, worst case of the plan: 1.34M to 1.67M gas with a flood of 25 layers; the game's flood stops at 15 layers (D-127). Estimates: nothing was measured, and no figure of the plan is a budget |

## Done

| Date | What |
|---|---|
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
| 2026-09-28 | LIB-04: workspace and tooling by `[Sonnet 5]`; four audit passes by `[GPT-6-Sol]`, three fix loops; escalated |
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

- **Credentials and agents (corrected on 2026-09-28).** The user-level settings of the machine
  define the registry token and, since 20:21 UTC, the Sepolia account (`STARKNET_*`, a private
  key among them); the claude CLI passes them to every shell an agent opens. **The launcher
  now empties them** through its `--settings` override, as the game's does: a probe agent
  started from a clean environment reads them present without the override and empty with
  it. *The earlier note here said that the override did not work: that probe was started from
  the orchestrator's own shell, which already holds the variables, and the agent inherited
  them. The measurement was wrong, not the override.* What remains: the agent of LIB-04 now
  running was started before this change and holds them until it ends; a program an agent
  runs can still read the settings file of the same user (accepted residual, the owner's act
  is asked by the project manager); `CLAUDE_CODE_MESSAGING_TOKEN` cannot be emptied this way.
- **Models.** `sonnet` is now Sonnet 5.5 in the launcher, as in the game's; `claude-sonnet-5`
  only resumes an agent started on it (LIB-04). A resume must use the model of the launch.
- **Rule of decision (game's `OPERATIONS.md` §10, D-128).** At a gate or a blocker the project
  manager decides by its own recommendation and reports to the owner afterwards. Publishing
  on a registry, money, accounts and secrets stay the owner's act.
- **Budget (game's `OPERATIONS.md` §3).** 3 Grim World agents in total over three tracks; one
  slot is the library's, the third is shared. Count units `grimworld-*`, `hexmap-*`,
  `quiver-*` and the codex audits (detached processes, not units) before each launch.

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
