# [GPT-6-Sol] Audit — launcher at 2628b21 and profiles

## Verdict

FAIL

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | major | `scripts/agent.sh:249` | **Inherited from the reference:** an error reading the game’s waiting marker is treated as no marker, so this check does not fail closed. | `find` errors are discarded; if the marker’s parent directory is accidentally inaccessible, the empty result permits a hexmap launch while the game may be waiting. | Treat only a confirmed missing marker as absence; refuse on other read or stat errors. |
| 2 | major | `scripts/profiles/implement.txt:13,129-130` | A typed Scarb publication can pass the profile rules. | `scarb -v publish` is accepted by Scarb and matches the allow rule `Bash(scarb *)`, but neither publication deny matches it. Whether upload succeeds still depends on credentials. | Deny publication with global options before the subcommand, or narrow the Scarb allow rules to needed subcommands. |
| 3 | minor | `scripts/profiles/research.txt:66-67`; `scripts/profiles/implement.txt:137` | The release deny blocks the profile’s read-only release commands. | `Bash(gh release view*)` and `Bash(gh release list*)` are allowed in `research`, but inherited `!Bash(gh release*)` wins under [Claude Code’s rule precedence](https://code.claude.com/docs/en/permissions). | Deny release creation and modification commands specifically, while retaining read-only view and list. |

## Coverage

Compared the supplied launcher reference with `scripts/agent.sh`: the diff contains only the stated header, help, `TRACK=hexmap`, and option-refusal changes. Static review confirmed one `lib-1` track slot, three total slots, refusal for missing slot files or directory, and the normal waiting-marker check. Read-only dry runs confirmed both flags are refused before launch. The shared new and resume Claude path empties the registry and Sepolia variables; Codex uses `env -i`.

Reviewed all three profiles against their named publication, credential, environment, and shared-machine command forms using [Claude Code’s documented Bash matching rules](https://code.claude.com/docs/en/permissions). The named safe `rm` form, `mktemp -d -p "$PWD/tmp"`, `git status`, and `scarb build` do not match the listed denies. No live launch, slot mutation, or file write was performed. The stipulated slot-probe race was excluded.