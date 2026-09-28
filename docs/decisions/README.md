# Decisions

One file per decision of the owner. An open question is `PENDING-<gate>.md`: the question, the
options, the orchestrator's recommendation. Once decided, the file is renamed after the
decision and records the answer and its date.

| Gate | Question | State |
|---|---|---|
| L-G1 | Is a port of `hexx` relevant, and where does it land? | **Decided** 2026-09-28: full parity where it makes sense, plus extensions; in this repository; `origami_hexmap` decommissioned at the end. [L-G1](L-G1-hexx-port.md) |
| L-G2 | Is the porting plan accepted? | **Decided** 2026-09-28: accepted with two conditions; package `hexx`; no publication without the owner's go. [L-G2](L-G2-porting-plan.md) |
| LIB-03 | Three fix loops used, the audit still failed: what next? | **Decided** 2026-09-28 by the project manager: a fourth, limited loop, then merge with open points. [LIB-03 fix loops](LIB-03-fix-loops.md) |
| LIB-04 | Three fix loops used, the audit still failed: what next? | **Decided** 2026-09-28 by the project manager: merge, the three findings as task LIB-04b before the first release candidate. [LIB-04 fix loops](LIB-04-fix-loops.md) |
