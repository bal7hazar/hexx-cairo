> Orchestrator note `[Fable 5.1]`, 2026-09-28. Findings 3 and 4 are fixed in the pull request (both options are refused and the help says so). Findings 1 and 2 are in the code shared with the game's launcher (`bal7hazar/grimworld`, `scripts/agent.sh` at `64d4d67`), which this copy must follow line for line for the count to mean the same thing in the three tracks: they are reported to the project manager to be fixed there first, then synced here.

# [GPT-6-Sol] Audit — PR 24 — launcher

## Verdict

**FAIL** — the shared lock is in place, but the detached-agent count does not reliably enforce the three-agent limit.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | major | `scripts/agent.sh:164–179` | The count misses Codex audits whose command line does not match the single Node pattern and which have no launcher PID file. | With two active units and a native `codex exec` audit running in one of the three repositories, `pgrep -f '^/usr/bin/node .*codex[^ ]* exec( \|$)'` misses the audit. The count is 2, so a fourth agent may launch. | Count supported Codex process forms, or require a reliable PID record for every detached audit and refuse launch when that count cannot be established. |
| 2 | major | `scripts/agent.sh:169–173` | PID-record read and validation failures silently reduce the count instead of failing closed. | The code uses `pid=$(cat "$f" 2> /dev/null \|\| true)` and `continue` for invalid PIDs or unreadable `/proc/$pid/cmdline`. If that agent also misses the narrow `pgrep` pattern, it disappears from the count. | Distinguish stale records from unreadable or inconsistent live records; refuse launch when a live record cannot be verified. |
| 3 | minor | `scripts/agent.sh:24,235,378–380` | `--with-assets` remains available although this repository has no `assets` submodule. | `git ls-tree HEAD .gitmodules assets` returns neither path; the option runs `git ... submodule update --init assets`. | Remove the option and its launch branch for this repository. |
| 4 | minor | `scripts/agent.sh:25–26,297` | The help text says `--with-sepolia` can leave credentials available, while every launch using it is refused. | The option description promises a brief-granted launch; line 297 exits whenever the option is set. | State the refusal in the help text. |

## Coverage

- `diff -u sources/grimworld-agent.sh scripts/agent.sh` showed only the header, `hexmap-` prefix, and Sepolia refusal.
- Both copies use `~/orchestrator/agent-launch.lock`; count and start are inside `flock`, and both agent launch commands close descriptor 9. The lock prevents a last-slot race when the count sees every agent. The findings above allow an undercount despite that lock.
- A read-only dry run showed empty registry-token and Sepolia settings. A dry run with `--with-sepolia` exited 2; the same refusal and settings construction apply to new and resume launches.
- `docs/briefs/` and the `research`, `implement`, and `audit` profile files exist. `bash -n` passed for both launchers. No live launch was performed.