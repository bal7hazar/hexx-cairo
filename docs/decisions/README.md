# Decisions

One file per decision of the owner. An open question is `PENDING-<gate>.md`: the question, the
options, the orchestrator's recommendation. Once decided, the file is renamed after the
decision and records the answer and its date.

| Gate | Question | State |
|---|---|---|
| L-G1 | Is a port of `hexx` relevant, and where does it land? | **Decided** 2026-09-28: full parity where it makes sense, plus extensions; in this repository; `origami_hexmap` decommissioned at the end. [L-G1](L-G1-hexx-port.md) |
| L-G2 | Is the porting plan accepted? | **Open** since 2026-09-28: [PENDING-L-G2](PENDING-L-G2.md) |
| LIB-03 | Three fix loops used, the audit still failed: what next? | **Decided** 2026-09-28 by the project manager: a fourth, limited loop, then merge with open points. [LIB-03 fix loops](LIB-03-fix-loops.md) |
