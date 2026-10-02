# Handover — orchestrator, hexmap library (track LIB), 2026-10-01

Written at 2026-10-01T15:40Z by `[Opus 5.5] Orchestrator — grimworld — LIB` (session
`local_859f04d3-8022-49e1-98c6-b84a86ba7a7d`), on the owner's soft stop (via the Overseer and the
project manager): running agents end, nothing is started, resumed or merged after them. The
author does not retire: it stays for the owner until the successor is opened.

## Who you are

Orchestrator of track LIB of Grim World: the `hexx` port to Cairo in `bal7hazar/hexx-cairo` (local
clone `/home/claude/projects/hexx-cairo`). Mandate `grimworld:docs/briefs/ORCH-hexmap.md`; rules in
`AGENTS.md` and `docs/briefs/COMMON.md`. You orchestrate and never implement anything large.
Implementers are `claude` processes started by `scripts/agent.sh`; reviews and audits go through
`nexus review` and `nexus audit`. Never write in the game's repository.

- **Above you**: the project manager, `[Fable 5.1] Chef de projet Grim World`, session
  `local_3ab2583a-0d2b-469d-872e-cffdf357185d`.
- **Before you**: `[Opus 5.5] Orchestrator — grimworld — LIB` (`local_859f04d3`, this note's
  author, on standby), and `[Retired] [Opus 5.5] Orchestrateur hexmap (lib)` (`local_2e7bf177`).
- **Below you**: the agent of M1-T8 (`[Fable 5.1]`, unit `hexmap-M1-T8-144446`, running at the time
  of writing) and the stopped agent of LIB-04e (`[Sonnet 5.5]`). No other agent of the track runs.

## State

`main` at `01b9da7`. Pull requests #1 to #82 are merged except #81 (open, below).

**Done since the previous handover (2026-09-30)**: M1-T3 (#54), M1-T6 (#57, N-5), M1-T5 (#65,
N-6), M1-T7 (#74, N-2), M1-N9 (#70, follow-up #72: the cause of 1.8.0's defect is Scarb 2.13.1's
resolver), LIB-04c (#58, CI partitions), LIB-04d (#76, the gas gate accepts the recorded second
build), CI partitions raised (#79: tests 6, regular gas 6, ignored gas 3), the release check fixed
(#61 timeout 120 min, #62 reports outside the checkout). **`hexx` 0.1.0-rc.1 published** on
scarbs.xyz from `fe2b529`, checksum `sha256:9313e06b7b11282cb015f47af41fcd41a3162b627fb14b0734e35569f5ca1500`,
tag and release `v0.1.0-rc.1` ([record](../decisions/D-132-publish-hexx-0.1.0-rc.1.md)).

**Launcher slots at 15:36Z**: `lib-1` and `total-2` held by M1-T8; `total-1`, `total-3` by the
game (ENG-R1a, ENG-02). `nexus progress --project grimworld` lists no agent of LIB beyond these.

### Open tasks

| Task | Branch | Pull request | Head | State | Next |
|---|---|---|---|---|---|
| M1-T8, N-1 (generation with margins, `smooth`) | `feat/lib-05-m1-t8-margins` | none yet | — | **running** (`[Fable 5.1]`, launched 14:44Z); ends with a PR or a stop | read its report; decide a stop if any; **review** (`nexus review`, Sonnet fallback while Codex is out, `--model fable` not needed: Fable wrote it) **and audit** (D-177: generation from a seed is "randomness"; `nexus audit --lens determinism`, falls back to Opus); merge on PASS |
| LIB-04e, single-thread builds (`RAYON_NUM_THREADS=1`, D-176) | `feat/lib-04e-single-thread` | #81, **open** | `9310c61` (pin, `.builds` files dropped, determinism job, `test`/`gas` timeouts 20 min) | the ten CI runs of Scope 6 are attempts of run `36867216720`: 1 to 6 **success**, 7 in progress at 15:36Z; the re-run loop is stopped (soft stop) | re-run to ten attempts (`gh run rerun 36867216720`, one after the other); resume the agent with the run id so that it reads the 40 rows and the class size of every attempt (`gh run view 36867216720 --attempt N --log`); then review (Sonnet fallback) and merge. Snapshots did not change single-threaded (the agent's local measurement) |
| LIB-04f, Scarb 2.20.1 / starknet-foundry 0.64.0 (D-180) | — | — | — | briefed (`docs/briefs/LIB-04f-scarb-2.20.md`); the toolchain is installed on the VPS (the owner); SPK-13's result on 2.20.1: **the drift remains, the pin stays** | launch after LIB-04e and M1-T8 are merged; tell the agent at launch that the pin is kept (SPK-13: 12/8 split on 20 builds, 6/6 identical pinned) |

Resume commands (from your worktree, after exporting
`XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus`):

```bash
scripts/agent.sh M1-T8 claude claude-fable-5-1 resume "<decisions on its report>"
scripts/agent.sh LIB-04e claude claude-sonnet-5-5 resume "Run 36867216720 has ten attempts; read the 40 rows and HexxGenerators' class size of each (gh run view 36867216720 --attempt N --log), report them, and finish the task."
scripts/agent.sh --branch feat/lib-04f-scarb-2-20 LIB-04f claude sonnet new "<launch prompt: the brief, the allowlist verbatim, the pin kept per SPK-13>" implement
```

### Order to rc.2

1. M1-T8 reviewed, audited, merged.
2. LIB-04e: ten attempts read, reviewed, merged (the pin on `main`; `gas/*.builds` gone).
3. LIB-04f: the migration, every figure re-measured on 2.20.1; reviewed, merged.
4. rc.2: version `0.1.0-rc.2`, CHANGELOG section (N-1, N-2, N-6 added; built with Scarb 2.20.1 and
   starknet-foundry 0.64.0; rc.1 stays as published), merged; the release check dispatched from
   `main` on the merge commit; **one audit of the release** (a published interface, D-177;
   `nexus audit` with a real lens falls back to Opus); `docs/decisions/PENDING-publish-hexx-0.1.0-rc.2.md`;
   the project manager's go (D-132 delegates release candidates); publish by hand from a clean
   clone of the sha (the token is `SCARB_REGISTRY_AUTH_TOKEN` in the session's environment, used by
   name only); confirm the registry; tag and release; the consumer check runs on the tag; one line
   to the project manager with the checksum.
5. Then M1-R: `0.1.0` stable, **the owner's go**.

## Decisions

Taken today and recorded: the stops of M1-T3, M1-T6, M1-T5 decided in their briefs; figures
accepted in `gas/accepted.md` and §14 (none on the tick); M1-T5 before M1-T7/M1-T8 while SPK-14 was
open; chunks stay 15 × 15 (D-165, the owner); rc.1's content and publication (D-132: release
candidates delegated to the project manager, stable versions the owner's); D-164 extended to gas
(LIB-04d), then superseded by the pin (D-176, LIB-04e); timeouts of `test` and `gas` 20 min with the
pin (what would reverse it: CI time a bottleneck; then compile once and share `target/`); M1-N9
merged before its audit, then the audit stopped under D-177.

**D-177 (the owner)**: audits are the exception (value, access control, randomness and the reveal,
a published interface once before its publication, a cost or determinism only a measurement proves,
a large refactoring, a lot the owner asks to see); the review is the routine gate. **3 audits
stopped** on 2026-10-01 (M1-T5, M1-T7, M1-N9). Each PR says in one line why an audit was asked or
that none was needed.

Pending: none for the owner on this track. Deferred notes (non-blocking): M1-T7 review pass 2 (a
test with bits above `W·H`; §14 to record `openings` 15 × 15 East odd 32,296); #72 review pass 2 (five
wording notes); LIB-04d's note on pairing a second value with its snapshot value (moot once LIB-04e
drops the files).

## Rules of the day to carry

- Audits are the exception (D-177). While Codex has no quota (until 2026-10-04 13:36 per the
  provider): reviews fall back to Claude (Sonnet; Nexus R2) and audits to Opus 5.5 (D-175); pass
  `--model fable` to a review when Opus wrote the work.
- Orchestrators run on Opus 5.5.
- Agents install toolchain versions themselves (the project manager's last word of the day; the
  Overseer had first held it the owner's and raised it to the standard).
- Every repository migrates to Scarb 2.20.1 with the single-thread pin (D-176, D-180).

## Threads

- The project manager: every merge and decision above is reported; rc.2 is the next gate (ENG-05).
- The owner: nothing open on this track.

## Traps

- **The merge guard** must test CI's result and the head together:
  `[ "$(gh pr checks N | awk -F'\t' '$2!="pass"' | wc -l)" = 0 ] && [ head = reviewed ] && gh pr merge`.
  #61 was merged red once because only the head was tested.
- **Agents cannot wait on or re-run CI**: the `implement` profile refuses `gh run watch`,
  `gh run rerun`, `gh workflow run`, `sleep` loops, `env VAR=… cmd`, `export`, `git pull` and other
  binaries. Give those steps to yourself in the brief. A commit you make in an agent's worktree
  needs no pull. A refused command is reported, never worked around (LIB-04e worked around `export`
  once; it was told).
- **Resuming an agent** can fail once with "Refusing to use … as an isolation worktree"; the binding
  is cleared and the same command works the second time.
- **The drift (D-154)**: until LIB-04e is merged, `main` is unpinned and `gas/takeover_tests.builds`
  (LIB-04d) accepts the known second build of 40 `takeover_tests` rows. The pin doubles the compile
  time of every partition (execution unchanged); more partitions do not help, since each recompiles
  the whole test target.
- **Stops**: a stop holds from the first measurement (`COMMON.md` §4). M1-T5's agent crossed its stop
  and rewrote; repeat the rule verbatim in every launch prompt.
- **Documents-only PRs** merged without a review say so in the merge body; the permission layer
  refused one such merge while Codex was available, so start a review on a docs PR when the review
  path is up.
- **Nexus**: a Codex account blocked without a reset is probed every 15 minutes; a review that is
  the probe fails with a 400; ask again at once.
- **CI time**: the slowest job is about 7 min unpinned with the partitions of #79, and LIB-04e takes
  `test` and `gas` to 20-minute timeouts.
- Watch your own context and hand over at about 950K tokens.
