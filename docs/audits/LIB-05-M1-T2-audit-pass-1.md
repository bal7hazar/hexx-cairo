# [GPT-6-Sol] Audit — M1-T2 — the mirror items (pass 1)

## Verdict
FAIL

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | major | `scripts/api_parity.py` | A public impl using an unrecognized `…Trait` is silently omitted, contrary to the required file-and-line failure. | I injected `pub impl FooImpl of CustomTrait<HexOrientation> { … }` into an in-memory module tree. The scan returned no item and raised no error. The `trait.endswith("Trait")` branch skips it before ownership is checked. | Resolve the trait against known declarations; raise with file and line when a public mirror impl cannot be classified. Add a regression test. |
| 2 | minor | `test_hex.cairo`, `test_conversions.cairo` | Four test helpers are free functions without the written reason required by COMMON.md §4. | `oracle_distance`, `oracle_shove`, `oracle_to_offset`, and `check` are module-level functions. | Scope the helpers in traits and impls, or document why each must be free. |

## Coverage

I compared the M1-T2 items with the local `hexx` source at tag `0.25.0`, commit `b6b9afb1a6d413817509d00ce9ec6b9d52339a7c`. The reviewed Cairo formulas, names, signatures, direction order, and documented overflow behavior matched that source. Read-only checks verified the values in 4,096 seeded hex pairs, 1,536 rotations, 256 seeded offset conversions, 566 successful hex boundary vectors, and 816 successful offset boundary vectors. `api_parity.py --check` and `deviations.py --check` passed; the L-M1 report listed only `Hex::line_to`.

Byte-for-byte regeneration and Cairo tests could not run under this read-only profile: Cargo failed while creating `tools/refgen/target…`, and Python fixture tests failed while creating `scripts/tests/tmp`. The class-size difference identified as D-154 was excluded from findings.
