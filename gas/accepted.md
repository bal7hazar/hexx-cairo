## Figures accepted above their range

Written by the orchestrator, never generated. A measurement above the upper bound of its range in
§7 of the plan is accepted here with its reason, and in §14 of the plan for the audits. The project
manager's rule (2026-09-30, D-144's logic): an accepted figure that moves the library's share of a
worst tick (1,064,209 cave, 1,106,666 serpentine: `gas/hexx.snap` minus the baseline 30,250 of `bench_tick`, the last figures of M1-T9b) or of a reveal by more than 10 % goes to
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
| `Geometry::chunk_of` | 3,020 | [2,196, 2,745] | M1-T3 | Called by no benchmark of the tick, the assembly, the finders, the generators, the facade or `cut` (the agent's grep, M1-T3 report); the sketch charged 300 per `u8` operation |
| `Geometry::to_hex` | 2,750 | [1,998, 2,498] | M1-T3 | idem; one `DivRem` and a range-checked `try_into` |
| `Geometry::from_hex` | 3,840 | [2,198, 2,748] | M1-T3 | idem; the one attempt (`bounded_int` constrain, 3,990) was dearer |
| `Geometry::hex_to_index` | 5,370 | [2,998, 3,748] | M1-T3 | idem; inherits `from_hex`. The loop path of N-5's `line` calls it per step: M1-T6's ranges are derived from this figure |
| `LayoutTrait::neighbor_direction` | 9,640 | [4,294, 5,368] | M1-T3 | idem; the two bounds checks against `H` the contract requires are not in the sketch; the one attempt (one `DivRem` by `2W`, 12,020) was dearer. N-5's `approach` calls it once |
