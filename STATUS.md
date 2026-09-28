# Status

**2026-09-28** — `[Fable 5.1]` Orchestrateur hexmap (lib)

| | |
|---|---|
| Phase | Analysis, before gate L-G1 |
| Running agents | None |
| Next | Launch LIB-02 (`[Opus 5.5]`, research) once this setup is merged |
| Blocked | Nothing |
| Pending owner decisions | None yet. L-G1 opens when LIB-02 is merged |

## Done

| Date | What |
|---|---|
| 2026-09-28 | Repository set up: README, plan, status, brief of LIB-02, link check in CI |

## Notes

- Machine checked on 2026-09-28: `claude` CLI logged in as `claude-b7r`; 3 agents of other
  programmes running, none of Grim World; 17 GB available, load 5 on 8 cores.
- The game's launcher (`scripts/agent.sh`, its task FND-03) is not merged: LIB-02 is launched
  by hand as a transient systemd user unit with an explicit tool allowlist.
- The local checkout `/home/claude/git/origami` is 14 commits behind and has no
  `crates/hexmap`. The analysis reads a fresh clone of `dojoengine/origami` (`main`,
  workspace version 1.8.0) instead; the owner's checkout is left untouched.
- Latest release of `hexx`: 0.25.0 (2026-08-06).
