# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | **Stopped at gate L-G1**, waiting for the owner's decision |
| Running agents | None |
| Pending owner decisions | [PENDING-L-G1](docs/decisions/PENDING-L-G1.md): is a port of `hexx` relevant, and where does it land |
| Next | LIB-03 (porting analysis), **only after** the decision |
| Blocked | The `codex` read-only sandbox does not start on the VPS (below). Not blocking today |

## Done

| Date | What |
|---|---|
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
| 2026-09-28 | LIB-02: [analysis of `hexx` and `origami_hexmap`](docs/research/LIB-02-hexx-analysis.md) by `[Opus 5.5]` (pull request #2); audit by `[GPT-6-Sol]` in two passes, 4 then 2 findings, all fixed by the resumed agent in two fix loops; [report](docs/reports/LIB-02-REPORT.md) archived |

## Recommendation at the gate, in short

Port `hexx` **partly** (its integer geometry: directions and rotation, line, range and ring),
landing in **`origami_hexmap` extended in place**; this repository keeps the track and the
parity harness.

`u252` moves to its own crate in `bal7hazar/types-cairo` (owner's decision, 2026-09-28),
extracted and published by a separate session; the library will depend on it by published
version.

## Notes

- **Audit sandbox.** `codex exec -s read-only` cannot run a shell on the VPS
  (`bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`): the auditor reads no file.
  For LIB-02 the material was passed in the prompt (report in full, sources as excerpts
  chosen by the orchestrator), which keeps the sandbox but limits the audit to what it is
  given. The sandbox was not bypassed. A code audit (LIB-05) will need a real fix on the
  machine: to raise with the project manager before LIB-04.
- **Launcher.** The game's `scripts/agent.sh` (FND-03) is not merged: agents were launched by
  hand as transient systemd user units with an explicit tool allowlist. To adopt when it lands.
- **Sources.** `hexx` 0.25.0 and `origami` `main` at `04ab30c` (workspace 1.8.0), pinned in
  [LIB-02-sources](docs/research/LIB-02-sources.md). The owner's checkout
  `/home/claude/git/origami` is at the same commit.
- **Game documents** are read from `origin/main` of `bal7hazar/grimworld` (pull request #6
  merged). LIB-02 read them at the branch commit `da2a30e`; the documents it used are
  identical on `main`.
- Machine on 2026-09-28: `claude` CLI logged in as `claude-b7r`; 2 to 3 agents of other
  programmes running; 23 GB available.
