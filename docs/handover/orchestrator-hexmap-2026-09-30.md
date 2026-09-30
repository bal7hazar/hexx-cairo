# Handover — orchestrator, hexmap library (track LIB), 2026-09-30

## Who you are

Orchestrator of track LIB of the Grim World project: the `hexx` port to Cairo in
`bal7hazar/hexx-cairo` (local clone `/home/claude/projects/hexx-cairo`). Mandate:
`grimworld:docs/briefs/ORCH-hexmap.md`; its rules are restated in `AGENTS.md` and
`docs/briefs/COMMON.md`. You orchestrate and never implement anything large. Implementers are
`claude` CLI processes started by `scripts/agent.sh`, never the in-session Agent tool. Audits
and reviews go through `nexus audit` and `nexus review` (D-162). Codex audits and never
implements. Never write in the game repository.

- **Above you:** the project manager, session `local_3ab2583a-0d2b-469d-872e-cffdf357185d`.
  Message it only at gates or for a blocker you cannot lift.
- **Predecessor:** `[Retired] [Opus 5.5] Orchestrateur hexmap (lib)`, session `768ce265`.
- **Below you:** no live agent. `M1-T3` (claude session `942590a7-371d-4bd0-98f2-c30add164aee`,
  model `claude-opus-5-5`, worktree `.claude/worktrees/cli-M1-T3`, branch
  `feat/lib-05-m1-t3-directions`) has stopped. Resume it with `scripts/agent.sh M1-T3 claude
  claude-opus-5-5 resume "<text>"`. Do not relaunch it.

## State

- `main` is at `9b51d56` (#51, the brief of M1-T3). Pull requests #1 to #51 are merged. Done:
  LIB-02 (analysis), LIB-03 (plan, gates L-G1 and L-G2 passed), LIB-04 (tooling), and of LIB-05
  M1-T1a/b/c (the engine take-over), M1-T9a (`Bfs::flood`), M1-T4a (N-3/N-8 flood cap, D-25),
  M1-T4b (N-4 `cut` = `grid & mask`), M1-T2 (the mirror items; their figures are accepted in
  §14 of the plan).
- `STATUS.md` still shows the pause of 2026-09-29. Bring it up to date in your first docs
  pull request.
- **M1-T3 stopped on the plan's gas stop condition**, exit 0 at 2026-09-30T20:35:59Z, with
  **no pull request**. Commits: `f47a5a5` (the three renames; the move proof printed
  `29 pairs, 0 problem(s)`) and `0ca5d42` (N-7 and the board coordinates; all 101 `board::`
  tests pass). The report is in its worktree, and the end of `.claude/worktrees/logs/M1-T3.log`
  summarises it. These six figures are above the upper bound of their §7 range:

  | Function | Measured | Range |
  |---|---|---|
  | `distance_between` (hot path) | 7,220 | 5,196–6,495 |
  | `hex_to_index` | 5,370 | 2,998–3,748 |
  | `from_hex` | 3,840 | 2,198–2,748 |
  | `chunk_of` | 3,020 | 2,196–2,745 |
  | `to_hex` | 2,750 | 1,998–2,498 |
  | `neighbor_direction` | see its report | — |

  Not done because of the stop: `scripts/check.sh`, CI, the `takeover_tests` re-run, the real
  gas budgets (the new tests carry a placeholder of 1,000,000,000), the snapshots, the generated
  documents, and the call sites in `crates/consumer`.
- Slots: `lib-1` is free. The game holds `total-1` and `total-3` (CBT-02c, SPK-14). The
  sub-agents' account was at 94 % of its week on 2026-09-28. Run `nexus accounts --refresh`
  before any launch.

## Decisions

Taken in this session and recorded: L-G1 (port `hexx` at feature parity where it makes sense,
extended with the Cairo and network features such as bitmaps; the library lives here with
`origami_hexmap`'s engine taken over; `origami_hexmap` is decommissioned once the port is done),
L-G2, and the project manager's D-120, D-127, D-25 (reading B: the cap lives in `Flood`), D-134,
D-23 reversed, D-143, D-154/D-164 (`gas/bytecode.builds`), D-162, D-165 and D-167.

Pending:

| For | Decision | Recommendation |
|---|---|---|
| You, now | M1-T3's figures (above), and its escalations 2 to 4 | (2) Add the three `EXTENDED` entries (`direction`, `layout`, `geometry.cairo`) to `scripts/takeover_check.py` yourself: it is orchestrator-owned, and additions-only mode is what those files need. (3) Leave the old layout and geometry tests in `bench_foundation.cairo` and `properties.cairo`, as D-167 applies to new tests. (4) Accept the edit of `scripts/tests/test_takeover_check.py`: a mechanical consequence of the renames you asked for. (1) Accept the five conversions as §14 did for the mirror, since they are not hot. For `distance_between` (hot, +11 %), ask the agent for one bounded optimisation attempt, then accept what it measures. Record every accepted figure in §14 on the branch: the Codex reviewer reads only the code and the brief |
| The owner, before the first publication | Confirm the delegation of the decision to publish to the project manager (D-132) | Ask when rc.1 is ready, with the `PENDING-publish` file |
| The owner | An upstream compiler issue on the compile drift, if SPK-13 finds the cause | Wait for SPK-13 |

## Threads

- The project manager: the tick is measured (1,064,209 cave, 1,069,012 ring walker, 1,106,666
  serpentine) and reported (condition 1 of L-G2 is met). Agreed order: M1-T3 → M1-T6 → rc.1
  (ENG-02) → M1-T7/M1-T8 → rc.2 (ENG-05) → M1-T5 → 0.1.0. **Ask the project manager about
  SPK-14 (hexagonal chunks) before briefing M1-T7 (N-2) or M1-T8 (N-1)** (D-165).
- The owner: `uint252` 0.1.0 is published on scarbs.xyz from `bal7hazar/types-cairo`.
- The launcher is a copy of the game's reference at `2628b21`. Sync it when the game's
  CHANGELOG marks a new reference (the probe-race fix `74c7d50` is in audit). Audit AUD-25
  finding 1, the waiting marker failing open on a read error, is inherited from the reference:
  report it to the game, do not patch the copy.

## Next

1. Close M1-T3: decide as above, resume the agent with the decisions (real budgets, snapshots,
   generated documents, consumer call sites, `scripts/check.sh`, pull request). Add its new
   files to `OWN_FILES` in `scripts/takeover_check.py`. Then run `nexus audit` (lens
   determinism, GPT-6-Astra as in the brief), `nexus review`, and merge.
2. M1-T6 (N-5, the integer line and line of sight): brief, launch, audit, review, merge.
3. rc.1: `docs/decisions/PENDING-publish-hexx-0.1.0-rc.1.md`, ask the owner for D-132, one
   line to the project manager.
4. Ask about SPK-14, then M1-T7, M1-T8 → rc.2 → M1-T5 → M1-R (0.1.0).

## Traps

- Before any `scripts/agent.sh` call or wait, run
  `export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus`.
  Without it, `wait` returns at once. An agent has ended only when its log has an `exit=` line
  after the launch header (check from the start offset in `logs/<task>.start`).
- `nexus wait` can exit 1 on a control-plane blip. Retry while `nexus status` still says
  running.
- Hold one `lib-1` slot at a time. A queued audit counts: once I held two and had to cancel one.
- Put the stop condition verbatim in every implementer prompt. Agents have gone past it
  silently before (origin/local rewritten).
- Rules that were set in the game, not in the library, did not hold. The caller-side distance
  fix doubled the tick and was reverted.
- Every lot adds its new files to `OWN_FILES` (and `EXTENDED` where it adds to a moved file) in
  `scripts/takeover_check.py`, or the takeover CI job fails.
- CI's hexx test job was close to its 10-minute timeout, so it runs in partitions 1/2 and 2/2.
  Add a third partition before it reaches the timeout again.
- The compile drift (D-154) recurs: `HexxGenerators` 27,101 against 27,092 Sierra felts. Record
  each occurrence in `.claude/worktrees/logs/drift-occurrences.txt` and in `STATUS.md`. A
  second different build needs a line in `gas/bytecode.builds` (D-164).
- The Codex reviewer repeats a finding you dismissed unless the dismissal is written in the
  branch (§14 of the plan, or the brief).
- Watch your own context: hand over at about 950K tokens. Nothing warns you. I missed this
  threshold myself.
