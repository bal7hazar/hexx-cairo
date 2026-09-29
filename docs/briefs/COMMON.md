# COMMON — rules every brief inherits

Adapted from `docs/briefs/COMMON.md`, `OPERATIONS.md` and `docs/CAIRO.md` of
`bal7hazar/grimworld`, which remain the reference. The orchestrator launches an agent through
`scripts/agent.sh` (copied from the game's repository) in the task's own worktree. When a brief
and this file disagree, the brief wins for its task, and says so.

## 1. How you work

| Rule | |
|---|---|
| One task | One worktree, one branch, one pull request, one `REPORT.md` at the worktree root (ignored by git; the orchestrator archives it in `docs/reports/`) |
| Foreground only | Never run a command in the background and never end your turn waiting for one: in headless mode that ends the session. **Your turn ends when `REPORT.md` is written** |
| Autonomy | Nobody answers during your run. Do not ask questions, do not widen the scope |
| Ambiguity stops you | If the design or the brief does not say, do not invent a rule: stop that part and write the question under *Escalations* in the report |
| Allowlist | Write only the files the brief lists. Anything else is an escalation |
| Shared files | `PLAN.md`, `STATUS.md`, `README.md`, `docs/briefs/`, `docs/decisions/`, `docs/reports/`, `docs/audits/`, `.github/`, `scripts/` belong to the orchestrator |
| Permissions | They come from the profile of your launch (`scripts/profiles/`): `research`, `audit` or `implement`. A refused command is not an obstacle to work around: use an allowed one, or report what you needed |
| Never merge | The orchestrator merges, on green CI |
| Evidence | A claim about a source cites the file and the line or symbol, at a stated version or commit. What is inferred or estimated is marked as such. No figure that was not measured is given as measured |
| Language | English |
| Secrets | None in the repository, the log or the report |

## 2. Branch, commits, pull request

| Profile | |
|---|---|
| `research` | You cannot commit. You write the deliverable and `REPORT.md`; **the orchestrator commits the deliverable and opens the pull request** |
| `implement` | Commit early, in small coherent commits. Push with exactly `git push -u origin HEAD` the first time and `git push` afterwards. Open the pull request with `gh pr create --base main`, title `[<Model>] <TASK-ID> <short description>`, last line of the body `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Wait for CI in the foreground (`gh pr checks <n> --watch --interval 30`) and fix until green |

Conventional commits, each ending with the trailer naming the model that did the work:
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or `Claude Sonnet 5.5`,
`Claude Sonnet 5`, `Claude Fable 5.1`). Branch `<type>/<task-id>-<slug>`, cut from `origin/main` by the
orchestrator. Never force-push, never rebase a pushed branch, never skip hooks.

## 3. The machine

The VPS (8 vCPU, 31 GB) is shared with the owner's other programmes.

| Rule | |
|---|---|
| Heavy commands | Through the build lock: `scripts/lock.sh scarb build`, `scripts/lock.sh snforge test <filter>`. It may wait for minutes: that is normal |
| Local checks | Package-scoped; the pull-request CI is the full gate |
| Exit code 137 | The OOM killer, not your code: wait a minute and run again |
| Toolchain | Never installed, upgraded or changed globally |
| **Delete and kill only what you created, named exactly** | A path you made yourself, a process whose pid you recorded. Temporary directories under your own worktree (`mktemp -d -p "$PWD/tmp"`), never directly under `/tmp`. Never a wildcard outside your own directory (`rm -rf /tmp/tmp.*`), never a kill by pattern (`pkill`, `killall`, `kill $(pgrep …)`), never a `git clean` or a `git worktree prune` outside your worktree. The machine is shared with other programmes (game's `OPERATIONS.md` §3, incident of 2026-09-29) |

## 4. Every Cairo task

The game's `docs/CAIRO.md` in full. In short:

| Rule | |
|---|---|
| Test-driven | Tests first, from the brief's acceptance criteria |
| Gas is a test result | `#[available_gas(l2_gas: N)]` on every test, `N = ceil(1.05 × measured)`; benchmarks on the worst case; figures in `GAS.md` and in the report |
| Execution cost first | Over contract size; tables over run-time computation |
| Order of preference | Plain arithmetic, then bitwise operations, then loops as a last resort, bounded |
| Types | No `u256` without a written reason; `u252` (package `uint252` on scarbs.xyz, from `bal7hazar/types-cairo`) for bitmaps and packed values; smallest integer that holds the value |
| Oracles | An optimised algorithm is tested against a plain, obviously correct version kept in the tests |
| Determinism | Fixed iteration and tie-break orders: lowest tile index. No block data |
| **Functions are scoped** (owner's rule D-143, game's `docs/CAIRO.md` §7) | Functions live in traits and impls, with short names scoped by the trait: `#[generate_trait] pub impl AssemblyImpl of AssemblyTrait { fn window(…) }`, called `AssemblyTrait::window(…)` or as a method. Not free functions in a file, not names that repeat their module (`assembly_window`). Checks in an `…Assert` impl with an `errors` module. **A free function needs a written reason** next to it (a table of constants is one); an auditor reads a free function as a finding to justify. The library stores nothing: the rules on models, events and the store do not apply here |

## 5. The port (decision L-G1)

| Rule | |
|---|---|
| Reference | The Rust crate `hexx`, at the version the plan pins |
| Mirror the crate | Same module, type and function names, same API where it makes sense on-chain |
| Exclusions | What has no meaning on-chain is excluded, each with its reason, and with its integer counterpart where one exists |
| Deviations | Each one documented, with its reason |
| Extensions | What Cairo and the network require beyond `hexx` (boards as bitmaps in one felt, generation, floods, assembly) is part of the library, documented as an extension, outside the parity table |
| Parity table | Generated, checked in CI |
| Numeric results are API | A change in a result for the same input is a versioned change. What is taken over from `origami_hexmap` 1.8.0 keeps its results |

## 6. Publications

| Rule | |
|---|---|
| No sub-agent publishes, ever | Not on a registry, not a tag, not a release. The profiles refuse the typed forms; the rule holds for anything an agent runs |
| A release candidate is a publication | Same procedure |
| Who publishes | The orchestrator's session, never an agent, and only after a **go that names the package, the version and the commit** |
| How it is asked | `docs/decisions/PENDING-publish-hexx-<version>.md` (package, version, commit, what changed, what the consumer must do), then one message to the project manager with its path |
| What is checked before the go | The commit is on `main` with every CI check completed and green; audits closed without blocker or major; changelog and version agree; the gas tables are those of that commit; `scarb package` from a clean checkout; name and version free on the registry; no test dependency declared as a regular one |
| Order | Publish; when the registry shows the version, tag and release |
| A task that prepares a release | Its brief repeats this section |

The game's `OPERATIONS.md` §7 is the reference (rule D-132, 2026-09-28: the owner delegated
the decision to publish to the project manager).

## 7. REPORT.md

```markdown
# [<Model>] <TASK-ID> — <title>

## Summary            What exists now that did not before. Pull request URL if any.
## Files changed      One line each.
## Commands run       Each with its real output, trimmed.
## Cost               Gas table for a Cairo task; "—" otherwise.
## Deviations         From the brief, with reasons.
## Escalations        What you needed and could not do; ambiguities met.
## Open questions
```

`[<Model>]` is the model you read from your own session, not the one the brief names; if they
differ, say so in the summary.

## 8. Glossary

| Term | Meaning |
|---|---|
| Tile | A pointy-top hex with global coordinates `(x, y)` in its location |
| Chunk | Unit of storage and generation: 15 × 15 tiles, 225 bits, one felt per layer |
| Window | The board on which a tick is computed: 15 × 15 tiles, assembled from 1 to 4 chunks, origin on an even row |
| Sight | Hexagon of radius 6 around the adventurer |
| Board | A bitmap of tiles held in one felt |
| Mirror | The part of the library that follows `hexx` name for name |
| Extension | The part that `hexx` does not have |
