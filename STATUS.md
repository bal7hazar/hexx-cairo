# Status

**2026-10-03** — orchestrator `grimworld-lib` (herdr; the track moved from Nexus to herdr on 2026-10-01); predecessor's handover `docs/handover/orchestrator-hexmap-2026-10-01.md`

| | |
|---|---|
| Phase | **Milestone L-M1: LIB-05; L-M2 (LIB-06) started.** `hexx` 0.1.0-rc.2 published on 2026-10-03 (see *Done*); M2-T0 (#92) reviewed, merges after this record. N-1 to N-8 merged. Next: M2-T0 and M1-R |
| Procedures (herdr) | Implementers, reviews and audits are threads of the project `grimworld-lib` (profiles `impl-sonnet`, `impl-opus`, `review`, `review-opus`, `audit`); Nexus and `scripts/agent.sh` are not used. Every code pull request is reviewed on another model than the one that wrote it; audits are the D-177 exceptions (randomness, among them seeded generation). The owner merges; the project manager is told one line per ready pull request |
| Running agents | M2-T0 (#92) in review |
| Decisions pending | None for the owner on this track |

## Pause 2026-09-29 (ended 2026-09-30)

The pause is over; its open task M1-T4b is done (below). Kept for the record.

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
| 2026-09-30 | local (VPS), M1-T3 | `takeover_tests`: 40 rows of `Digger::dig` +0.2 to +1.9 %, twice; CI measured `main`'s figures exactly; `main`'s snapshot kept. `HexxGenerators` 27,092 (no class-size drift). Rule added to `COMMON.md` §4 |
| 2026-10-01 | CI, pull request #61 (a workflow timeout), run 36809041479 | `takeover_tests`: the same 40 rows +0.22 to +1.94 %: the second build, first seen in CI |
| 2026-10-01 | CI, pull request #70 (consumer check, no Cairo change), run 36836722836 | the same 40 rows, the same figures; the failed job re-run once. D-164 extended to the gas gate by the project manager: LIB-04d |

Diagnosis: the game's task SPK-13 on the owner's Mac ([reproduction](docs/reports/LIB-05-M1-T1c-REPORT.md)). An upstream issue is the owner's go.

### Decisions pending

| For | Decision |
|---|---|
| The owner, in this session, before the first publication | Confirm the delegation of the decision to publish to the project manager (D-132). Nothing is published until then |
| The owner | An upstream issue on the compile drift, if SPK-13 finds the cause in the compiler |

## Done

| Date | What |
|---|---|
| 2026-10-05 | **`hexx` 0.2.0 published** on scarbs.xyz by the orchestrator, by hand, from `a045239`, after the owner's go (D-211 on the game's main, #355); registry checksum `sha256:853a6f70…9b08` equal to the go, `0.1.0-rc.1` and `0.1.0-rc.2` unchanged; tag and stable release `v0.2.0`. [Record](docs/decisions/D-211-publish-hexx-0.2.0.md) |
| 2026-10-04 | L-M2 and its release prep merged (#117 release request, #118 parity fixes after the audit); `hexx` 0.2.0 requested ([request](docs/decisions/D-211-publish-hexx-0.2.0.md)) |
| 2026-10-03 | L-M2 merged (#92, #105, #107, #108, #110, #111, #112, #114, #115, #116); `hexx` 0.2.0 requested ([request](docs/decisions/D-211-publish-hexx-0.2.0.md)); `Sum`/`Product` of `Hex` recorded `dropped` in the parity table (deferred, M2-T3) |
| 2026-10-03 | **`hexx` 0.1.0-rc.2 published** on scarbs.xyz by the orchestrator, by hand, from `c60e05a`, after the project manager's go (request #102, `6678326`); `sha256sum --check` of `hexx-0.1.0-rc.2.tar.zst` OK; registry checksum `sha256:c4bf8aef…a753` equal to the go, `0.1.0-rc.1` unchanged; tag and pre-release `v0.1.0-rc.2`. [Record](docs/decisions/D-132-publish-hexx-0.1.0-rc.2.md) |
| 2026-10-03 | L-M2 started: M2-T0 (#92) reviewed, merges after this record. LIB-04g (CI runs jobs by changed paths) merged in #100 |
| 2026-10-03 | Merged since the last status: #89 each gas job uploads only its own partition report; #90 `prepush.sh` retries on tool downloads; #91 no scarb call with an option before its subcommand (VPS lock gap); #93 CI cancels only a pull request's superseded runs; #95 M1-T8 follow-up, `Caver::smooth` masks its grid to the board; #96 deferred items recorded in `PLAN.md` (#94 closed as replaced by #96); #97 `prepush.sh` clears git's local environment variables first; #98 release: hexx 0.1.0-rc.2; #99 brief LIB-04g; #100 CI: a job runs only when its files changed (LIB-04g); #101 release: rc.2 fix (licence notice, package README, CHANGELOG); #102 rc.2 publication request (sha, release check, checksum) |
| 2026-10-02 (afternoon) | LIB-04f: Scarb 2.20.1 and starknet-foundry 0.64.0 merged in #86 as `1527ac2`, by `[Sonnet 5.5]`; two reviews, one minor finding fixed (the workflows read `.tool-versions`). Accepted figures re-read in `gas/accepted.md` and plan §14: marginal figures unchanged, small absolute figures down (snforge 0.64 harness about 7.5–7.8k less per test). E2201 on `extern fn bitwise` kept as a known warning (the file is under the strict take-over proof). rc.2 requires Cairo ≥ 2.20.0 |
| 2026-10-02 (afternoon) | LIB-06: the briefs of milestone L-M2 merged in #87 as `38736b3` (M2-T0 to M2-T7, M2-R); tasks in `PLAN.md`. In progress: the `smooth` mask follow-up (variant B, +3.92 % on order 1), rc.2 preparation, M2-T0 |
| 2026-10-02 | LIB-04e: single-thread pin (`RAYON_NUM_THREADS=1`, D-176), both `gas/*.builds` files dropped, a determinism job in CI, by `[Sonnet 5.5]`; ten CI runs identical. First review FAIL (the runs tested a stale base, before #65, #74 and #84); fixed by merging `main` and re-checking single-threaded with no row changed; second review PASS. Merged as `920ddee`, [pull request #81](https://github.com/bal7hazar/hexx-cairo/pull/81) |
| 2026-10-02 | LIB-05 M1-T8, N-1: `Caver::generate_with_margins`, `smooth`, by `[Fable 5.1]`; review PASS WITH FINDINGS (notes, Sonnet); determinism audit PASS WITH FINDINGS (one note, Opus; D-177: seeded generation). Merged as `ad03dbc`, [pull request #84](https://github.com/bal7hazar/hexx-cairo/pull/84). Decision on plan §6.2 recorded in `PLAN.md` (a corner set in `values` is cleared) |
| 2026-10-01 | LIB-04d: the gas gate accepts the exact recorded second build of a row (D-164 extended to gas by the project manager), `gas/takeover_tests.builds` (40 rows), by `[Sonnet 5.5]`; review `[Opus 5.5]` (fallback): PASS. [pull request #76](https://github.com/bal7hazar/hexx-cairo/pull/76) |
| 2026-10-01 | LIB-05 M1-N9: `tools/consumer_check/` and its workflow, green against 0.1.0-rc.1; the cause of 1.8.0's defect reproduced by the orchestrator (Scarb 2.13.1 against 2.19.4, `docs/research/N-9-cause.md`), by `[Sonnet 5.5]`; reviews `[Opus 5.5]` and `[Fable 5.1]` (fallback), three passes; its quality audit waits for Codex. Follow-up #72 (`docs/RELEASING.md`, plan §14) |
| 2026-10-01 | **`hexx` 0.1.0-rc.1 published** on scarbs.xyz by the orchestrator, from `fe2b529`, after the owner's D-132 (release candidates delegated to the project manager) and the project manager's go (#67); registry checksum `sha256:9313e06b…1500`; tag and GitHub release `v0.1.0-rc.1`. [Record](docs/decisions/D-132-publish-hexx-0.1.0-rc.1.md) |
| 2026-10-01 | `0.1.0-rc.1` cut (#60: version, CHANGELOG, five Codex review passes); release check fixed (#61 timeout, merged with a red check by the orchestrator's error, the D-154 drift; #62 reports outside the checkout, merged without a Codex review by the project manager's decision, Codex out of quota) and green on `fe2b529` (run `36813005979`); pending file #64; D-132 answered by the owner |
| 2026-10-01 | LIB-05 M1-T5, N-6, by `[Opus 5.5]`: `HexagonTrait::{hexagon, hexagon_ring}`, table and loop paths, generated tables; pull request #65 green, **not merged** (audit and Codex review wait for Codex's quota). The agent crossed its stop (first loop 940,040 at 83 rows, above twice its bound) and rewrote instead of stopping: work kept, breach recorded in its brief; `COMMON.md` now says a stop holds from the first measurement |
| 2026-10-01 | LIB-05 M1-T6, N-5: `HexTrait::line_to` (the integer line, the game's tie rule), `LineTrait::{line, line_of_sight, approach}` with a keyed table for width 15 at distance ≤ 6 and a loop elsewhere, the `refgen` line generator, golden vectors as digests, `docs/deviations/line_ties.md` (every difference with `hexx`, all at ties or `f32` rounding), by `[Opus 5.5]` (one stop on the table figure of `line`, 11,150, accepted with `approach` on a ring and `line_to` in `gas/accepted.md`; none on the tick); audit `[GPT-6-Astra]` PASS WITH FINDINGS (one minor, a free test helper, scoped by the orchestrator), Codex review `[GPT-6-Sol]` PASS. L-M1 lists no missing mirror item. [report](docs/reports/LIB-05-M1-T6-REPORT.md) |
| 2026-10-01 | LIB-04c: `bench.py --partition` and `complete`, CI partitioned (tests 5, gas 4 + 2, two completeness jobs), every job under 6 minutes (was 9 m 4 s and a timeout on #57), by `[Sonnet 5.5]`; Codex review `[GPT-6-Sol]` two passes, PASS. [report](docs/reports/LIB-04c-REPORT.md) |
| 2026-09-30 | LIB-05 M1-T3, N-7 and the board coordinates: `Direction::{rotate, arc}`, `Arc`, the conversions with `EdgeDirection`, `distance_between` (on `bounded_int`, 4,220, down from 7,220), `chunk_of`, `to_hex`, `from_hex`, `index_to_hex`, `hex_to_index`, `neighbor_direction`, the three renames, by `[Opus 5.5]` (one stop on the gas condition, decided in its brief; five figures accepted above range in `gas/accepted.md`, none on the tick); audit (determinism) and Codex review by `[GPT-6-Sol]`: PASS, PASS. The brief named GPT-6-Astra for the audit; the orchestrator omitted `--model` and the project default ran. [report](docs/reports/LIB-05-M1-T3-REPORT.md) |
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

## Deferred follow-up

From the notes of #84's review and audit: `Caver::smooth` does not mask `grid` to the board; stray bits at or above `W*H` are returned and can change in-board tiles. To mask it (one AND) after LIB-04f.

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
