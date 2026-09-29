# [GPT-6-Astra] Audit — M1-T9a — N-8, the flood

## Verdict

**PASS WITH FINDINGS**

No flood correctness defect found. The finding below does **not block M1-T9b**.

Audited `origin/main...HEAD` at `97a335217a7af8fcf9bed0815a2eff4bdbf3943b`. Independent execution covered Python models and read-only checks; Cairo tests, fresh gas measurements and CI status could not be independently verified.

## Findings

| # | Severity | Location | Finding | Evidence or failing scenario | Suggested fix |
|---|---|---|---|---|---|
| 1 | Minor | scripts/takeover_check.py:74–87; scripts/tests/test_takeover_check.py::OnlyAdditions | The guard proves textual subsequence preservation, which permits changes to existing behaviour when the original text survives elsewhere. **Does not block M1-T9b:** the actual additions were independently checked and do not exploit this limitation. | In the rewritten original `BfsInternal::check_one`, replace its walkability assertion with `assert(true, errors::BFS_POSITION_NOT_WALKABLE);`, followed by the original assertion inside a multiline comment. Executing `only_additions` returns `True`, although the original check is disabled. A duplicated or earlier reordered block likewise passes when a complete original subsequence remains. This satisfies the predicate’s documented definition, but cannot establish behavioural preservation. | Restrict additions to approved new imports/declarations and compare existing function bodies exactly. Add adversarial tests retaining replaced code in comments or duplicated blocks. Keep the independent behavioural audit. |

## Coverage

