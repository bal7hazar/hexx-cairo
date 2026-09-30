## Figures accepted above their range

Written by the orchestrator, never generated. A measurement above the upper bound of its range in
§7 of the plan is accepted here with its reason, and in §14 of the plan for the audits. The project
manager's rule (2026-09-30, D-144's logic): an accepted figure that moves the library's share of a
worst tick (1,066,089 cave, 1,113,746 serpentine, M1-T9b) or of a reveal by more than 10 % goes to
the project manager before the merge; under that, the orchestrator decides.

| Function | Measured | Range of §7 | Task | Reason |
|---|---:|---|---|---|
| `FloodTrait::depth` | 670 | [200, 250] | M1-T9a | 8 calls per tick, about 5,400: under 0.6 % of the worst tick |
| `Hex::length` | 7,257 | ranges at ~300 per `i32` operation | M1-T2 | The mirror is not on the tick's path; the ranges assumed 300 per `i32` operation |
| `Hex::ulength` | 9,579 | idem | M1-T2 | idem |
| `Hex::distance_to` | 8,722 | idem | M1-T2 | idem |
| `Hex::unsigned_distance_to` | 11,043 | idem | M1-T2 | idem |
| `to_offset_coordinates`, `from_offset_coordinates` | 7,183 | idem | M1-T2 | idem |
| `EdgeDirection::const_neg` | 1,785 | idem | M1-T2 | idem |
| `EdgeDirection::counter_clockwise` | 1,868 | idem | M1-T2 | idem |
