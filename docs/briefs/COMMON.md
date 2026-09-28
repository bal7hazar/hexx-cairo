# COMMON — rules every brief inherits

Adapted from `OPERATIONS.md` and `docs/CAIRO.md` of `bal7hazar/grimworld`, which remain the
reference. When the game's launcher (`scripts/agent.sh`, profiles) is merged there, it is
adopted here and this file is aligned with the game's `docs/briefs/COMMON.md`.

## Every task

| Rule | |
|---|---|
| One task | One worktree, one branch, one pull request, one `REPORT.md` at the worktree root (not committed; the orchestrator archives it in `docs/reports/`) |
| Foreground only | Never start a background command. **Your turn ends when `REPORT.md` is written and the pull request is open** |
| Allowlist | Write only the files the brief lists. Anything else is an escalation, written in `REPORT.md` |
| Shared files | Never edit `PLAN.md`, `STATUS.md`, `README.md`, `docs/briefs/`, `docs/decisions/`, CI |
| Never merge | The orchestrator merges, on green CI |
| Ambiguity | If the design or the brief is ambiguous, stop and report it. Do not invent a rule |
| Titles | `REPORT.md`, the pull request and every report start with the model in brackets: `[Opus 5.5] LIB-02 …` |
| Commits | Conventional commits, in English; trailer `Co-Authored-By: Claude <Model> <noreply@anthropic.com>` with the model's display name |
| Branch | `<type>/<task-id>-<slug>` |
| Language | English |
| Evidence | A claim about a source cites the file and the line or symbol, at a stated version or commit. What is inferred is marked as inferred |
| Secrets | None in the repository, the log or the report |

## Every Cairo task (from LIB-04 on)

The game's `docs/CAIRO.md` in full. In short:

| Rule | |
|---|---|
| Test-driven | Tests first, from the brief's acceptance criteria |
| Gas is a test result | `#[available_gas(l2_gas: N)]` on every test, `N = ceil(1.05 × measured)`; benchmarks on the worst case; figures in `GAS.md` and in the report |
| Execution cost first | Over contract size; tables over run-time computation |
| Order of preference | Plain arithmetic, then bitwise operations, then loops as a last resort, bounded |
| Types | No `u256` without a written reason; `u252` for bitmaps and packed values; smallest integer that holds the value |
| Oracles | An optimised algorithm is tested against a plain, obviously correct version kept in the tests |
| Checks | Package-scoped locally; the pull-request CI is the full gate |

## A port

| Rule | |
|---|---|
| Mirror the crate | Same module and function names, same API where it makes sense on-chain |
| Deviations | Each one documented, with its reason |
| Parity table | Generated, checked in CI |
| Numeric results are API | A change in a result for the same input is a versioned change |

## Glossary

| Term | Meaning |
|---|---|
| Tile | A pointy-top hex with global coordinates `(x, y)` in its location |
| Chunk | Unit of storage and generation: 15 × 15 tiles, 225 bits, one felt per layer |
| Window | The board on which a tick is computed: 15 × 15 tiles, assembled from 1 to 4 chunks, origin on an even row |
| Sight | Hexagon of radius 6 around the adventurer |
| Board | A bitmap of tiles held in one `u252` |
