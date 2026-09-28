# [Fable 5.1] Window and row parity — check of the library's code

Asked by the project manager on 2026-09-28, after the owner's decision that the window follows
the adventurer and is recomputed at each tick. Written by the orchestrator, in session,
read-only. Source: `origami_hexmap` 1.8.0, `dojoengine/origami` at `04ab30c`; paths are
relative to `crates/hexmap/`. **Nothing was run or measured**: figures marked *measured* are
quoted from the library's `GAS.md`; the others are estimates.

## Answers in short

| # | Question | Answer |
|---|---|---|
| 1 | Must the origin of a board be on an even global row? | **Yes.** Every neighbour is derived from the parity of the **local** row. A window therefore moves vertically by 2 rows at a time. No public function takes an odd origin |
| 2 | On 15 × 15, does sight of radius 6 reach the ring for half of the positions? | **Confirmed.** A goblin there is shown and cannot be simulated correctly |
| 3 | Remedy | **(a), the window of 15 × 16.** Same cost per layer as 15 × 15, no change to the engine's finders. Nothing forbids `H ≠ W` or `H = 16`; the two-limb path is unchanged |
| 4 | Fallback sizes | **Confirmed**: `W = 2r + 3`, `H = 2r + 4`. Sight 5 → 13 × 14 = 182 tiles; sight 4 → 11 × 12 = 132 tiles. **Both are on the two-limb path.** "11 × 12 with sight 5" does not hold |

## 1. The origin must be on an even row

The parity that decides the neighbours is always the parity of the row **inside the board**:

| Where | What it does |
|---|---|
| `src/types/direction.cairo:7-14` | The neighbour table: North-East is `i + W − 1` on an even row and `i + W` on an odd row, and so on |
| `src/helpers/layout.cairo:334-336` | `neighbor`: `odd = y % 2 == 1`, with `y` the local row |
| `src/helpers/layout.cairo:317-324` | `parity`: from `position mod 2W`, local |
| `src/helpers/layout.cairo:273-284` | `neighbour_mask`: picks the offsets of the odd or of the even row from `parity` |
| `src/helpers/layout.cairo:101-112` | `even`: the mask of the even rows, built from local row 0 |
| `src/helpers/layout.cairo:401-424` | `dilate`, the step of every flood: `rows = 2·pairs − (pairs & even)`, so even rows shift by `2^(W−1)` and odd rows by `2^W` |
| `src/finders/bfs.cairo:1177`, `src/finders/dial.cairo:198, 753` | Backtracking: parity of the local row again |
| `src/helpers/geometry.cairo:20-24, 39-40` | Distance: `q = x − ⌊y/2⌋` with the local `y` |

If local row 0 is an odd global row, all of these use the wrong table: diagonal neighbours
are off by one column, and the distance is wrong whenever the two rows have different
parities. The board is a different hex grid from the map.

**Is there an existing way to give a board an odd origin? No.**

- `LayoutTrait::new(width, height)` (`src/helpers/layout.cairo:68`) and every finder and
  generator take the dimensions only.
- The closest thing is `Direction::next(position, width, odd)`
  (`src/types/direction.cairo:62`), which takes the parity as an argument, and the public
  fields of `Layout` and `Dilation` (`src/helpers/layout.cairo:31-57`): a caller could build
  a `Dilation` by hand with the mask of the **odd** local rows in place of `even`, and the
  dilation would then be right for an odd origin with the same `up` and `down` (inferred from
  the formula of `dilate`, not tested). Nothing else follows: the finders build their own
  constants, and `neighbor`, `neighbour_mask`, `parity`, the backtracking and the distance
  have no such input.

## 2. Sight reaches the ring on 15 × 15: confirmed

| | |
|---|---|
| Width | 15 columns: ring at columns 0 and 14, interior 1 to 13, centre 7. Sight of radius 6 spans columns 1 to 13 **whatever the parity of the centre row** (`GAS.md:115`, hypothesis 5: "15x15 … whatever the centre-row parity"). Horizontal centring is exact for every position, since a horizontal move of the origin does not change any row parity |
| Height | The origin row is `g − local row` and must be even. Global row `g` odd: local row 7, sight spans rows 1 to 13, inside. **Global row `g` even: local row 6 or 8, sight spans rows 0 to 12 or 2 to 14, and touches the ring** |
| How much | The row of the hexagon at distance 6: 7 tiles of the ring |

What the ring is for the computation:

- A flood only holds and expands interior tiles: "a bitmap that is expanded only holds
  interior tiles" (`src/helpers/layout.cairo:5-8`). The ring is never in a layer.
- "A path may start or end on an open edge tile but never crosses one" (`README.md:63-66`).

So a goblin on the ring is within sight and **shown**; it is in no layer of the flood, no
goblin can step onto its tile or along the ring, and its own step can only be the special
case of an edge endpoint entering the interior. With the ring imposed as wall when the window
is assembled (ADR-0006 §4), it is simply not simulated. The project manager's statement holds.

## 3. The two remedies

| | (a) Window of 15 × 16, origin always even | (b) Window of 15 × 15, odd origin through a parity flag |
|---|---|---|
| Sight of radius 6 | Inside the ring always: adventurer on local row 7 (global row odd) or 8 (even); sight spans rows 1 to 13 or 2 to 14, interior is 1 to 14 | Inside always: adventurer on local row 7, exact fit |
| Allowed by the library today | **Yes.** `assert_valid_dimension` asks only `W, H ≥ 3` and `W·H ≤ 251` (`src/helpers/asserter.cairo:51-56`); 240 ≤ 251. `even` has a branch for an even height (`src/helpers/layout.cairo:105-109`). The README lists 16x15 among its examples (`README.md:77`), and the tests run 17x14, 19x13, 25x10, 8x16 (`GAS.md:114, 143`) | **No.** See §1 |
| Change to the engine taken over | None in the finders | The flag goes through the layout, `neighbor`, `neighbour_mask`, `parity`, the backtracking of both finders, and the distance |
| Results identical to 1.8.0 | Yes, by construction | For an even origin only; the odd origin is a second set of results to freeze and to test, for every algorithm |
| Limb path | Two limbs: 240 > 128 (`src/finders/bfs.cairo:28-29, 260`). Same as 225 | Two limbs |
| Cost per flood layer | ~19.3k, *measured* on 17 × 14 = 238 tiles (`GAS.md:156`). The operations of `dilate` do not depend on the size within a path: **no difference with 15 × 15** *(estimate)* | The same per layer. Per call: one subtraction to complement the mask and a selection of constants, a few hundred gas *(estimate)* |
| Number of layers | At most one more than on 15 × 15 in open ground, ~19k *(estimate)* | Unchanged |
| Assembly | Width 15 = width of a chunk: moving a chunk into the window is still **one** shift by `dy·15 + dx`, after a mask of columns and rows. A window of 16 rows always overlaps exactly 2 rows of chunks (16 > 15), and 1 or 2 columns: **2 or 4 chunks**, never 1, never more than 4 | 1, 2 or 4 chunks |
| Tables (range, line of sight) | Per parity of the centre row: 2 sets | 2 sets as well (per parity of the origin) |

**Recommendation: (a).** Both cost the same in the hot path; the difference is elsewhere.
(a) is a board the library already accepts, so the finders are taken over unchanged and
their results stay those of 1.8.0. (b) adds a second parity to every algorithm of the tick,
each with its own results to freeze, to buy one row of 15 bits.

The parity flag is still needed, but **only for generation and seams** of the chunks that
start on an odd global row (chunks are 15 rows high): that is the project manager's answer to
point 2 of LIB-02, and it stays. With (a) it does not reach the tick.

Two consequences of (a) to write in the design:

| | |
|---|---|
| The adventurer is not at a fixed local tile | Local `(7, 7)` or `(7, 8)`. Anything indexed "from the centre" takes the local position as input |
| Need N-3 | "Assemble a board of 15 × 16 from up to 4 chunks of 15 × 15, the origin on an even global row being an explicit constraint of the function" (it should refuse an odd origin rather than return a board that is wrong) |

## 4. Fallback sizes

The rule `W = 2r + 3` is the library's own: "the hexagon of radius `radius` centred in its
`(2R+3) x (2R+3)` board, whose outer ring is left as wall" (`src/helpers/layout.cairo:128-129`;
`README.md:80`). With one more row for the parity, `H = 2r + 4`.

| Sight | Window | Tiles | Limb path |
|---|---|---|---|
| 6 | 15 × 16 | 240 | Two limbs |
| 5 | 13 × 14 | 182 | Two limbs |
| 4 | 11 × 12 | 132 | **Two limbs** (132 > 128) |
| 3 | 9 × 10 | 90 | Single limb |

- "11 × 12 with sight 5" is refuted: 11 columns hold a sight of radius 4. The same error is
  in ADR-0006 ("11 × 11 with sight 5").
- **The single-limb path** (~9.9k per layer against ~19.3k, *measured*, `GAS.md:156-161`) is
  out of reach of every fallback that keeps a sight of 4 or more under (a). A smaller window
  saves layers (fewer tiles to flood), not the cost of a layer.
- The only way to a single limb with sight 4 is 11 × 11 = 121 tiles, which needs remedy (b).
  If SPK-7 shows that the tick does not fit, that is the case in which (b) would be worth its
  price; not before.
