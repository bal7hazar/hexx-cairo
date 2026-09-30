# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Milestone L-M1: LIB-05.** N-3, N-4, N-8 and the mirror items merged; next **M1-T3** (N-7, `distance_between`, the renames), then M1-T6 (N-5), release candidate `0.1.0-rc.1` for the game's ENG-02. N-2 and N-1 wait for the game's study of hexagonal chunks (SPK-14, D-165) before their briefs |
| Procedures (Nexus, D-162) | Every pull request gets a Codex review (`nexus review`) before its merge; audits through `nexus audit`; implementers through `scripts/agent.sh`; `nexus accounts` and `nexus resources` before a launch. The sub-agents' account `claude:b7r` is at 94 % of its week until 2026-10-03 06:00 UTC: one implementer at a time, Sonnet where the task allows |
| Running agents | None |
| Decisions pending | The owner, in this session, before the first publication: confirm the delegation of the decision to publish to the project manager (D-132) |

## Pause 2026-09-29 (ended 2026-09-30)

### Open tasks

| Task | Branch | Pull request | Last commit | State |
|---|---|---|---|---|
| M1-T4b, N-4 (`cut`) | `feat/lib-05-m1-t4b-cut` | #46 | `5d70069` (orchestrator: the move proof knows the new files), after `57f6cc7` (the agent) | **Done by `[Sonnet 5.5]`, not audited, not merged.** `CutTrait::cut` is `grid & mask` (§14 of the plan); one `cut` about 10,122 L2 gas (range 16,905 to 21,132); the coverage of `local` deferred from M1-T4a is a documented Cartesian sweep. Worktree `.claude/worktrees/cli-M1-T4b`, report at its root and in `.claude/worktrees/logs/M1-T4b-REPORT.md` |

Resume commands (from this worktree of the orchestrator, after exporting
`XDG_RUNTIME_DIR=/run/user/$(id -u)` and `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus`):

```bash
# M1-T4b: its audit first (GPT-6-Sol, a new codex session: nothing to resume)
scripts/agent.sh AUD-M1-T4b codex gpt-6-sol new "<the audit prompt, written from docs/briefs/LIB-05-T4b-cut.md § What the auditor will check>" audit "" high
# if the audit asks for fixes, resume the implementer (claude session a3872e97-acec-41b2-a704-979f49c1c814, model claude-sonnet-5-5)
scripts/agent.sh M1-T4b claude claude-sonnet-5-5 resume "<follow-up>"
```

### Next steps, in order (decided with the project manager on 2026-09-29)

1. Audit and merge of M1-T4b (N-4).
2. M1-T2: the mirror items L-M1 rests on (`Hex`, `EdgeDirection`, the offset conversions, `HexOrientation`, reference vectors).
3. M1-T3: N-7 (rotation, arcs), `distance_between`, `new_odd`, the three renames.
4. M1-T6: N-5 (the integer line, line of sight).
5. **Release candidate `0.1.0-rc.1`** for the game's ENG-02: N-3, N-4, N-5, N-7, N-8. Asked by `docs/decisions/PENDING-publish-hexx-0.1.0-rc.1.md` (D-132).
6. M1-T7: N-2 (sides and openings). 7. M1-T8: N-1 (generation with margins, corners wall, D-134).
8. **Release candidate `0.1.0-rc.2`** for the game's ENG-05: adds N-1, N-2.
9. M1-T5: N-6 (geometric range and ring). 10. M1-R: `0.1.0`, the consumer check of N-9.

### The compile drift (D-154), occurrences recorded

| When | Where | What |
|---|---|---|
| 2026-09-28 | CI, M1-T1a | `test_readme_open` 2,053,706 against 2,030,366 (+1.15 %), twice |
| 2026-09-29 | CI, M1-T1b | 47 tests through `Digger::dig`, +0.5 to +1.3 % |
| 2026-09-29 | local and CI, M1-T1c | 42 tests +0.22 to +0.62 % (four builds, four hashes); CI run 36568463132: `test_readme_open` +1.15 % and `HexxGenerators` 27,101 against 27,092 Sierra felts |
| 2026-09-29 | CI, pull request #43, run 36609917335 | `HexxGenerators` 27,101 against 27,092; re-run once, green |
| 2026-09-29 | local, M1-T4b | `HexxGenerators` 27,101 against 27,092; CI green |

Diagnosis: the game's task SPK-13 on the owner's Mac ([reproduction](docs/reports/LIB-05-M1-T1c-REPORT.md)). An upstream issue is the owner's go.

### Decisions pending

| For | Decision |
|---|---|
| The owner, in this session, before the first publication | Confirm the delegation of the decision to publish to the project manager (D-132). Nothing is published until then |
| The owner | An upstream issue on the compile drift, if SPK-13 finds the cause in the compiler |

## Done

| Date | What |
|---|---|
| 2026-09-30 | LIB-05 M1-T2: the mirror items of L-M1 (`Hex`, `EdgeDirection`, offset coordinates, `HexOrientation`), parity by golden vectors from `hexx` 0.25.0, by `[Sonnet 5.5]`; two audit passes and two Codex reviews; [report](docs/reports/LIB-05-M1-T2-REPORT.md) |
| 2026-09-30 | LIB-05 M1-T4b, N-4: `cut` as `grid & mask`, and the exhaustive coverage of `local`, by `[Sonnet 5.5]`; audit and Codex review by `[GPT-6-Sol]`: PASS, PASS; [report](docs/reports/LIB-05-M1-T4b-REPORT.md) |
| 2026-09-29 | LIB-05 M1-T9b, N-8: the steps of the walkers and the benchmark of the tick, by `[Opus 5.5]`; two audit passes by `[GPT-6-Astra]`, two fix loops, final PASS; [report](docs/reports/LIB-05-M1-T9b-REPORT.md) with the orchestrator's decisions |
| 2026-09-29 | LIB-05 M1-T9a, N-8: the flood of the tick on the engine's layered flood, `depth` a parameter, by `[Opus 5.5]` (stopped once on the stop condition, `depth()` at 670 accepted); audit by `[GPT-6-Astra]`: PASS WITH FINDINGS (one on the move proof, fixed); [report](docs/reports/LIB-05-M1-T9a-REPORT.md) |
| 2026-09-29 | LIB-05 M1-T4a, N-3: the window of 15 × 16 assembled from 2 or 4 chunks, void chunks as wall, measured at 64,234 (two layers and ring, 4 chunks), by `[Opus 5.5]`; audit by `[GPT-6-Astra]`: PASS WITH FINDINGS (the stop condition was bypassed, the rewrite accepted after review); [report](docs/reports/LIB-05-M1-T4a-REPORT.md) |
| 2026-09-29 | LIB-05 M1-T1c: one gas job per package, ignored tests measured, the 702 inherited and 89 more budgets conformant, no baseline left, the drift instrumented, by `[Sonnet 5.5]`; two audit passes by `[GPT-6-Sol]`; [report](docs/reports/LIB-05-M1-T1c-REPORT.md) with a section of reproduction for SPK-13 |
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
