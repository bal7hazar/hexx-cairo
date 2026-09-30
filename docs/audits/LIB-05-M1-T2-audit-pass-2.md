# [GPT-6-Sol] Audit — M1-T2 — the mirror items (pass 2)

## Verdict
PASS WITH FINDINGS

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | — | `bb457cc:scripts/api_parity.py:1414,1509` | **Resolved.** Unknown public mirror impls now raise; declared and generated traits remain accepted. | Running the `bb457cc` parser in memory, my `CustomTrait<HexOrientation>` probe raised `src/orientation.cairo:47` with the trait name. Declared and generated trait controls produced no error. | None. |
| 2 | — | `bb457cc:crates/hexx/src/tests/test_hex.cairo:8`, `test_conversions.cairo:11` | **Resolved.** The four oracle helpers are scoped in `OracleImpl` and `OffsetOracleImpl`. | The diff preserves their calculations and updates call sites. A scan of both revised files found no remaining free helper with the four names from pass 1. | None. |
| 3 | note | `2379a74:scripts/bytecode_size.py:116–141` | The D-164 guard accepts a third value **if someone adds it to** `gas/bytecode.builds`; the parser does not limit a contract to one alternative record. | With the committed record, an unrecorded third value and a changed contract name both returned `False`. Supplying two alternative records made the third value return `True`. Adding a record requires a deliberate repository edit, so this is a note under the audit severity rule. | Reject more than one alternative record per contract when reading `bytecode.builds`. |

## Coverage

I reviewed the changed files at `bb457ccff5aa853e28674dad5dc86ff641a963f5` and ran the parser and class-size probes above against code read from that commit. The committed D-164 record admits the snapshot and its exact second build; an unrecorded third value, a new contract name, and a removed contract all failed the probes.

`git fetch origin` failed because `FETCH_HEAD` is read-only, and `git checkout bb457cc…` failed because Git could not create `index.lock`. I used read-only `git show` of the locally available target commit. Cairo tests and a build were therefore not rerun.
