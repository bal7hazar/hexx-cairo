# PENDING — LIB-04: three fix loops used, the audit still fails

| | |
|---|---|
| Asked by | `[Fable 5.1]` Orchestrateur hexmap (lib), 2026-09-28 |
| Decides | The project manager (the game's `OPERATIONS.md` §6 and §10: after three fix loops the orchestrator escalates; the project manager decides and reports to the owner) |
| Lot | LIB-04, workspace and tooling: pull request #18, branch `feat/lib-04-workspace-tooling`, **not merged**. CI green (10 checks) |
| Blocks | LIB-05, whose first task (M1-T1, the take-over of the engine) depends on LIB-04 |
| State | **Open.** No agent of the library is running. Nothing is launched until the answer |

## What happened

| Pass of `[GPT-6-Sol]` | Verdict | Findings open after the pass | Blocker | Major |
|---|---|---|---|---|
| [1](../audits/LIB-04-audit-gpt-6-sol-pass-1.md) | FAIL | 11 | 2 | 7 |
| [2](../audits/LIB-04-audit-gpt-6-sol-pass-2.md), after fix loop 1 | FAIL | 13 | 0 | 9 |
| [3](../audits/LIB-04-audit-gpt-6-sol-pass-3.md), after fix loop 2 | FAIL | 6 | 1 | 4 |
| [4](../audits/LIB-04-audit-gpt-6-sol-pass-4.md), after fix loop 3 | FAIL | **3** | 0 | **3** |

Closed and confirmed by the auditor: no workflow of the repository publishes or reads a
secret (the publication workflow was deleted after rule D-132); no context or input reaches a
shell except through a quoted variable; the release check verifies a full commit hash, the
`main` workflow revision and the absence of the tag, and fails closed; the gas gate discovers
every unit and integration test; the parity inventory of `hexx` 0.25.0 has 692 items and
matches a fresh parse; on the module layout of the plan, the extension inventory finds the 20
functions of `HexMapTrait` and 206 public items of the engine to take over.

**Auditor's statement, pass 4: "M1-T1 coding can proceed."**

## What remains open

| # | Severity | What | Blocks M1-T1 | Blocks the first release candidate | Size of the fix |
|---|---|---|---|---|---|
| New 1 | major | Parity tool: a re-export through a chain (`pub use` of a `pub use`), and two exports of the same item under two names, are silently dropped. Decision "never silently wrong" not met | No | No, for the planned layout | Resolve re-exports transitively and keep every exported name, or raise with file and line |
| New 2 | major | Release check: a stable version with a hyphen in its build metadata (`0.1.0+build-1`) takes the informational branch meant for pre-releases | No | No. Yes for a stable release with such a version | Test the hyphen before the `+`, a few lines |
| P2-13 | major | Release check: for a pre-release, the list of missing items goes to stderr, so the job summary and the artifact are empty; only 40 of 66 items are printed | No | Yes, under the documented review of the artifact | Capture both streams, list every item |

## Options

| | Option | Cost | Risk |
|---|---|---|---|
| **A** | **A fourth fix loop, limited to the three findings**, by resuming the same implementer (`[Sonnet 5]`), then a fifth audit pass limited to them and to what they touch. Merge if no blocker or major remains; otherwise B without another loop | One short resume and one audit pass | Low: the three fixes are small and named |
| B | Merge now. The three findings become a task of their own (LIB-04b, `[Sonnet 5.5]`), to be merged **before the first release candidate**; M1-T1 starts at once | None now; one more task later | `main` carries a release check and a parity gate known to be wrong in three cases until LIB-04b |
| C | Stop and re-scope the parity tool (for example on `rustdoc` JSON, the alternative D-11 of the plan) | Days | Delays L-M1 |

## Recommendation of the orchestrator

**A**, with the fallback to B written in it. Three passes show a lot that converges (11, 13,
6, 3 findings) and whose security part is closed. What remains costs less to fix now, with
the implementer's context still warm, than to carry as a known defect of the gates that every
task of LIB-05 will rely on. It is an exception to the rule of three loops, which is why it
is asked.

Not C: the parity tool now inventories both trees correctly for every form they use, and
raises on the others; what remains is two forms of re-export.

## Answer

*To be filled with the decision and its date.*
