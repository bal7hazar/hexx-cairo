# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Milestone L-M1: LIB-05.** M1-T1a and M1-T1b merged: the engine is taken over and proved equal to the published 1.8.0. Next M1-T1c (the gas gate), then N-3 and N-8 |
| Cap | **One agent at a time for the library, audits included**: the single slot `lib-1`, held by a kernel lock (launcher at the game's `2628b21`). Nothing is launched while `~/orchestrator/waiting/game` is less than 30 minutes old |
| Waiting for the slot, in this order | M1-T1c (`[Sonnet 5.5]`); then M1-T4a (N-3, the assembly) |
| Pending decisions | None |
| Gates | L-G1 and L-G2 decided by the owner on 2026-09-28: [L-G1](docs/decisions/L-G1-hexx-port.md), [L-G2](docs/decisions/L-G2-porting-plan.md) |
| Publication | Nothing is published. No workflow of the repository publishes or holds a token. Rule D-132 (game's `OPERATIONS.md` §7): the orchestrator's session publishes, never an agent, after a go that names package, version and commit. LIB-04b is merged (pull request #26, audit PASS without finding). **Before its first publication the orchestrator asks the owner, in its own session, to confirm the delegation of that decision to the project manager** |
| Stop condition of LIB-05 | A measurement above the upper bound of its range: stop and report before any budget is set |
| **Open risk: gas measurements that moved** | Twice in CI, on an unchanged tree, tests measured 0.5 to 1.3 % above their snapshot and passed on the next run (`test_readme_open`; then 47 tests). **Every test that moved goes through `Digger::dig`.** Toolchain, runner image, cache and actions were the same; the auditor found nothing in the code that can vary. Suspects now: the compiled artefact or the measurement. M1-T1c keeps the raw output and the artefact hashes of every run and runs the `Digger` tests twice; until the cause is found a pull request can fail the gas gate at random |
| Figures of the take-over | 811 tests (708 run, 103 ignored), all measurements equal to those of 1.8.0; CI job of the engine's tests 7 min 20 s of the 10 minutes allowed; the 20 functions of the facade do not fit one contract (limit 81,920 CASM felts): three fixtures of 21,007, 44,469 and 49,375 |
| Figures of the game's spike SPK-7, on 1.8.0 | Assembly of the window 65,224; flood 26,452 per layer; capped flood with 8 goblins and their steps 1,150,737; the chunked map adds about 720,000 per tick. The measurements of N-3 and N-8 are compared with them |

## Done

| Date | What |
|---|---|
| 2026-09-29 | LIB-05 M1-T1b: `crates/takeover_tests`, 630 tests proving every public function of the engine equal to the published `origami_hexmap` 1.8.0, panics included, gas identical on the 22 measured call sites, by `[Opus 5.5]`; three audit passes by `[GPT-6-Astra]`, two fix loops; [report](docs/reports/LIB-05-M1-T1b-REPORT.md) archived |
| 2026-09-29 | LIB-04b: the three findings of the tooling audit and four more silent cases of the parity tool, by `[Sonnet 5.5]`; audit by `[GPT-6-Sol]`: PASS, no finding; [report](docs/reports/LIB-04b-REPORT.md) archived |
| 2026-09-29 | LIB-05 M1-T1a: the engine of `origami_hexmap` 1.8.0 moved unchanged (29 files, proved by `scripts/takeover_check.py` and by the auditor's own comparison), by `[Sonnet 5.5]`; two audit passes by `[GPT-6-Sol]`, one fix loop; [report](docs/reports/LIB-05-M1-T1a-REPORT.md) archived |
| 2026-09-29 | Launcher synced with the game's slot locks (`2628b21`); rule of the shared machine in `COMMON.md` and the profiles |
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
| 2026-09-28 | LIB-04: workspace and tooling by `[Sonnet 5]`; four audit passes by `[GPT-6-Sol]`, three fix loops; merged by decision of the project manager; [report](docs/reports/LIB-04-REPORT.md) archived |
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

- **Session model and project manager (2026-09-29).** This session runs on Opus 5.5 (owner's
  change, the Fable quota of the app's account being spent until 2026-09-30 14:00 UTC); titles
  carry `[Opus 5.5]` from then. The project manager is now session `local_3ab2583a`
  (`grimworld`, `docs/briefs/PM-handoff-2026-09-29.md`).

- **Organisation of Cairo code (owner's rule D-143, 2026-09-29).** Functions scoped in traits
  and impls with short names; a free function needs a written reason. In `COMMON.md` §4,
  `AGENTS.md` and §14 of the plan; carried into every brief and audit of LIB-05 from its next
  task. The library stores nothing, so the rules on models and events do not apply.

- **Audit of the launcher and the profiles (`[GPT-6-Sol]`, 2026-09-29): FAIL, three findings.**
  [Report](docs/audits/launcher-2628b21-audit-gpt-6-sol.md). (2) `scarb -v publish` passed the
  profile: fixed, publication is refused with a global option before the subcommand too;
  (3) the release deny blocked the read-only `gh release view` and `list`: fixed, only
  creation and changes are refused. (1) **open, inherited from the reference**: an error
  while reading the game's waiting marker reads as "no marker" (not failing closed); passed to
  the project manager for the game's launcher, synced here when the reference fixes it.

- **The machine is shared (game's `OPERATIONS.md` §3, `27ceea0`).** Sessions and agents delete
  and kill only what they created, named exactly; temporary directories under their own
  scratchpad or worktree. In `COMMON.md` and in the profiles. The orchestrator itself, on
  2026-09-28, stopped two of its own queued shell loops with a kill by pattern
  (`pgrep -f` on the text of its own command): only its own loops matched, but the form is the
  one the rule forbids, and it is not used again: pids are recorded at launch.

- **Inputs of the game for N-1 and N-3 (D-134, 2026-09-28).** Corners of a chunk always wall,
  openings never on a corner; a void chunk is assembled as wall without a read and the window
  is never clamped. Recorded in §14 of the plan and carried into the briefs. The game's spike
  SPK-7 measured about +720,000 L2 gas per tick with goblins on `origami_hexmap` 1.8.0.
- **Cap exceeded on 2026-09-28, corrected.** The orchestrator held two agents (M1-T1a and
  LIB-04b) while its cap is one; a queued audit was cancelled before it started, the two agents
  were left to end.

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
- **Launcher: slots held by kernel locks.** `scripts/agent.sh` matches the game's at `2628b21`
  except `TRACK=hexmap` and the two refused options. Nothing is counted by reading processes any
  more: an agent holds one of `~/orchestrator/slots/total-1..3` and the slot of its track, which
  for the library is the single slot **`lib-1`**, by a lock for as long as it lives; a codex
  audit takes a slot like any agent. The directory `~/orchestrator/slots` is read-only: slot
  files are opened read-only, never created by a probe or an agent, a missing one refuses the
  launch, and nobody of this track creates or removes a file there, nor runs `slots-init`. The
  launcher guards against accidental over-launch and fails closed; a deliberate act by the same
  Unix user is out of its scope. From now on the reference is read in the game's CHANGELOG at
  each check-in (no more relay by the project manager). While `~/orchestrator/waiting/game` is less than 30 minutes
  old the library launches nothing. Synced **by exception before its audit** (decision of the
  project manager, 2026-09-29: a mixed state of launchers is worse than an unaudited lock); to be
  read by `[GPT-6-Sol]` when the slot is free, and synced again when the game's CHANGELOG marks
  the audited reference. The counting code and its inherited findings are gone with it.
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
