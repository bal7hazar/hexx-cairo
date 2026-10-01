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
| `LineTrait::line`, table path | 11,150 | [7,399, 9,249] | M1-T6 | The lookup proper measures 7,110, at the sketch's sum; the rest is the bounds check the contract requires (1,940) and the call taking a `HexMap` by value (about 2,100), neither in the sketch. `line_of_sight` on the same case is in its range (17,706). No line call in the tick (§7) |
| `LineTrait::approach`, ring target | 86,046 | [62,827, 78,534] | M1-T6 | `edge_neighbors`: six `neighbor` calls, each far above the sketch's 3,696; not in the tick |
| `HexTrait::line_to`, `N = 22` | 169,230 | [68,310, 85,388] | M1-T6 | The mirror, off the board's paths; about 7,300 per element against the sketch's 2,970 |
| `SeamTrait::side` | 3,840 | [3,032, 3,790] | M1-T7 | The sketch leaves out the `NonZero` conversion, two products and the `match` on `Side`; not on the tick |
| `HexagonTrait::hexagon`, loop path, 16 rows | 128,670 | [72,064, 90,080] | M1-T5 | About 5,840 per row against the sketch's 4,504; the tick reads the sight on the table path (16,430) |
| `HexagonTrait::hexagon`, loop path, 83 rows | 519,840 | [373,832, 467,290] | M1-T5 | idem; the domain-wide worst case (3 × 83, radius 255) |
