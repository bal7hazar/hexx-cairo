# [GPT-6-Astra] Audit — M1-T9b — N-8, steps and tick (pass 1)

## Verdict

**FAIL**

One major mismatch with D-127 in the tick caller. The selection functions and new ring computation match the normative §6.9 contract in my independent models.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | Major | crates/hexx/src/tests/bench_tick.cairo:152; crates/hexx/src/tests/test_steps.cairo:453 | The tick moves a walker at distance **16**, despite D-127 requiring a goblin without a path within **15 steps** to hold. Capping the stored flood at layer 15 does not enforce that game rule: the library legitimately selects a neighbour in layer 15 for a walker outside the layers. | Independent scalar reproduction: SERPENTINE_15X16, source 127, cap 15, walkers in ascending id order `[95,31,32,33,34,181,182,183]`, all frozen as obstacles. W1 at 95 has inferred distance 16; tile 96 is in layer 15. Tick::steps moves W1 to 96. The existing boundary test also explicitly expects this library behaviour. D-127’s accepted explanation says a goblin without a path within 15 steps stays put: sources/grimworld/docs/decisions/2026-09-28-L-G2-porting-plan.md:52. Neither benchmark fixture exposes this boundary. | Preserve the library’s normative selection contract. Enforce the game’s requested distance cap in the tick caller, add distance-15/distance-16 regressions with frozen walkers, and remeasure the tick including that check. Escalate any proposed reinterpretation of D-127 to the orchestrator. |

## Coverage

