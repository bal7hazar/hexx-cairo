# [GPT-6-Sol] Codex review — pull request 49 (M1-T2), pass 1

## Verdict
FAIL

## Revision
`87fe239cf11193d95564d8a436544f5b68b2fbd4`, compared with `origin/main`.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | major | `bench_mirror.cairo` | Measured mirror costs exceed the brief’s stop threshold, but budgets were set. | The brief requires stopping above §7’s upper bound of 1,875 gas for these `Hex` methods. The committed measurements for `length` and its operand baseline are 1,905,330 and 453,990 gas. The benchmark’s 200 calls give a derived 7,256.7 gas per call. `ulength` and both offset conversions also exceed 1,875 by the same benchmark calculation. | Apply the brief’s stop condition: report the measurements and obtain a decision on the bounds before accepting budgets. |
| 2 | minor | `edge_direction.cairo` | Deserialization can bypass the documented `0..=5` index invariant. | `Serde` accepts a struct containing any `u8`. An external caller can supply index `12`; `rotate_cw(0)` subtracts six only once and returns index `6`, while `into_hex()` indexes past the six-element array. The type documentation says these methods cannot panic. | Validate the index when decoding it, or handle invalid indices in the methods and document that behavior. Add a test through a deserialized input. |
| 3 | minor | `tmp/t.txt` | Temporary working files are committed outside the task allowlist. | `git ls-files tmp` lists `tmp/scope.py` and `tmp/t.txt`; `git diff --check origin/main...HEAD` fails on a trailing blank line in `tmp/t.txt`. This violates AC-5. | Remove the two temporary files from the PR. |

## Coverage
Read the branch diff, brief, plan §14 and relevant contracts, Cairo implementations and tests, Rust `hexx` 0.25.0 source, generator, snapshots, and CI changes. Parity, deviation, extension, and gas-table checks passed; the release report lists only `line_to` missing. I could not run build or Cairo tests in this read-only checkout. The Python unit suite also could not complete because its fixtures create `scripts/tests/tmp`; its reported errors were filesystem errors.
