# PENDING — LIB-03: three fix loops used, the audit still fails

| | |
|---|---|
| Asked by | `[Fable 5.1]` Orchestrateur hexmap (lib), 2026-09-28 |
| Decides | The owner, through the project manager (the game's `OPERATIONS.md` §6: "after three fix loops on the same lot, escalate") |
| Lot | LIB-03, the porting plan: pull request #9, branch `docs/lib-03-porting-plan`, **not merged**. CI green |
| Blocks | Gate L-G2, and through it LIB-04 and LIB-05 |
| State | **Open.** No agent is running. Nothing is launched until the answer |

## What happened

| Pass of `[GPT-6-Astra]` | Verdict | Findings open after the pass | Of which major |
|---|---|---|---|
| [1](../audits/LIB-03-audit-gpt-6-astra-pass-1.md) | FAIL | 20 | 18 |
| [2](../audits/LIB-03-audit-gpt-6-astra-pass-2.md), after fix loop 1 | FAIL | 17 | 15 |
| [3](../audits/LIB-03-audit-gpt-6-astra-pass-3.md), after fix loop 2 | FAIL | 17 | 13 |
| [4](../audits/LIB-03-audit-gpt-6-astra-pass-4.md), after fix loop 3 | FAIL | **6** | **3** |

Every finding was verified by the implementer (`[Fable 5.1]`) before it was fixed; none was
disputed. The orchestrator checked a sample of each pass by hand and found it right. The
auditor read the sources itself and ran its own in-memory checks.

What the audit now confirms, by independent recomputation: the 45 regression cases except
one, the 57 operation totals and 51 range bounds of the gas section, the tick range
**1,337,678 to 1,672,098** (an estimate, conditional on the stated inputs; nothing was
measured), the assembly of the 15 × 16 window on its 225 offsets, the 65,536 origins, the
seams, the geometric masks, the integer line and its deviations from `hexx`, the flood
fixtures; no dependency on Dojo; Cairo 2.19; a demonstrable exit criterion for N-9.

## What remains open

| # | Severity | What | Blocks an implementer | Size of the fix |
|---|---|---|---|---|
| 42 | major | Regression case R-N4-1 (cut by a mask) names tile 8 of a 7 × 7 board as an edge tile; it is interior tile `(1, 1)`. The case contradicts the contract | Yes (LIB-05, N-4) | One index and one expected value |
| 33 | major | Flood: the oracle requires every step to be interior, while the contract lets a walker step onto the source when the source is an open edge tile | Yes (LIB-05, N-8) | One clause: "interior, or equal to `from`"; one assertion |
| 27 | major | Task graph of milestone L-M2: two dependencies are missing between its tasks | No for LIB-04 and LIB-05; yes for L-M2 later | Two edges, or one more item in the bootstrap task |
| 14 | minor | Two helper rows of the gas table do not follow the exact-sum rule | No | Two rows |
| 30 | minor | Two summaries quote superseded figures | No | Two lines |
| 39 | minor | Three conservative bounds are presented as attainable benchmark cases; one tie description is wrong | No | Three labels, one line |

## Why the loops did not converge in three

The brief of LIB-03 asked for algorithms and gas figures per function, in a document, with
no code and no measurement. The first draft was too optimistic (the tick at 740k; it is now
estimated at 1.34M to 1.67M) and its formulas were wrong on valid inputs. Each loop fixed
what the audit had found and the next pass, reading deeper, found the next layer. From fix
loop 2 the plan separates what is **normative** (the contract of each function: signature,
domain, semantics against a scalar oracle, tie-breaks, worst case, regression cases) from
what is a **design sketch** (masks, shifts, tables), which LIB-05 must prove against the
oracle and may replace; gas figures that are not measured are target ranges. That is the
orchestrator's doing and its responsibility: the brief should have been framed this way from
the start.

## Options

| | Option | Cost | Risk |
|---|---|---|---|
| **A** | **A fourth fix loop, limited to the six findings above, then a fifth audit pass limited to them and to what they touch.** Merge if no major remains. If a major remains, fall to B without another loop | One short resume of the implementer, one audit pass | Low: the fixes are small and named. The pass may still find something new |
| B | Merge the plan as it is, with the six findings listed in it as open points; they are carried into the briefs of LIB-05 (N-4, N-8) and of L-M2 | None now | Two contradictions stay in a normative document until LIB-05 is briefed |
| C | Stop and restructure: the plan keeps scope, milestones, releases and decisions; the contracts of the ten functions move to one specification per function, each written and audited with its task | A new task, a new brief, days | Delays L-G2, L-M1 and the game |

## Recommendation of the orchestrator

**A.** The trend is convergent (20, 17, 17, 6 findings; 18, 15, 13, 3 majors), what remains
is small, and two of the three majors are one-line contradictions that an implementer would
hit on the first day. A fourth loop costs less than carrying them. It is an exception to the
rule of three loops, which is why it is asked and not taken.

Whatever the option, the orchestrator proposes to write in the plan and in the briefs of
LIB-05 that **no figure of the plan is a budget**: budgets are set from measurements.

## Answer

*To be filled with the decision and its date.*
