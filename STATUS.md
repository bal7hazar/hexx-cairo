# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | Planning: **LIB-03 (porting plan)**, before gate L-G2 |
| Gate L-G1 | **Decided by the owner on 2026-09-28**: [L-G1](docs/decisions/L-G1-hexx-port.md). Full parity with `hexx` wherever it makes sense, extended with what Cairo and the network require; the library lives here; the engine of `origami_hexmap` is taken over; `origami_hexmap` is decommissioned once the port is complete |
| Running agents | `[Fable 5.1]` LIB-03, profile research, launched once this pull request is merged |
| Pending owner decisions | None |
| Window (D-120, owner, 2026-09-28) | It follows the adventurer, is 15 columns × 16 rows, is recomputed at each tick and not stored. Merged in the game's documents (`bal7hazar/grimworld` `2e5bdbc`), on the basis of [the check of the library's code](docs/research/window-parity-check.md). LIB-03 receives it as an input when it is resumed |
| Next | Audit of LIB-03 by `[GPT-6-Astra]`, then gate L-G2 |
| Blocked | Nothing |

## Done

| Date | What |
|---|---|
| 2026-09-28 | LIB-01: repository set up (pull request #1) |
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
  expected to start (it could not from a systemd unit during LIB-02): to be confirmed by the
  audit of LIB-03.
- **`u252`.** Extraction to `bal7hazar/types-cairo` started by the owner in a separate
  session on 2026-09-28; not published yet.
- **Sources.** `hexx` 0.25.0 and `origami` `main` at `04ab30c` (workspace 1.8.0), pinned in
  [LIB-02-sources](docs/research/LIB-02-sources.md). The owner's checkout
  `/home/claude/git/origami` is at the same commit.
- **Game documents** are read from `origin/main` of `bal7hazar/grimworld` (pull request #6
  merged). LIB-02 read them at the branch commit `da2a30e`; the documents it used are
  identical on `main`.
- Machine on 2026-09-28: `claude` CLI logged in as `claude-b7r`; 2 to 3 agents of other
  programmes running; 23 GB available.
