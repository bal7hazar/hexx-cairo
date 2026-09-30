# [GPT-6-Sol] Audit — M1-T4b — N-4, the cut

## Verdict
PASS

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| — | — | — | None | — | — |

## Coverage

Read the brief, COMMON §4, plan §§6.4–6.5 and §14, and the changed implementation, tests, consumer call site, snapshots, and takeover file list. `cut` implements `grid & mask & board`, preserving dimensions, seed, and masked ring bits. The per-tile oracle covers 32 seeded pairs at each required size. The `local` column and row sweeps cover each axis of every permitted window; the implementation combines those axes independently.

Recomputed R-N4-1 as `0xc38f0c08` with the full mask and `0xc38f0c00` without ring bit 3; R-N4-3 yields zero. R-N4-2 follows from clearing mask bits above the board. Every new snapshot budget equals `ceil(1.05 × measured)`; the measured cut difference is 10,122, below the plan’s upper bound. The diff changes no taken-over engine file. The orchestrator’s `OWN_FILES` entries include both new files.

`git diff --check`, parity and extensions checks, and the gas-table check passed. The takeover check skipped because its source checkout is absent. I could not rerun Cairo tests or the full gate in this read-only workspace, so the runtime results are supported by the committed measurements rather than a fresh test run.
