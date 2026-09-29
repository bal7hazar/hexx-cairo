# [GPT-6-Sol] Audit — M1-T1c — the gas gate

## Verdict

**FAIL.** The package split and removal of the baseline are in place, but the exact budget requirement is unmet, the three newly budgeted ignored tests have no committed measurements, and the drift artefact can lose the hash from the failing run.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | Major | `gas/hexx.snap`; `scripts/bench.py:443` | Nine budgets do not equal `ceil(1.05 × measured)`. **Blocks M1-T4a: Yes.** | For example, `bench_rng_draw` records 562,744 measured and 589,000 budget; the exact value is 590,882. All nine are within the gate’s permitted interval, so CI accepts them. They predate this PR, but the requested every-budget equality is unmet. | Resolve the exact-equality requirement against the existing lower-budget decision, then update the nine budgets and snapshots if equality governs. |
| 2 | Major | `crates/hexx/src/tests/bench_caver.cairo:842`; `scripts/bench.py:428` | The three newly budgeted ignored tests are outside the committed snapshot and their budgets are not checked against a measurement. **Blocks M1-T4a: Yes.** | They have no rows in `gas/hexx.snap`. `budget_violations` explicitly accepts an unmeasured test that has a budget. `REPORT.md` gives measurements from `--include-ignored`, but provides no committed measurements with the attributes included; the normal second passes did not run ignored tests. | Measure these tests with their attributes present, commit the measurements, and add a CI check for them. |
| 3 | Major | `scripts/bench.py:264`, `scripts/bench.py:527`; `.github/workflows/ci.yml:153` | The Digger reruns overwrite `artifacts.sha256` from the initial gas check. **Blocks M1-T4a: Yes.** | Each of the check, repeat 1, and repeat 2 calls writes the same hash filename. A drift in the initial check followed by a different compile in a repeat leaves only the final hash; the uploaded evidence cannot distinguish compiled artefact drift from measurement drift. The claim that the repeats used the same compiled code is also unverified. | Save hashes separately for the check and both repeats, and compare the repeat hashes before calling their measurements a same-code comparison. |
| 4 | Moderate | `scripts/bench.py:574` | A budget violation suppresses the requested snapshot-mismatch details. **Blocks M1-T4a: Yes.** | `check` returns on `budget_violations` before `snapshot_differences`. If a measurement rises beyond its budget, the output lacks the snapshot figure, current figure, and artefact location promised for a mismatch. | Compute and print snapshot differences and the evidence location even when budget violations also occur. |

## Coverage

My `git diff origin/main...HEAD` check found **1,159 changed Cairo lines, all solely `#[available_gas(l2_gas: N)]` lines**, and no changed file outside the allowlist. `takeover_check.py` strips only whole attribute lines, so a comment or code sharing a line remains visible; it **can hide removal of an entire gas attribute**. The budget gate catches a missing attribute on a declared test.

The old baseline, inherited-test list, and their exemptions are removed. The previous measured-test interval, discovery, reconciliation, and snapshot checks remain. The three CI gas matrix legs match the three workspace packages; each selects its package once, and `all-checks` depends on the matrix job. Actions are commit-pinned, with no secret or context expression interpolated into a `run` step. `REPORT.md` reports job times of 6m32s, 2m32s, and 27s.

This was a read-only audit. I did not run the build or gas gate. GitHub access failed, so I could not independently confirm the reported CI run or timings.
[exited with code 0]
