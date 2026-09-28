# [Fable 5.1] LIB-03 — Porting plan of `hexx` to Cairo

Task: [LIB-03](../briefs/LIB-03-porting-plan.md), under [COMMON.md](../briefs/COMMON.md) and
[PLAN.md](../../PLAN.md). The plan is what the owner accepts or amends at gate L-G2. It binds
LIB-04 (repository, CI, tooling) and LIB-05 (milestone L-M1).

It is built on the decisions of [L-G1](../decisions/L-G1-hexx-port.md) and on the facts of
[LIB-02](LIB-02-hexx-analysis.md), whose recommendation L-G1 superseded. Where LIB-02 is
corrected or refined, the section says so.

## 0. Sources, versions, conventions

| Source | Ref | Commit | Path in the worktree |
|---|---|---|---|
| `hexx` (github.com/ManevilleF/hexx) | tag `0.25.0` | `b6b9afb1a6d413817509d00ce9ec6b9d52339a7c` | `sources/hexx/` |
| `origami` (github.com/dojoengine/origami), `crates/hexmap`, workspace 1.8.0 | `main` | `04ab30caf02dcc8d2ecc46e9596b81732eedcec1` | `sources/origami/crates/hexmap/` |
| Grim World documents (`bal7hazar/grimworld`) | `origin/main`, refreshed for D-120 | `0a3d85e26094ce3cc7b7e31542249a23d561939e` | `sources/grimworld/` |
| `hexx-cairo` `main` (`window-parity-check.md`, `PLAN.md`) | `origin/main` | `2af2b88a931c911ec8cf60f00a44776cb285348b` | `sources/hexx-cairo-main/` |
| `glam-cairo` (house style) | local HEAD | `dc03def57edb8260576af0567388242a6c0cc40f` | `sources/house-style/glam-cairo/` |
| `nalgebra-cairo` (house style) | local HEAD | `7177cf30734ca5c3edf216f66d5c97b6f4b0ff93` | `sources/house-style/nalgebra-cairo/` |

The versions are those of `sources/VERSIONS.md`, fetched on 2026-09-28 and refreshed the same
day after the owner's decision D-120 (the window follows the adventurer, is 15 columns × 16
rows, is recomputed at each tick and is not stored; chunks stay 15 × 15:
`grimworld:docs/needs/hexmap.md` § "N-3 in detail", `grimworld:docs/architecture/ADR-0006-chunked-maps.md`
§4, and the check of the library's code in `sources/hexx-cairo-main/window-parity-check.md`).
The plan is written against that decision; the point is no longer open. `origami_hexmap` 1.8.0
is published on scarbs.xyz (checked on 2026-09-28: one version, 1.8.0). No package named
`hexx` exists on scarbs.xyz on that date (its package page returns 404).

Toolchain of every figure marked *measured*: scarb 2.19.4, snforge 0.61.0, Sierra gas
(`sources/origami/crates/hexmap/GAS.md:140`).

Conventions:

- Paths into `hexx` are relative to `sources/hexx/` (`src/hex/mod.rs:903`); paths into
  `origami_hexmap` are relative to `sources/origami/crates/hexmap/` and, where ambiguous,
  prefixed `hexmap:`; game documents are prefixed `grimworld:`.
- **measured** marks a figure read from `GAS.md` or `README.md` of `origami_hexmap` 1.8.0;
  **estimate** marks a figure reasoned from measured primitives; **(inferred)** marks a
  conclusion drawn from the code, not stated by it. Nothing was run and nothing was measured
  in this task (brief, *Out*).
- "The mirror" is the part of the library that follows `hexx` name for name; "the extension"
  is the rest (COMMON.md §7).

## 1. Principles

### 1.1 The rule, function by function

Every public item of `hexx` 0.25.0 gets exactly one of four statuses. The test is applied to
the item's **signature and semantics**, in this order; the first test that fires decides.

| # | Test on the `hexx` item | Status | What the Cairo library does |
|---|---|---|---|
| 1 | Its **meaning** needs floating point, a screen, a mesh, a host engine, an allocator or a hash map, and no exact integer restatement of the same meaning exists (`f32` angles, world positions, `MeshInfo`, Bevy, `HashMap<Hex, T>`) | **excluded** | Nothing exists under that name ("no stubbed success", house rule). The parity table records the reason |
| 2 | Its meaning is integer or has an **exact rational restatement**, but its Rust signature cannot exist in Cairo (an `impl Iterator`, an `impl Fn` callback, a const generic, a `&mut` slice, an `f32` parameter that only scales an integer) | **counterpart** | The same name where Cairo allows it (an eager `Span<T>` for an iterator, a bitmap for a set, a `usize` for a const generic), a new name otherwise. The item documents what it replaces under `#### Deviations` |
| 3 | Its signature ports and its result is **identical to `hexx` on every input**, up to a documented difference that the vectors can list (overflow panics instead of wrapping; ties of `line_to`) | **port** (with a *deviation* note when a difference exists) | Same name, same semantics, vectors generated from `hexx` 0.25.0 |
| 4 | Otherwise | **port** | Same name, same semantics, exact vectors |

Two consequences:

- Nothing is written to *look* ported. An excluded item is absent; a counterpart says which
  Rust item it stands for; a port with a deviation lists the inputs where results differ.
- Numeric results are API (COMMON.md §5). A port or a counterpart freezes its results at the
  release that ships it. The board engine taken over from `origami_hexmap` 1.8.0 freezes
  nothing new: its results are already API since 1.8.0 (`README.md` § Randomness).

Mapping to the house-style table of `glam-cairo` (`docs/API_PARITY.md`: `ported`, `renamed`,
`dropped`, `missing`, `extra`): *port* is `ported`; *counterpart* is `ported` when the name is
kept and `renamed` when it is not; *excluded* is `dropped`; nothing may stay `missing` at the
final release. The extension is `extra`, listed per module but outside the percentage.

### 1.2 What qualifies as an extension

An extension is a public item that `hexx` does not have and that exists because the library
runs on Starknet: boards held as bitmaps in one felt, their generators, floods, seams,
assembly, masks, tables, and the `u8` index geometry that `origami_hexmap` 1.8.0 already
provides. An extension must:

1. live in an extension module (§2), never on a mirror type under a `hexx` name that means
   something else (`Hex::range` stays geometric; the bitmap that respects walls is
   `HexMapTrait::range`);
2. be documented as an extension with the need or the constraint that justifies it;
3. carry a test with a gas budget, a scalar oracle and a benchmark on its worst case
   (`grimworld:docs/CAIRO.md` §2);
4. keep its results once released.

What is *not* an extension: a convenience that `hexx` deliberately does not have and that
Cairo does not require. Such additions are refused unless the game names a need.

### 1.3 Signed coordinates against `u8` indices

The rules of the game prefer the smallest integer and signed values only where a rule needs
them (`grimworld:docs/CAIRO.md` §4). The plan keeps both worlds and states where the boundary
is: the **mirror** is written on `i32`, because it mirrors `hexx` and because its functions are
called a handful of times per transaction; the **extension** is written on `u8` indices and
`felt252` bitmaps, because that is where the transaction's cost is. A game never has to go
through `Hex` to use a board; the conversion between the two exists (§3.5) for the parity
vectors and the client.

## 2. Package and module tree

### 2.1 Package

| | Decision | Alternative rejected |
|---|---|---|
| Scarb package name | **`hexx`** (free on scarbs.xyz on 2026-09-28). The house names the Cairo package after the Rust crate: `glam`, `nalgebra`, `fixed`, `simba` (`sources/house-style/glam-cairo/docs/DESIGN.md` §1) | `hexx_cairo`: nothing else on the registry needs the disambiguation, and the game would import `hexx_cairo::Hex` for a crate whose name is the parity claim |
| Repository | `bal7hazar/hexx-cairo`, a Scarb workspace: `crates/hexx` (published), `crates/takeover_tests` (unpublished, depends on `origami_hexmap = "1.8.0"` from the registry, §5.4), later `crates/hexx_glam` (§4, L-M3) and `crates/benches` if the class-size fixture of the house is adopted (`consumer` in `glam-cairo`) | One package with everything: the take-over test needs a dependency on `origami_hexmap` that the published package must not carry |
| Edition, dependencies | `edition = "2024_07"`, no `starknet` dependency (the library is pure Cairo, as the house ports; storage packing of `HexMap` is the consumer's). Dev-dependency `snforge_std` as in `hexmap:Scarb.toml:14-15` | — |
| Version | `0.1.0` at L-M1, pre-releases `0.1.0-rc.N` before it (§9) | — |
| Licence | MIT, as the repository already is. `origami_hexmap` is MIT (`sources/origami/Scarb.toml:14`), its author is the owner; the taken-over files keep their module headers and the README credits `origami_hexmap` 1.8.0 at commit `04ab30c` (§5.6) | — |

### 2.2 Module tree

The mirror keeps `hexx`'s module names (`src/lib.rs:273-292`). The extension keeps the module
names of `origami_hexmap` under one root module `board`, so that the take-over is a move of
files and the game's migration is a change of import path.

```text
crates/hexx/src/
  lib.cairo                    re-exports (§2.4)
  hex.cairo                    Hex, HexTrait: src/hex/mod.rs + rings.rs + swizzle.rs + euclidean.rs + convert.rs
  hex/impls.cairo              operator impls of Hex (src/hex/impls.rs)
  hex/iter.cairo               HexSpanExt: counterpart of HexIterExt (src/hex/iter.rs)         L-M2
  hex/grid/edge.cairo          GridEdge (src/hex/grid/edge.rs)                                L-M2
  hex/grid/vertex.cairo        GridVertex (src/hex/grid/vertex.rs)                            L-M2
  direction/edge_direction.cairo   EdgeDirection (src/direction/edge_direction.rs)
  direction/vertex_direction.cairo VertexDirection (src/direction/vertex_direction.rs)         L-M2
  direction/way.cairo          DirectionWay (src/direction/way.rs)                             L-M2
  direction/impls.cairo        Neg, Mul<i32>, rotation operators of the directions
  conversions.cairo            OffsetHexMode, DoubledHexMode, the conversions (src/conversions.rs)
  orientation.cairo            enum HexOrientation only (src/orientation.rs:124)
  bounds.cairo                 HexBounds (src/bounds.rs)                                       L-M2
  shapes.cairo                 shapes (src/shapes.rs)                                          L-M2
  algorithms/fov.cairo         range_fov, directional_fov on a board (counterparts)            L-M3
  algorithms/field_of_movement.cairo  field_of_movement on a board (counterpart)              L-M3
  algorithms/pathfinding.cairo a_star counterpart (search_path_weighted), documented           L-M3
  board/map.cairo              HexMap, HexMapTrait: the facade of origami_hexmap (map.cairo)
  board/direction.cairo        enum Direction, Arc, DirectionTrait (types/direction.cairo + N-7)
  board/layout.cairo           Layout, Dilation (helpers/layout.cairo)
  board/geometry.cairo         Geometry (helpers/geometry.cairo) + distance on coordinates
  board/asserter.cairo         Asserter (helpers/asserter.cairo)
  board/bits.cairo             Bits, Set, POW, INV, POW128 (helpers/bits.cairo)
  board/rng.cairo              Rng (helpers/rng.cairo)
  board/seams.cairo            N-2: sides, openings                                            new
  board/assembly.cairo         N-3: origin, assemble, window (15 × 16 from 2 or 4 chunks)      new
  board/line.cairo             N-5: line, line_of_sight, approach, LINE table                  new
  board/hexagon.cairo          N-6: hexagon, hexagon_ring, HEXAGON tables                      new
  board/printer.cairo          HexPrinter, test only (helpers/printer.cairo)
  finders/bfs.cairo            Bfs (finders/bfs.cairo) + N-8 flood entry point
  finders/dial.cairo           Dial (finders/dial.cairo)
  finders/flood.cairo          N-8: Flood, FloodTrait                                          new
  generators/caver.cairo       Caver (generators/caver.cairo) + N-1 generate_with_margins
  generators/digger.cairo      Digger
  generators/mazer.cairo       Mazer
  generators/spreader.cairo    Spreader
  generators/walker.cairo      Walker
  tests/                       bench_*, fixtures, properties, variants (src/tests/, #[cfg(test)])
crates/hexx/tests/             readme.cairo (taken over), golden_*.cairo (generated, §4.3)
crates/takeover_tests/         equality against origami_hexmap 1.8.0 (§5.4)
tools/refgen/                  Rust: vectors from hexx 0.25.0 and the exhaustive line comparison (§4.3)
scripts/                       api_parity.py, deviations.py, gas_tables.py, bench.py, check.sh (§4.2)
```

Files without a milestone mark are in L-M1 (§8).

### 2.3 Every module of `hexx` 0.25.0: kept, adapted or excluded

| `hexx` module (`src/lib.rs`) | Feature | Status | Where | Reason |
|---|---|---|---|---|
| `hex` (`mod.rs`, `impls.rs`, `rings.rs`, `swizzle.rs`, `euclidean.rs`, `convert.rs`, `iter.rs`) | — | **kept**, adapted item by item (§4.4) | `hex.cairo`, `hex/` | Integer coordinates; the heart of the mirror |
| `hex::grid` (`edge.rs`, `vertex.rs`) | `grid` | **kept** | `hex/grid/` | Integer; `GridEdge` and `GridVertex` are pairs of a `Hex` and a direction |
| `direction` (`edge_direction.rs`, `vertex_direction.rs`, `way.rs`, `impls.rs`, `angles`) | — | **kept**, the angle functions and `angles` excluded | `direction/` | Directions are `u8`; angles are `f32` |
| `conversions` | — | **kept** | `conversions.cairo` | Integer; the offset conversion defines the board mapping (§3.5) |
| `bounds` | — | **kept**, `from_min_max` as a counterpart | `bounds.cairo` | Integer, except the `f32` division inside `from_min_max` |
| `shapes` | — | **kept** | `shapes.cairo` | Integer iterators, ported as spans |
| `algorithms` | `algorithms` | **adapted**: counterparts on boards | `algorithms/` | The four functions take callbacks and return hash sets; the board engine has their bitmap forms |
| `orientation` | — | **adapted**: the enum `HexOrientation` (with `Not` and `Default`) is kept; `HexOrientationData`, `forward`, `inverse`, `orientation_data`, `Deref` are excluded | `orientation.cairo` | The enum parametrises the integer offset conversions (`src/conversions.rs:65-84`); the data are `f32` matrices (`src/orientation.rs:52-115`) |
| `layout` | — | **excluded** | — | `HexLayout` and its 24 functions map hexes to `f32` world positions (`src/layout.rs:61-315`); world and screen space belong to the client (L-G1 consequence, parity table) |
| `storage` | — | **excluded** as a module | — | `HexStore<T>`, `HexagonalMap<T>`, `HexModMap<T>`, `RombusMap<T>`, `RectMap<T>`, `RectMetadata`, `WrapStrategy` store one generic `T` per hex in a `Vec` or a `HashMap` (`src/storage/mod.rs:69-104`). On-chain state lives in models and boards live in bitmaps: the counterpart of the whole module is `board` (one bitmap per layer). The index formulas survive as `LayoutTrait::index` and `coords` (row-major offset, like `RectMap`, `src/storage/rect.rs:337-358`) and as `Hex::to_hexmod_coordinates` (like `HexModMap`) |
| `mesh` | `mesh` | **excluded** as a module | — | Rendering: `MeshInfo`, the three builders, `UVOptions`, `Rect`, `Face`, `Tri`, `InsetOptions`, `InsetScaleMode`, `FaceOptions` (inventory in LIB-02 §1.10) produce `Vec<Vec3>` vertices |
| `glam` re-exports (`src/lib.rs:301`), `serde`, `facet`, `rayon`, `bevy*`, `packed` | features | **excluded** | — | Host integrations. Cairo's `Serde`, `Hash`, `Debug`, `Default` derives are applied to every mirror type as a matter of course, not as a port of `serde` |

### 2.4 Root re-exports and where each meaning lives

`lib.cairo` re-exports, as `src/lib.rs:294-312` does: `Hex`, `HexTrait`, `hex`,
`EdgeDirection`, `VertexDirection`, `DirectionWay`, `HexBounds`, `HexOrientation`,
`OffsetHexMode`, `DoubledHexMode`, `GridEdge`, `GridVertex`; and from the extension `HexMap`,
`HexMapTrait`, `Direction` (the three names the game imports today,
`hexmap:src/lib.cairo:2-3`). Nothing else is re-exported: `u252` (the package `uint252`) is not (§9.3).

**Name clashes** between `hexx` and `origami_hexmap`, and which module owns which meaning:

| Name | On `Hex` (mirror, `hexx::hex`) | On `HexMap` (extension, `hexx::board`) | Note |
|---|---|---|---|
| `distance_to` | Geometric: `max(|dx|, |dy|, |dz|)` (`src/hex/mod.rs:615`) | Path length, walls block, `Option<u8>` (`hexmap:src/map.cairo:290`) | Different receivers, both kept. The geometric distance on the board is `hex_distance` (`:304`), unchanged |
| `range` | The `range_count(r)` coordinates around `self`, as a `Span<Hex>` (`:993`) | The tiles within `r` steps, walls block, as a bitmap (`:338`) | Both kept. The geometric bitmap is the new `hexagon` (§6.7) |
| `ring` | The `6r` coordinates at distance `r`, ordered (`src/hex/rings.rs:57`) | The tiles at exactly `r` steps, walls block, a bitmap (`:354`) | Both kept. The geometric bitmap is the new `hexagon_ring` (§6.7) |
| `neighbor` | `self + direction`, always defined (`src/hex/mod.rs:665`) | `Option<u8>`, `None` off the board (`:424`) | Same meaning |
| `field_of_movement` | `hexx::algorithms::field_of_movement` (counterpart, L-M3) | `HexMapTrait::field_of_movement` (taken over) | The L-M3 counterpart forwards to the extension: one implementation |
| `hexagon` | `hexx::shapes::hexagon(center, radius)`: coordinates (`src/shapes.rs:144`) | `HexMapTrait::hexagon(position, radius)`: a bitmap (§6.7); `LayoutTrait::hexagon(radius)`: the centred mask (`hexmap:src/helpers/layout.cairo:134`) | Same geometric meaning in three forms |
| `clockwise`, `rotate_cw` | `hexx`'s sense: `+1` on the index (`src/direction/edge_direction.rs:261`), which turns **counter-clockwise on a north-up map** (LIB-02 §3.1) | Not used: the board's `Direction` has `opposite` and the new `rotate(n)` (§6.8) | Decided by the project manager (L-G1, point 7) |

## 3. Types

One paragraph per choice, with the alternative rejected.

### 3.1 `Hex`

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
pub struct Hex { pub x: i32, pub y: i32 }
pub fn hex(x: i32, y: i32) -> Hex;
pub trait HexTrait { fn new(x: i32, y: i32) -> Hex; fn z(self: Hex) -> i32; /* … */ }
```

**Decision: signed 32-bit components, as `hexx` (`src/hex/mod.rs:69-74`).** Range: the full
`i32`, with two documented deviations: an operation whose result leaves `i32` **panics** with
Cairo's native message (Rust wraps in release builds and panics in debug builds), and `z()` is
`-x - y`, which panics when `x + y` leaves `i32`. Cost: every `i32` operation is a range-checked
Sierra libfunc, of the same order as the `u8` operations of the board (~1.1k for a `u8`
`DivRem`, `GAS.md:1535`, measured; addition and comparison a few hundred gas, estimate). No
mirror function is on a hot path of the game; the board is. Alternative rejected: `i16`
components, cheaper by nothing measurable (both are one range check per operation), and
breaking `from_u64` / `as_u64` (32-bit halves, `src/hex/convert.rs:76-103`) and `IVec2` interop.

### 3.2 Directions

```cairo
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
pub struct EdgeDirection { index: u8 }        // 0..=5, private field, as hexx's pub(crate) u8
pub struct VertexDirection { index: u8 }      // L-M2
pub enum DirectionWay<T> { Single: T, Tie: [T; 2] }   // L-M2
```

**Decision: `EdgeDirection` is a struct around a private `u8`, with `hexx`'s constants
verbatim** (`X`, `NEG_Y`, `FLAT_TOP`, `POINTY_SOUTH_EAST`… `src/direction/edge_direction.rs:79-190`),
`ALL_DIRECTIONS`, `index()`, `const_neg`, `clockwise`, `rotate_cw(n)`, and the operators `-`,
`>>`, `<<`, `* i32`. Cairo has no tuple structs, so the field is named; it stays private so that
`index()` is the only reader, as in `hexx`. The compass constants assume a screen with y
pointing down, so on the game's north-up map `POINTY_SOUTH_EAST` (index 1) is the **north-east**
neighbour and `clockwise` turns counter-clockwise (LIB-02 §3.1). This is documented on the type
and in the README; the names are not changed (L-G1, point 7).

**The board keeps its own `enum Direction`** (`hexmap:src/types/direction.cairo:25`, names
`East` … `SouthEast`, north-up), with `opposite`, `next`, `pop_front`, `Into<u8>`,
`TryInto<u8>` as today, plus `Into<EdgeDirection>` and `Into<Direction>` both ways (the index
is identical in both crates: LIB-02 §3.1, point 2). The board functions take `Direction`, as
in 1.8.0. Reason: the engine dispatches on the enum with `match` (`DirectionTrait::next`,
`:62-87`), the game's code and vectors compile unchanged, and `hexx`'s names stay pure.
Alternative rejected: a single direction type. It would force either renaming `hexx`'s compass
constants (the table would lie) or making the game write `POINTY_SOUTH_EAST` for north-east.
The cost of two types is one free `match` conversion where the two meet.

| Index | `EdgeDirection` (y down) | `Direction` (north up) |
|---|---|---|
| 0 | `X`, `POINTY_EAST`, `POINTY_RIGHT`, `FLAT_SOUTH_EAST`, `FLAT_BOTTOM_RIGHT` | `East` |
| 1 | `Y`, `POINTY_SOUTH_EAST`, `POINTY_BOTTOM_RIGHT`, `FLAT_SOUTH`, `FLAT_BOTTOM` | `NorthEast` |
| 2 | `NEG_X_Y`, `POINTY_SOUTH_WEST`, `POINTY_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`, `FLAT_BOTTOM_LEFT` | `NorthWest` |
| 3 | `NEG_X`, `POINTY_WEST`, `POINTY_LEFT`, `FLAT_NORTH_WEST`, `FLAT_TOP_LEFT` | `West` |
| 4 | `NEG_Y`, `POINTY_NORTH_WEST`, `POINTY_TOP_LEFT`, `FLAT_NORTH`, `FLAT_TOP` | `SouthWest` |
| 5 | `X_NEG_Y`, `POINTY_NORTH_EAST`, `POINTY_TOP_RIGHT`, `FLAT_NORTH_EAST`, `FLAT_TOP_RIGHT` | `SouthEast` |

### 3.3 The board and its index

```cairo
#[derive(Copy, Drop, Serde)]
pub struct HexMap { pub width: u8, pub height: u8, pub grid: felt252, pub seed: felt252 }
```

**Decision: `HexMap` is taken over unchanged** (`hexmap:src/map.cairo:63-69`): the tile
`(x, y)` is bit `i = y·W + x`, `1` is walkable, `+x` is West and `+y` is North, odd-r offset,
`W·H ≤ 251`, the outer ring is wall for every generator and every flood (`README.md`
§ Conventions). The parity flag of chunks on odd global rows (L-G1, point 2) is **a parameter
of the chunk-level functions** (`generate_with_margins`, `openings`, §6.2 and §6.3), not a field
of `HexMap`: adding a field would change the `Serde` layout the game stores, and the window
on which every simulation function runs (15 × 16, assembled at each tick, D-120) has an even
origin by construction (ADR-0006 §4), so no simulation function needs the flag: the finders
are taken over unchanged and the flag never reaches the tick
(`sources/hexx-cairo-main/window-parity-check.md` §3). Alternative rejected: a `parity` field on `HexMap`, or a
second type `Chunk`; both change the facade for a flag that two functions read.

**Bitmaps stay `felt252` in the API**, as in 1.8.0. `u252` is a free wrapper of a felt
(`hexmap:src/types/u252.cairo:1-5`); the game converts with `.into()` where its rules want the
type (`grimworld:docs/CAIRO.md` §4). Consequence for the package `uint252`: **L-M1 does not
depend on it** (§9.3). Alternative rejected: `u252`-typed bitmaps from 0.1.0, which would
change every signature the game's vectors are written against, for no gas.

### 3.4 `u252`, the package `uint252`

The type is not defined in this library. It is **published** on scarbs.xyz since 2026-09-28
as the package **`uint252`**, version 0.1.0 (repository `bal7hazar/types-cairo`,
`crates/u252`, commit `35f74d5`); the package is named `uint252`, the type keeps the name
`u252`, and its only dependency is `snforge_std` for its tests (L-G1, question 3). Where a
future extension needs the type (a packed model of several boards, a `StorePacking`), the
library depends on `uint252 = "0.1.0"` by published version and does not re-export it. The bit
helpers that `u252` shares with the engine (`Bits`, `POW`, `INV`, `POW128`,
`hexmap:src/helpers/bits.cairo`) stay in `board::bits`; `uint252` carries its own copy.

### 3.5 The conversion between a `Hex` and a board index

Derived in LIB-02 §3.1 and checked again here on the six neighbour tables **(inferred)**: a
tile `(x, y)` of a board is the `hexx` coordinate

```text
Hex::from_offset_coordinates([-(x as i32), y as i32], OffsetHexMode::Even, HexOrientation::Pointy)
  = Hex { x: -x - ceil(y / 2), y }
```

so that index 0 is `Hex::ZERO`, `Direction::East` (`i - 1`) is `EdgeDirection` 0 (`+x`), and
`Direction::NorthEast` is `EdgeDirection` 1 (`(0, +1)`): the direction indices coincide and no
other identification of the two grids does that while keeping `+x` West in the index (L-G1,
point 3). The negation of `x` is what absorbs "`+x` West".

The extension provides, in `board::geometry`:

```cairo
fn to_hex(x: u8, y: u8) -> Hex;                        // the formula above
fn from_hex(hex: Hex) -> Option<(u8, u8)>;             // None when x or y leaves 0..=255
fn index_to_hex(width: u8, position: u8) -> Hex;
fn hex_to_index(width: u8, height: u8, hex: Hex) -> Option<u8>;
```

`Geometry::to_axial` (`hexmap:src/helpers/geometry.cairo:20`, `q = x − ⌊y/2⌋`, `r = y`,
`i16`) is kept as it is: its results are API, and its frame is not the mirror's (it does not
negate `x`). The doc of both says so. Alternative rejected: changing `to_axial` to return a
`Hex`; that is a changed result for a public function.

## 4. The parity table

### 4.1 Form

The inventory below (§4.4) is the plan's table: every public item of `hexx` 0.25.0 in a kept
or adapted module, with its status and the milestone that delivers it. A generated
`docs/API_PARITY.md` replaces it from LIB-04 on, in the form of
`sources/house-style/glam-cairo/docs/API_PARITY.head.md`: a summary per owner (`Hex`,
`EdgeDirection`, `VertexDirection`, `DirectionWay`, `HexBounds`, `HexOrientation`,
`conversions`, `shapes`, `algorithms`, `GridEdge`, `GridVertex`, `HexSpanExt`) with the counts
`Ported | Dropped | Renamed | Missing | Extra | Parity`, then one row per item, then the
embedded Rust inventory as JSON.

### 4.2 Generation and check in CI

**From the source, not from `rustdoc` JSON**, following the house (`scripts/api_parity.py` of
`glam-cairo`, a dependency-free parser that masks comments and finds `pub fn`, `pub const`
and `impl … for …` blocks). Reasons: the house script is proven on two ports and runs in CI
without a Rust toolchain; `rustdoc` JSON is unstable across nightly versions and needs
`cargo +nightly` in CI. What changes for `hexx`:

| Aspect | `glam-cairo` script | `hexx` adaptation |
|---|---|---|
| Owners | One file per type (`TYPE_FILES`) | `Hex` spans `src/hex/mod.rs`, `rings.rs`, `swizzle.rs`, `euclidean.rs`, `convert.rs`, `conversions.rs` (all `impl Hex` blocks); `EdgeDirection` and `VertexDirection` have their own files; `shapes.rs` and `algorithms/*.rs` hold free functions; `way.rs` holds a generic enum |
| Cairo side | `pub trait XTrait` methods, `pub impl X of Trait<…>` | Same, plus `#[generate_trait] pub impl HexImpl of HexTrait` |
| Rules | Regex rules for `dropped` and `renamed` | The exclusion rules of §4.4: any signature with `f32`, `Vec2`, `Vec3`, `Quat`, `&HexLayout`, `impl Fn`, `HashSet`, `&mut [i32]`, `&[i32]`, `[Vec<Self>; RANGE]` |
| Extras | Cairo-only items per owner | Extension modules are excluded from the walk (`board`, `finders`, `generators`); their public items are listed by module in `docs/EXTENSIONS.md` (generated by the same script, `--extensions`) so that they stay outside the parity percentage but are still inventoried |
| Check | `python3 scripts/api_parity.py --check` in `scripts/check.sh` | Same; `--refresh --hexx /path/to/hexx` regenerates the embedded inventory from the pinned checkout |

The deviations are inventoried by `scripts/deviations.py` (house script, unchanged in
principle): every public item carries the doc template `Mirrors …` / `#### Panics` /
`#### Deviations`, and `--check` keeps the appendix of `docs/DEVIATIONS.md` current.

Gas tables follow `scripts/gas_tables.py` and `scripts/bench.py` of the house: `gas/*.snap`
committed, `bench.py check` in CI, the README regions generated. The `origami_hexmap` form
(`#[available_gas(l2_gas: N)]` on every test, `N = ceil(1.05 × measured)`, figures in `GAS.md`)
is kept **as well**, because it is what the game's rules require (`grimworld:docs/CAIRO.md`
§2) and what the taken-over tests already do. LIB-04 decides whether one of the two forms can
be derived from the other; both are cheap.

### 4.3 Reference vectors from `hexx` 0.25.0

`tools/refgen`, a Rust crate as in `glam-cairo` (`tools/refgen`, `cargo run -- gen <module>`),
depends on `hexx = "=0.25.0"` with `default-features = false, features = ["algorithms", "grid"]`
and writes `crates/hexx/tests/golden_<module>.cairo`. One TOML spec per module lists the inputs:

| Module | Inputs | Size |
|---|---|---|
| `hex` | 64 seeded coordinates in `[-40, 40]²`, every pair for `distance_to`, `way_to`, `rotate_*`, `reflect_*`, `to_lower_res(1..=6)`, `to_hexmod_coordinates(1..=6)` | ~4k assertions |
| `direction` | All 36 pairs, all rotations 0..=11 | exhaustive |
| `conversions` | 64 coordinates × 4 offset modes × 2 doubled modes, round trips | exhaustive on the sample |
| `rings`, `shapes`, `bounds` | Radii 0..=6 around 8 centres; spans compared element by element | ~10k coordinates |
| `line_to` | Every ordered pair of the 15 × 16 window in the mirror frame (240 × 239 = 57 360 pairs): compared **off-chain** in `refgen` against the integer rule (§6.6), which writes (a) the list of pairs where `hexx` and the rule differ, all of them exact ties (`docs/deviations/line_ties.md`, committed, checked by `--check`), and (b) a seeded sample of 512 non-tie pairs and every pair of a 7 × 7 board as Cairo golden tests | 57 360 pairs off-chain, ~1.5k on-chain |

The Cairo tests also compare every optimised function with a plain scalar oracle kept in the
tests (`grimworld:docs/CAIRO.md` §2): the integer line against the exhaustive `refgen` model
on a 7 × 7 board, the table forms against the loop forms, the bitmap functions against per-tile
loops.

### 4.4 Inventory

Columns: item (with its line in `hexx`), status (§1.1), Cairo form or reason, milestone. The
compass alias constants share one row each because their status is identical. "Span" means
that a Rust `impl Iterator` becomes an eager `Span<T>`: this is a systematic counterpart,
documented once on the type, and counted as `ported` when the name is kept.

#### `hex` — struct, constants, constructors (`src/hex/mod.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `struct Hex { x, y }` `:69` | port | `Hex { pub x: i32, pub y: i32 }`, derives `Copy, Drop, Serde, PartialEq, Debug, Default, Hash` | L-M1 |
| `fn hex(x, y)` `:89` | port | `hexx::hex::hex` (imported from its module, as the house does for `vec3`) | L-M1 |
| `ORIGIN`, `ZERO`, `ONE`, `NEG_ONE`, `X`, `NEG_X`, `Y`, `NEG_Y` `:95-110` | port | `const` on `HexTrait` | L-M1 |
| `INCR_X`, `INCR_Y`, `INCR_Z`, `DECR_X`, `DECR_Y`, `DECR_Z` `:113-124` | port | `const [Hex; 2]` | L-M2 |
| `NEIGHBORS_COORDS` `:159`, `DIAGONAL_COORDS` `:186` | port | `const [Hex; 6]` | L-M1 |
| `new` `:208`, `splat` `:225` | port | | L-M1 |
| `new_cubic` `:247` | port | panics `'Hex: cubic sum'` when `x + y + z != 0` (Rust `assert!`) | L-M1 |
| `x` `:256`, `y` `:264`, `z` `:274` | port | | L-M1 |
| `from_array` `:290`, `to_array` `:307`, `to_cubic_array` `:333` | port | `[i32; 2]`, `[i32; 3]` | L-M1 |
| `to_array_f32` `:315`, `to_cubic_array_f32` `:341` | excluded | `f32` output | — |
| `from_slice` `:352`, `write_to_slice` `:362` | excluded | slice APIs (house rule) | — |
| `as_ivec2` `:375`, `as_ivec3` `:390` | counterpart | `Into<Hex, IVec2>`, `Into<Hex, IVec3>` in the companion package `hexx_glam` (§9), as `nalgebra_glam` | L-M3 |
| `as_vec2` `:406` | excluded | `f32` output | — |
| `const_neg` `:421`, `const_add` `:435`, `const_sub` `:449` | port | same names (Cairo has no `const fn`; they are the plain functions behind the operators) | L-M1 |
| `round([f32; 2])` `:474` | excluded | `f32` input. The hexround algorithm is used internally on exact rationals by `line_to` and `Div<i32>` | — |
| `abs` `:498`, `min` `:511`, `max` `:525`, `dot` `:535`, `signum` `:546` | port | | L-M2 |
| `length` `:568`, `ulength` `:594`, `distance_to` `:615`, `unsigned_distance_to` `:625` | port | | L-M1 |
| `neighbor_coord` `:633`, `neighbor` `:665`, `all_neighbors` `:760` | port | | L-M1 |
| `diagonal_neighbor_coord` `:641`, `diagonal_neighbor` `:682`, `all_diagonals` `:767` | port | | L-M2 |
| `neighbor_direction` `:700` | port | `Option<EdgeDirection>` | L-M1 |
| `main_diagonal_to` `:709`, `diagonal_way_to` `:715` | port | | L-M2 |
| `main_direction_to` `:734`, `way_to` `:740` | port | `DirectionWay<EdgeDirection>` | L-M2 |
| `counter_clockwise` `:784`, `ccw_around` `:791`, `rotate_ccw` `:799`, `rotate_ccw_around` `:814`, `clockwise` `:831`, `cw_around` `:838`, `rotate_cw` `:846`, `rotate_cw_around` `:860` | port | the sense is `hexx`'s (§3.2) | L-M1 |
| `reflect_x` `:868`, `reflect_y` `:876`, `reflect_z` `:884` | port | | L-M2 |
| `line_to` `:903` | port, **deviation** | `Span<Hex>`, `distance + 1` items, endpoints included. Integer line; exact ties resolved by the game's rule (§6.6). Differs from `hexx` on the exact-tie pairs listed by `refgen`; identical elsewhere | L-M1 |
| `rectiline_to` `:936` | port | `Span<Hex>` | L-M2 |
| `lerp` `:973` | excluded | `f32` parameter | — |
| `range` `:993`, `xrange` `:1021` | port | `Span<Hex>`, same order (x then y) | L-M2 |
| `to_lower_res` `:1064` | port, deviation | exact floor division instead of `f32` floor: identical while `hexx`'s `f32` is exact (`|value| < 2^24`), exact beyond | L-M2 |
| `to_higher_res` `:1114`, `to_local` `:1143`, `wrap_in_range` `:1183` | port | | L-M2 |
| `range_count` `:1160` | port | | L-M1 |
| `impl Debug` `:1189` | port | prints `x`, `y`, `z` as `hexx` | L-M2 |

#### `hex` — operators (`src/hex/impls.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `PartialEq<Hex> for &Hex` `:10` | excluded | reference glue | — |
| `Add<Hex>` `:16`, `Sub<Hex>` `:95`, `Neg` `:321` | port | `HexAdd`, `HexSub`, `HexNeg` | L-M1 |
| `Add<i32>` `:25`, `Sub<i32>` `:104` | counterpart | `add_scalar`, `sub_scalar` (Cairo's `Add<T>` is homogeneous; house convention `mul_scalar`) | L-M2 |
| `Add<EdgeDirection>` `:37`, `Sub<EdgeDirection>` `:116` | counterpart | `add_direction`, `sub_direction` (same reason) | L-M1 |
| `Add<VertexDirection>` `:46`, `Sub<VertexDirection>` `:125` | counterpart | `add_diagonal`, `sub_diagonal` | L-M2 |
| `AddAssign` `:55`, `SubAssign` `:134`, `MulAssign` `:196`, `DivAssign` `:268`, `RemAssign` `:307` | port | `core::ops::*Assign` | L-M2 |
| `AddAssign<i32>` `:62`, `SubAssign<i32>` `:141`, `MulAssign<i32>` `:203`, `DivAssign<i32>` `:275`, `RemAssign<i32>` `:314`, `AddAssign<EdgeDirection>` `:69`, `AddAssign<VertexDirection>` `:76`, `SubAssign<EdgeDirection>` `:148`, `SubAssign<VertexDirection>` `:155` | excluded | heterogeneous assignment operators; the named `*_scalar` / `*_direction` methods cover them (house rule for `Vec * scalar`) | — |
| `Sum`, `Sum<&Hex>` `:83-89`, `Product`, `Product<&Hex>` `:217-223` | port | `Sum` / `Product` of an iterator, as `nalgebra-cairo` does (`docs/DESIGN.md` D10); the `&Hex` variants collapse into the by-value ones | L-M2 |
| `Mul<Hex>` `:162`, `Div<Hex>` `:229`, `Rem<Hex>` `:289` | port | per component; `Div` truncates toward zero as Rust; division by a zero component panics | L-M2 |
| `Mul<i32>` `:174` | counterpart | `mul_scalar` | L-M1 |
| `Mul<f32>` `:186`, `Div<f32>` `:254`, `MulAssign<f32>` `:210`, `DivAssign<f32>` `:282` | excluded | `f32` operand | — |
| `Div<i32>` `:241`, `Rem<i32>` `:298` | counterpart, deviation | `div_scalar`, `rem_scalar`: `hexx` rescales the **length** through an `f32` lerp and `Hex::round`. The counterpart computes the same rescale on exact rationals with the same rounding rule (half away from zero, then `>=`); vectors from `hexx` decide, and any pair where `f32` error made `hexx` deviate from its own rule is listed as a deviation | L-M2 |
| `BitAnd`, `BitOr`, `BitXor` (`Hex`) `:330-352`, (`i32`) `:363-385` | excluded | Cairo's corelib has no bitwise operators on signed integers; a two's-complement emulation per component is more code than any use justifies, and no consumer names one. Reversible (§12) | — |
| `Shl<T>`, `Shr<T>` for `i8`, `i16`, `i32`, `u8`, `u16`, `u32` `:396-526`, `Shl<Hex>` `:528` | excluded | same reason (no shifts on signed integers in the corelib) | — |

#### `hex` — rings, wedges, spirals (`src/hex/rings.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `custom_ring` `:15`, `ring` `:57` | port | `Span<Hex>`, same order (`start_dir`, counter-clockwise unless `clockwise`) | L-M2 |
| `rings` `:75`, `custom_rings` `:95` | port | `range: Span<u32>` → `Span<Span<Hex>>` | L-M2 |
| `custom_ring_edge` `:113`, `ring_edge` `:160` | port | `Span<Hex>` | L-M2 |
| `ring_edges` `:185`, `custom_ring_edges` `:211` | port | `Span<Span<Hex>>` | L-M2 |
| `custom_wedge` `:229`, `custom_wedge_to` `:245`, `custom_full_wedge` `:261`, `wedge` `:295`, `wedge_to` `:308`, `full_wedge` `:318`, `corner_wedge` `:330`, `corner_wedge_to` `:345` | port | `Span<Hex>` | L-M2 |
| `wedge_count` `:285`, `ring_count` `:540` | port | | L-M2 |
| `cached_custom_ring_edges` `:382`, `cached_ring_edges` `:425`, `cached_rings` `:464`, `cached_custom_rings` `:500` | counterpart | const generic `RANGE` becomes a runtime `range: usize`; returns `Span<Span<Hex>>` | L-M2 |
| `custom_spiral_range` `:516`, `spiral_range` `:533` | port | `Span<Hex>` | L-M2 |

#### `hex` — swizzles, conversions, euclidean, iterator helpers

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `xx`, `yy`, `zz`, `yx`, `yz`, `xz`, `zx`, `zy` (`src/hex/swizzle.rs:17-148`) | port | | L-M2 |
| `From<(i32, i32)>`, `From<[i32; 2]>` (`src/hex/convert.rs:4, 11`) | port | `Into<(i32, i32), Hex>`, `Into<[i32; 2], Hex>` | L-M2 |
| `From<(f32, f32)>`, `From<[f32; 2]>`, `From<Vec2>` `:18, 25, 39` | excluded | `f32` input | — |
| `From<Hex> for IVec2`, `From<Hex> for IVec3`, `From<IVec2> for Hex` `:32, 46, 53` | counterpart | `hexx_glam` companion package (§9) | L-M3 |
| `from_u64` `:76`, `as_u64` `:99` | port | two's-complement halves in a `u64`, as documented | L-M2 |
| `squared_euclidean_length` (`src/hex/euclidean.rs:20`), `squared_euclidean_distance_to` `:65` | port | integer | L-M2 |
| `euclidean_length` `:41`, `euclidean_distance_to` `:90` | excluded | `f32` output; the squared forms are the integer counterparts | — |
| `circular_range(f32)` `:110` | counterpart | `circular_range_squared(range_squared: i32) -> Span<Hex>`: the same set for `range_squared = round(range²)` when `range` is an integer | L-M2 |
| `HexIterExt::{average, center, bounds}` (`src/hex/iter.rs:4-46`) | counterpart | `HexSpanExt` on `Span<Hex>`: `average` through the exact `div_scalar` (same deviation), `center`, `bounds` | L-M2 |
| `ExactSizeHexIterator` `:73` | excluded | iterator plumbing; a `Span` has a length | — |

#### `hex::grid` (`src/hex/grid/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `GridEdge { origin, direction }` (`edge.rs:12`); `equivalent` `:23`, `destination` `:31`, `vertices` `:38`, `flipped` `:55`, `const_neg` `:65`, `clockwise` `:75`, `counter_clockwise` `:85`, `rotate_cw` `:95`, `rotate_ccw` `:104`, `Hex::all_edges` `:116`, `Neg` `:124`, `From<EdgeDirection>` `:133` | port | | L-M2 |
| `GridVertex { origin, direction }` (`vertex.rs:13`); `equivalent` `:24`, `coordinates` `:44`, `destinations` `:54`, `side_edges` `:65`, `const_neg` `:81`, `clockwise` `:91`, `counter_clockwise` `:101`, `rotate_cw` `:111`, `rotate_ccw` `:120`, `Hex::all_vertices` `:132`, `Neg` `:140`, `From<VertexDirection>` `:149` | port | | L-M2 |

#### `direction` (`src/direction/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `struct EdgeDirection(u8)` (`edge_direction.rs:75`), derives | port | §3.2 | L-M1 |
| The 30 compass constants of `EdgeDirection` `:79-190` (`X_NEG_Y`, `FLAT_TOP_RIGHT`, `FLAT_NORTH_EAST`, `POINTY_TOP_RIGHT`, `POINTY_NORTH_EAST`, `NEG_Y`, `FLAT_TOP`, `FLAT_NORTH`, `POINTY_TOP_LEFT`, `POINTY_NORTH_WEST`, `NEG_X`, `FLAT_TOP_LEFT`, `FLAT_NORTH_WEST`, `POINTY_LEFT`, `POINTY_WEST`, `NEG_X_Y`, `FLAT_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`, `POINTY_BOTTOM_LEFT`, `POINTY_SOUTH_WEST`, `Y`, `FLAT_BOTTOM`, `FLAT_SOUTH`, `POINTY_BOTTOM_RIGHT`, `POINTY_SOUTH_EAST`, `X`, `FLAT_BOTTOM_RIGHT`, `FLAT_SOUTH_EAST`, `POINTY_RIGHT`, `POINTY_EAST`), `ALL_DIRECTIONS` `:208` | port | verbatim, with the north-up note (§3.2) | L-M1 |
| `iter` `:212` | counterpart | `ALL_DIRECTIONS.span()` (a `Span` is the iterator) | L-M1 |
| `index` `:219`, `into_hex` `:226`, `const_neg` `:243`, `clockwise` `:261`, `counter_clockwise` `:279`, `rotate_ccw` `:296`, `rotate_cw` `:313` | port | | L-M1 |
| `angle_between` `:326`, `angle_degrees_between` `:333`, `angle_to` `:341`, `angle_degrees_to` `:350`, `angle_flat` `:360`, `angle_pointy` `:370`, `angle` `:378`, `unit_vector` `:393`, `world_unit_vector` `:404`, `angle_flat_degrees` `:415`, `angle_pointy_degrees` `:425`, `angle_degrees` `:435`, `from_pointy_angle_degrees` `:453`, `from_flat_angle_degrees` `:469`, `from_pointy_angle` `:486`, `from_flat_angle` `:502`, `from_angle_degrees` `:527`, `from_angle` `:553` | excluded | `f32` angles and vectors. Integer counterparts of "the direction of a hex": `Hex::way_to`, `main_direction_to`, `neighbor_direction`; of "rotate by an angle": `rotate_cw(n)` | — |
| `diagonal_ccw` `:571`, `vertex_ccw` `:586`, `diagonal_cw` `:601`, `vertex_cw` `:616`, `vertex_directions` `:623` | port | | L-M2 |
| `From<EdgeDirection> for Hex` `:628`, `impl Debug` `:635` | port | `Into<EdgeDirection, Hex>`; `Debug` prints the index and the pointy name | L-M1 |
| `struct VertexDirection(u8)` (`vertex_direction.rs:74`), its 36 compass constants `:78-201` (`X_NEG_Y_NEG_Z`, `X`, `FLAT_RIGHT`, `FLAT_EAST`, `POINTY_TOP_RIGHT`, `POINTY_NORTH_EAST`, `X_NEG_Y_Z`, `NEG_Y`, `FLAT_TOP_RIGHT`, `FLAT_NORTH_EAST`, `POINTY_TOP`, `POINTY_NORTH`, `NEG_X_NEG_Y`, `Z`, `FLAT_TOP_LEFT`, `FLAT_NORTH_WEST`, `POINTY_TOP_LEFT`, `POINTY_NORTH_WEST`, `NEG_X_Y_Z`, `NEG_X`, `FLAT_LEFT`, `FLAT_WEST`, `POINTY_BOTTOM_LEFT`, `POINTY_SOUTH_WEST`, `NEG_X_Y_NEG_Z`, `Y`, `FLAT_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`, `POINTY_BOTTOM`, `POINTY_SOUTH`, `X_Y`, `NEG_Z`, `FLAT_BOTTOM_RIGHT`, `FLAT_SOUTH_EAST`, `POINTY_BOTTOM_RIGHT`, `POINTY_SOUTH_EAST`), `ALL_DIRECTIONS` `:221` | port | | L-M2 |
| `VertexDirection::iter` `:225` | counterpart | `ALL_DIRECTIONS.span()` | L-M2 |
| `VertexDirection::{index, into_hex, const_neg, clockwise, counter_clockwise, rotate_ccw, rotate_cw}` `:232-314`, `direction_ccw` `:573`, `edge_ccw` `:588`, `direction_cw` `:603`, `edge_cw` `:618`, `edge_directions` `:625`, `From<VertexDirection> for Hex` `:630`, `Debug` `:637` | port | | L-M2 |
| `VertexDirection` angle functions `:327-555` (same 18 names as the edge ones) | excluded | `f32` | — |
| `Neg` for both directions (`impls.rs:5, 13`) | port | | L-M1 (edge), L-M2 (vertex) |
| `Shr<u8>`, `Shl<u8>` for both `:21-51` | counterpart | Cairo's corelib has no `Shl`/`Shr` for user types; the named `rotate_cw(n)` / `rotate_ccw(n)` are the operators' bodies (`:25, :41`) | — (nothing to add) |
| `Mul<i32>` for both `:53, 61` | counterpart | `mul_scalar(n) -> Hex` | L-M1 (edge), L-M2 (vertex) |
| `enum DirectionWay<T>` (`way.rs:30`), `unwrap` `:53`, `contains` `:62`, `map` `:75`, `PartialEq<T>` `:42`, `From<T>` `:95`, `From<[T; 2]>` `:102` | port | `map` takes a function pointer, not a closure, unless the `closures` feature of Cairo is adopted (LIB-04 decides) | L-M2 |
| `trait Way` `:37` and its impls `:109, 121` | port | | L-M2 |
| `angles::{DIRECTION_ANGLE_OFFSET_RAD, DIRECTION_ANGLE_OFFSET_DEGREES, DIRECTION_ANGLE_RAD, DIRECTION_ANGLE_DEGREES}` (`mod.rs:18-31`) | excluded | `f32` constants | — |

#### `conversions` (`src/conversions.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `enum DoubledHexMode` `:12` (`Default = DoubledWidth`), `enum OffsetHexMode` `:29` | port | | L-M1 |
| `to_offset_coordinates` `:65`, `from_offset_coordinates` `:142` | port | exact: `midpoint` and the divisions act on even numerators | L-M1 |
| `to_doubled_coordinates` `:50`, `from_doubled_coordinates` `:128` | port | | L-M2 |
| `to_hexmod_coordinates` `:92`, `from_hexmod_coordinates` `:110` | port | `rem_euclid` written out | L-M2 |

#### `orientation` (`src/orientation.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `enum HexOrientation { Pointy, Flat }` `:124`, `Default = Flat`, `Not` `:152` | port | | L-M1 |
| `HexOrientationData` `:52`, `flat` `:65`, `pointy` `:86`, `forward` `:106`, `inverse` `:113`, `orientation_data` `:136`, `Deref` `:144` | excluded | `f32` matrices | — |

#### `bounds` (`src/bounds.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `struct HexBounds { center, radius }` `:36`; `new` `:47`, `from_radius` `:54`, `positive_radius` `:78`, `is_in_bounds` `:86`, `hex_count` `:95`, `hex_count32` `:104`, `wrap_local` `:135`, `wrap` `:149`, `corners` `:156` | port | `hex_count` returns `usize` | L-M2 |
| `from_min_max` `:64` | port, deviation | uses `div_scalar` (exact rational; same rounding rule) | L-M2 |
| `all_coords` `:111`, `intersecting_with` `:116` | port | `Span<Hex>` | L-M2 |
| `FromIterator<Hex>` `:161` | counterpart | `from_span(Span<Hex>)` | L-M2 |

#### `shapes` (`src/shapes.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `Parallelogram` `:11` (`new` `:31`, `coords` `:37`, `Default` `:18`), `parallelogram` `:45` | port | `Span<Hex>` | L-M2 |
| `Triangle` `:62` (`new` `:77`, `coords` `:84`, `Default` `:67`), `triangle` `:95` | port | | L-M2 |
| `Hexagon` `:111` (`new` `:131`, `coords` `:137`, `Default` `:118`), `hexagon` `:144` | port | the coordinate form of the bitmap `HexMapTrait::hexagon` (§6.7) | L-M2 |
| `Rombus` `:156` (`coords` `:178`, `Default` `:165`), `rombus` `:186` | port | | L-M2 |
| `PointyRectangle` `:205` (`coords` `:231`, `Default` `:216`), `pointy_rectangle` `:243` | port | | L-M2 |
| `FlatRectangle` `:266` (`coords` `:291`, `Default` `:277`), `flat_rectangle` `:303` | port | | L-M2 |

#### `algorithms` (`src/algorithms/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `field_of_movement(coord, budget, cost: Fn(Hex) -> Option<u32>) -> HashSet<Hex>` (`field_of_movement.rs:63`) | counterpart | `hexx::algorithms::field_of_movement(map: HexMap, from: u8, budget: u8, costs: Span<felt252>) -> felt252`, forwarding to `HexMapTrait::field_of_movement`. Same cost model: `hexx` charges `1 + cost(h)` (`:16-18`), the board charges `k + 2` for class `k` (`hexmap:src/finders/dial.cairo:3-4`), so class `k` is `cost(h) = k + 1`, `None` is a wall, and `cost(h) = 0` is any other walkable tile. Limits documented: at most 3 classes (cost 2..=4), a bounded board, the outer ring as wall. This corrects LIB-02 §3.2, which called the two "close": they are the same model within those limits | L-M3 |
| `a_star(start, end, cost: Fn(Hex, Hex) -> Option<u32>) -> Option<Vec<Hex>>` (`pathfinding.rs:110`) | counterpart, deviation | `hexx::algorithms::a_star(map, from, to, costs) -> Option<Span<u8>>`, forwarding to `search_path_weighted` and reordering the path from start to end with both included (the board returns target to start, start excluded, `hexmap:src/map.cairo:255`). Per-directed-step costs (`cost(a, b)`) have no counterpart: only per-tile entry costs. Ties: lowest tile index (the board's rule) against the heap order of `hexx` (unspecified) | L-M3 |
| `range_fov(coord, range, blocking: Fn(Hex) -> bool) -> HashSet<Hex>` (`fov.rs:29`) | counterpart, deviation | `hexx::algorithms::range_fov(map, from, range) -> felt252`: for every tile of `hexagon_ring(from, range)`, the prefix of `line` up to the first wall (`take_while(!blocking)`, `:29-34`); walls are the blocking set. The lines carry the game's tie rule (§6.6) | L-M3 |
| `directional_fov(coord, range, direction: VertexDirection, blocking)` `:61` | counterpart, deviation | `directional_fov(map, from, range, direction: VertexDirection) -> felt252`, keeping the ring tiles whose `diagonal_way_to` matches the two vertex directions of the facing (`:61-76`) | L-M3 |

#### Modules excluded as a whole

`layout` (24 functions, `HexLayout`, `Default`), `storage` (`HexStore<T>` with `get`, `get_mut`,
`values`, `values_mut`, `iter`, `iter_mut`; `HexagonalMap<T>`, `HexModMap<T>`, `RombusMap<T>`,
`RectMap<T>`, `RectMetadata` and its 23 builders and accessors, `WrapStrategy`) and `mesh`
(the items of LIB-02 §1.10) have the module-level status of §2.3 with their reasons. The
generated table lists their items as `dropped` with the module's reason, so that the
percentage is honest.

#### Counts

From the source: `hex` has 62 public functions and 16 constants in `mod.rs`, 24 in
`rings.rs`, 8 swizzles, 5 euclidean, 2 packing functions, 57 operator impls and 8 `From`
impls; the directions have 31 functions and 31 constants (edge), 31 and 37 (vertex), 8
operator impls, 3 `DirectionWay` methods; `conversions` 6 functions and 2 enums; `bounds` 12
functions; `shapes` 15 functions and 6 structs; `grid` 20 functions; `algorithms` 4;
`orientation` 5 and 1 enum; `layout` 24; `storage` 55; `mesh` 69. Of the kept and adapted
modules, 46 items are excluded, all `f32`, slice, bit-operator or reference glue; every other
item is a port or a counterpart. The percentage of the generated table will be computed by
the script, not by hand.

## 5. The take-over of the engine of `origami_hexmap`

### 5.1 What is taken as is

Every source file of `hexmap:src/` except `types/u252.cairo`, moved into the tree of §2.2 with
its module doc, its constants, its tests and its gas budgets; `tests/readme.cairo`;
`GAS.md` (as `docs/GAS.md`, the sections L0 to F1 kept as the record of the measurements);
`.scarbignore` (`GAS.md:1888-1891`). The `extern fn bitwise` declaration
(`hexmap:src/helpers/bits.cairo:54`, allowed by the owner) is kept.

Every public function of 1.8.0 (LIB-02 §2.1) and its destination:

| `origami_hexmap` 1.8.0 | Destination in `hexx` | Change |
|---|---|---|
| `HexMap`, `HexMapTrait::{new, new_empty, new_maze, new_cave, new_random_walk, new_hexagon, open_with_corridor, open_with_maze, keep_component, compute_distribution, search_path, search_path_weighted, field_of_movement, distance_to, hex_distance, reachable, range, ring, neighbor, is_walkable}` (`src/map.cairo:64-441`) | `hexx::board::map`, re-exported at the root as `hexx::{HexMap, HexMapTrait}` | None. Results identical |
| `Direction`, `DirectionTrait::{opposite, next, pop_front}`, `DirectionIntoU8`, `U8TryIntoDirection`, `DIRECTION_COUNT`, `DIRECTION_SIZE` (`src/types/direction.cairo`) | `hexx::board::direction`, `Direction` re-exported at the root | None; N-7 adds `rotate`, `arc`, `Arc`, and the conversions with `EdgeDirection` |
| `Bfs::{search, distance, reachable, tiles_within_range}`, `errors::BFS_POSITION_NOT_WALKABLE` (`src/finders/bfs.cairo`) | `hexx::finders::bfs` | None; N-8 adds `Bfs::flood` |
| `Dial::{search, field_of_movement}`, its errors (`src/finders/dial.cairo`) | `hexx::finders::dial` | None |
| `Caver::{generate, keep_component}`, its error (`src/generators/caver.cairo`) | `hexx::generators::caver` | None; N-1 adds `generate_with_margins` |
| `Digger::{maze, corridor}` | `hexx::generators::digger` | None |
| `Mazer::generate`, its error | `hexx::generators::mazer` | None |
| `Spreader::generate`, its errors | `hexx::generators::spreader` | None |
| `Walker::generate` | `hexx::generators::walker` | None |
| `Layout`, `Dilation`, `LayoutTrait::{new, board, even, interior, hexagon, with_interior, expand, expand_small, dilation, index, coords, parity, neighbor}`, `DilationTrait::{dilate, expand_small}` (`src/helpers/layout.cairo`) | `hexx::board::layout` | None |
| `LayoutTrait::edge_neighbours` `:234`, `neighbour_in` `:253`, `neighbour_mask` `:273` | `hexx::board::layout` as `edge_neighbors`, `neighbor_in`, `neighbor_mask` | **Renamed** to the American spelling of `hexx` (`neighbor`, `all_neighbors`) and of the facade itself (`HexMapTrait::neighbor`); results unchanged. The three are helpers a consumer rarely calls; the migration table lists them (§10) |
| `Geometry::{to_axial, distance}` (`src/helpers/geometry.cairo`) | `hexx::board::geometry` | None; adds `distance_between(x1, y1, x2, y2)` and the `Hex` conversions (§3.5) |
| `Bits` (18 functions), `Set`, `WideSet`, `SmallSet`, the constants and tables `TWO_POW_128`, `TWO_POW_32`, `TWO_POW_64`, `BYTES_ONE`, `TWO_POW_120`, `POW`, `INV`, `POW128` (`src/helpers/bits.cairo`) | `hexx::board::bits` | None |
| `Rng`, `RngTrait` (9 functions), `PERMUTATIONS` (`src/helpers/rng.cairo`) | `hexx::board::rng` | None |
| `MAX_SIZE`, `Asserter` (6 functions), its errors (`src/helpers/asserter.cairo`) | `hexx::board::asserter` | None |
| `HexPrinter` (test only) | `hexx::board::printer`, `#[cfg(test)]` | None |
| `u252`, `U252Trait`, `PRIME`, every `u252` impl (`src/types/u252.cairo`) | **Dropped** from this library | The type lives in the package `uint252` 0.1.0 (`bal7hazar/types-cairo`, `crates/u252`, published on scarbs.xyz; L-G1, question 3). `origami_hexmap` keeps re-exporting its own copy until it is decommissioned |

### 5.2 What is renamed to follow `hexx`

Only the three British-spelt helpers above. The facade renames nothing: `distance_to`,
`range`, `ring`, `hex_distance`, `search_path`, `new_cave` keep their names and meanings, and
the mirror carries `hexx`'s meanings on `Hex` (§2.4). Alternative rejected: renaming
`hex_distance` to `distance_to` and `distance_to` to `path_length` on the facade, closer to
`hexx`; it changes the game's code and the readability of the take-over for no result.

### 5.3 What changes visibility

Nothing becomes public that was private, and nothing becomes private. `BfsInternal` stays
`pub(crate)` and `CaverInternal` private; N-1 and N-8 are new public functions of the same
modules (`Caver::generate_with_margins`, `Bfs::flood`) that call them. The private `is_inside`
of the facade stays private. The finders (`Bfs`, `Dial`) are taken over **unchanged**: the
window of D-120 (15 × 16, even origin) is a board the library already accepts
(`W, H ≥ 3`, `W·H ≤ 251`, `hexmap:src/helpers/asserter.cairo:51-56`; 16 × 15 is among the
README's examples, `README.md:77`), so the row-parity flag of the layout serves the generation
and the seams of chunks on odd global rows only (§6.2, §6.3) and never enters a finder.

### 5.4 How results are proved identical to 1.8.0

Three layers, all in CI from the first pull request that moves the files:

1. **Every test of 1.8.0 moves with its budget** (`src/tests/*`, the module tests, and
   `tests/readme.cairo`): the pinned grids of one seed per generator (`README.md`
   § Randomness, "each generator has a test pinning the exact grid of one seed"), the property
   tests (`src/tests/properties.cairo`), the oracles (scalar BFS at
   `src/finders/bfs.cairo:1183`, scalar Dial in `bench_dial.cairo`, scalar automaton in
   `bench_caver.cairo`, reference walker at `src/generators/walker.cairo:535`), the variants
   and the 256-seed spreader statistics.
2. **Equality against the registry package**: the unpublished package
   `crates/takeover_tests` depends on `origami_hexmap = "1.8.0"` (scarbs.xyz) and on `hexx`
   by path, and asserts, function by function, that both return the same value on the same
   inputs: every generator on 64 seeds and on the fixture dimensions (`3x3` to `83x3`,
   `7x7`, `17x14`, `19x13`, `25x10`, `15x15`), every finder on the fixtures of
   `src/tests/fixtures.cairo` (`CAVE_17X14`, `MAZE_17X14`, `SERPENTINE_17X14`,
   `UNREACHABLE_17X14`, their `7x7` forms) and on 32 generated boards, every query on every
   position of a `7x7` and on 512 seeded positions of a `17x14`. This is the proof that no
   move, rename or re-export changed a result.
3. **Gas equality**: the moved benches keep their budgets unchanged; a budget that has to rise
   is a finding, not an adjustment (`GAS.md:6-20`, the recording rule).

The equality package is kept until `origami_hexmap` is decommissioned (§10), then deleted.

### 5.5 What is not taken over

`u252` (§3.4). The `README.md` of 1.8.0, replaced by this repository's, with its sections
Conventions, Border ring and entrances, Panics, Randomness and Migration carried into the
`board` documentation because they define the results.

### 5.6 Licence and attribution

`origami_hexmap` is MIT (`sources/origami/Scarb.toml:14-15`, `sources/origami/LICENSE`); its
author is the owner (L-G1). This repository is MIT. The take-over keeps the MIT notice of
`origami` in `LICENSE-origami` next to `LICENSE`, keeps every module header, and the README
states: "The board engine is taken over from `origami_hexmap` 1.8.0
(`dojoengine/origami`, commit `04ab30c`, MIT)." `hexx` is Apache-2.0
(`sources/hexx/Cargo.toml:7`): the mirror reuses names and semantics and generates vectors
from the crate, which copies no code; where a doc comment is reproduced, it says "after
`hexx`". Nothing else is needed.

## 6. Extensions for Grim World

Every entry gives the signatures, the module, the algorithm retained with its reason (the
order of preference of `grimworld:docs/CAIRO.md` §3: arithmetic, then bitwise, then bounded
loops; tables over computation), the oracle, the worst case to benchmark, and the gas target
(measured or estimate, §7). The board of the tick is the **15 × 16 window** of ADR-0006 §4
as decided by D-120: 240 bits, one felt, two-limb path like the 225 bits of a chunk
(`sources/hexx-cairo-main/window-parity-check.md` §3: "the cost of a flood layer does not
change"); it follows the adventurer, is assembled from 2 or 4 chunks of 15 × 15 at each tick
and is not stored; its origin is on an even global row, so the adventurer stands on local
column 7 and local row 7 (global row odd) or 8 (global row even). Every figure marked measured
was taken on a 17 × 14 board (238 bits, also two-limb) and is carried as the target for
15 × 16. Nothing below is indexed from a fixed centre: N-5 and N-6 take the local position.

### 6.1 Distance and neighbours

| | |
|---|---|
| Signatures | Mirror: `HexTrait::distance_to(self, rhs) -> i32`, `unsigned_distance_to -> u32`, `neighbor(self, EdgeDirection) -> Hex`, `all_neighbors -> [Hex; 6]`, `neighbor_direction(self, other) -> Option<EdgeDirection>`. Board (taken over): `HexMapTrait::hex_distance(from, to) -> u8`, `neighbor(position, direction) -> Option<u8>`, `LayoutTrait::neighbor_mask(position) -> felt252`. New: `Geometry::distance_between(x1: u8, y1: u8, x2: u8, y2: u8) -> u8` (global coordinates, no board), `Geometry::chunk_of(x: u8, y: u8) -> (u8, u8)` (`(x / 15, y / 15)`, chunk size a constant of the caller: `chunk_of(x, y, size: NonZero<u8>)`), `LayoutTrait::neighbor_direction(width, from: u8, to: u8) -> Option<Direction>` |
| Module | `board::geometry`, `board::layout` |
| Algorithm | Arithmetic: the formula of `Geometry::distance` (`hexmap:src/helpers/geometry.cairo:35-59`, no negative intermediates) on coordinates; two `DivRem` for the chunk; `neighbor_direction` from `to − from` and the row parity, a `match` on the six offsets |
| Oracle | `distance_between(x1, y1, x2, y2) == hex_distance` on a board that contains both; `Hex` distance through `to_hex`; the property test of all pairs of a 7 × 7 (`src/tests/properties.cairo:153`) extended to global coordinates up to 105 |
| Worst case | Any pair; `neighbor_direction` on an odd row |
| Gas | `hex_distance` **10,393 measured** (`GAS.md:1878`); `distance_between` ~5k **estimate** (the same arithmetic without the two `bounded_int` checks); `chunk_of` ~2.5k **estimate** (2 × 1,098 measured `DivRem`, `GAS.md:1535`); `neighbor` **6,959 measured** (`:1869`); `neighbor_direction` ~3k **estimate** |

### 6.2 N-1 — Generation of a board given its margins

The project manager's answers (L-G1, points 1 and 2): the seam is inside the chunk, the
chunk's outer ring holds the tiles copied from its neighbours, the 13 × 13 interior evolves,
chunks stay 15 × 15, and a parity flag handles chunks whose first row is a global odd row.

```cairo
/// `fixed`: the ring tiles whose value is given (the sides that face a generated neighbour);
/// `values`: their values; the other ring tiles are drawn from the seed with the interior
/// and do not evolve; `odd`: the chunk's first row is a global odd row.
fn generate_with_margins(
    width: u8, height: u8, order: u8, seed: felt252, fixed: felt252, values: felt252, odd: bool,
) -> felt252;                                                   // Caver
fn new_cave_with_margins(width, height, order, seed, fixed, values, odd) -> HexMap;   // facade
fn smooth(self: HexMap, order: u8, fixed: felt252, odd: bool) -> HexMap;   // `order` generations on an existing grid, the tiles of `fixed` held
```

| | |
|---|---|
| Module | `generators::caver`, facade in `board::map` |
| Algorithm | Bitwise, the bit-sliced automaton B4/S2 of `Caver` (`hexmap:src/generators/caver.cairo:1-5, 171-249`) with three changes **(inferred from the code)**: (1) the initial fill ANDs the noise with `interior + (ring − fixed)` instead of `interior`, then ORs `values & fixed`; (2) before every down-shift, the bits the shift would drop are cleared (row 0 for `2^-W` and `2^-(W+1)`, tile `(0, 1)` for `2^-(W-1)` on odd-row operands): three limb ANDs with constant masks, so that the field products stay exact (`hexmap:src/helpers/layout.cairo:5-8`); the up-shifts stay exact because `2^(W·H) · 2^(W+1) < 2^251` for 15 × 15 (241 bits); (3) after the rule, the next grid is `(next & interior) + (grid & ring)`: the ring never evolves. The neighbour planes of an interior tile read the ring tiles' values, which is the purpose. The parity flag swaps `up_even`/`up_odd` and `down_even`/`down_odd` and complements the `even` mask within the board (`LayoutTrait::new_odd(width, height)`), the two constants the project manager named. The flag serves generation and seams only: the window of the tick has an even origin by construction (D-120) and the finders never see it |
| Why not a loop or a wider board | A per-tile loop is ≥ 1.1M (LIB-02 §6); a 17 × 17 margin does not fit a felt |
| Oracle | The scalar automaton `reference` of `src/tests/bench_caver.cairo`, extended with fixed tiles and the parity flag; a property: the fixed tiles are unchanged after any `order`; the free ring tiles equal the fill; on `fixed = 0`, `odd = false`, the result of `generate_with_margins` on the **interior** equals `generate` (the rings differ: `generate` leaves the ring wall) |
| Stream | The stream of `generate_with_margins` is API from 0.1.0: one test pins the grid of one seed per parity |
| Worst case | 15 × 15, order 3, all four sides fixed, `odd = true`; and order 5 for the per-generation figure |
| Gas | One generation **35,710 measured** on 17 × 14 (`GAS.md:629`); with margins ~42–46k per generation **estimate** (+3 limb ANDs ≈ 5k, +1 interior AND and ring OR ≈ 4k); `Layout::new` **12.9k measured** (`:630`); fill 27k measured (`:616`); whole call at order 3: ~165–180k **estimate**, against **143,737 measured** for `generate(17, 14, 3)` (`:618`). LIB-02 §5.2 estimated +5–15 %; this plan estimates +15–25 % |

### 6.3 N-2 — Edges and openings between boards

```cairo
pub enum Side { East, North, West, South }      // East = column 0 (the low x side), West = column W-1
fn side(width: u8, height: u8, side: Side) -> felt252;                     // the mask of one side, ring included
fn openings(width: u8, height: u8, near: felt252, far: felt252, side: Side, odd: bool) -> felt252;
/// Tiles of `near`'s `side` that are open and adjacent, across the seam, to an open tile of the
/// neighbouring board `far` (whose opposite side touches `side`). `odd`: the parity of `near`'s
/// row 0 in global coordinates (North/South seams) or of `near`'s rows (East/West seams).
fn is_open_across(width, height, near, far, side, odd) -> bool;            // openings != 0
```

| | |
|---|---|
| Module | `board::seams`; `Digger::corridor` (taken over) creates an opening from a chosen edge tile; `Asserter::is_edge`, `is_corner` (taken over) validate it. Seams are between chunks of 15 × 15; the `odd` flag is the second and last use of the row-parity flag (D-120) |
| Algorithm | Arithmetic and bitwise. Side masks are constants of `W` and `H`: rows `2^W − 1` and `(2^W − 1)·2^(W(H−1))`; columns `(2^(WH) − 1)/(2^W − 1)` (exact field division, as `LayoutTrait::even`, `hexmap:src/helpers/layout.cairo:93-112`) and its product by `2^(W−1)`. East/West seams: `far`'s column `W−1` is shifted onto `near`'s column 0 by `2^-(W-1)` after masking, then the two diagonal contacts are the same column shifted by `±W` on the rows whose parity gives a diagonal contact across the seam (even rows in local terms, swapped by `odd`), masked by the `even` or odd-row mask. North/South seams: `far`'s row `H−1` shifted by `2^-(W(H−1))` onto row 0, then its neighbours by `2^±1` on the parity that applies. Every shift is an exact field product because the operand was masked to one row or column first; the union is an addition of disjoint bitmaps and the final AND with `near & side` needs one limb AND. LIB-02 §5.3 derived the same, with the parity alternation of chunk rows (`15cy + 14` and `15cy + 15` have opposite parities) |
| Why | Reading a column tile by tile costs 15 × 4.9k ≈ 75k (`GAS.md:65`, `Bits::get`); the masked shifts cost a few products and two ANDs |
| Oracle | A scalar loop over the 15 tiles of the side, calling `LayoutTrait::neighbor` on a 30 × 15 (or 15 × 30) board that holds both chunks side by side with the right global parity |
| Worst case | A North seam with `odd = true` (three contacts per tile), both sides fully open |
| Gas | ~12–20k per seam **estimate** (4 field products, 2 lookups at 1,269 measured each, 2 `u256` ANDs at 2,682 measured, 2 wide conversions at 1,809 measured; `GAS.md:48, 58, 53`) |

### 6.4 N-3 — Assembly of a board of 15 × 16 from 2 or 4 chunks of 15 × 15

Decided by D-120 (`grimworld:docs/needs/hexmap.md` § "N-3 in detail", ADR-0006 §4): the
window is 15 columns × 16 rows (240 tiles, one felt), assembled **at each tick** from the
chunks it overlaps and never stored; 16 rows always span two rows of chunks and 1 or 2
columns, so the input is 2 or 4 chunks, never 1, never more; the origin is on an even global
row, and the function **refuses an odd origin** rather than return a board that is a different
hex grid from the map; no loop over rows.

```cairo
/// Constants of the window: `WIDTH = 15`, `HEIGHT = 16`, `CHUNK = 15`.
/// The window of an adventurer at global `(x, y)`: origin `(x - 7, y - 7)` when `y` is odd,
/// `(x - 7, y - 8)` when `y` is even, so that the origin row is even. Global coordinates are
/// `i16` because the origin may lie before the location's first tile (an absent chunk is 0).
pub struct Origin { pub cx: i16, pub cy: i16, pub ox: u8, pub oy: u8 }   // chunk (cx, cy) holds the origin at local (ox, oy)
fn origin(x: i16, y: i16) -> Origin;                                       // never odd by construction
fn local(self: @Origin, x: i16, y: i16) -> Option<u8>;                     // the window index of a global tile, None outside the window
/// `chunks[0]` is chunk `(cx, cy)`, `[1]` is `(cx + 1, cy)`, `[2]` is `(cx, cy + 1)`, `[3]` is
/// `(cx + 1, cy + 1)`; `[1]` and `[3]` are ignored when `ox == 0` (the window fits one column of
/// chunks). `odd_chunk_row` is the parity of `cy`.
/// # Panics
/// * `'Assembly: odd origin'` when `oy + cy` is odd (the origin is on an odd global row)
/// * `'Assembly: invalid offset'` when `ox >= 15` or `oy >= 15`
fn assemble(chunks: [felt252; 4], ox: u8, oy: u8, odd_chunk_row: bool) -> felt252;   // one layer
fn window(terrain: [felt252; 4], occupied: [felt252; 4], origin: @Origin, seed: felt252) -> (HexMap, felt252);   // both layers, ring imposed on the terrain
```

| | |
|---|---|
| Module | `board::assembly` |
| Algorithm | Arithmetic and bitwise, no loop. Per chunk and per layer: (1) the rectangle that lands in the window is the **product of two constants from tables**: a column band `COL_BAND[k]` (the 15 masks `(2^(15−k) − 1)·2^k` of columns `k..=14` in row 0, and their complements for columns `0..k`) and a row band `ROW_BAND[k]` (the 15 masks `Σ_{j≥k} 2^(15j)` of rows `k..=14` at column 0, and their complements), 60 felts in all; the product of a band in row 0 by a band at column 0 is the rectangle, exact because the bits are disjoint. (2) One limb AND of the chunk with the rectangle. (3) One shift, exact because the dropped bits were masked: chunk `(cx, cy)` moves by `−(15·oy + ox)` (a product by `INV`), chunk `(cx + 1, cy)` by `15 − ox − 15·oy`, chunk `(cx, cy + 1)` by `15·(15 − oy) − ox`, chunk `(cx + 1, cy + 1)` by `15·(15 − oy) + 15 − ox`; a negative shift is a product by `INV[−s]`, a positive one by `POW[s]`, and no piece exceeds `2^240`, so the field products stay exact. (4) The pieces are disjoint and are added. The window and the chunk share the width 15, which is what makes a 2-D move one 1-D shift (ADR-0006 §1). Finally one AND with `LayoutTrait::interior(15, 16)` imposes the wall ring on the terrain layer. The parity check is one `u8` addition and one `DivRem` |
| Why a panic and not an `Option` | An odd origin is a programming error of the caller, never a runtime condition: `origin` cannot produce one, and a window on an odd origin is a board on which every neighbour is wrong (`window-parity-check.md` §1). The library's convention for invalid inputs is a panic with a named message (`README.md` § Panics, `Asserter` errors); an `Option` would put a branch in every tick and invite a silent fallback that returns a wrong grid. The message is `errors::ASSEMBLY_ODD_ORIGIN = 'Assembly: odd origin'` |
| Oracle | A scalar per-tile copy through `LayoutTrait::coords` and `index` over the 240 tiles, on 2 and on 4 chunks, for every `(ox, oy)` of `0..15 × 0..15` with the matching parity; a `#[should_panic]` test on each odd origin |
| Worst case | **4 chunks, two layers each, at each tick**: `ox = oy = 7`, `odd_chunk_row = true` (every chunk contributes, both layers) |
| Gas | Per chunk and layer ~8k **estimate**: 3 lookups (band, band, shift: 3 × 1,269 measured, `GAS.md:48`), 2 products (98 measured, `:46`), 1 wide conversion (1,809 measured, `:53`), 1 limb AND (2 × 1,696 measured, `:57`), 1 rebuild (197 measured, `:55`). `assemble` (one layer, 4 chunks) ~32k **estimate**; `window` (two layers, ring, parity check) ~65–70k **estimate**, storage reads excluded. This is above the "about 40k" of ADR-0006 § Cost, which is itself an estimate; SPK-7 measures it, with and without a stored window, as the ADR says. Two chunks: half |

### 6.4b The fallback size, not designed

If SPK-7 finds the tick too expensive, ADR-0006 § Cost keeps the same rule with a sight of
radius 5 on a window of 13 × 14 (182 tiles, still two limbs). Its **width differs from the
chunk's 15**, so a chunk piece is no longer moved by one 1-D shift: each of its rows would land
`2` bits short of the next, which needs either a per-row re-pack (a loop, or a multiplication
by a constant that spreads the rows, to be studied) or an assembly in the chunk's width
followed by a cut. This plan does not design it; it is a later option, taken up only if
SPK-7 asks for it, as one task of L-M3.

### 6.5 N-4 — Cutting a board by a mask

```cairo
fn cut(self: HexMap, mask: felt252) -> HexMap;   // grid & mask & interior
```

| | |
|---|---|
| Module | `board::map` |
| Algorithm | Bitwise: two limb ANDs (`Bits::and`) |
| Oracle | Per-tile `is_walkable` after the cut equals `is_walkable` before AND the bit of the mask, and is false on the ring |
| Worst case | Any; input independent |
| Gas | ~6k **estimate** (2 × 2,682 measured `u256 &`, `GAS.md:58`, minus the shared conversion) |

### 6.6 N-5 — Line of sight

The project manager's answer (L-G1, point 6): integer line, ties to the lower tile index,
symmetric; a documented deviation from `line_to`, excluded from the parity table at ties.

**The rule, in both frames.** Cube coordinates, `Δ = b − a`, `N = max(|Δx|, |Δy|, |Δz|)`; along
the axis `k` with `|Δk| = N`, sample `i` has the exact integer `a_k + i·sign(Δk)` and the other
two coordinates are exact rationals with denominator `N`; a tie happens only when `2·(i·Δu mod N)
= N`, so only for even `N`, and never on a vertex (LIB-02 §5.6, derivation). At a tie the two
candidates are neighbours; the game's rule "lower tile index" means, in the index frame, the
tile with the **smaller `y`, and on the same row the smaller `x`** (`i = y·W + x`); in the mirror
frame (§3.5, `x_hex = −x − ⌈y/2⌉`) the same rule reads **the smaller `y`, and on the same row the
larger `x`**. The rule depends only on the two candidates, so it is symmetric and
translation-invariant; `hexx`'s `f32` rule is neither (LIB-02 §5.6, worked examples). One
subtlety for the board form **(inferred)**: at a tie on the same row, the preferred tile may lie
at column `−1` (off the board, wrapping to the previous row's last column in the index); the
board form therefore clears every tile outside the column band `[min(x1, x2) − 1, max(x1, x2) + 1]`
before testing, and a line that leaves the board is treated as blocked.

```cairo
// Mirror (hexx name, documented deviation)
fn line_to(self: Hex, other: Hex) -> Span<Hex>;                 // distance + 1 tiles, endpoints included
// Board
fn line(self: HexMap, from: u8, to: u8) -> felt252;              // the tiles strictly between, as a bitmap
fn line_of_sight(self: HexMap, from: u8, to: u8) -> bool;        // line & ~grid == 0: walls block, actors do not, endpoints are not tested
fn approach(self: HexMap, from: u8, to: u8) -> Direction;        // the direction, from `to`, of the last tile of the line before `to` (`from` itself when adjacent): the arc a ranged attack arrives from
```

| | |
|---|---|
| Module | `hex` (mirror), `board::line` with the table `LINES: [felt252; 254]` |
| Inputs | Both endpoints are **local positions** of the caller's choosing: the adventurer is on local `(7, 7)` or `(7, 8)` of the window (D-120), a goblin anywhere; nothing is indexed from a fixed centre. The table is indexed by the offset and by the **row parity of the start**, which the function reads from the start's index |
| Algorithm | Mirror: a bounded loop (`N ≤ 2^31`, in practice ≤ 29 on a window), one accumulator per step, no division (Bresenham-like), `Span<Hex>` output. Board: **a table**, because the rule is translation-invariant and depends only on the offset and the row parity of the start: for every offset within distance 6 (127 offsets, `range_count(6)`) and each parity, the between-mask around a canonical centre of the 15 × 16 board (`(7, 8)` even, `(7, 7)` odd: the adventurer's two positions) is stored; placing it is one product by `2^(i − c0)` (or its inverse) after clearing the bits that would fall below 0, then one AND with the column band (kills the bits that wrapped to another row) and one with the board (`2^240 − 1`). Beyond distance 6 the board form runs the loop of the mirror on indices (bounded by the board's diameter, 15 on 15 × 16). `line_of_sight` is one more AND with `~grid` (`grid` XOR board). `approach`: `neighbor_mask(to) & line` is one bit (the line enters `to` from exactly one neighbour); its index is the lowest set bit (the backtracking primitive of `Bfs`, `hexmap:src/finders/bfs.cairo:4-6`), then `neighbor_direction` |
| Why the table | The rules prefer a table (`grimworld:docs/CAIRO.md` §1); the loop form is ~6 bit tests at 4,949 measured each (`GAS.md:65`) plus the arithmetic, ~40k; the table form is one lookup and three ANDs |
| Class size | 254 felts; ~300 CASM felts **estimate** (one felt per entry plus the array's Sierra constant), 0.4 % of the 81,920-felt class limit cited by the house (`glam-cairo docs/DESIGN.md` §4.3) |
| Oracle | The mirror loop against the Rust model of `refgen` (exhaustive on 7 × 7, sampled on 15 × 16, §4.3); the table against the loop on every pair within distance 6 of a 15 × 16 board (57,360 ordered pairs, one Cairo test per start row); symmetry `line(a, b) == line(b, a)` on all pairs; `line_of_sight` against a per-tile scalar walk |
| Worst case | Distance 6 with a tie on every even step (`N = 6`, e.g. `Δ = (3, 3)` in axial), start on an odd row, from the adventurer's position `(7, 7)`; and distance 14 (the longest line inside the interior of 15 × 16) for the loop fallback |
| Gas | Table path ~10k **estimate** (lookup 1,269, product 98, 2 wide conversions 3,618, 2 `u256` ANDs 5,364, index arithmetic ~1k; all from measured primitives `GAS.md:46-58`); `line_of_sight` ~13k **estimate**; `approach` ~10k **estimate** (one more AND and a lowest-bit extraction, ~8.4k measured per backtracking step, `GAS.md:159`); loop fallback ~6k per step **estimate** |

### 6.7 N-6 — Range and ring as geometry

```cairo
fn hexagon(self: HexMap, position: u8, radius: u8) -> felt252;       // tiles within `radius`, walls ignored, clipped to the board (ring included)
fn hexagon_ring(self: HexMap, position: u8, radius: u8) -> felt252;  // tiles at exactly `radius`
```

| | |
|---|---|
| Module | `board::hexagon` with the tables `HEXAGONS: [felt252; 16]` and `HEXAGON_RINGS: [felt252; 16]` (parity × radius 1..=8; radius 0 is `2^position`) |
| Inputs | `position` is a **local position**: the adventurer's `(7, 7)` or `(7, 8)` for sight (D-120: the sight of radius 6 then always lies inside the ring, rows 1 to 13 or 2 to 14 of the 16), a target's tile for an area of effect; the row parity is read from the index |
| Algorithm | Table and arithmetic: the canonical hexagon of each radius and parity (the mask of `LayoutTrait::hexagon`, `hexmap:src/helpers/layout.cairo:134-151`, re-centred on `(7, 8)` or `(7, 7)` of the 15 × 16 board) is placed by one product after clearing the bits that fall below 0, then ANDed with the column band `[x − r, x + r]` and the board (`2^240 − 1`, which clips the rows above 15 for centres near the top). The tables depend on the width only; they serve every board of width 15 (a chunk of 15 × 15 included, with its own board mask); for other widths the function builds the mask arithmetically as `LayoutTrait::hexagon` does (a loop of `2r + 1` rows, ≤ 17 iterations), which is the general fallback. Radii above 8 fall back to the same loop |
| Why not the flood | `tiles_within_range(6)` on an empty 17 × 14 costs **159,255 measured** (`GAS.md:242`): one dilation per unit of radius. Why not a table per position (240 felts per radius, one lookup, ~2k): it saves ~10k on a query made once per tick and costs 1,440 felts of class for six radii; it is kept as a measured **variant** in the benches and promoted only if SPK-7 finds the query on a hot path |
| Oracle | `hexagon(p, r) == tiles_within_range(p, r)` on `new_empty` boards where the hexagon fits (`README.md` § Migration, "on an empty board they hold the same tiles"); per-tile `hex_distance <= r` on every position of a 15 × 16 for every radius; the sight of radius 6 from `(7, 7)` and `(7, 8)` never touches the ring |
| Worst case | Radius 8, centre `(1, 1)` (maximal clipping), odd row; and radius 6 from `(7, 8)` for the tick's own figure |
| Gas | ~12k **estimate** (2 lookups, 1 product, 2 wide conversions, 2–3 `u256` ANDs, from `GAS.md:46-58`) for both functions; the loop fallback ~2k per row **estimate** (`Bits::pow` lookups and products) |

### 6.8 N-7 — Directions, opposite, rotation, arcs

```cairo
// Mirror (hexx names, hexx sense: +1 is counter-clockwise on a north-up map)
fn clockwise(self: EdgeDirection) -> EdgeDirection;  fn counter_clockwise(...);  fn const_neg(...);
fn rotate_cw(self: EdgeDirection, offset: u8) -> EdgeDirection;  fn rotate_ccw(...);
// Board (north-up names)
pub enum Arc { Front, FrontSide, RearSide, Back }
fn opposite(self: Direction) -> Direction;                    // taken over
fn rotate(self: Direction, steps: u8) -> Direction;           // (index + steps) % 6, counter-clockwise on the map
fn arc(self: Direction, facing: Direction) -> Arc;            // from (self - facing) mod 6: 0 Front, 1 and 5 FrontSide, 2 and 4 RearSide, 3 Back
impl Into<Direction, EdgeDirection>; impl Into<EdgeDirection, Direction>;   // index identity
```

| | |
|---|---|
| Module | `direction::edge_direction` (mirror), `board::direction` (extension) |
| Algorithm | Arithmetic on `u8`: one addition and one `DivRem` by 6; `arc` is a `match` on the difference (six arms; `grimworld:docs/design/04-combat.md` § Facing: front `d`, front-side `d ± 1`, rear-side `d ± 2`, back `d + 3`). The game writes arcs with directions, never with the word "clockwise" (L-G1, point 7) |
| Oracle | Exhaustive: 36 pairs for `arc`, 6 × 12 for the rotations, `rotate(3) == opposite`, `Into` round trips, and `EdgeDirection::rotate_cw(n).into() == Direction::rotate(n)` (same index arithmetic) |
| Worst case | Input independent |
| Gas | ~1.5k **estimate** per rotation (`DivRem` 1,098 measured, `GAS.md:1535`), ~1k **estimate** for `arc` |

### 6.9 N-8 — One flood giving every walker its next step

The project manager's answer (L-G1, point 5): one flood per tick on the occupancy frozen at
the start of the tick; the current occupancy filters each goblin's candidate tiles, in
ascending id order; when no closer tile is free, fall back to the same layer. Frozen at the
first release.

```cairo
#[derive(Drop)]
pub struct Flood { width: u8, height: u8, layers: Span<u256> }   // layers[d] = tiles at path distance d from the source, on grid & ~obstacles; layers[0] = {from}
fn flood(self: HexMap, from: u8, obstacles: felt252, depth: u8) -> Flood;         // Bfs::flood; `from` walkable and not an obstacle, else 'Bfs: position not walkable'
fn next_step(self: @Flood, position: u8, blocked: felt252) -> Option<u8>;       // the free neighbour in the lowest layer, lowest index; None when no neighbour is in any layer or all are blocked
fn next_step_away(self: @Flood, position: u8, blocked: felt252) -> Option<u8>;  // the free neighbour in the highest layer (kiting)
fn distance(self: @Flood, position: u8) -> Option<u8>;                           // the layer of `position`, or of its nearest neighbour + 1 when `position` was an obstacle
```

| | |
|---|---|
| Module | `finders::bfs` (`Bfs::flood`), `finders::flood` (`Flood`, `FloodTrait`); facade `HexMapTrait::flood` |
| Algorithm | Bitwise: the layer loop of `Bfs` (`hexmap:src/finders/bfs.cairo:1-16`) on `grid & ~obstacles`, storing every layer (`ArrayStore`, `:87`) up to `depth` or until the frontier is empty; the source is not an obstacle, the walkers are (they sit on occupied tiles), so a walker is in no layer and its neighbours are. `next_step`: `around = neighbor_mask(position)` (or `edge_neighbors` on the ring, where goblins stand 7 tiles out, ADR-0006 §4), then the first layer `k` with `around & layers[k] != 0`, then `candidates = around & layers[k] & ~blocked`, else `around & layers[k + 1] & ~blocked` (the walker's own distance is `k + 1`: the fallback of the rule), then the lowest set bit. With `blocked` = the current occupancy, the id-order rule of the tick is the caller's loop |
| Why one flood | The design ("one flood per tick, not one per goblin", `grimworld:docs/design/02-core-loop.md` § Simulation budget); rule (b) of LIB-02 §5.9 costs up to 8 floods |
| Oracle | The scalar queue BFS of `src/finders/bfs.cairo:1183` (`reference_all`) for the layers; a scalar choice for `next_step`; a property: `next_step` is never a wall, never blocked, and is adjacent |
| Worst case | 15 × 16 cave assembled from 4 chunks, the adventurer at `(7, 8)`, 8 walkers at distances 3 to 14, `depth = 15`, `blocked` changing after each walker |
| Gas | Flood: **~19.3k measured per layer** on two limbs (`GAS.md:156`; the 240 tiles of the window are on the same path as the 238 of the measurement, `window-parity-check.md` §3) plus **~55k measured** fixed (`:162`): ~345k for 15 layers **estimate**, one layer more than a 15 × 15 window in open ground. `next_step`: ~2.5k per layer scanned **estimate** (two limb ANDs on stored limbs and a loop iteration at 1,270 measured, `:45`) plus ~8.4k measured for the lowest-bit step (`:159`): 15–45k per walker **estimate**. Per tick with 8 walkers: **470–670k estimate**, before the assembly of the window (§6.4, ~70k). This refines LIB-02 §5.9 (300–450k), which did not count the per-walker layer scans. Eight `search_path` calls would cost ~5.6M (8 × 706,135 measured, `GAS.md:1207`) |

## 7. Gas targets of milestone L-M1

Every public function of L-M1, with its target and the origin of the figure. Budgets on the
tests are `ceil(1.05 × measured)` once measured (`grimworld:docs/CAIRO.md` §2). A target marked
estimate is a ceiling that the implementation must meet or explain.

| Function | Module | Worst case | Target | Origin |
|---|---|---|---:|---|
| `HexMapTrait::new_empty` | board | 17 × 14 | 18,480 | measured `GAS.md:1198` |
| `new_maze` | board | 17 × 14, order 0 | 2,873,670 | measured `:1199` |
| `new_cave` | board | 17 × 14, order 3 | 144,927 | measured `:1200` |
| `new_random_walk` | board | 17 × 14, 200 steps | 999,629 | measured `:1201` |
| `new_hexagon` | board | radius 6 | 125,770 | measured `:1202` |
| `open_with_corridor` / `open_with_maze` | board | 17 × 14 cave, entrance 8 | 63,018 / 61,858 | measured `:1203-1204` |
| `keep_component` / `reachable` | board | 17 × 14 cave | 555,119 | measured `:1205` |
| `compute_distribution` | board | 17 × 14 cave, 10 objects | 193,168 | measured `:1855` |
| `search_path` | board | 17 × 14 cave, 24 steps | 706,135 | measured `:1207` |
| `search_path_weighted` | board | 17 × 14 cave, 2 classes | 1,427,654 | measured `:1208` |
| `field_of_movement` | board | 17 × 14 cave, budget 6, 2 classes | 261,829 | measured `:1209` |
| `distance_to` | board | 17 × 14 cave, 24 steps | 501,642 | measured `:1210` |
| `range` / `ring` | board | 17 × 14 cave, radius 4 | 103,793 / 99,903 | measured `:1212, :1318` |
| `hex_distance` / `neighbor` / `is_walkable` | board | per call | 10,393 / 6,959 / 7,073 | measured `:1878, :1869, :1874` |
| `Geometry::distance_between` | board | any | 5,000 | estimate §6.1 |
| `Geometry::chunk_of` | board | any | 2,500 | estimate §6.1 |
| `LayoutTrait::neighbor_direction` | board | odd row | 3,000 | estimate §6.1 |
| `Caver::generate_with_margins` | generators | 15 × 15, order 3, 4 sides fixed, odd | 180,000 | estimate §6.2 |
| `HexMapTrait::smooth` (per generation) | board | 15 × 15, 4 sides fixed | 46,000 | estimate §6.2 |
| `seams::side` | board | any | 3,000 | estimate §6.3 |
| `seams::openings` | board | North seam, odd, both open | 20,000 | estimate §6.3 |
| `assembly::origin` / `local` | board | any | 3,000 each | estimate §6.4 |
| `assembly::assemble` (one layer, 4 chunks) | board | `ox = oy = 7`, odd chunk row | 32,000 | estimate §6.4 |
| `assembly::window` (2 layers, 4 chunks, ring) | board | same, **at each tick** | 70,000 | estimate §6.4 |
| `HexMapTrait::cut` | board | any | 6,000 | estimate §6.5 |
| `HexMapTrait::line` | board | distance 6, ties, from `(7, 7)` | 10,000 | estimate §6.6 |
| `line_of_sight` | board | same | 13,000 | estimate §6.6 |
| `approach` | board | same | 10,000 | estimate §6.6 |
| `line` beyond radius 6 (loop) | board | distance 14 | 85,000 | estimate §6.6 |
| `hexagon` / `hexagon_ring` | board | radius 8, centre `(1, 1)`, odd; radius 6 from `(7, 8)` | 12,000 each | estimate §6.7 |
| `Direction::rotate` / `arc` | board | any | 1,500 / 1,000 | estimate §6.8 |
| `Bfs::flood` | finders | 15 × 16 cave, 15 layers | 345,000 | estimate §6.9 |
| `FloodTrait::next_step` / `next_step_away` | finders | 14 layers scanned | 45,000 | estimate §6.9 |
| One tick, 8 walkers (`window` + `flood` + 8 `next_step`) | — | 4 chunks, two layers, as above | 740,000 | estimate §6.4, §6.9 |
| `HexTrait::distance_to`, `neighbor`, `rotate_cw`, `to_offset_coordinates` | hex | any | 1,500 each | estimate §3.1 |
| `HexTrait::line_to` | hex | distance 13 | 3,000 per tile | estimate §6.6 |
| `EdgeDirection::rotate_cw` | direction | any | 1,500 | estimate §6.8 |
| `Geometry::to_hex` / `from_hex` | board | any | 2,000 | estimate §3.5 |

Tables and their class-size cost (estimate, one CASM felt per entry plus a constant per array):

| Table | Entries | Used by | Estimated class cost |
|---|---:|---|---:|
| `POW`, `INV`, `POW128` (taken over, `hexmap:src/helpers/bits.cairo:403, 537, 791`) | 252 + 252 + 129 | every shift | already paid by the game today |
| `LINES` (canonical centres `(7, 7)` and `(7, 8)` of 15 × 16) | 254 | `line`, `line_of_sight`, `approach` | ~300 felts (0.4 %) |
| `HEXAGONS`, `HEXAGON_RINGS` | 16 + 16 | `hexagon`, `hexagon_ring` | ~40 felts |
| `COL_BAND`, `ROW_BAND` (with complements) | 30 + 30 | `assemble` | ~70 felts |
| `arc` | 6 arms of a `match` | `arc` | negligible |
| Variant, not shipped by default: per-position sight table | 240 per radius | `hexagon` | ~280 felts per radius |

## 8. Milestones

### L-M1 — What the game needs first (release 0.1.0)

| | |
|---|---|
| Content | The take-over of the engine with identical results (§5); the extensions N-1 to N-8, distance and neighbours (§6); the **mirror foundation**: `Hex` (constructors, constants, `z`, arrays, `const_*`, length and distance, `neighbor`, `all_neighbors`, `neighbor_direction`, rotations, `line_to`, `range_count`, `Add`, `Sub`, `Neg`, `mul_scalar`, `add_direction`), `EdgeDirection` (constants, `index`, `into_hex`, `const_neg`, rotations, `Neg`, `mul_scalar`, `Into<Hex>`), `HexOrientation`, `OffsetHexMode`, `DoubledHexMode`, the offset conversions, the board ↔ `Hex` conversions (§3.5) |
| Why the mirror foundation is in L-M1 | N-7's rotation and N-5's line are specified in `hexx`'s terms and their vectors come from `hexx`; and the parity table and the deviation list must exist at the first release, since numeric results are API from then on. Everything else of the mirror waits |
| Depends on | LIB-04 (repository, CI, parity script, `refgen`, gas tooling, publication pipeline) |
| Exit criterion | (1) `crates/takeover_tests` green against `origami_hexmap` 1.8.0 on every function (§5.4); (2) every extension has a scalar oracle, a worst-case bench and a budget within 5 % of its measurement, and the estimates of §7 are replaced by measurements in `GAS.md` (a target missed by more than 25 % is reported to the owner before release); (3) `api_parity.py --check`, `deviations.py --check`, `bench.py check` green; (4) `docs/deviations/line_ties.md` generated; (5) the pinned streams of `generate_with_margins` committed; (6) `0.1.0` published on scarbs.xyz and consumed by the game's SPK-7 branch |
| Size | 9 tasks (below), 2 of them in parallel at most (1 agent at a time in wave 1, `PLAN.md`; the pairs below are for when the budget allows) |

Tasks of L-M1, with allowlists that do not overlap:

| Task | Content | Allowlist | Can run with |
|---|---|---|---|
| M1-T1 | Take-over: move the sources and tests, `takeover_tests`, `docs/GAS.md`, budgets unchanged | `crates/hexx/src/board/**`, `finders/**`, `generators/**`, `tests/**`, `crates/takeover_tests/**` | — (first) |
| M1-T2 | Mirror foundation: `hex.cairo`, `hex/impls.cairo`, `direction/edge_direction.cairo`, `direction/impls.cairo`, `conversions.cairo`, `orientation.cairo`, `refgen` specs for them, golden tests | `crates/hexx/src/{hex.cairo,hex/impls.cairo,direction/**,conversions.cairo,orientation.cairo}`, `tools/refgen/specs/{hex,direction,conversions}.toml`, `crates/hexx/tests/golden_{hex,direction,conversions}.cairo` | M1-T3, M1-T4 |
| M1-T3 | N-7 and distance: `board/direction.cairo` (`rotate`, `arc`, conversions), `board/geometry.cairo` (`distance_between`, `chunk_of`, `to_hex`…), `board/layout.cairo` (`neighbor_direction`, renames) | those three files and their tests | M1-T2 |
| M1-T4 | N-4 and N-3: `cut`, `board/assembly.cairo` (`origin`, `local`, `assemble`, `window` for the 15 × 16 window, the band tables, the odd-origin panic, the per-tick bench with 4 chunks and two layers) | `board/assembly.cairo`, the `cut` block of `board/map.cairo` (a dedicated file `board/cut.cairo` forwarded by the facade avoids sharing `map.cairo`) | M1-T2 |
| M1-T5 | N-6: `board/hexagon.cairo`, tables generated by `tools/refgen` (or a Python script), the per-position variant in the benches | `board/hexagon.cairo`, `tools/refgen/src/hexagon.rs`, its tests and benches | M1-T6 |
| M1-T6 | N-5: `Hex::line_to`, `board/line.cairo`, `LINES` table, `docs/deviations/line_ties.md`, the exhaustive off-chain comparison | `hex.cairo` (the `line_to` block: coordinate with M1-T2, or run after it), `board/line.cairo`, `tools/refgen/src/line.rs`, `docs/deviations/` | M1-T5 |
| M1-T7 | N-2: `board/seams.cairo` | that file, tests, benches | M1-T8 |
| M1-T8 | N-1: `Caver::generate_with_margins`, `LayoutTrait::new_odd`, the facade entries, pinned streams | `generators/caver.cairo`, the `new_cave_with_margins` / `smooth` block of the facade, `board/layout.cairo` (`new_odd`: coordinate with M1-T3, or run after it) | M1-T7 |
| M1-T9 | N-8: `Bfs::flood`, `finders/flood.cairo`, the tick bench with 8 walkers | `finders/bfs.cairo`, `finders/flood.cairo`, tests, benches | — (needs M1-T3 for `neighbor_direction`) |
| M1-R | Release 0.1.0: README, CHANGELOG, `API_PARITY.md`, publication | orchestrator | — |

The facade file `board/map.cairo` is shared by several tasks: the orchestrator adds the
forwarding entries after each task merges (one-line methods, as every facade method is,
`hexmap:src/map.cairo:1-4`), so that no task edits it.

### L-M2 — The mirror completed (release 0.2.0)

| | |
|---|---|
| Content | Every remaining port and counterpart of §4.4 marked L-M2: the rest of `Hex` (operators, swizzles, rings, wedges, spirals, ranges, reflections, resolution, `way_to`, packing, euclidean), `VertexDirection`, `DirectionWay`, `HexBounds`, `shapes`, `HexSpanExt`, `GridEdge`, `GridVertex`, the doubled and hexmod conversions |
| Depends on | L-M1 (0.1.0 released) |
| Exit criterion | `API_PARITY.md`: no `missing` item in `hex`, `direction`, `conversions`, `bounds`, `shapes`, `grid`, `orientation`; golden tests from `refgen` for every ported item; every deviation documented and inventoried; benches for every non-trivial function; 0.2.0 published |
| Size | 6 tasks: `Hex` operators and arithmetic (impls, swizzles, euclidean, packing); rings, wedges, spirals, ranges; `VertexDirection` and `DirectionWay` and `way_to`; `HexBounds` and `HexSpanExt` and resolution; `shapes`; `grid`. All six have disjoint files; up to three in parallel |

### L-M3 — Algorithms, interop, closure of the table (release 0.3.0)

| | |
|---|---|
| Content | `algorithms` counterparts on boards (`range_fov`, `directional_fov`, `field_of_movement`, `a_star`, §4.4); the companion package `hexx_glam` (`Into` between `Hex` and `IVec2`/`IVec3` of `glam-cairo`, published separately, like `nalgebra_glam`); the `uint252` dependency if the owner decides on `u252`-typed bitmaps (§12); whatever new need the game files in `docs/needs/hexmap.md` during phases 1 and 2 |
| Depends on | L-M2 |
| Exit criterion | No `missing` item in any kept or adapted module; every exclusion has its reason in the generated table; `hexx_glam` published; 0.3.0 published |
| Size | 4 tasks: fov; field of movement and a_star; `hexx_glam`; the game's new needs (one task per need) |

### L-M4 — Final release (1.0.0) and decommissioning

| | |
|---|---|
| Content | Parity reached or every exclusion closed and documented (LIB-07); the game migrated (§10); the decommissioning of `origami_hexmap` executed |
| Depends on | L-M3; the game's migration pull request merged; the audit of LIB-07 |
| Exit criterion | The parity table shows `Missing = 0` for every kept and adapted module; the game's `docs/CAIRO.md` no longer names `origami_hexmap`; `dojoengine/origami` `main` no longer builds `crates/hexmap`; `1.0.0` published; `takeover_tests` deleted |
| Size | 2 tasks: the release; the pull request in `dojoengine/origami` |

## 9. Release plan

### 9.1 Versions

| Version | Content | Consumed by |
|---|---|---|
| `0.1.0-rc.1` | The take-over alone (M1-T1), results identical to 1.8.0 | SPK-7 can start on it, or on `origami_hexmap` 1.8.0 (`grimworld:PLAN.md`, R-18) |
| `0.1.0-rc.2` … | Each extension as it merges (N-3, N-4, N-6, N-7 first: they unblock the window and the sight; then N-5, N-2, N-1, N-8) | SPK-7 |
| `0.1.0` | L-M1 complete | ENG-05 (`grimworld:PLAN.md`, Phase 1) |
| `0.2.0`, `0.3.0` | L-M2, L-M3 | The game, at its pace (by published version, never a git revision) |
| `1.0.0` | Parity or documented exclusions; `origami_hexmap` decommissioned | Version 1 of the game |

Pre-release identifiers follow semver (`0.1.0-rc.N`). If scarbs.xyz refuses pre-release
identifiers (not verified), the fallback is `0.0.N` for the release candidates and `0.1.0` for
the milestone; LIB-04 verifies on the first publication and records the answer.

### 9.2 What is API from which version

| Item | API from |
|---|---|
| The board API of 1.8.0: every signature and every result, including the generator streams | `0.1.0-rc.1` (already API since `origami_hexmap` 1.8.0; the take-over adds nothing to it) |
| The streams of `generate_with_margins`; the tie rule of the line; the flood rule of N-8 (rule (a)); the `Arc` values; the seam conventions | `0.1.0` (the release candidates may still move them, and say so in the changelog) |
| The mirror items of L-M1 | `0.1.0` |
| Each later mirror item | The version that ships it |
| Everything | Pre-1.0 rule of the house (`glam-cairo docs/DESIGN.md` §6): PATCH is an identical API and identical results; MINOR is any API change or any changed numeric result. A changed generator stream or a changed tie is therefore a MINOR bump, announced, and it moves the game's test vectors (`grimworld:PLAN.md` § Releases) |

### 9.3 The dependency on `uint252`

The package `uint252` 0.1.0 is published on scarbs.xyz (§3.4). L-M1 does not depend on it
(§3.3): bitmaps are `felt252` in the API, as in 1.8.0, and the engine uses `u256` limbs
internally. The dependency `uint252 = "0.1.0"` is added by the first item that needs the type
(a packed model, a `StorePacking`, or the owner's decision to type the bitmaps), as a MINOR
bump, by published version. The library does not re-export `u252`; a consumer that wants it
depends on `uint252` itself. `origami_hexmap` 1.8.0 keeps its own `u252` for its users until
it is decommissioned.

### 9.4 Changelog

`CHANGELOG.md`, keep-a-changelog form, one entry per version with four fixed headings:
*Parity* (items ported, counterparts, exclusions, the percentage), *Extensions* (new or changed
functions, with their need), *Deviations* (new or changed documented differences from `hexx`),
*Results changed* (any numeric change, with the affected functions and the reason; empty on a
PATCH). The game reads the last heading to know whether its vectors move.

## 10. Migration of the game and decommissioning of `origami_hexmap`

| Step | Condition | What is done | Who |
|---|---|---|---|
| 1. Pre-releases | `0.1.0-rc.1` published | SPK-7 may consume it or stay on 1.8.0: both give the same results. The game's `docs/CAIRO.md` §4 still names `origami_hexmap` | Game's orchestrator |
| 2. Migration | `0.1.0` published; `takeover_tests` green | The game's dependency moves to `hexx = "0.1.0"` and `uint252 = "0.1.0"` (published; needed for the type); imports change from `origami_hexmap::{HexMap, HexMapTrait, Direction, U252Trait, u252}` to `hexx::{HexMap, HexMapTrait, Direction}` and `uint252::{U252Trait, u252}`; the three renamed helpers (§5.2) if used; the game's test vectors are unchanged by construction. `docs/CAIRO.md` §4 is updated ("`u252` from the package `uint252`", "the map library `hexx`") | Game (ENG-05 or a dedicated lot), with the library's changelog |
| 3. Deprecation notice | The game's migration merged | A pull request in `dojoengine/origami`: the README of `crates/hexmap` says "Superseded by `hexx` (scarbs.xyz), same results; no further releases", the `Scarb.toml` description says the same. No code change, no release needed; the notice is on `main` and on the registry's README when 1.8.1 is published, which is the owner's call | Owner (maintainer of `origami`) |
| 4. Removal | LIB-07: parity reached or exclusions closed; the game on `hexx` for one full phase; no open issue naming `origami_hexmap` | `crates/hexmap` removed from the `origami` workspace on `main`; the tag `v1.8.0` keeps the source; the registry keeps `origami_hexmap` 1.8.0 (registry packages are not unpublished). `takeover_tests` deleted here | Owner, LIB-07 |

What existing users of `origami_hexmap` are told (step 3): the package stays installable at
1.8.0 forever; `hexx` `0.1.0` returns the same values for the same inputs (proved by
`takeover_tests`); the migration is a change of import path, plus the package `uint252` for the type;
new features land in `hexx` only. The `origami_map` sibling is untouched.

Final state of the crate in `dojoengine/origami`: absent from `main`, present in the tag
`v1.8.0` and on scarbs.xyz at 1.8.0.

## 11. Risks and open questions

| # | Risk or question | Evidence | Plan | Decides |
|---|---|---|---|---|
| R-1 | **The window is assembled at each tick** (D-120): its cost is paid at every action, and this plan's estimate (~70k for 4 chunks and two layers, §6.4) is above the ADR's "about 40k" | ADR-0006 § Cost; §6.4 | SPK-7 measures the assembly with and without a stored window, as the ADR says; the plan's function is the same in both cases. If the tick does not fit, the ADR's fallback is sight 5 on 13 × 14, which this plan does not design (§6.4b): its width differs from the chunk's, so the one-dimensional shift no longer applies | SPK-7 measures; owner decides |
| R-2 | **Closed.** The `u252` type was published on 2026-09-28 as the package `uint252` 0.1.0 (§3.4); L-M1 does not depend on it anyway (§9.3) | L-G1, question 3 | Nothing to do | — |
| R-3 | scarbs.xyz may refuse pre-release identifiers | Not verified | Fallback `0.0.N` (§9.1) | LIB-04 verifies |
| R-4 | The name `hexx` may be taken before publication | Free on 2026-09-28 | LIB-04 publishes an empty `0.0.1` at repository setup to reserve it, if the owner agrees | Owner |
| R-5 | The estimates of §7 are refuted by measurement, in particular N-8 (470–670k per tick), the assembly (~70k per tick) and N-1 (+15–25 %) | All marked estimate; the tick budget is the game's R-2 (`grimworld:PLAN.md`) | Every estimate is replaced by a measurement in LIB-05; a miss above 25 % is reported before the release; the fallback of ADR-0006 (sight 5 on 13 × 14, not designed here, §6.4b) stays the game's | LIB-05 reports; owner decides |
| R-6 | The row-parity trap: a chunk-level function (N-1, N-2) called with the wrong `odd` flag, or a window built on an odd origin, runs on a different hex grid than the map | LIB-02 §5.4; ADR-0006 §4; `window-parity-check.md` §1 | The flag is explicit on the two chunk-level functions and nowhere else; `assembly::origin` cannot produce an odd origin and `assemble` panics on one (`'Assembly: odd origin'`); the seam tests run on a double-width board with true global parity | LIB-05 |
| R-14 | The window's origin can lie before the location's first tile (adventurer within 7 columns or 8 rows of the location's edge) | §6.4 | Global coordinates are `i16` in `origin` and `local`; a chunk outside the location is passed as 0 (wall), which the location's closed border already implies | LIB-05 |
| R-7 | The tie rule at column 0 (the preferred tile can be off the board) | §6.6 (inferred) | The board form clears the column band and treats leaving the board as blocked; the property `line(a, b) == line(b, a)` is tested on every pair | LIB-05 |
| R-8 | `hexx`'s `f32` ties in `Div<i32>` and `to_lower_res` cannot be reproduced bit for bit where `f32` error decides | LIB-02 §4; §4.4 | Exact rational counterparts; the vectors list the inputs where `hexx` deviates from its own rule; they are deviations, not misses | Owner accepts at L-G2 |
| R-9 | Toolchain drift: every measured figure is at scarb 2.19.4 / snforge 0.61.0; the game pins its own toolchain in SPK-5 | `GAS.md:140`; `grimworld:PLAN.md` SPK-5 | LIB-04 pins the same versions in `.tool-versions`; a bump is a dedicated pull request that regenerates every snapshot (house rule) | LIB-04 |
| R-10 | The local `extern fn bitwise` declaration (`hexmap:src/helpers/bits.cairo:54`) is a private corelib libfunc; a compiler version could refuse it | Allowed by the owner for `origami_hexmap` | Kept; the fallback is the corelib operators at +30 % per generation (`GAS.md:654`) | Owner, if a compiler refuses it |
| R-11 | Class size of the game's contract with the tables | §7: ~340 felts for L-M1's new tables | A `consumer` fixture and `bytecode_size.py check` as in `glam-cairo`, from LIB-04 | LIB-04 |
| R-12 | Two direction types (§3.2) may confuse consumers | — | One table in the README (§3.2), conversions in both directions, the compass note on `EdgeDirection` | Owner may reverse (§12) |
| R-13 | The mirror's `Span<Hex>` outputs allocate per element; a consumer that calls them in a hot path pays for it | LIB-02 §4 | Documented on the type: the bitmap forms of `board` are the on-chain tools; the mirror's spans are for parity, tests and the client | — |
| Q-1 | Does the game need `hexagon(8)` (earshot) on the window, where the adventurer at `(7, 7)` or `(7, 8)` is 7 tiles from the ring? | `grimworld:docs/design/04-combat.md` § Ranges | `hexagon` clips at the board; earshot beyond the window is a distance test on global coordinates (`distance_between`), which the game can do without a board. To confirm with the game | Game |
| Q-3 | Which toolchain versions does LIB-04 pin: `origami_hexmap`'s (2.19.4 / 0.61.0) or SPK-5's? | R-9 | Recommendation: `origami_hexmap`'s until SPK-5 is done, then the game's, in one dedicated bump | Owner |
| Q-4 | Should the release candidates be consumed by SPK-7, or should SPK-7 stay on 1.8.0 and switch at 0.1.0? | `grimworld:PLAN.md` R-18 | Recommendation: switch at `0.1.0-rc.1` (identical results, no risk) so that the extensions are exercised as they land | Game's orchestrator |

The former Q-2 (goblins on the ring as targets) is closed by D-120: a tile of the ring is 7
tiles or more from the adventurer, never in sight and never in ranged range (ADR-0006 §4).

None of the decisions of L-G1 or D-120 leads to a problem this plan cannot honour; no
reopening is asked, and no point of L-G1 is open any more.

## 12. Recommendation for gate L-G2

**What the owner is asked to accept.** A Cairo package named `hexx`, in this repository, in
which:

1. the **mirror** follows `hexx` 0.25.0 name for name on integer coordinates `Hex { x: i32,
   y: i32 }` and `EdgeDirection`, with three kinds of departure only, all listed in a
   generated table checked in CI: floating-point, host and allocator items are absent;
   iterators become spans and callbacks become bitmaps; and `line_to` resolves exact ties by the
   game's rule, with the affected pairs listed by an off-chain comparison against `hexx`;
2. the **extension** is the engine of `origami_hexmap` 1.8.0 moved here under `board`,
   `finders` and `generators` with every result and every gas budget unchanged, proved by a
   test package that compares it with the registry package, plus the ten functions of L-M1
   (§6) on `u8` indices and `felt252` bitmaps, each with a scalar oracle, a worst-case bench and
   a target (§7), among them the assembly of the 15 × 16 window of D-120 from 2 or 4 chunks at
   each tick, without a loop, refusing an odd origin;
3. **L-M1** is exactly the game's needs plus the mirror foundation that N-5 and N-7 are
   specified against, released as `0.1.0` after release candidates for SPK-7; L-M2 completes
   the mirror, L-M3 closes the algorithms and the table, `1.0.0` decommissions
   `origami_hexmap` in four conditioned steps (§10);
4. the plan honours every decision of L-G1 and every answer of the project manager, at the
   places given in §13.

**Decisions taken here that the owner may want to reverse**, one line each, with the
alternative:

| # | Decision (section) | Alternative |
|---|---|---|
| D-1 | Package name `hexx` (§2.1) | `hexx_cairo` |
| D-2 | `Hex` on `i32`, overflow panics (§3.1) | `i16` components (no measurable gain; breaks `as_u64`) |
| D-3 | Two direction types: `EdgeDirection` (mirror, `hexx` names, y-down compass) and `Direction` (board, north-up names), same indices (§3.2) | One type, at the price of renaming `hexx`'s constants or teaching the game y-down names |
| D-4 | Bitmaps stay `felt252` in the board API; no `uint252` dependency in L-M1 (§3.3, §9.3) | `u252`-typed bitmaps from 0.1.0 (`uint252 = "0.1.0"`, published), changing every signature |
| D-5 | The mirror foundation is inside L-M1 (§8) | L-M1 = extensions only; the mirror starts at L-M2 and the line's definition lives only on the board |
| D-6 | `Hex::line_to` carries the game's tie rule as a documented deviation (§6.6) | A separately named `line_between`, leaving `line_to` unported (it cannot be reproduced without an `f32` model) |
| D-7 | Geometric bitmaps named `hexagon` and `hexagon_ring` on the facade (§6.7) | `range_geometric` / `ring_geometric` |
| D-8 | Canonical hexagon tables shifted and clipped, not a table per position (§6.7) | Per-position table for radius 6 (~2k instead of ~12k per query, +280 felts of class) |
| D-9 | Line table for distance ≤ 6, loop beyond (§6.6) | Loop only (~40k per query, no table) |
| D-10 | N-8 as `flood` returning layers plus `next_step` per walker, the id-order loop in the game (§6.9) | `next_steps(walkers) -> Span<u8>` computing all moves inside the library, which would freeze the id-order rule in the library |
| D-11 | Parity tooling by source parsing, house scripts adapted (§4.2) | `rustdoc` JSON |
| D-12 | Iterator-returning items ported as eager spans (§1.1) | Excluding them (the table would drop ~40 integer items) |
| D-13 | Bit operators and shifts on `Hex` excluded (§4.4) | Two's-complement emulation per component |
| D-14 | `glam` interop in a companion package `hexx_glam` at L-M3 (§4.4, §8) | Dropped altogether |
| D-15 | Three helpers renamed to American spelling (§5.2) | Keep the British names |
| D-16 | Release candidates `0.1.0-rc.N` (§9.1) | `0.0.N` |
| D-17 | `origami_hexmap` removed from `origami` `main` at the end, kept on the registry and in the tag (§10) | Kept on `main` as deprecated |
| D-18 | The parity flag is a parameter of the chunk-level functions (N-1, N-2), not a field of `HexMap` (§3.3) | A `parity` field or a `Chunk` type, changing the stored layout |
| D-19 | `assemble` refuses an odd origin by a panic `'Assembly: odd origin'` (§6.4) | An `Option`, at the price of a branch in every tick and of a silent fallback |
| D-20 | `assemble` takes the chunk offsets `(ox, oy)` and the chunk-row parity; the helper `origin(x, y)` on `i16` global coordinates computes them and can never produce an odd origin (§6.4) | `assemble` on global coordinates directly, with the two `DivRem` inside the per-tick call |
| D-21 | The rectangle masks of the assembly are the product of two 15-entry band tables (§6.4) | One 225-entry table per chunk role (900 felts), or a field division per call |

## 13. Where each decision and answer is honoured

| Decision or answer | Section |
|---|---|
| L-G1 Q1: `hexx` is the reference; feature parity wherever it makes sense on-chain; scope extended with what Cairo and the network require | §1 (the rule), §2.3 (every module), §4.4 (every item), §6 (extensions) |
| L-G1 Q2: the library lives in `bal7hazar/hexx-cairo`, published under its own name and cadence; the engine of `origami_hexmap` taken over as an extension | §2.1, §5, §9 |
| L-G1 Q2b: `origami_hexmap` decommissioned once the port is complete; the game consumes 1.8.0 then migrates by published version | §10, §9.1 |
| L-G1 Q3: `u252` from the package `uint252` of `bal7hazar/types-cairo` (published 0.1.0 on 2026-09-28) | §3.4, §5.1 (dropped here), §9.3, §11 R-2 closed |
| L-G1 consequences: parity table against the whole public API of 0.25.0, every exclusion with its reason and its integer counterpart | §4 |
| L-G1 consequences: extensions documented outside the parity table | §1.2, §4.2 (`docs/EXTENSIONS.md`) |
| L-G1 consequences: results identical to 1.8.0 so that the game migrates without moving its vectors | §5.4, §10 step 2 |
| L-G1 consequences: milestone L-M1 unchanged | §8 |
| L-G1 consequences: decommissioning steps and condition in the release plan | §10 |
| Point 1: margins inside the chunk, 13 × 13 interior evolves | §6.2 |
| Point 2: a parity flag in the layout; chunks stay 15 × 15 | §6.2 (`LayoutTrait::new_odd`), §3.3 (a parameter, not a field), §6.3 |
| Point 3: the library's axis convention is kept (`+x` West, odd-r); the client mirrors | §3.3, §3.5 (the negation of `x` in the conversion) |
| Point 4, decided by D-120 (owner, 2026-09-28): the window follows the adventurer, is 15 × 16, is recomputed at each tick and not stored; chunks stay 15 × 15; the origin on an even global row is an explicit constraint; the adventurer is on local `(7, 7)` or `(7, 8)`; the parity flag serves N-1 and N-2 only; the fallback is sight 5 on 13 × 14 | §6.4 (assembly, the refusal of an odd origin, the worst case at each tick), §6.4b (the fallback, not designed), §6.6 and §6.7 (local position as input), §6.9 and §7 (figures on 15 × 16), §3.3 and §5.3 (the flag never reaches the finders), §11 R-1 and R-6 |
| Point 5: one flood per tick on frozen occupancy; current occupancy filters; id order; fallback to the same layer; frozen at the first release | §6.9, §9.2 |
| Point 6: the game's tie rule; a documented deviation from `line_to`, excluded from the table at ties | §6.6, §4.3 (the tie list), §4.4 (`line_to` row) |
| Point 7: `hexx`'s names and semantics kept in the mirror; the game's arcs written with directions | §3.2, §6.8, §2.4 (the clash table) |
| COMMON.md §5: parity table generated and checked in CI; deviations documented; numeric results are API; what is taken over keeps its results | §4.2, §9.2, §5.4 |
| `grimworld:docs/CAIRO.md`: test-driven, gas as a test result, execution cost first, arithmetic then bitwise then loops, tables, oracles, determinism (lowest tile index) | §6 (each entry), §7, §6.9 |
