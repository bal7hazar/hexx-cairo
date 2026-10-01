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
| Grim World documents refreshed for ADR-0007 (`docs/needs/hexmap.md`, `docs/architecture/ADR-0007-native-starknet.md`, `docs/CAIRO.md`, `PLAN.md`) | `origin/main` | `a9f6e5663274021c2e37a3d86ad5db5ee61c792c` | `sources/grimworld/` |
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

**Compiler target: Cairo 2.19** (Scarb 2.19.4, snforge 0.61), the toolchain of
`origami_hexmap` 1.8.0 and of the owner's other libraries. The game is on the same compiler
since the owner dropped Dojo (ADR-0007, D-123, 2026-09-28: plain Starknet contracts on Cairo
2.19; exact pins by the game's SPK-5b). Consequences: `BoundedInt` stays (used by the engine at
`hexmap:src/map.cairo:8-11`, `helpers/bits.cairo:11-12`, `helpers/rng.cairo:23-24`); **no floor
at Cairo 2.13**, no second code base and **no separate class** called by library call; the
library keeps one target. What remains of need N-9 is `snforge_std` as a dev-dependency (§2.1,
§8). Nothing in the library depends on Dojo: no dependency, no model, no world; the consumer
is a Starknet contract (`#[starknet::contract]`) or a storage-free library of rules; the
tests and examples use snforge only.

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

### 1.4 What is normative in §6, and what is a sketch

Two audit passes showed that bit-exact formulas and gas sums written in prose, without code
and without tests, keep producing new errors. The plan therefore separates, for every
function of §6:

- **The contract, normative**: the signature; the domain (dimensions, coordinates, radius,
  what is refused and how); the semantics, stated as a property over a scalar oracle; the
  tie-breaks; the oracle itself; the worst case to benchmark; and the **regression cases**,
  every failing scenario found by the audits, each named with its input and its expected
  output. An implementation that satisfies the contract on the whole stated domain is
  correct, whatever its algorithm.
- **The design sketch, not normative**: the algorithm retained so far (masks, shifts,
  tables), corrected after the audits, under a heading that says so. **The implementation
  task of LIB-05 proves the sketch against the oracle over the whole stated domain before any
  optimisation is kept, and may replace it** by any algorithm that satisfies the contract;
  a replaced sketch is recorded in the task's report and in the plan.

Gas figures that are not measured are **targets given as ranges** (§7): the sum of the
stated operations of the sketch is the lower bound, never a single optimistic number; LIB-05
replaces every target by a measurement.

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
| Edition, dependencies | `edition = "2024_07"`, Cairo 2.19 (§0), no `starknet` dependency and no Dojo dependency (the library is pure Cairo, as the house ports; storage packing of `HexMap` is the consumer's, a Starknet contract or a storage-free library of rules). `snforge_std` under **`[dev-dependencies]` only** (need N-9, §8) | A regular dependency on `snforge_std`, which is what the published `origami_hexmap` 1.8.0 resolves to for its consumers |
| Need N-9 | The source manifest of 1.8.0 already declares `snforge_std` under `[dev-dependencies]` (`hexmap:Scarb.toml:14-15`, `snforge_std.workspace = true`; the workspace pins `0.61.0`, `sources/origami/Scarb.toml`), yet the package published on scarbs.xyz is resolved by its consumers as depending on `snforge_std >=0.61.0, <0.62.0` (`grimworld:docs/needs/hexmap.md` § "N-9 in detail", failure 1). **The defect is in the published artefact, not in the manifest**: the criterion of N-9 is therefore demonstrated on the published package (§8, L-M1 exit (8)), not by reading `Scarb.toml`. LIB-04 finds where the publication turns the dev-dependency into a dependency (the packaging step, the registry's index, or the version of Scarb that published 1.8.0) and records it | — |
| Manifest metadata | `description = "Hexagonal grids for Starknet: the hexx port and a bitmap board engine"`, `keywords = ["starknet", "cairo", "hexagon", "hexx", "pathfinding", "generation"]`, `homepage`, `documentation` and `repository` pointing at this repository. The description ("Hexagonal tile maps library for Dojo based games") and the keyword `dojo` of `hexmap:Scarb.toml:5, 12` are **not** taken over (§5.5) | — |
| Version | `0.1.0` at L-M1, pre-releases `0.1.0-rc.N` before it (§9) | — |
| Licence | MIT, as the repository already is. `origami_hexmap` is MIT (`sources/origami/Scarb.toml:14`), its author is the owner; the taken-over files keep their module headers and the README credits `origami_hexmap` 1.8.0 at commit `04ab30c` (§5.6) | — |

### 2.2 Module tree

The mirror keeps `hexx`'s module names (`src/lib.rs:273-292`). The extension keeps the module
names of `origami_hexmap` under one root module `board`, so that the take-over is a move of
files and the game's migration is a change of import path.

```text
crates/hexx/src/
  lib.cairo                    re-exports (§2.4)
  hex.cairo                    Hex, HexTrait (src/hex/mod.rs); one trait per hexx source file below
  hex/impls.cairo              operator impls of Hex (src/hex/impls.rs)                        L-M2
  hex/rings.cairo              HexRingsTrait (src/hex/rings.rs)                                L-M2
  hex/swizzle.cairo            HexSwizzleTrait (src/hex/swizzle.rs)                            L-M2
  hex/euclidean.cairo          HexEuclideanTrait (src/hex/euclidean.rs)                        L-M2
  hex/convert.cairo            HexConvertTrait, the Into impls (src/hex/convert.rs)            L-M2
  hex/iter.cairo               HexSpanExt: counterpart of HexIterExt (src/hex/iter.rs)         L-M2
  hex/grid/edge.cairo          GridEdge (src/hex/grid/edge.rs)                                L-M2
  hex/grid/vertex.cairo        GridVertex (src/hex/grid/vertex.rs)                            L-M2
  direction/edge_direction.cairo   EdgeDirection (src/direction/edge_direction.rs)
  direction/vertex_direction.cairo VertexDirection (src/direction/vertex_direction.rs)         L-M2
  direction/way.cairo          DirectionWay (src/direction/way.rs)                             L-M2
  direction/impls.cairo        Neg, mul_scalar of the directions (src/direction/impls.rs)      L-M2
  conversions.cairo            OffsetHexMode, the offset conversions (src/conversions.rs); DoubledHexMode, doubled and hexmod L-M2
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
  board/tables.cairo           the band tables COL_FROM, COL_TO, ROW_FROM, ROW_TO             new
  board/seams.cairo            N-2: sides, openings                                            new
  board/assembly.cairo         N-3: origin, assemble, window (15 × 16 from 2 or 4 chunks)      new
  board/cut.cairo              N-4: cut                                                        new
  board/line.cairo             N-5: line, line_of_sight, approach, LINES and LINE_SPANS        new
  board/hexagon.cairo          N-6: hexagon, hexagon_ring, HEXAGONS tables                     new
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
| `storage` | — | **excluded** as a module | — | `HexStore<T>`, `HexagonalMap<T>`, `HexModMap<T>`, `RombusMap<T>`, `RectMap<T>`, `RectMetadata`, `WrapStrategy` store one generic `T` per hex in a `Vec` or a `HashMap` (`src/storage/mod.rs:69-104`). On-chain state lives in the consumer's contract storage and boards live in bitmaps: the counterpart of the whole module is `board` (one bitmap per layer). The index formulas survive as `LayoutTrait::index` and `coords` (row-major offset, like `RectMap`, `src/storage/rect.rs:337-358`) and as `Hex::to_hexmod_coordinates` (like `HexModMap`) |
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
future extension needs the type (a packed storage struct of several boards, a `StorePacking`),
the library depends on `uint252 = "0.1.0"` by published version and does not re-export it. The bit
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
| Effective visibility | Every `pub` declaration of the listed files | Only what a consumer can reach: the walk follows `pub mod` and `pub use` from `src/lib.rs` and drops `pub(crate)` modules and re-exports (`pub(crate) mod way` in `src/direction/mod.rs:11`: `DirectionWay` is public through `pub use way::DirectionWay`, the trait `Way` is not; `pub(crate) use iter::ExactSizeHexIterator` in `src/hex/mod.rs:23`: not public). Public **fields** (`Hex::{x, y}`, `HexBounds::{center, radius}`, the shape fields, `GridEdge::{origin, direction}`, `GridVertex::{origin, direction}`), enum **variants** (`DirectionWay::{Single, Tie}`, `OffsetHexMode::{Even, Odd}`, `DoubledHexMode::{DoubledWidth, DoubledHeight}`, `HexOrientation::{Pointy, Flat}`) and public **trait members** (`HexIterExt`) are inventoried as items (audit, finding 12) |
| Cairo side | `pub trait XTrait` methods, `pub impl X of Trait<…>` | Same, plus `#[generate_trait] pub impl HexImpl of HexTrait`, one trait per `hexx` source file (§8, L-M2) |
| Precedence | Direct name match, then regex rules, else `missing` | (1) A direct match of name and owner; (2) **a curated per-item map** `COUNTERPARTS` (Rust item → Cairo item, or Rust item → reason), which is the machine form of §4.4 and wins over every rule: it holds the counterparts whose Rust signature would otherwise trip an exclusion rule (`field_of_movement`, `a_star`, `range_fov`, `directional_fov` with `impl Fn` and `HashSet`; `cached_*` with `[Vec<Self>; RANGE]`; `HexIterExt`; `FromIterator`); (3) the broad exclusion rules (`f32`, `Vec2`, `Vec3`, `Quat`, `&HexLayout`, `&mut [i32]`, `&[i32]`, reference glue, `serde`) for what neither of the first two resolved; (4) everything else stays **`missing`**, and a `missing` item fails `--check` at the release that scheduled it. The first version of this plan let the broad rules classify the counterparts' signatures, which would have hidden incomplete parity (audit, finding 13). The parser has unit tests on those cases, on public trait methods, on effective visibility and on re-exports |
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
| `struct Hex` `:69`, public fields `x`, `y` `:71, 73` | port | `Hex { pub x: i32, pub y: i32 }`, derives `Copy, Drop, Serde, PartialEq, Debug, Default, Hash` | L-M1 |
| `fn hex(x, y)` `:89` | port | `hexx::hex::hex` (imported from its module, as the house does for `vec3`) | L-M2 |
| `ZERO` `:97` | port | `const` on `HexTrait` | L-M1 |
| `ORIGIN`, `ONE`, `NEG_ONE`, `X`, `NEG_X`, `Y`, `NEG_Y` `:95-110` | port | `const` on `HexTrait` | L-M2 |
| `INCR_X`, `INCR_Y`, `INCR_Z`, `DECR_X`, `DECR_Y`, `DECR_Z` `:113-124` | port | `const [Hex; 2]` | L-M2 |
| `NEIGHBORS_COORDS` `:159` | port | `const [Hex; 6]` (read by `EdgeDirection::into_hex`) | L-M1 |
| `DIAGONAL_COORDS` `:186` | port | `const [Hex; 6]` | L-M2 |
| `new` `:208` | port | | L-M1 |
| `splat` `:225` | port | | L-M2 |
| `new_cubic` `:247` | port | panics `'Hex: cubic sum'` when `x + y + z != 0` (Rust `assert!`) | L-M2 |
| `x` `:256`, `y` `:264`, `z` `:274` | port | | L-M1 |
| `from_array` `:290`, `to_array` `:307`, `to_cubic_array` `:333` | port | `[i32; 2]`, `[i32; 3]` | L-M2 |
| `to_array_f32` `:315`, `to_cubic_array_f32` `:341` | excluded | `f32` output | — |
| `from_slice` `:352`, `write_to_slice` `:362` | excluded | slice APIs (house rule) | — |
| `as_ivec2` `:375`, `as_ivec3` `:390` | counterpart | `Into<Hex, IVec2>`, `Into<Hex, IVec3>` in the companion package `hexx_glam` (§9), as `nalgebra_glam` | L-M3 |
| `as_vec2` `:406` | excluded | `f32` output | — |
| `const_sub` `:449` | port | same name (Cairo has no `const fn`; the plain function behind `-`), used by `distance_to` | L-M1 |
| `const_neg` `:421`, `const_add` `:435` | port | same names | L-M2 |
| `round([f32; 2])` `:474` | excluded | `f32` input. The hexround algorithm is used internally on exact rationals by `line_to` and `Div<i32>` | — |
| `abs` `:498`, `min` `:511`, `max` `:525`, `dot` `:535`, `signum` `:546` | port | | L-M2 |
| `length` `:568`, `ulength` `:594`, `distance_to` `:615`, `unsigned_distance_to` `:625` | port | | L-M1 |
| `neighbor_coord` `:633`, `neighbor` `:665`, `all_neighbors` `:760` | port | | L-M2 |
| `diagonal_neighbor_coord` `:641`, `diagonal_neighbor` `:682`, `all_diagonals` `:767` | port | | L-M2 |
| `neighbor_direction` `:700` | port | `Option<EdgeDirection>` | L-M2 |
| `main_diagonal_to` `:709`, `diagonal_way_to` `:715` | port | | L-M2 |
| `main_direction_to` `:734`, `way_to` `:740` | port | `DirectionWay<EdgeDirection>` | L-M2 |
| `counter_clockwise` `:784`, `ccw_around` `:791`, `rotate_ccw` `:799`, `rotate_ccw_around` `:814`, `clockwise` `:831`, `cw_around` `:838`, `rotate_cw` `:846`, `rotate_cw_around` `:860` | port | the sense is `hexx`'s (§3.2) | L-M2 |
| `reflect_x` `:868`, `reflect_y` `:876`, `reflect_z` `:884` | port | | L-M2 |
| `line_to` `:903` | port, **deviation** | `Span<Hex>`, `distance + 1` items, endpoints included. The exact integer line; exact ties resolved by the game's rule (§6.6). **No identity domain is claimed**: `hexx` rounds its endpoints to `f32` (`:906`) and interpolates in `f32` (`:908`), and either rounding can flip a sample even below `2^24` (`(8_000_000, 0) → (8_000_001, 6)`, sample 2). Verified identical on every non-tie pair of the 15 × 16 window and on the seeded sample of `[-40, 40]²`; every other difference is listed by `refgen` as a deviation (§6.6, §4.3) | L-M1 |
| `rectiline_to` `:936` | port | `Span<Hex>` | L-M2 |
| `lerp` `:973` | excluded | `f32` parameter | — |
| `range` `:993`, `xrange` `:1021` | port | `Span<Hex>`, same order (x then y) | L-M2 |
| `to_lower_res` `:1064` | port, deviation | exact floor division instead of `f32` floor: identical while `hexx`'s `f32` is exact (`|value| < 2^24`), exact beyond | L-M2 |
| `to_higher_res` `:1114`, `to_local` `:1143`, `wrap_in_range` `:1183` | port | | L-M2 |
| `range_count` `:1160` | port | | L-M2 |
| `impl Debug` `:1189` | port | prints `x`, `y`, `z` as `hexx` | L-M2 |

#### `hex` — operators (`src/hex/impls.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `PartialEq<Hex> for &Hex` `:10` | excluded | reference glue | — |
| `Add<Hex>` `:16`, `Sub<Hex>` `:95`, `Neg` `:321` | port | `HexAdd`, `HexSub`, `HexNeg` | L-M2 |
| `Add<i32>` `:25`, `Sub<i32>` `:104` | counterpart | `add_scalar`, `sub_scalar` (Cairo's `Add<T>` is homogeneous; house convention `mul_scalar`) | L-M2 |
| `Add<EdgeDirection>` `:37`, `Sub<EdgeDirection>` `:116` | counterpart | `add_direction`, `sub_direction` (same reason) | L-M2 |
| `Add<VertexDirection>` `:46`, `Sub<VertexDirection>` `:125` | counterpart | `add_diagonal`, `sub_diagonal` | L-M2 |
| `AddAssign` `:55`, `SubAssign` `:134`, `MulAssign` `:196`, `DivAssign` `:268`, `RemAssign` `:307` | port | `core::ops::*Assign` | L-M2 |
| `AddAssign<i32>` `:62`, `SubAssign<i32>` `:141`, `MulAssign<i32>` `:203`, `DivAssign<i32>` `:275`, `RemAssign<i32>` `:314`, `AddAssign<EdgeDirection>` `:69`, `AddAssign<VertexDirection>` `:76`, `SubAssign<EdgeDirection>` `:148`, `SubAssign<VertexDirection>` `:155` | excluded | heterogeneous assignment operators; the named `*_scalar` / `*_direction` methods cover them (house rule for `Vec * scalar`) | — |
| `Sum`, `Sum<&Hex>` `:83-89`, `Product`, `Product<&Hex>` `:217-223` | port | `Sum` / `Product` of an iterator, as `nalgebra-cairo` does (`docs/DESIGN.md` D10); the `&Hex` variants collapse into the by-value ones | L-M2 |
| `Mul<Hex>` `:162`, `Div<Hex>` `:229`, `Rem<Hex>` `:289` | port | per component; `Div` truncates toward zero as Rust; division by a zero component panics | L-M2 |
| `Mul<i32>` `:174` | counterpart | `mul_scalar` | L-M2 |
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
| `trait HexIterExt` and its members `average`, `center`, `bounds` (`src/hex/iter.rs:4-46`) | counterpart | `HexSpanExt` on `Span<Hex>`: `average` through the exact `div_scalar` (same deviation), `center`, `bounds` | L-M2 |
| `ExactSizeHexIterator` `:73` | not public | `pub(crate) use` in `src/hex/mod.rs:23`: not in the inventory (the first version counted it as an excluded public item, audit finding 12) | — |

#### `hex::grid` (`src/hex/grid/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `GridEdge` (`edge.rs:12`), public fields `origin` `:14`, `direction` `:16`; `equivalent` `:23`, `destination` `:31`, `vertices` `:38`, `flipped` `:55`, `const_neg` `:65`, `clockwise` `:75`, `counter_clockwise` `:85`, `rotate_cw` `:95`, `rotate_ccw` `:104`, `Hex::all_edges` `:116`, `Neg` `:124`, `From<EdgeDirection>` `:133` | port | | L-M2 |
| `GridVertex` (`vertex.rs:13`), public fields `origin` `:15`, `direction` `:17`; `equivalent` `:24`, `coordinates` `:44`, `destinations` `:54`, `side_edges` `:65`, `const_neg` `:81`, `clockwise` `:91`, `counter_clockwise` `:101`, `rotate_cw` `:111`, `rotate_ccw` `:120`, `Hex::all_vertices` `:132`, `Neg` `:140`, `From<VertexDirection>` `:149` | port | | L-M2 |

#### `direction` (`src/direction/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `struct EdgeDirection(u8)` (`edge_direction.rs:75`), derives | port | §3.2 | L-M1 |
| The 30 compass constants of `EdgeDirection` `:79-190` (`X_NEG_Y`, `FLAT_TOP_RIGHT`, `FLAT_NORTH_EAST`, `POINTY_TOP_RIGHT`, `POINTY_NORTH_EAST`, `NEG_Y`, `FLAT_TOP`, `FLAT_NORTH`, `POINTY_TOP_LEFT`, `POINTY_NORTH_WEST`, `NEG_X`, `FLAT_TOP_LEFT`, `FLAT_NORTH_WEST`, `POINTY_LEFT`, `POINTY_WEST`, `NEG_X_Y`, `FLAT_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`, `POINTY_BOTTOM_LEFT`, `POINTY_SOUTH_WEST`, `Y`, `FLAT_BOTTOM`, `FLAT_SOUTH`, `POINTY_BOTTOM_RIGHT`, `POINTY_SOUTH_EAST`, `X`, `FLAT_BOTTOM_RIGHT`, `FLAT_SOUTH_EAST`, `POINTY_RIGHT`, `POINTY_EAST`), `ALL_DIRECTIONS` `:208` | port | verbatim, with the north-up note (§3.2) | L-M1 |
| `iter` `:212` | counterpart | `ALL_DIRECTIONS.span()` (a `Span` is the iterator) | L-M1 |
| `index` `:219`, `into_hex` `:226`, `const_neg` `:243`, `clockwise` `:261`, `counter_clockwise` `:279`, `rotate_ccw` `:296`, `rotate_cw` `:313` | port | | L-M1 |
| `angle_between` `:326`, `angle_degrees_between` `:333`, `angle_to` `:341`, `angle_degrees_to` `:350`, `angle_flat` `:360`, `angle_pointy` `:370`, `angle` `:378`, `unit_vector` `:393`, `world_unit_vector` `:404`, `angle_flat_degrees` `:415`, `angle_pointy_degrees` `:425`, `angle_degrees` `:435`, `from_pointy_angle_degrees` `:453`, `from_flat_angle_degrees` `:469`, `from_pointy_angle` `:486`, `from_flat_angle` `:502`, `from_angle_degrees` `:527`, `from_angle` `:553` | excluded | `f32` angles and vectors. Integer counterparts of "the direction of a hex": `Hex::way_to`, `main_direction_to`, `neighbor_direction`; of "rotate by an angle": `rotate_cw(n)` | — |
| `diagonal_ccw` `:571`, `vertex_ccw` `:586`, `diagonal_cw` `:601`, `vertex_cw` `:616`, `vertex_directions` `:623` | port | | L-M2 |
| `From<EdgeDirection> for Hex` `:628` | port | `Into<EdgeDirection, Hex>` | L-M1 |
| `impl Debug` for `EdgeDirection` `:635` | port | prints the index and the pointy name | L-M2 |
| `struct VertexDirection(u8)` (`vertex_direction.rs:74`), its 36 compass constants `:78-201` (`X_NEG_Y_NEG_Z`, `X`, `FLAT_RIGHT`, `FLAT_EAST`, `POINTY_TOP_RIGHT`, `POINTY_NORTH_EAST`, `X_NEG_Y_Z`, `NEG_Y`, `FLAT_TOP_RIGHT`, `FLAT_NORTH_EAST`, `POINTY_TOP`, `POINTY_NORTH`, `NEG_X_NEG_Y`, `Z`, `FLAT_TOP_LEFT`, `FLAT_NORTH_WEST`, `POINTY_TOP_LEFT`, `POINTY_NORTH_WEST`, `NEG_X_Y_Z`, `NEG_X`, `FLAT_LEFT`, `FLAT_WEST`, `POINTY_BOTTOM_LEFT`, `POINTY_SOUTH_WEST`, `NEG_X_Y_NEG_Z`, `Y`, `FLAT_BOTTOM_LEFT`, `FLAT_SOUTH_WEST`, `POINTY_BOTTOM`, `POINTY_SOUTH`, `X_Y`, `NEG_Z`, `FLAT_BOTTOM_RIGHT`, `FLAT_SOUTH_EAST`, `POINTY_BOTTOM_RIGHT`, `POINTY_SOUTH_EAST`), `ALL_DIRECTIONS` `:221` | port | | L-M2 |
| `VertexDirection::iter` `:225` | counterpart | `ALL_DIRECTIONS.span()` | L-M2 |
| `VertexDirection::{index, into_hex, const_neg, clockwise, counter_clockwise, rotate_ccw, rotate_cw}` `:232-314`, `direction_ccw` `:573`, `edge_ccw` `:588`, `direction_cw` `:603`, `edge_cw` `:618`, `edge_directions` `:625`, `From<VertexDirection> for Hex` `:630`, `Debug` `:637` | port | | L-M2 |
| `VertexDirection` angle functions `:327-555` (same 18 names as the edge ones) | excluded | `f32` | — |
| `Neg` for both directions (`impls.rs:5, 13`) | port | | L-M2 |
| `Shr<u8>`, `Shl<u8>` for both `:21-51` | counterpart | Cairo's corelib has no `Shl`/`Shr` for user types; the named `rotate_cw(n)` / `rotate_ccw(n)` are the operators' bodies (`:25, :41`) | — (nothing to add) |
| `Mul<i32>` for both `:53, 61` | counterpart | `mul_scalar(n) -> Hex` | L-M2 |
| `enum DirectionWay<T>` (`way.rs:30`, public through `pub use way::DirectionWay`, `mod.rs:15`), variants `Single` `:32`, `Tie` `:34`, `unwrap` `:53`, `contains` `:62`, `map` `:75`, `PartialEq<T>` `:42`, `From<T>` `:95`, `From<[T; 2]>` `:102` | port | `map` takes a function pointer, not a closure, unless the `closures` feature of Cairo is adopted (LIB-04 decides) | L-M2 |
| `trait Way` `:37` and its impls `:109, 121` | not public | `pub(crate) mod way` (`src/direction/mod.rs:11`): only `DirectionWay` is re-exported; `Way` is a crate-private helper and is not in the inventory (the first version marked it ported, audit finding 12). Its two methods are `counter_clockwise` and `clockwise` of the directions, already ported | — |
| `angles::{DIRECTION_ANGLE_OFFSET_RAD, DIRECTION_ANGLE_OFFSET_DEGREES, DIRECTION_ANGLE_RAD, DIRECTION_ANGLE_DEGREES}` (`mod.rs:18-31`) | excluded | `f32` constants | — |

#### `conversions` (`src/conversions.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `enum OffsetHexMode` `:29`, variants `Even` `:34`, `Odd` `:39` | port | | L-M1 |
| `enum DoubledHexMode` `:12`, variants `DoubledWidth` `:15` (`Default`), `DoubledHeight` `:17` | port | | L-M2 |
| `to_offset_coordinates` `:65`, `from_offset_coordinates` `:142` | port | exact: `midpoint` and the divisions act on even numerators | L-M1 |
| `to_doubled_coordinates` `:50`, `from_doubled_coordinates` `:128` | port | | L-M2 |
| `to_hexmod_coordinates` `:92`, `from_hexmod_coordinates` `:110` | port | `rem_euclid` written out | L-M2 |

#### `orientation` (`src/orientation.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `enum HexOrientation` `:124`, variants `Pointy`, `Flat`, `Default = Flat`, `Not` `:152` | port | | L-M1 |
| `HexOrientationData` `:52`, `flat` `:65`, `pointy` `:86`, `forward` `:106`, `inverse` `:113`, `orientation_data` `:136`, `Deref` `:144` | excluded | `f32` matrices | — |

#### `bounds` (`src/bounds.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `struct HexBounds` `:36`, public fields `center` `:38`, `radius` `:40`; `new` `:47`, `from_radius` `:54`, `positive_radius` `:78`, `is_in_bounds` `:86`, `hex_count` `:95`, `hex_count32` `:104`, `wrap_local` `:135`, `wrap` `:149`, `corners` `:156` | port | `hex_count` returns `usize` | L-M2 |
| `from_min_max` `:64` | port, deviation | uses `div_scalar` (exact rational; same rounding rule) | L-M2 |
| `all_coords` `:111`, `intersecting_with` `:116` | port | `Span<Hex>` | L-M2 |
| `FromIterator<Hex>` `:161` | counterpart | `from_span(Span<Hex>)` | L-M2 |

#### `shapes` (`src/shapes.rs`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `Parallelogram` `:11`, public fields `min` `:13`, `max` `:15`; `new` `:31`, `coords` `:37`, `Default` `:18`; `parallelogram` `:45` | port | `Span<Hex>` | L-M2 |
| `Triangle` `:62`, public field `size` `:64`; `new` `:77`, `coords` `:84`, `Default` `:67`; `triangle` `:95` | port | | L-M2 |
| `Hexagon` `:111`, public fields `center` `:113`, `radius` `:115`; `new` `:131`, `coords` `:137`, `Default` `:118`; `hexagon` `:144` | port | the coordinate form of the bitmap `HexMapTrait::hexagon` (§6.7) | L-M2 |
| `Rombus` `:156`, public fields `origin` `:158`, `rows` `:160`, `columns` `:162`; `coords` `:178`, `Default` `:165`; `rombus` `:186` | port | | L-M2 |
| `PointyRectangle` `:205`, public fields `left` `:207`, `right` `:209`, `top` `:211`, `bottom` `:213`; `coords` `:231`, `Default` `:216`; `pointy_rectangle` `:243` | port | | L-M2 |
| `FlatRectangle` `:266`, public fields `left` `:268`, `right` `:270`, `top` `:272`, `bottom` `:274`; `coords` `:291`, `Default` `:277`; `flat_rectangle` `:303` | port | | L-M2 |

#### `algorithms` (`src/algorithms/`)

| Item | Status | Cairo form or reason | Milestone |
|---|---|---|---|
| `field_of_movement(coord, budget, cost: Fn(Hex) -> Option<u32>) -> HashSet<Hex>` (`field_of_movement.rs:63`) | counterpart | `hexx::algorithms::field_of_movement(map: HexMap, from: u8, budget: u8, costs: Span<felt252>) -> felt252`, forwarding to `HexMapTrait::field_of_movement`. Same cost model: `hexx` charges `1 + cost(h)` (`:16-18`), the board charges `k + 2` for class `k` (`hexmap:src/finders/dial.cairo:3-4`), so class `k` is `cost(h) = k + 1`, `None` is a wall, and `cost(h) = 0` is any other walkable tile. Limits documented: at most 3 classes (cost 2..=4), a bounded board, the outer ring as wall. This corrects LIB-02 §3.2, which called the two "close": they are the same model within those limits | L-M3 |
| `a_star(start, end, cost: Fn(Hex, Hex) -> Option<u32>) -> Option<Vec<Hex>>` (`pathfinding.rs:110`) | counterpart, deviation | `hexx::algorithms::a_star(map, from, to, costs) -> Option<Span<u8>>`, forwarding to `search_path_weighted` and reordering the path from start to end with both included (the board returns target to start, start excluded, `hexmap:src/map.cairo:255`). Per-directed-step costs (`cost(a, b)`) have no counterpart: only per-tile entry costs. Ties: lowest tile index (the board's rule) against the heap order of `hexx` (unspecified) | L-M3 |
| `range_fov(coord, range, blocking: Fn(Hex) -> bool) -> HashSet<Hex>` (`fov.rs:29`) | counterpart, deviation | `hexx::algorithms::range_fov(map, from, range) -> felt252`: for every tile of `hexagon_ring(from, range)`, the prefix of `line` up to the first wall (`take_while(!blocking)`, `:29-34`); walls are the blocking set. The lines carry the game's tie rule (§6.6) | L-M3 |
| `directional_fov(coord, range, direction: EdgeDirection, blocking)` `:61-66` | counterpart, deviation | `directional_fov(map, from, range, direction: EdgeDirection) -> felt252`: as upstream, the facing is an **`EdgeDirection`** (`:64`), whose two vertex directions `direction.vertex_directions()` (`:67`) select the ring tiles whose `diagonal_way_to` matches one of them (`:70-73`); then the board and line deviations of `range_fov`. The first version of this plan wrote `VertexDirection` for the parameter (audit, finding 11) | L-M3 |

#### Modules excluded as a whole

`layout` (24 functions, `HexLayout`, `Default`), `storage` (`HexStore<T>` with `get`, `get_mut`,
`values`, `values_mut`, `iter`, `iter_mut`; `HexagonalMap<T>`, `HexModMap<T>`, `RombusMap<T>`,
`RectMap<T>`, `RectMetadata` and its 23 builders and accessors, `WrapStrategy`) and `mesh`
(the items of LIB-02 §1.10) have the module-level status of §2.3 with their reasons. The
generated table lists their items as `dropped` with the module's reason, so that the
percentage is honest.

#### Counts

From the source, counting effective visibility: `hex` has 62 public functions and 16
constants in `mod.rs`, 24 in `rings.rs`, 8 swizzles, 5 euclidean, 2 packing functions, 57
operator impls, 8 `From` impls, 2 public fields and the 3 members of `HexIterExt`; the
directions have 31 functions and 31 constants (edge), 31 and 37 (vertex), 8 operator impls,
the `DirectionWay` enum with 2 variants, 3 methods and 3 impls; `conversions` 6 functions and
2 enums with 4 variants; `bounds` 12 functions, 2 fields and 1 impl; `shapes` 15 functions, 6
structs with 16 public fields and 6 `Default` impls; `grid` 20 functions, 4 fields and 4
impls; `algorithms` 4; `orientation` 5 functions, 1 enum with 2 variants and 2 impls; `layout`
24; `storage` 55; `mesh` 69. `Way` and `ExactSizeHexIterator` are crate-private and not
counted. Every item of a kept or adapted module is a port or a counterpart except the
`f32`, slice, bit-operator and reference-glue items marked excluded above. The percentage of
the generated table is computed by the script, not by hand.

## 5. The take-over of the engine of `origami_hexmap`

### 5.1 What is taken as is

Every source file of `hexmap:src/` except `types/u252.cairo` and the tests of the type `u252`
(`src/tests/bench_u252.cairo`, the module tests of `types/u252.cairo`, `test_readme_u252`,
§5.4), moved into the tree of §2.2 with its module doc, its constants, its tests and its gas
budgets; `tests/readme.cairo` minus `test_readme_u252`;
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

1. **Every engine test of 1.8.0 moves with its budget** (`src/tests/*` except
   `bench_u252.cairo`, the module tests except those of `types/u252.cairo`, and
   `tests/readme.cairo` except `test_readme_u252`): the pinned grids of one seed per generator
   (`README.md` § Randomness, "each generator has a test pinning the exact grid of one seed"),
   the property tests (`src/tests/properties.cairo`), the oracles (scalar BFS at
   `src/finders/bfs.cairo:1183`, scalar Dial in `bench_dial.cairo`, scalar automaton in
   `bench_caver.cairo`, reference walker at `src/generators/walker.cairo:535`), the variants
   and the 256-seed spreader statistics. **The tests of the type `u252` belong to the package
   `uint252`**: `src/tests/bench_u252.cairo` imports `types::u252::{PRIME, U252Trait, u252}`
   and `starknet::storage_access::StorePacking` (`:16-17`), neither of which exists in this
   library (`u252` is dropped, §5.1; no `starknet` dependency, §2.1). They move to
   `bal7hazar/types-cairo` with the type, and this plan claims nothing about them (audit,
   finding 17).
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
`board` documentation because they define the results; its first paragraph ("for Dojo-based
games", "the hexagonal sibling of `origami_map`") is not carried. The manifest of 1.8.0: its
description and its keyword `dojo` are replaced (§2.1), and `snforge_std` stays a
dev-dependency, verified on the published package (N-9).

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

Every entry has two parts (§1.4). **Contract (normative)**: signatures, module, domain,
semantics as a property over the scalar oracle, tie-breaks, oracle, worst case, regression
cases. **Design sketch (not normative)**: the algorithm retained so far with its reason (the
order of preference of `grimworld:docs/CAIRO.md` §3: arithmetic, then bitwise, then bounded
loops; tables over computation) and the sum of its operations, which is the lower bound of
the target range of §7. LIB-05 proves each sketch against its oracle on the whole domain
before keeping it, and may replace it. The board of the tick is the **15 × 16 window** of ADR-0006 §4
as decided by D-120: 240 bits, one felt, two-limb path like the 225 bits of a chunk
(`sources/hexx-cairo-main/window-parity-check.md` §3: "the cost of a flood layer does not
change"); it follows the adventurer, is assembled from 2 or 4 chunks of 15 × 15 at each tick
and is not stored; its origin is on an even global row, so the adventurer stands on local
column 7 and local row 7 (global row odd) or 8 (global row even). Every figure marked measured
was taken on a 17 × 14 board (238 bits, also two-limb) and is carried as the target for
15 × 16. Nothing below is indexed from a fixed centre: N-5 and N-6 take the local position.

### 6.1 Distance and neighbours

**Contract (normative)**

| | |
|---|---|
| Signatures | Mirror (L-M1 subset, §8): `HexTrait::length(self) -> i32`, `ulength -> u32`, `distance_to(self, rhs) -> i32`, `unsigned_distance_to -> u32`. Board (taken over): `HexMapTrait::hex_distance(from, to) -> u8`, `neighbor(position, direction) -> Option<u8>`, `LayoutTrait::neighbor_mask(self, position) -> felt252` (renamed, §5.2; the position must be an interior tile, as documented at `hexmap:src/helpers/layout.cairo:269`). New, one signature each: `Geometry::distance_between(x1: u8, y1: u8, x2: u8, y2: u8) -> u16` (global coordinates, no board); `Geometry::chunk_of(x: u8, y: u8) -> (u8, u8)` (`(x / 15, y / 15)`, the chunk size is the constant `CHUNK = 15` of D-120; unsigned, for tiles of the location only); `LayoutTrait::neighbor_direction(width: u8, height: u8, from: u8, to: u8) -> Option<Direction>` |
| Module | `board::geometry`, `board::layout` |
| Domain | `distance_between`: every `u8` pair; the result reaches 382 for `(255, 0)` and `(0, 255)`, hence `u16`, and every intermediate sum is computed on `u16`. `chunk_of`: every `u8` pair (chunk indices `0..=17`); it is not used to place a window (§6.4). `neighbor_direction`: `from` and `to` inside the board (`< W·H`, else `None`); `None` when the two tiles are not adjacent |
| Semantics | `distance_between(x1, y1, x2, y2)` equals the cube distance of the two tiles in the odd-r frame of the board (`q = x − ⌊y/2⌋`, `r = y`), which equals `hex_distance` on any board that contains both. `neighbor_direction(from, to)` is `Some(d)` if and only if `LayoutTrait::neighbor(W, H, from, d) == Some(to)`, and `None` otherwise |
| Tie-breaks | None (the functions are total on their domain) |
| Oracle | The scalar definitions above: `hex_distance` on a containing board, `Hex` distance through `to_hex`, and `LayoutTrait::neighbor` for every direction; the property test of all pairs of a 7 × 7 (`src/tests/properties.cairo:153`) extended to global coordinates |
| Domain coverage | Worst case of the whole domain: `distance_between` is maximal at `(0, 0)`–`(255, 255)` (`dq = 128`, `dr = 255`, `dq + dr = 383`; every other pair has `|dq + dr| ≤ 255 + 255 − 127`); the other functions are input-independent within their domain, up to a `match` arm |
| Worst case | `distance_between`: `(0, 0)` and `(255, 255)`, result 383; `neighbor_direction`: an odd row, a non-adjacent pair |
| Regression cases | **R-D1** (audit pass 1, finding 10; pass 3, finding 31): `distance_between(255, 0, 0, 255) = 382` (`q`: `255 − 0 = 255` and `0 − 127 = −127`, `dq = −382`, `dr = 255`, `dq + dr = −127`, max 382) and `distance_between(0, 0, 255, 255) = 383` (`q`: `0` and `255 − 127 = 128`, `dq = 128`, `dr = 255`, `dq + dr = 383`). **R-D2** on width 15, `neighbor_direction(15, 16, 14, 15) = None` (the last tile of row 0 and the first of row 1 are not neighbours although their indices differ by one). **R-D3** every position `from` and direction `d` of a 15 × 16: when `neighbor(from, d) = Some(to)`, `neighbor_direction(from, to) = Some(d)`; when `neighbor(from, d) = None` (a boundary, for example East of `(0, 0)`), no `to` is asserted (audit pass 3, finding 31). **R-D4** `neighbor_direction(15, 16, 0, 1) = Some(West)` and `neighbor_direction(15, 16, 0, 14) = None` |

**Design sketch (not normative)**

| | |
|---|---|
| Algorithm | Arithmetic: the formula of `Geometry::distance` (`hexmap:src/helpers/geometry.cairo:35-59`, no negative intermediates) on `u16`; two `DivRem` by 15 for the chunk. `neighbor_direction` decodes both indices into `(x, y)` with `LayoutTrait::coords` and matches on `(x_to − x_from, y_to − y_from)` and the parity of `y_from` against the six offsets of the neighbour table (`hexmap:src/types/direction.cairo:7-14`) |
| Operations, summed (exact lower bound of the target) | `hex_distance` **10,393 measured** (`GAS.md:1878`); `neighbor` **6,959 measured** (`:1869`). `distance_between`: 2 `DivRem` (2 × 1,098 measured, `:1535`) + 10 `u16` operations at 300: `2,196 + 3,000 = ` **5,196**. `chunk_of`: `2 × 1,098 = ` **2,196**. `neighbor_direction`: 2 `DivRem` (2,196) + 1 `DivRem` for the parity (1,098) + the `match` (1,000): **4,294**. `neighbor_mask` (taken over, no bench in 1.8.0): 1 `DivRem` (1,098) + 1 lookup (1,269) + 2 products (196): **2,563**. Unit costs of the estimates: an `i32`/`u16` operation 300, a comparison 100, a six-arm `match` 1,000, a loop iteration 1,270 (measured, `:45`) |

### 6.2 N-1 — Generation of a board given its margins

The project manager's answers (L-G1, points 1 and 2): the seam is inside the chunk, the
chunk's outer ring holds the tiles copied from its neighbours, the 13 × 13 interior evolves,
chunks stay 15 × 15, and a parity flag handles chunks whose first row is a global odd row.

```cairo
/// `fixed`: the ring tiles whose value is given (the sides that face a generated neighbour);
/// `values`: their values; the other ring tiles are drawn from the seed with the interior
/// and then frozen (D-22); `odd`: the chunk's first row is a global odd row.
fn generate_with_margins(
    width: u8, height: u8, order: u8, seed: felt252, fixed: felt252, values: felt252, odd: bool,
) -> felt252;                                                   // Caver
fn new_cave_with_margins(width, height, order, seed, fixed, values, odd) -> HexMap;   // facade, forwards
/// `order` generations on an existing grid; the tiles of `held` (any tiles, interior included)
/// and the whole ring keep their current value (D-28).
fn smooth(self: HexMap, order: u8, held: felt252, odd: bool) -> HexMap;
```

**Contract (normative)**

| | |
|---|---|
| Module | `generators::caver`, facade in `board::map` |
| Domain | `W, H ≥ 3` and **`W·(H + 1) + 1 ≤ 251`**, else `'Caver: dimensions too large'` (D-30): 15 × 15 gives 241 and passes; 17 × 14, the fixture of every measured figure, gives 256 and is refused (it stays valid for `generate`, whose ring is empty). `fixed` and `values` are masked to the ring; `held` may be any tiles; `order` any `u8`; `odd` states the global parity of local row 0 |
| Domain coverage | Cost given as a **bound parameterised by `order`** (audit pass 3, finding 39): every generation costs the same within the domain (the two-limb path serves every board of the domain, since `W·H ≥ 129` for 15 × 15 and the sketch takes the two-limb form for every board; the single-limb form of `generate` is not used by `generate_with_margins`), so `cost(order) = fixed + order × per_generation` (the sums below). The domain-wide worst case is `order = 255`; the **game-sized fixture** is `order = 3` (the game's default, `README.md` § Create a map). Both are benchmarked |
| Semantics | Let `S` be the scalar automaton B4/S2 (`hexmap:src/generators/caver.cairo:1-5`: a wall with at least 4 floor neighbours becomes floor, a floor with at least 2 stays floor) run on the board with the **global** parity of each row (local row `y` is globally even iff `y` is even XOR `odd`), reading the six neighbours from the neighbour table (`hexmap:src/types/direction.cairo:7-14`), where a neighbour outside the board is wall and a frozen tile keeps its value. `generate_with_margins` returns `S` applied `order` times to the initial grid `fill`, with the ring frozen, where `fill` is the interior and the free ring tiles (the ring minus `fixed`) drawn from the seed exactly as `CaverInternal::fill` draws them (`:101-104`) and the `fixed` tiles set to `values`. `smooth` returns `S` applied `order` times to `self.grid` with `held ∪ ring` frozen (D-28) |
| Tie-breaks | None: the automaton is synchronous and deterministic |
| Oracle | (1) The scalar automaton `reference` of `src/tests/bench_caver.cairo`, extended with a set of frozen tiles and with the global parity of row 0, run on 3 × 3 to 15 × 15 boards, both parities, 64 seeds. (2) **Equality with `generate`** when the whole ring is fixed to wall: `generate_with_margins(W, H, o, s, ring, 0, false) == generate(W, H, o, s)` bit for bit (audit pass 1, finding 3). (3) The fixed tiles and, for `smooth`, the held tiles are unchanged after any `order`; the free ring tiles equal the fill. (4) **Plane tests, on interior destinations**: the six neighbour planes of the implementation, exposed to the test module, compared with the scalar neighbour table **on every interior tile** of 15 × 15 and 7 × 7 for both parities, on 256 seeded grids. The planes are only consumed for interior tiles (the ring is frozen), so their bits at ring destinations are unspecified: the sketch's `P_W = G_low / 2` has no bit at `(0, 0)` for a live `(1, 0)`, which is correct for the output and wrong as a whole-board plane (audit pass 3, finding 35); the property is therefore stated on interior destinations, and the frozen-ring output is tested separately by (1) to (3). A single-live-tile output of B4/S2 is always empty and validates nothing by itself (audit pass 2, finding 21) |
| Stream | The stream of `generate_with_margins` is API from 0.1.0: one test pins the grid of one seed per parity, all sides fixed and none fixed |
| Worst case | Domain-wide: `generate_with_margins` at `order = 255`, 15 × 15, all four sides fixed, `odd = true`. Game-sized fixture: `order = 3`, same inputs; `order = 5` for the per-generation figure. `smooth`: `order = 255` domain-wide; fixture `order = 3`, `held` = ring plus 20 interior tiles, `odd = true` |
| Regression cases | **R-N1-1** (audit pass 1, finding 1): 15 × 15, `odd = false`, live tiles `{0, 190, 191}` = `(0, 0)`, `(10, 12)`, `(11, 12)`, `smooth` with `held = ring`, one generation: tile `(10, 12)` (even row) has the live neighbour `(11, 12)` only and tile `(11, 12)` has `(10, 12)` only; each has one, fewer than the two of S2, and dies; expected grid `= 2^0` (the held ring tile only). **R-N1-2** (audit pass 1, finding 2): 15 × 15, `odd = true`, the single live tile `(7, 6)`: on the interior destinations, the planes `P_S1` and `P_S2` hold exactly `(7, 7)` and `(8, 7)` (local row 6 is globally odd, so its northern neighbours are `i + W` and `i + W + 1`), not `(6, 7)`. **R-N1-3** (audit pass 2, finding 21): 15 × 15, `odd = false`, live tiles `(14, 11)`, `(1, 12)`, `(1, 13)`, `smooth` with `held = ring`, one generation: `(1, 12)` (even row: neighbours `(0, 12)`, `(2, 12)`, `(0, 13)`, `(1, 13)`, `(0, 11)`, `(1, 11)`) has one live neighbour, `(1, 13)`; `(1, 13)` (odd row: `(0, 13)`, `(2, 13)`, `(1, 14)`, `(2, 14)`, `(1, 12)`, `(2, 12)`) has one, `(1, 12)`; both die; expected grid `= 2^(11·15 + 14) = 2^179` (the held ring tile only); and on the interior destinations the plane `P_S2` holds no bit at `(1, 13)`. **R-N1-4** (finding 3): `generate_with_margins(15, 15, 3, s, ring, 0, false) == generate(15, 15, 3, s)` for 64 seeds. **R-N1-5** (D-30): `generate_with_margins(17, 14, …)` panics `'Caver: dimensions too large'`. **R-N1-6** (audit pass 3, finding 35): 15 × 15, `odd = false`, the single live tile `(1, 0)` (bit 1, a ring tile), `smooth` with `held = ring`, one generation: expected grid `= 2^1`. The plane property is asserted on interior destinations only: on the odd row 1, `SE = i − W`, so `(1, 0)` is the `SE` neighbour of `(1, 1)` (bit 16) and of no other interior tile (`(2, 1)` has `SE = (2, 0)`, `SW = (3, 0)`); on the interior, `P_S1` (the `i − W` plane, `G · 2^W = 2^16`) holds `(1, 1)` and every other plane is empty. The ring destination `(0, 0)`, whose true West neighbour `(1, 0)` is live, is **not** asserted (the sketch's `P_W` has no bit there). **R-N1-7** (finding 39): `generate_with_margins(15, 15, 255, s, ring, 0, false) == generate(15, 15, 255, s)` for 4 seeds (the domain-wide worst case runs and agrees) |

**Design sketch (not normative)**

| | |
|---|---|
| The six planes, derived | Bit `i` of plane `P_D` is the grid at the neighbour `D` of tile `i`. From the neighbour table, for a tile `i` on a **globally even** row: `E = i − 1`, `W = i + 1`, `NE = i + W − 1`, `NW = i + W`, `SE = i − W − 1`, `SW = i − W`; on a globally odd row: `NE = i + W`, `NW = i + W + 1`, `SE = i − W`, `SW = i − W + 1`, `E` and `W` unchanged. Hence, with `G` the grid and `G_e`, `G_o` its restriction to the globally even and odd **local** rows: `P_E = G·2`, `P_W = G / 2`, `P_N1 = G / 2^W`, `P_N2 = G_o' / 2^(W−1) | G_e' / 2^(W+1)`, `P_S1 = G · 2^W`, `P_S2 = G_o' · 2^(W+1) | G_e' · 2^(W−1)`, with `G_o' = G_o & ~COL_LAST` and `G_e' = G_e & ~COL_0` (below). These are the formulas of `CaverInternal::step` (`hexmap:src/generators/caver.cairo:179-184`), in which `grid_even` is `G & even` (`:174-177`), plus the two column masks. **For a chunk whose local row 0 is a global odd row, `G_e` is the set of odd local rows and `G_o` the set of even local rows: the parity split is complemented and the shift factors are unchanged** (audit pass 1, finding 2; pass 2 confirms the mapping). `LayoutTrait::new_odd(width, height)` returns a `Layout` whose `even` field is `board − even`, everything else equal |
| No carry between the two diagonal operands | The two operands of `P_S2` overlap when a source tile of the last column `(W−1, y)` in `G_o` (shifted by `W + 1`, it lands on `(0, y + 2)`) meets a source tile `(1, y + 1)` in `G_e` (shifted by `W − 1`, it lands on `(0, y + 2)` as well); their **addition** then carries into `(1, y + 2)`, an interior tile, and invents a neighbour (audit pass 2, finding 21: `(14, 11)`, `(1, 12)` and `(1, 13)` on 15 × 15). The same happens in `P_N2` between `(W−1, y)` in `G_o` (`/2^(W−1)`, landing on `(0, y)`) and `(1, y + 1)` in `G_e` (`/2^(W+1)`, landing on `(0, y)`). The sketch therefore clears the wrapping sources first: `G_o' = G_o & ~COL_LAST`, `G_e' = G_e & ~COL_0` (their true diagonal neighbours across the column edge lie outside the board, so nothing an interior tile needs is lost), after which the two operands have disjoint destinations (a destination `(x, y)` would need an odd source row `y ∓ 1` for one operand and an even source row `y ∓ 1` for the other) and may be added; the sketch combines them with **OR** anyway, so that the proof of disjointness is not load-bearing. The audit's diagnostic run with OR passed 1,000 sampled comparisons |
| Exactness of every field product | A product by `2^k` is exact when the result stays below `2^251`: the domain guarantees it (`2^(W·H − 1) · 2^(W+1) < 2^251`). A product by `2^-k` is exact only when the operand has no set bit below `k` (`hexmap:src/helpers/layout.cairo:5-8`). With margins the ring may hold bits, so before the three downward planes the operand is masked: `G_low = G & ~(ROW_0 | 2^W)` clears row 0 (bits `0..W−1`) and tile `(0, 1)` (bit `W`), the only bits below `W + 1`; `P_W = G_low / 2` (audit pass 1, finding 1), `P_N1 = G_low / 2^W`, `P_N2` from `G_low_o' / 2^(W−1)` and `G_low_e' / 2^(W+1)`. The cleared bits are ring tiles whose only destinations under these shifts are the ring or nothing. The upward planes take `G`, `G_e'`, `G_o'` |
| Algorithm | Bitwise, the bit-sliced automaton B4/S2 of `Caver` (`:171-249`) with: (1) the initial fill `(noise & (interior | (ring − fixed))) + (values & fixed)`; (2) the masked planes above; (3) after the rule, `next = (rule & interior) + (G & ring)` for `generate_with_margins`, and `next = (rule & interior & ~held) + (G & (ring | held))` for `smooth`: the ring never evolves, held tiles never evolve. The parity flag serves generation and seams only: the window of the tick has an even origin by construction (D-120) and the finders never see it. Why not a loop or a wider board: a per-tile loop is ≥ 1.1M (LIB-02 §6); a 17 × 17 margin does not fit a felt |
| Operations, summed (exact lower bound of the target) | One generation of `generate`: **35,710 measured** on 17 × 14 (`GAS.md:629`). Added per generation: the low-limb clear of `G_low` (1 limb AND, 1,696 measured, `:57`), the split of `G_low` by parity on two limbs (`2 × 1,696 = 3,392`), the two column masks on two limbs each (`2 × 3,392 = 6,784`), the two ORs replacing additions (`2 × 3,392 = 6,784`, `:59`), the interior AND on two limbs (3,392), the ring AND on two limbs (3,392), four rebuilds (`4 × 197 = 788`): `1,696 + 3,392 + 6,784 + 6,784 + 3,392 + 3,392 + 788 = 26,228`; per generation `35,710 + 26,228 = ` **61,938**; `smooth` adds one `held` AND (3,392): **65,330**. Fixed part: the fill **27,157 measured** (`:616`, order 0), the two fill masks (`2 × 3,392 + 1,809 = 8,593`), `Layout::new` **12,900 measured** (`:630`, "about 12.9k"): `27,157 + 8,593 + 12,900 = 48,650`. **`generate_with_margins(order) = 48,650 + 61,938 × order`**: order 3 `= 48,650 + 185,814 = ` **234,464** (≈ 234k), against **143,737 measured** for `generate(17, 14, 3)` (`:618`), so +63 %; order 255 `= 48,650 + 15,794,190 = ` **15,842,840**. **`smooth(order) = 12,900 + 65,330 × order`**: order 3 `= 12,900 + 195,990 = ` **208,890**; order 255 `= 12,900 + 16,659,150 = ` **16,672,050** |

### 6.3 N-2 — Edges and openings between boards

```cairo
pub enum Side { East, North, West, South }      // East = column 0 (the low x side), West = column W-1, South = row 0, North = row H-1
fn side(width: u8, height: u8, side: Side) -> felt252;                     // the mask of one side, corners included
/// Tiles of `near`'s `side` that are open and adjacent, across the seam, to an open tile of the
/// neighbouring board `far`, whose opposite side touches `side`. `odd`: `near`'s local row 0 is
/// a global odd row (the same flag as N-1, for every side).
fn openings(width: u8, height: u8, near: felt252, far: felt252, side: Side, odd: bool) -> felt252;
fn is_open_across(width, height, near, far, side, odd) -> bool;            // openings != 0
```

**Contract (normative)**

| | |
|---|---|
| Module | `board::seams`; `Digger::corridor` (taken over) creates an opening from a chosen edge tile; `Asserter::is_edge`, `is_corner` (taken over) validate it. Seams are between chunks of 15 × 15; the `odd` flag is the second and last use of the row-parity flag (D-120) |
| Domain | `W, H ≥ 3`, `W·H ≤ 251`, both boards of the same dimensions (every dimension class of the engine: 15 × 15, 15 × 16, 16 × 15, 17 × 14, 19 × 13, 25 × 10, 83 × 3, 3 × 83, 7 × 7, 3 × 3); any bitmaps. Corner tiles of a side are tested like the others (a corner of `near` touches `far` across one seam only) |
| Semantics | Place `far` next to `near` on the side opposite to `side` in global coordinates, with `near`'s local row 0 on a global row of parity `odd`. `openings` is the set of tiles `t` of `near`'s `side` such that `t` is open in `near` and at least one of the six neighbours of `t` (from the neighbour table with the **global** parity of `t`'s row, `hexmap:src/types/direction.cairo:7-14`) lies in `far` and is open there. Consequently a tile of a vertical seam has up to three contacts (`(W−1, y)` and `(W−1, y ± 1)` for the East side on globally even rows; `(0, y)` and `(0, y ± 1)` for the West side on globally odd rows) and a tile of a horizontal seam two (`(x, H−1)` and `(x − 1, H−1)` for the South side when row 0 is even, `(x, H−1)` and `(x + 1, H−1)` when odd; `(x, 0)` and `(x − 1, 0)` or `(x + 1, 0)` for the North side by the parity of row `H−1`, which is `odd XOR ((H − 1) mod 2)`) |
| Tie-breaks | None |
| Oracle | The scalar definition above, on signed global coordinates: for every tile of `near`'s side, its six global neighbours are computed with the global parity, the neighbours that fall in `far` are looked up bit by bit. No board of `2W × H` is built (audit pass 1, finding 5). Run on every side, both parities, 32 seeded pairs of boards and the four full/empty combinations, on **every dimension class of the domain** (audit pass 2, finding 22) |
| Domain coverage | Worst case of the whole domain: the sketch performs a fixed sequence of operations that does not depend on the dimensions or on the bitmaps (the masks are constants of `W` and `H`), so the vertical seams (three contacts) are the worst case for every board of the domain and the horizontal seams cost less; the 15 × 16 benchmark is representative of every dimension class |
| Worst case | An **East seam with `odd = false`** (three contacts on every even row), both boards fully open, 15 × 16; and a North seam with `odd = true` for the two-contact form |
| Regression cases | Every case pins both bitmaps. **R-N2-1** (audit pass 1, finding 4): South seam, 15 × 15, `odd = false`, `near = board`, `far = board` (both fully open): `openings = ROW_0`, the whole row 0 (15 tiles; an addition of the overlapping contact sets would clear tiles). **R-N2-2** (audit pass 2, finding 22): West seam, `W = 15`, `H = 16`, `odd = false`, `near = board`, `far = 2^(15·15 + 0) = 2^225` (the single tile `(0, 15)`): `openings = 2^(15·15 + 14) = 2^239`, the single tile `(14, 15)`; nothing at `(14, 1)`, `(14, 3)`, …, `(14, 13)`. **R-N2-3** (corrected after audit pass 3, finding 32): East seam, 15 × 15, `odd = false`, `near = board`, `far = 2^(5·15 + 14) = 2^89` (the single tile `(14, 5)`): the straight contact gives `(0, 5)`; row 4 is globally even, and the `NE` of `(0, 4)` is `i + W − 1 = (−1, 5)`, that is `far`'s `(14, 5)`; row 6 is globally even, and the `SE` of `(0, 6)` is `i − W − 1 = (−1, 5)`, the same tile; row 5 is odd and has no diagonal across the seam. Expected `openings = 2^(4·15) + 2^(5·15) + 2^(6·15) = 2^60 + 2^75 + 2^90`, the three tiles `{(0, 4), (0, 5), (0, 6)}`. **R-N2-3b**: the same with `odd = true`: rows 4 and 6 are globally odd and have no diagonal across the seam; row 5 is globally even and its diagonals reach `(−1, 6)` and `(−1, 4)`, not `(14, 5)`; expected `openings = 2^75`, the tile `(0, 5)` only. **R-N2-4**: North seam, 15 × 16, `odd = true` (row 15 is then globally even, since `15` is odd and `odd XOR 1 = 0`), `near = board`, `far = 2^7` (the tile `(7, 0)`): the straight contact gives `(7, 15)`; the `NE` of `(8, 15)` (globally even) is `i + W − 1 = (7, 16)`, that is `far`'s `(7, 0)`; expected `openings = 2^(15·15 + 7) + 2^(15·15 + 8) = 2^232 + 2^233`, the tiles `{(7, 15), (8, 15)}` |

**Design sketch (not normative)**

| | |
|---|---|
| Formulas, one per side, every product with its exactness condition | Constants of `W` and `H` (arithmetic, no loop): `ROW_0 = 2^W − 1`, `ROW_LAST = ROW_0 · 2^(W(H−1))`, `COL_0 = (2^(WH) − 1)/(2^W − 1)` (exact field division, as `LayoutTrait::even`, `hexmap:src/helpers/layout.cairo:93-112`), `COL_LAST = COL_0 · 2^(W−1)`; `E_rows` the mask of `near`'s globally even rows (`layout.even` when `odd = false`, `board − even` when `odd = true`), `O_rows` its complement; `TOP = 2^(W(H−1))` the bit of `(0, H−1)` and `TOP_LAST = TOP · 2^(W−1)` the bit of `(W−1, H−1)`. **East** (`near`'s column 0 against `far`'s column `W−1`): `A = far & COL_LAST`; `C = A / 2^(W−1)`, exact since every bit of `A` is at `≥ W − 1`; straight contacts `C`; upper diagonal `(C & ~1) / 2^W`, exact once bit 0 is cleared; lower diagonal `(C & ~TOP) · 2^W`, the last-row bit cleared first so that the product stays below `2^(WH) ≤ 2^251`; `openings = near & COL_0 & (C | ((C & ~1) / 2^W | (C & ~TOP) · 2^W) & E_rows)`. **West** (`near`'s column `W−1` against `far`'s column 0): `A = far & COL_0`, `C = A · 2^(W−1)` (exact: below `2^(WH)`); upper diagonal `(C & ~2^(W−1)) / 2^W` (bit `(W−1, 0)` cleared); lower diagonal **`(C & ~TOP_LAST) · 2^W`**: without clearing the last-row bit, `C · 2^W` reaches bit `WH + W − 1`, which is 254 on 15 × 16 and wraps modulo the field (audit pass 2, finding 22; pass 1's finding 4 had asked for it); `openings = near & COL_LAST & (C | ((C & ~2^(W−1)) / 2^W | (C & ~TOP_LAST) · 2^W) & O_rows)`. **South** (`near`'s row 0 against `far`'s row `H−1`): `A = far & ROW_LAST`, `R = A / 2^(W(H−1))` (exact); row 0 even: `openings = near & ROW_0 & (R | R · 2)`; odd: `near & ROW_0 & (R | (R & ~1) / 2)`; the bit that `R · 2` pushes to position `W` lies outside `ROW_0`. **North** (`near`'s row `H−1` against `far`'s row 0): `A = far & ROW_0`, `R = A · 2^(W(H−1))` (exact, below `2^(WH)`); row `H−1` even: `near & ROW_LAST & (R | (R & ~TOP_LAST) · 2)`; odd: `near & ROW_LAST & (R | R / 2)`, exact since every bit of `R` is at `≥ W(H−1) ≥ 2`. **Every union is an OR**: the contact sets overlap (audit pass 1, finding 4) |
| Why | Reading a column tile by tile costs 15 × 4.9k ≈ 75k (`GAS.md:65`, `Bits::get`); the masked shifts cost a few products and a handful of limb operations |
| Operations, summed (exact lower bound of the target), East seam | `far → u256` 1,809 (measured, `GAS.md:53`); AND `COL_LAST` on two limbs 3,392 (`:57`); rebuild 197 (`:55`); product `/2^(W−1)` 98 (`:46`); conversion of `C` 1,809; clear of bit 0 and of `TOP` on the limbs `2 × 1,696 = 3,392`; two rebuilds 394; two products 196; two conversions 3,618; OR of the two diagonals 3,392; AND `E_rows` 3,392; OR with `C` 3,392; `near → u256` 1,809; AND `near` 3,392; AND `COL_0` 3,392; rebuild 197. Sum: `1,809 + 3,392 + 197 + 98 + 1,809 + 3,392 + 394 + 196 + 3,618 + 3,392 + 3,392 + 3,392 + 1,809 + 3,392 + 3,392 + 197 = ` **33,871** (≈ 34k). Horizontal seam (South, odd): `far → u256` 1,809; AND `ROW_LAST` 3,392; rebuild 197; product 98; conversion of `R` 1,809; clear of bit 0 (1 limb) 1,696; rebuild 197; product 98; conversion 1,809; OR with `R` 3,392; `near → u256` 1,809; AND `near` 3,392; AND `ROW_0` 3,392; rebuild 197: **23,287**. `side`: 2 lookups (`2 × 1,269 = 2,538`) and one field division (494 measured, `:47`): **3,032** |

### 6.4 N-3 — Assembly of a board of 15 × 16 from 2 or 4 chunks of 15 × 15

Decided by D-120 (`grimworld:docs/needs/hexmap.md` § "N-3 in detail", ADR-0006 §4): the
window is 15 columns × 16 rows (240 tiles, one felt), assembled **at each tick** from the
chunks it overlaps and never stored; 16 rows always span two rows of chunks and 1 or 2
columns, so the input is 2 or 4 chunks, never 1, never more; the origin is on an even global
row, and the function **refuses an odd origin** rather than return a board that is a different
hex grid from the map; no loop over rows.

```cairo
/// Constants of the window: `WIDTH = 15`, `HEIGHT = 16`, `CHUNK = 15`.
/// The window of an adventurer at global `(x, y)` (the tile coordinates of the location, `u8`,
/// ADR-0006 §1) has its origin at `(x - 7, y - 7)` when `y` is odd and `(x - 7, y - 8)` when
/// `y` is even, so that the origin row is even. The origin may lie before the location's first
/// tile (negative), which `Origin` represents as a chunk index `cx, cy` in `-1..=16` and an
/// offset `ox, oy` in `0..15` (Euclidean: the origin is `15·cx + ox`, `15·cy + oy`).
pub struct Origin { pub cx: i8, pub cy: i8, pub ox: u8, pub oy: u8 }
fn origin(x: u8, y: u8) -> Origin;                                         // never odd by construction
fn local(self: @Origin, x: u8, y: u8) -> Option<u8>;                       // the window index of a global tile, None outside the window
/// `chunks[0]` is chunk `(cx, cy)`, `[1]` is `(cx + 1, cy)`, `[2]` is `(cx, cy + 1)`, `[3]` is
/// `(cx + 1, cy + 1)`; `[1]` and `[3]` are ignored when `ox == 0` (the window fits one column of
/// chunks). An absent chunk (outside the location) is passed as 0. `odd_chunk_row` is the
/// parity of `cy`.
/// # Panics
/// * `'Assembly: odd origin'` when `oy + cy` is odd (the origin is on an odd global row)
/// * `'Assembly: invalid offset'` when `ox >= 15` or `oy >= 15`
fn assemble(chunks: [felt252; 4], ox: u8, oy: u8, odd_chunk_row: bool) -> felt252;   // one layer
fn window(terrain: [felt252; 4], occupied: [felt252; 4], origin: @Origin, seed: felt252) -> (HexMap, felt252);   // both layers, ring imposed on the terrain
```

**Contract (normative)**

| | |
|---|---|
| Module | `board::assembly`, with the band tables of `board::tables` |
| Domain | `origin`, `local`: every `u8` pair (the location's tiles); the resulting `cx, cy` lie in `−1..=16`. `assemble`: `ox, oy < 15` (else `'Assembly: invalid offset'`), `oy + cy` even (else `'Assembly: odd origin'`); the chunks are any bitmaps (bits at or above 225 are ignored). The window is always 15 × 16 |
| Semantics | `origin(x, y)` is the unique `(cx, cy, ox, oy)` with `15·cx + ox = x − 7` and `15·cy + oy = y − 7` (`y` odd) or `y − 8` (`y` even), `0 ≤ ox, oy < 15`: the **Euclidean** quotient and remainder, so that a negative origin gives `cx = −1` or `cy = −1` with a positive offset (audit pass 2, finding 28: for the adventurer at `(0, 0)` the origin is `(−7, −8)`, hence `cx = cy = −1`, `ox = 8`, `oy = 7`; a truncating division would give the wrong chunk). `local(o, x, y) = Some(dy·15 + dx)` where `dx = x − (15·cx + ox)`, `dy = y − (15·cy + oy)`, when `0 ≤ dx < 15` and `0 ≤ dy < 16`, else `None`. `assemble` returns the bitmap `M` of 15 × 16 such that for every window tile `(dx, dy)`, bit `dy·15 + dx` of `M` equals the bit of the global tile `(15·cx + ox + dx, 15·cy + oy + dy)` in the chunk that holds it (`chunks[0]` for `dx < 15 − ox` and `dy < 15 − oy`, and so on with the half-open rectangles below). `window` returns `(HexMap { width: 15, height: 16, grid: assemble(terrain) & interior(15, 16), seed }, assemble(occupied))` |
| The four rectangles, half-open | The chunk `(cx, cy)` contributes columns `[ox, 15)` and rows `[oy, 15)`; `(cx + 1, cy)` columns `[0, ox)` and rows `[oy, 15)`; `(cx, cy + 1)` columns `[ox, 15)` and rows `[0, oy + 1)`; `(cx + 1, cy + 1)` columns `[0, ox)` and rows `[0, oy + 1)`. The four rectangles partition the 240 tiles of the window for every `(ox, oy)` (both audit passes re-checked the 225 offsets and 900 pieces) |
| Tie-breaks | None |
| Why a panic and not an `Option` | An odd origin is a programming error of the caller, never a runtime condition: `origin` cannot produce one, and a window on an odd origin is a board on which every neighbour is wrong (`window-parity-check.md` §1). The library's convention for invalid inputs is a panic with a named message (`README.md` § Panics, `Asserter` errors); an `Option` would put a branch in every tick and invite a silent fallback that returns a wrong grid (D-19) |
| Oracle | A scalar per-tile copy through `LayoutTrait::coords` and `index` over the 240 tiles, on 2 and on 4 chunks, for every `(ox, oy)` of `0..15 × 0..15` with the matching parity; `origin` against the definition on all 65,536 `(x, y)`; the round trip `local(origin(x, y), x', y')` for every tile `(x', y')` of the window against the definition; a `#[should_panic]` test on each odd origin |
| Worst case | **4 chunks, two layers each, at each tick**: `ox = oy = 7`, `odd_chunk_row = true` (every chunk contributes, both layers) |
| Domain coverage | Worst case of the whole domain: the window is always 15 × 16 and the sketch performs a fixed sequence of operations; the four-chunk case (every piece non-trivial) is the worst case; `origin` and `local` are input-independent |
| Regression cases | **R-N3-1** (audit pass 2, finding 28): `origin(0, 0) = Origin { cx: −1, cy: −1, ox: 8, oy: 7 }` (origin `(−7, −8)`: `−7 = 15·(−1) + 8`, `−8 = 15·(−1) + 7`); `origin(7, 8) = (0, 0, 0, 0)` (row 8 even: origin `(0, 0)`); `origin(7, 7) = (0, 0, 0, 0)` (row 7 odd: origin `(0, 0)`); `origin(255, 255) = (16, 16, 8, 8)` (row 255 odd: origin `(248, 248)`, `248 = 15·16 + 8`); in each case `oy + cy` is even (`7 − 1 = 6`, `0`, `0`, `8 + 16 = 24`). **R-N3-2**: `local(origin(0, 0), 0, 0) = Some(127)` (`dx = 0 − (−7) = 7`, `dy = 0 − (−8) = 8`, `8·15 + 7 = 127`: the adventurer stands on local `(7, 8)`); `local(origin(0, 0), 7, 7) = Some(239)` (`dx = 14`, `dy = 15`, `15·15 + 14 = 239`, the last tile); `local(origin(0, 0), 8, 8) = None` (`dx = 15`, outside); **`local(origin(255, 255), 0, 0) = None`** (`dx = 0 − 248 = −248`, outside; audit pass 3, finding 36). **R-N3-3** (audit pass 2, finding 23): `assemble` with `oy = 14` (the upper chunks contribute rows `[0, 15)`, all of them) and with `ox = 0` (two chunks), against the oracle. **R-N3-4**: an absent chunk passed as 0 contributes wall |

**Design sketch (not normative)**

| | |
|---|---|
| `origin` | On `u16`: `gx15 = x + 8` (that is `x − 7 + 15`, always positive), `(qx, ox) = DivRem(gx15, 15)`, then **`cx = (qx as i8) − 1` on `i8`** (`qx ≤ 17`, so the conversion cannot fail; the subtraction on `u16` would underflow at `x = 0`, where `qx = 0` and `cx = −1`, audit pass 3, finding 36); `gy15 = y + 8` when `y` is odd, `y + 7` when even; `(qy, oy) = DivRem(gy15, 15)`, `cy = (qy as i8) − 1`. `local`: on `i16`, `gx = 15·(cx as i16) + (ox as i16)` (in `−7..=248`), `dx = (x as i16) − gx`; `Some` only when `0 ≤ dx < 15` and `0 ≤ dy < 16`, the comparisons made **before** any unsigned conversion (`local(origin(255, 255), 0, 0)` has `dx = −248`, finding 36). The public unsigned `chunk_of` (§6.1) is not involved (audit pass 2, finding 28) |
| The band tables (`board::tables`) | With explicit terminal entries (audit pass 2, finding 23): `COL_FROM: [felt252; 16]`, entry `k` the mask `(2^(15−k) − 1)·2^k` of columns `[k, 15)` in row 0, entry 15 being 0; `COL_TO: [felt252; 16]`, entry `k` the mask `2^k − 1` of columns `[0, k)`, entry 15 being the full row; `ROW_FROM_15: [felt252; 16]` and `ROW_TO_15: [felt252; 16]`, the masks `Σ_{j=k}^{14} 2^(15j)` and `Σ_{j<k} 2^(15j)` of the rows `[k, 15)` and `[0, k)` of a **15-row chunk** at column 0, `k` in `0..=15`; `ROW_FROM_16: [felt252; 17]` and `ROW_TO_16: [felt252; 17]`, the same for the **16-row window**, `k` in `0..=16`. 98 felts. The assembly uses the 15-row bands (so that chunk bits at or above 225 are cleared by the rectangle); the hexagon clipping of §6.7 uses the 16-row bands |
| Algorithm | Arithmetic and bitwise, no loop. Per chunk and per layer: (1) the rectangle is the **product** of a column band and a row band, exact because the bits are disjoint and below `2^225`: chunk `(cx, cy)`: `COL_FROM[ox] · ROW_FROM_15[oy]`; `(cx + 1, cy)`: `COL_TO[ox] · ROW_FROM_15[oy]`; `(cx, cy + 1)`: `COL_FROM[ox] · ROW_TO_15[oy + 1]` (hence the entry 15 of `ROW_TO_15`); `(cx + 1, cy + 1)`: `COL_TO[ox] · ROW_TO_15[oy + 1]`. (2) One AND of the chunk with the rectangle, on two limbs (both operands converted). (3) One shift, exact because the dropped bits were masked: chunk `(cx, cy)` moves by `−(15·oy + ox)` (a product by `INV`), chunk `(cx + 1, cy)` by `15 − ox − 15·oy`, chunk `(cx, cy + 1)` by `15·(15 − oy) − ox`, chunk `(cx + 1, cy + 1)` by `15·(15 − oy) + 15 − ox`; a negative shift is a product by `INV[−s]`, exact because no bit of the masked piece lies below `s`; a positive one by `POW[s]`, exact because every destination is below `2^240`. (4) The pieces are disjoint and are added. The window and the chunk share the width 15, which is what makes a 2-D move one 1-D shift (ADR-0006 §1). Finally one AND with `LayoutTrait::interior(15, 16)` imposes the wall ring on the terrain layer. The parity check is one `u8` addition and one `DivRem` |
| Operations, summed (exact lower bound of the target) | Per piece: 3 lookups (band, band, shift: `3 × 1,269 = 3,807`, measured `GAS.md:48`); 2 products (`2 × 98 = 196`, `:46`); 2 wide conversions (the chunk and the rectangle, `2 × 1,809 = 3,618`, `:53`); 1 AND on two limbs (`2 × 1,696 = 3,392`, `:57`); 1 rebuild (197, `:55`): `3,807 + 196 + 3,618 + 3,392 + 197 = ` **11,210**. `assemble`, one layer: 4 pieces (`4 × 11,210 = 44,840`), 3 additions (`3 × 98 = 294`), the parity check (1 `DivRem` 1,098 + 1 addition 300): `44,840 + 294 + 1,098 + 300 = ` **46,532**. `window`: two layers (`2 × 46,532 = 93,064`), the ring AND (`1,809 + 3,392 + 197 = 5,398`), the `HexMap` construction (300): `93,064 + 5,398 + 300 = ` **98,762** (≈ 99k), storage reads excluded; two chunks: `2 × (2 × 11,210 + 98 + 1,398) + 5,698 = 2 × 23,916 + 5,698 = ` **53,530**. `origin`: 2 `DivRem` (2,196), 2 conversions and subtractions on `i8` (`4 × 300 = 1,200`), 2 additions (600): **3,996**. `local`: 2 products and 2 additions on `i16` (1,200), 2 subtractions (600), 4 comparisons (400), the index arithmetic (400): **2,600**. The window's sum is above the "about 40k" of ADR-0006 § Cost, which is itself an estimate; SPK-7 measures it, with and without a stored window, as the ADR says |

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
fn cut(self: HexMap, mask: felt252) -> HexMap;   // grid & mask & interior: the ring is cleared too (D-23)
```

**Contract (normative)**

| | |
|---|---|
| Module | `board::cut`, forwarded by the facade |
| Domain | Any `HexMap` of valid dimensions; any mask (bits outside the board are cleared) |
| Semantics | For every tile `t`: `cut(m, mask).is_walkable(t)` is true iff `m.is_walkable(t)`, bit `t` of `mask` is set, and `t` is an interior tile. Clearing the ring is the chosen policy of `cut` (D-23): the README of 1.8.0 allows open edge tiles as endpoints of a path (`README.md:63-66`), so a board with open ring tiles is a valid board; `cut` clears them because the game applies it to chunks whose ring is a seam and to the window whose ring is imposed anyway (ADR-0006 § Outlines, "what is outside is impassable"). A consumer that wants ring tiles kept ANDs the mask itself |
| Tie-breaks | None |
| Oracle | The per-tile definition above on every tile of 15 × 15, 15 × 16 and 7 × 7, on 32 seeded pairs |
| Worst case | Any; input independent |
| Domain coverage | Worst case of the whole domain: a fixed sequence of operations, input-independent |
| Regression cases | **R-N4-1** (corrected after audit pass 4, finding 42): 7 × 7, `m = new_cave(7, 7, 3, s)` then `m.open_with_corridor(3, 0)`. The entrance index `3 = 0·7 + 3` is the tile `(3, 0)`: on the edge (`y = 0`, `Asserter::is_edge`, `hexmap:src/helpers/asserter.cairo:27-29`) and not a corner (`x = 3` is neither 0 nor 6, `is_corner`, `:40-42`), so `Digger::corridor` (`hexmap:src/generators/digger.cairo:65-69`) accepts it at `:94-96` (`assert_inside`, `assert_not_corner`, `assert_on_edge`) and sets the entrance bit `2^3` (`:102-105`, `maze = entrance + power`); the previous index 8 was `1·7 + 1`, the interior tile `(1, 1)`, which `assert_on_edge` refuses. Before the cut, the ring of `m` holds bit 3 only (the cave's ring is wall and the digger opens the entrance and interior tiles only). `mask = 2^49 − 1` (every bit of the board): by the semantics above, `cut(m, 2^49 − 1).grid = m.grid & (2^49 − 1) & INTERIOR(7, 7) = m.grid & INTERIOR(7, 7)`, that is **`m.grid − 2^3`**: every interior tile (bits `y·7 + x`, `1 ≤ x ≤ 5`, `1 ≤ y ≤ 5`) unchanged, `is_walkable(3)` true before and false after, and no other bit changes. **R-N4-2** (corrected after audit pass 3, finding 41): for every board `m` and mask, **`cut(m, mask) == cut(m, mask & (2^(W·H) − 1))`**: the bits of the mask at or above `W·H` are ignored, the mask itself is not. **R-N4-3** (finding 41): 7 × 7, `m` with the single floor tile `(3, 3)` (index 24), `mask = 2^49`: expected grid `= 0` (the mask keeps no tile of the board) |

**Design sketch (not normative)**

| | |
|---|---|
| Algorithm | Bitwise: `grid → u256` (1,809 measured, `GAS.md:53`), `mask → u256` (1,809), AND on two limbs (3,392, `:57`), `interior(W, H)` (3 lookups, 2 products, 1 field division: `3,807 + 196 + 494 = 4,497`, `hexmap:src/helpers/layout.cairo:121-126`) converted (1,809) and ANDed (3,392), rebuild (197) |
| Operations, summed (exact lower bound of the target) | `1,809 + 1,809 + 3,392 + 4,497 + 1,809 + 3,392 + 197 = ` **16,905** |

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
at column `−1`, off the board (on a 7 × 7, `(0, 0) → (0, 2)` has the tied midpoint `(−1, 1)`).
Such a line **leaves the board**, and the board form says so explicitly (`None`) instead of
clipping: a clipped between-mask would be empty and `line & ~grid == 0` would report a clear
sight where the rule requires a blocked one (audit, finding 7). A line that leaves the board
blocks sight (D-27).

```cairo
// Mirror (hexx name, documented deviation)
fn line_to(self: Hex, other: Hex) -> Span<Hex>;                 // distance + 1 tiles, endpoints included
// Board
fn line(self: HexMap, from: u8, to: u8) -> Option<felt252>;      // Some(the tiles strictly between, as a bitmap); None when a tile of the line lies outside the board
fn line_of_sight(self: HexMap, from: u8, to: u8) -> bool;        // Some(m) with m & ~grid == 0: walls block, actors do not, endpoints are not tested (D-24); None is blocked
fn approach(self: HexMap, from: u8, to: u8) -> Option<Direction>; // the direction, from `to`, of the last tile of the line before `to` (`from` itself when adjacent); None when from == to or when the line leaves the board
```

**Contract (normative)**

| | |
|---|---|
| Module | `hex` (mirror), `board::line` |
| Domain | Mirror: every pair of `Hex` (cube arithmetic on `i32`; a difference that leaves `i32` panics, §3.1). Board: `from`, `to` inside the board (`< W·H`, else `'Asserter: position not inside'`), any dimensions of the engine, ring tiles included as endpoints; the result does not depend on which internal path (table or loop) serves the call |
| Semantics | Mirror: `line_to(a, b)` is the sequence of `N + 1` tiles, `N = distance(a, b)`, whose `i`-th element is the tile containing the point `a + (i/N)·(b − a)` in cube coordinates, rounded to the nearest tile; at an exact tie between two tiles the rule below applies; the first element is `a`, the last `b`. Board: `line(from, to) = Some(M)` where `M` is the bitmap of the elements of the mirror line between `index_to_hex(from)` and `index_to_hex(to)`, endpoints excluded, when every such element is a tile of the board; `None` when one of them is not. `line_of_sight(from, to)` is true iff `line(from, to) = Some(M)` and every tile of `M` is walkable; endpoints are not tested (D-24). `approach(from, to)` is `Some(d)` where `d` is the direction from `to` to the element of the line that precedes `to` (`from` itself when the line has no between tile), for every in-board `to`, **ring tiles included** (audit pass 2, finding 24); `None` when `from == to` or when `line` is `None` |
| Tie-breaks | The game's rule (L-G1, point 6): at an exact tie, the tile with the **smaller `y`, and on the same row the smaller `x`** in the index frame; in the mirror frame (§3.5), the smaller `y` and on the same row the larger `x`. Symmetric and translation-invariant (audit pass 2 checked symmetry on all 57,600 ordered pairs of the window) |
| Deviation from `hexx` | `hexx` converts both endpoints to `f32` (`src/hex/mod.rs:906`, `as_vec2`) and interpolates in `f32` (`a.lerp(b, i / N)`, `:908`), then rounds (`:474-483`). Two sources of difference exist besides the tie rule: the rounding of the endpoints beyond `2^24` (`Hex(16_777_217, 0) → Hex(16_777_218, 0)`, audit pass 1, finding 8) and **the rounding of the interpolation itself**, which can flip a sample far below `2^24` (audit pass 2, finding 25: `(8_000_000, 0) → (8_000_001, 6)`, `N = 7`, no tie; sample 2 is `(8_000_000, 2)` exactly and `hexx` returns `(8_000_001, 2)`). **No identity domain is claimed.** The parity claim is limited to what is verified: identity with `hexx` on every non-tie pair of the 15 × 16 window in the mirror frame and on the seeded sample of `[-40, 40]²` (§4.3), and elsewhere a documented deviation; `refgen` also generates adversarial large-coordinate vectors (endpoints near `2^k` for `k = 20..=30`, long lines) and lists every difference in `docs/deviations/line_ties.md` under its own heading |
| Oracle | The mirror loop against the Rust model of `refgen` (exhaustive on 7 × 7, exhaustive on the 15 × 16 window in the mirror frame, sampled on `[-40, 40]²`, §4.3); the table against the loop on every pair within distance 6 of a 15 × 16 board; symmetry `line(a, b) == line(b, a)` on all ordered pairs, `None` included; `line_of_sight` against a per-tile scalar walk that reports a tile outside the board as blocked; `approach` against the last ordered sample of the scalar line on every pair of a 15 × 16 with `to` on the ring |
| Domain coverage | Table path: a fixed sequence of operations, worst case = any pair within distance 6 (the tie case below for the mirror loop it validates against). Loop path: a **bound parameterised by the distance** `N` (steps), `cost = 8,388 + 6,835 × N`; on any board of the engine `N ≤ W + H − 2`, a **conservative bound** (84 on 3 × 83 and on 83 × 3), not an attainable length (audit pass 4, finding 39): the diameter of 3 × 83 is **82** (`(0, 0) → (2, 82)`: `to_hex(2, 82) = (−2 − 41, 82) = (−43, 82)`, `dq = −43`, `dr = 82`, `ds = −39`, distance 82) and the diameter of 83 × 3 is **83** (`(0, 0) → (82, 2)`: `to_hex(82, 2) = (−82 − 1, 2) = (−83, 2)`, `dq = −83`, `dr = 2`, `ds = 81`, distance 83); the **game-sized fixtures** are 22 (the board) and 19 (the interior) on 15 × 16; the **domain-wide executable fixture** is `(0, 0) → (82, 2)` on 83 × 3, `N = 83`; the bound `N = 84` is quoted as a bound and is not benchmarked |
| Worst case | Table: distance 6 with a tie at the steps **1, 3 and 5** (`N = 6`, `Δ = (3, 3)` in axial: the sample `i/6 · (3, 3)` has both coordinates at `.5` for odd `i` and is an exact tile for even `i`; audit pass 4, finding 39), start on an odd row at `(7, 7)`. Loop, fixtures: the longest line on the 15 × 16 board, `(0, 0) → (14, 15)` (22 steps), and the longest between interior tiles, `(1, 14) → (13, 1)` (19 steps). Loop, domain-wide fixture: `(0, 0) → (82, 2)` on 83 × 3, `N = 83` (the diameter); the bound `N ≤ 84` is not a fixture. `approach`: a ring target at distance 6 |
| Regression cases | **R-N5-1** (audit pass 1, finding 7): 7 × 7, `line((0, 0), (0, 2)) = None` (the tied midpoint is `(−1, 1)`), hence `line_of_sight = false` and `approach = None`. **R-N5-2** (finding 7): 7 × 7, `line((3, 3), (3, 5)) = Some(2^31)`, the single tile `(3, 4)` (index 31, not 39). **R-N5-3** (finding 8): on 15 × 16, `line((0, 0), (14, 15))` has 21 between tiles and `line((1, 14), (13, 1))` 18. **R-N5-4** (audit pass 2, finding 24): 15 × 16, `approach((7, 9), (10, 15)) = Some(SouthEast)`: the predecessor of the ring target `(10, 15)` is `(10, 14)`, which is its `SE` neighbour (`i − W` on the odd row 15). **R-N5-5** (finding 25): mirror, `line_to((8_000_000, 0), (8_000_001, 6))[2] = (8_000_000, 2)`; the `hexx` value `(8_000_001, 2)` is recorded as a deviation vector. **R-N5-6** (finding 8): mirror, `line_to((16_777_217, 0), (16_777_218, 0)) = [(16_777_217, 0), (16_777_218, 0)]`; the `hexx` value is recorded as a deviation vector |

**Design sketch (not normative)**

| | |
|---|---|
| Tables | `LINES: [felt252; 254]` (the between-masks around the canonical starts `(7, 8)` even and `(7, 7)` odd of the 15 × 16 board, one per offset within distance 6 and per parity) and `LINE_SPANS: [u8; 254]` (the column extent of each mask relative to its start, `(cmin + 7)·16 + (cmax + 7)`) |
| Dispatch | **The table path serves `width == 15` and distance ≤ 6 only**; every other board, and every longer line, runs the loop on indices (audit pass 1, finding 7: translating width-15 masks by a difference of indices is wrong on any other width) |
| Algorithm | Mirror: a bounded loop of `N` steps, one accumulator per step, no division (Bresenham-like), `Span<Hex>` output. Board, table path: (1) read the extent; if `x_from + cmin < 0` or `x_from + cmax ≥ 15`, return `None`; (2) otherwise multiply the mask by `POW[i − c0]` or `INV[c0 − i]`: exact, because every bit lands in `[0, 240)` and no bit crosses a row (the extent test guaranteed every column in `[0, 15)`); the rows of the between tiles lie between the endpoint rows and are always inside. No clipping before or after the shift. Board, loop path: the mirror's loop on `index_to_hex(from)` and `index_to_hex(to)`, each sample converted back with `hex_to_index`; a sample outside the board returns `None`; bound: the distance, at most `W + H − 2`. `line_of_sight`: `line` then one AND with `~grid`. `approach`: `line`, then the neighbour set of `to` intersected with the mask is one bit; **the neighbour set is `neighbor_mask(to)` only when `to` is interior, and `LayoutTrait::edge_neighbors(to)` when `to` is on the ring** (`neighbor_mask` documents an interior position, `hexmap:src/helpers/layout.cairo:269`; on a ring target its field products wrap and the intersection misses the predecessor, audit pass 2, finding 24; the flood of §6.9 dispatches the same way); its index is the lowest set bit (the backtracking primitive of `Bfs`, `hexmap:src/finders/bfs.cairo:4-6`), then `neighbor_direction(to, that tile)`; when the mask is empty (adjacent endpoints) the tile is `from` |
| Why the table | The rules prefer a table (`grimworld:docs/CAIRO.md` §1); the loop form costs ~5.3k per step plus the conversions; the table form is three lookups, one product and a few `u8` operations |
| Class size | 254 felts and 254 bytes; ~560 CASM felts estimate, 0.7 % of the 81,920-felt class limit cited by the house (`glam-cairo docs/DESIGN.md` §4.3) |
| Operations, summed (exact lower bound of the target) | Table path: index arithmetic for the offset and the parity (2 `DivRem`, `2 × 1,098 = 2,196` measured, `GAS.md:1535`), 3 lookups (`LINES`, `LINE_SPANS`, and `POW` or `INV`: `3 × 1,269 = 3,807`, `:48`), the extent split (1 `DivRem`, 1,098), 2 comparisons (200), 1 product (98): `2,196 + 3,807 + 1,098 + 200 + 98 = ` **7,399**. `line_of_sight`: `line` (7,399) + `mask → u256` (1,809) + `grid → u256` (1,809) + AND on two limbs (3,392) + a zero test (100): **14,509**. `approach`, interior target: `line` (7,399) + `neighbor_mask` (2,563) + 2 conversions (3,618) + AND (3,392) + the lowest-bit step (8,400 measured, `:159`) + `neighbor_direction` (4,294): **29,666**; ring target: `edge_neighbors` instead of `neighbor_mask`. `LayoutTrait::neighbor` (`hexmap:src/helpers/layout.cairo:334-337`): 1 `DivRem` for the coordinates (1,098), 1 `DivRem` for the parity (1,098), the six-arm `match` (1,000), 2 comparisons (200), 1 addition (300): `1,098 + 1,098 + 1,000 + 200 + 300 = ` **3,696** per call (below the **6,959 measured** for the facade's `neighbor`, `GAS.md:1869`, which adds the inside assertion and the bench iteration); `edge_neighbors` = 6 × (`neighbor` 3,696 + `POW` lookup 1,269 + addition 98) `= 6 × 5,063 = ` **30,378**; `approach` on a ring target: `29,666 − 2,563 + 30,378 = ` **57,481**. Loop path, per step: an `i32` accumulator update (600), the tie test (600), `hex_to_index` at its own per-call sum (**2,998**, the §7 row: `from_hex` 2,198, 2 comparisons against `W` and `H` 200, the index arithmetic `y·W + x` 600), one `POW` lookup and addition (`1,269 + 98 = 1,367`), the loop iteration (1,270 measured, `:45`): `600 + 600 + 2,998 + 1,367 + 1,270 = ` **6,835**; plus 2 `index_to_hex` at their per-call sum, **4,194 each** (`2 × 4,194 = 8,388`; the previous drafts charged 4,000 for both, then 4,000 each, then 1,500 per step for `hex_to_index` against a §7 row of 4,000: audit pass 3, finding 26; every call is now charged at the figure of its §7 row): **`cost(N) = 8,388 + 6,835 × N`**; 19 steps `= 8,388 + 129,865 = ` **138,253**; 22 steps `= 8,388 + 150,370 = ` **158,758**; 83 steps (the domain-wide fixture on 83 × 3) `= 8,388 + 567,305 = ` **575,693**; the bound `N = 84`: `8,388 + 574,140 = 582,528`, a bound and not a benchmark |

### 6.7 N-6 — Range and ring as geometry

```cairo
fn hexagon(self: HexMap, position: u8, radius: u8) -> felt252;       // tiles within `radius`, walls ignored, clipped to the board (ring included)
fn hexagon_ring(self: HexMap, position: u8, radius: u8) -> felt252;  // tiles at exactly `radius`
```

**Contract (normative)**

| | |
|---|---|
| Module | `board::hexagon`, with the band tables of `board::tables` (§6.4) |
| Domain | `position` inside the board (else `'Asserter: position not inside'`); any radius in `u8`; any dimensions of the engine; the result does not depend on which internal path serves the call |
| Inputs | `position` is a **local position**: the adventurer's `(7, 7)` or `(7, 8)` for sight (D-120: the sight of radius 6 then always lies inside the ring, rows 1 to 13 or 2 to 14 of the 16), a target's tile for an area of effect; the row parity is read from the index |
| Semantics | `hexagon(p, r)` is the bitmap of the tiles `t` of the board (ring included) with `hex_distance(p, t) ≤ r`; `hexagon_ring(p, r)` those with `hex_distance(p, t) = r`; walls are ignored. Radius 0 is `2^p` for both |
| Tie-breaks | None |
| Domain coverage | Table path: a fixed sequence of operations; worst case = maximal clipping. Loop path: a **bound parameterised by the number of rows visited**, `min(2r + 1, H)`, at most `H`: `hexagon ≤ 4,504 × H`, `hexagon_ring ≤ 7,738 × H` (the per-row sums below, and the bounds of §7); the **game-sized fixture** is 15 × 16 (`H = 16`, radius 8); the domain-wide worst case is `H = 83` (the 3 × 83 board of the engine) at any radius `≥ 41`, for example 255 (audit pass 3, finding 39). Both are benchmarked |
| Oracle | The per-tile definition (`hex_distance`) on **every position of a 15 × 16 and of a 7 × 7 for every radius 0..=9**, on every position of a 3 × 83 for radius 41 and 255, and on 32 seeded positions of every other dimension class; the two internal paths against each other on every position of a 15 × 16 for radius `1..=7`. The secondary equality `hexagon(p, r) == tiles_within_range(p, r)` on `new_empty` boards holds **only when every tile of the geometric hexagon is interior** (the per-tile set contains no ring tile): `tiles_within_range` never returns a ring tile, `hexagon` does (audit pass 3, finding 34: on 7 × 7, centre `(1, 1)`, radius 1, the hexagon has 7 tiles of which `(0, 1)`, `(1, 0)`, `(2, 0)` are ring, and `tiles_within_range` has 4); it is asserted on those centres only, and the per-tile oracle covers the ring-clipped cases |
| Worst case | Table: radius 7, centre `(1, 1)` (maximal clipping), odd row; radius 6 from `(7, 8)` for the tick's own figure. Loop, fixture: radius 8 and radius 9, centre `(7, 8)` on 15 × 16 (16 rows). Loop, domain-wide: radius 255, centre `(1, 41)` on 3 × 83 (83 rows) |
| Regression cases | **R-N6-1** (audit pass 1, finding 6): 15 × 16, `hexagon((7, 14), 6)` equals the per-tile definition; no bit at `(1, 0)` or `(2, 0)`. **R-N6-2** (finding 6): 15 × 16, `hexagon((6, 8), 8)` contains `(14, 8)`. **R-N6-3** (audit pass 2, finding 23): 15 × 16, `hexagon((7, 8), 7)` contains `(7, 15)` (the canonical shape reaches row 15). **R-N6-4**: `hexagon((7, 7), 6)` and `hexagon((7, 8), 6)` on 15 × 16 contain no ring tile. **R-N6-5**: `hexagon_ring(p, r) = hexagon(p, r) − hexagon(p, r − 1)` for every `p` of a 15 × 16 and `r` in `1..=9`. **R-N6-6** (audit pass 3, finding 40): `hexagon(p, 0) = 2^p` and `hexagon_ring(p, 0) = 2^p` for every `p` of a 15 × 16 (the table path has no radius-0 entry: the singleton is returned before dispatch). **R-N6-7** (finding 34): 7 × 7, `hexagon((1, 1), 1)` has 7 tiles: the centre `(1, 1)` is bit `1·7 + 1 = 8`; its neighbours on the odd row 1 are `E = i − 1 = 7` (`(0, 1)`), `W = i + 1 = 9` (`(2, 1)`), `NE = i + W = 15` (`(1, 2)`), `NW = i + W + 1 = 16` (`(2, 2)`), `SE = i − W = 1` (`(1, 0)`), `SW = i − W + 1 = 2` (`(2, 0)`); expected `2^1 + 2^2 + 2^7 + 2^8 + 2^9 + 2^15 + 2^16`. On `new_empty(7, 7)`, `tiles_within_range((1, 1), 1)` is `2^8 + 2^9 + 2^15 + 2^16` (the 4 interior tiles), and the two are **not** asserted equal |

**Design sketch (not normative)**

| | |
|---|---|
| Tables | `HEXAGONS: [felt252; 14]` and `HEXAGON_RINGS: [felt252; 14]` (parity × radius `1..=7`), the canonical shapes re-centred on `(7, 8)` (even) or `(7, 7)` (odd) of the 15 × 16 board: a radius-7 shape spans rows 1 to 15 around `(7, 8)`, hence the 16-row bands below |
| Dispatch | **Radius 0 returns `2^position` before any dispatch** (audit pass 3, finding 40: the tables have no radius-0 entry). Then **the table path serves `width == 15` and `1 ≤ radius ≤ 7` only**: a canonical hexagon of radius `r` spans `2r + 1` columns, so radius 8 (17 columns) has no complete representation on a width of 15 (audit pass 1, finding 6). Every other case runs the row loop |
| Algorithm, table path | The canonical shape is **clipped before it is shifted**: the canonical columns that would land outside `[0, 15)` and the canonical rows that would land outside `[0, H)` are removed by one AND with the product of a column band (`COL_FROM[lo_c] & COL_TO[hi_c]` with `lo_c = max(0, 7 − x)`, `hi_c = min(15, 7 − x + 15)`) and a row band taken from the **16-row** tables (`ROW_FROM_16[lo_r] & ROW_TO_16[hi_r]` with `lo_r = max(0, y0 − y)`, `hi_r = min(16, y0 − y + H)`, `y0` the canonical centre row); the 15-entry chunk bands of the first draft could not express `COL_TO[15]`, `ROW_TO[16]` nor keep row 15 (audit pass 2, finding 23). Then one product by `POW[i − c0]` or `INV[c0 − i]`, exact because after the clip every bit lands in `[0, W·H)` and no bit crosses a row. Shifting first and clipping afterwards reduces modulo the field (audit pass 1, finding 6) |
| Algorithm, loop path | Any width, any radius, `width == 15` with radius above 7: a loop over the rows `[y − r, y + r] ∩ [0, H)`, each iteration computing the row's extent from the centre with the formula of `LayoutTrait::hexagon` (`:141-147`), clipping it to `[0, W)`, and adding `(2^len − 1)·2^(row·W + start)` (two lookups, one product, one addition); bounded by `H` iterations. `hexagon_ring` on the loop path computes **both extents (radius `r` and `r − 1`) in the same row loop** and adds the two differences per row; it is one loop, not two calls |
| Why not the flood | `tiles_within_range(6)` on an empty 17 × 14 costs **159,255 measured** (`GAS.md:242`): one dilation per unit of radius. Why not a table per position (240 felts per radius, one lookup, ~2k): it saves ~30k on a query made once per tick and costs 1,440 felts of class for six radii; it is kept as a measured **variant** in the benches and promoted only if SPK-7 finds the query on a hot path |
| Operations, summed (exact lower bound of the target) | Table path: parity and coordinates (2 `DivRem`, 2,196), 1 mask lookup (1,269), 4 band lookups (`4 × 1,269 = 5,076`), 4 conversions of the bands to limbs (`4 × 1,809 = 7,236`), 2 ANDs of the band pairs (`2 × 3,392 = 6,784`), 2 rebuilds (394), 1 product of the two bands (98), its conversion (1,809), the mask conversion (1,809), 1 AND with the mask (3,392), rebuild (197), 1 shift lookup (1,269), 1 product (98): `2,196 + 1,269 + 5,076 + 7,236 + 6,784 + 394 + 98 + 1,809 + 1,809 + 3,392 + 197 + 1,269 + 98 = ` **31,627**, for `hexagon` and for `hexagon_ring` (its own table). Loop path, `hexagon`, per row: extent arithmetic (500), 2 lookups (2,538), one product and one felt addition (`98 + 98 = 196`), the loop iteration (1,270): `500 + 2,538 + 196 + 1,270 = ` **4,504**; **`cost = 4,504 × rows`**: 16 rows `= ` **72,064**; 83 rows `= ` **373,832**. Loop path, `hexagon_ring` in one loop, per row: two extents (1,000), 4 lookups (5,076), 2 products and 2 additions (392), the iteration (1,270): `1,000 + 5,076 + 392 + 1,270 = ` **7,738**; **`cost = 7,738 × rows`**: 16 rows `= ` **123,808**; 83 rows `= ` **642,254** |

### 6.8 N-7 — Directions, opposite, rotation, arcs

```cairo
// Mirror (hexx names, hexx sense: +1 is counter-clockwise on a north-up map)
fn clockwise(self: EdgeDirection) -> EdgeDirection;  fn counter_clockwise(...);  fn const_neg(...);
fn rotate_cw(self: EdgeDirection, offset: u8) -> EdgeDirection;  fn rotate_ccw(...);
// Board (north-up names)
pub enum Arc { Front, FrontSide, RearSide, Back }
fn opposite(self: Direction) -> Direction;                    // taken over
fn rotate(self: Direction, steps: u8) -> Direction;           // (index + steps % 6) % 6, counter-clockwise on the map; any `steps` in 0..=255
fn arc(self: Direction, facing: Direction) -> Arc;            // from (index + 6 - facing) % 6: 0 Front, 1 and 5 FrontSide, 2 and 4 RearSide, 3 Back
impl Into<Direction, EdgeDirection>; impl Into<EdgeDirection, Direction>;   // index identity
```

**Contract (normative)**

| | |
|---|---|
| Module | `direction::edge_direction` (mirror), `board::direction` (extension) |
| Domain | Every `u8` for `steps`; every pair of directions for `arc` |
| Semantics | `rotate(d, n)` is the direction of index `(index(d) + n) mod 6`; `EdgeDirection::rotate_cw(d, n)` the same on the mirror type (`hexx`, `src/direction/edge_direction.rs:314`), `rotate_ccw(d, n)` the index `(index(d) − n) mod 6`; `arc(d, facing)` is `Front` when `(index(d) − index(facing)) mod 6 = 0`, `FrontSide` for 1 and 5, `RearSide` for 2 and 4, `Back` for 3 (`grimworld:docs/design/04-combat.md` § Facing). The `Into` conversions between `Direction` and `EdgeDirection` preserve the index. The game writes arcs with directions, never with the word "clockwise" (L-G1, point 7) |
| Tie-breaks | None |
| Oracle | Exhaustive: 36 pairs for `arc`, 6 × 256 for `rotate` and for `EdgeDirection::rotate_cw` / `rotate_ccw` (every `steps` of `u8`), `rotate(3) == opposite`, `Into` round trips, and `EdgeDirection::rotate_cw(n).into() == Direction::rotate(n)` |
| Worst case | Input independent (`steps = 255` for the overflow test) |
| Regression cases | **R-N7-1** (audit pass 1, finding 10): `rotate(SouthEast, 255) = SouthEast.rotate(3) = NorthWest` (255 mod 6 = 3), no panic; `EdgeDirection` index 5 with `rotate_cw(255)` gives index 2. **R-N7-2**: `arc(East, West) = Back`, `arc(East, NorthEast) = FrontSide`, `arc(SouthEast, East) = FrontSide` (the difference wraps to 5) |

**Design sketch (not normative)**

| | |
|---|---|
| Algorithm | Arithmetic on `u8`: the offset is reduced modulo 6 before the addition (`steps % 6`, then `(index + r) % 6`); `arc` computes `(index + 6 − facing) % 6`, which never underflows, then a `match` on the six values |
| Domain coverage | Worst case of the whole domain: a fixed sequence of operations, input-independent (`steps = 255` exercises the reduction) |
| Operations, summed (exact lower bound of the target) | `rotate`: 2 `DivRem` (`2 × 1,098 = 2,196` measured, `GAS.md:1535`) and 1 addition (300): **2,496**; `arc`: 1 addition (300), 1 subtraction (300), 1 `DivRem` (1,098), 1 four-arm `match` (300): **1,998**; the mirror's `rotate_cw` / `rotate_ccw`: the same 2,496; `clockwise`, `counter_clockwise`, `const_neg` (one addition and one `DivRem`, `(index + 1, 5, 3) mod 6`): `300 + 1,098 = ` **1,398** each; `index`: a field read, **100**; `into_hex`: one lookup, **1,269** (audit pass 4, finding 14) |

### 6.9 N-8 — One flood giving every walker its next step

The project manager's answer (L-G1, point 5): one flood per tick on the occupancy frozen at
the start of the tick; the current occupancy filters each goblin's candidate tiles, in
ascending id order; when no closer tile is free, fall back to the same layer. Frozen at the
first release.

```cairo
#[derive(Drop)]
pub struct Flood { width: u8, height: u8, layers: Span<u256> }   // layers[d] = tiles at path distance d from the source, on grid & ~obstacles; layers[0] = {from}
/// `depth`: the largest number of layers computed after layer 0; the flood stops earlier when
/// the frontier is empty. `depth = 0` is not special. The bound the caller needs is D-25.
fn flood(self: HexMap, from: u8, obstacles: felt252, depth: u8) -> Flood;         // Bfs::flood; `from` walkable and not an obstacle, else 'Bfs: position not walkable'
fn next_step(self: @Flood, position: u8, blocked: felt252) -> Option<u8>;       // the free neighbour in the lowest layer, lowest index; None when no neighbour is in any layer or all are blocked
fn next_step_away(self: @Flood, position: u8, blocked: felt252) -> Option<u8>;  // the free neighbour in the highest layer, lowest index (kiting)
fn distance(self: @Flood, position: u8) -> Option<u8>;                           // the layer of `position`; for a tile in no layer, the lowest layer of a neighbour plus one (D-26); None when neither exists
fn depth(self: @Flood) -> u8;                                                    // the number of layers computed after layer 0
```

**Contract (normative)**

| | |
|---|---|
| Module | `finders::bfs` (`Bfs::flood`), `finders::flood` (`Flood`, `FloodTrait`); facade `HexMapTrait::flood` |
| Domain | `from` walkable and not in `obstacles`, else the panic of `Bfs`; `from` may be an **open edge tile** (an entrance), as for every finder of 1.8.0; `position` inside the board (`None` outside), ring tiles included; any `blocked`; `depth` any `u8`. A walker whose nearest layer is beyond `depth` gets `None` from `next_step`, `next_step_away` and `distance` |
| Open edge tiles (D-32) | The layers hold **interior tiles only**, except layer 0, which is `{from}` even when `from` is an open edge tile. An open edge tile other than the source never appears in a layer: it can end a path in the finders of 1.8.0 (`README.md:63-66`) but it is never a step of a walker here (the **source** is: a walker adjacent to an open edge source steps onto it from layer 0, R-N8-7; audit pass 4, finding 33), because the walkers of the game stand inside the window whose ring is imposed as wall (ADR-0006 §4) and because a layer must be expandable by the dilation (`hexmap:src/helpers/layout.cairo:5-8`). `dist` is therefore defined through interior tiles, with the source's open interior neighbours at distance 1 (`BfsInternal::endpoint`, `hexmap:src/finders/bfs.cairo:183-187`, seeds an edge start that way). Reversible decision D-32 (§12): the alternative includes open edge tiles reachable in one step as terminal members of their layer, as `reachable` and `tiles_within_range` do |
| Semantics | Let `open = grid & ~obstacles` restricted to the interior, and let `dist(t)` be the length of the shortest path from `from` to `t` whose every tile after `from` is in `open` (the scalar BFS, `src/finders/bfs.cairo:1183`, restricted to interior destinations, D-32), undefined when none exists. `layers[k]` is `{t : dist(t) = k}` for `0 ≤ k ≤ depth()`, where `depth()` is the smaller of `depth` and the largest defined `dist`; `layers[0] = {from}`. Let `N(p)` be the six board neighbours of `p` (from the neighbour table; on the ring, only those inside the board). `next_step(p, blocked)`: let `k` be the least layer index such that `N(p) ∩ layers[k] ≠ ∅`; the result is the **lowest index** of `N(p) ∩ layers[k] − blocked`, or, when that set is empty and `k + 1 ≤ depth()`, the lowest index of `N(p) ∩ layers[k + 1] − blocked`; `None` when no such `k` exists or both sets are empty. `next_step_away(p, blocked)`: let `k` be the **greatest** layer index such that `N(p) ∩ layers[k] − blocked ≠ ∅`; the lowest index of that set; `None` when none. `distance(p)`: `Some(dist(p))` when `p` is in a layer; otherwise `Some(k + 1)` with `k` the least index such that `N(p) ∩ layers[k] ≠ ∅` (D-26); otherwise `None`. With `blocked` = the current occupancy, the id-order rule of the tick is the caller's loop (L-G1, point 5) |
| Tie-breaks | The lowest tile index among the candidates, in every selection (`grimworld:docs/design/04-combat.md` § Goblin AI) |
| The true bound of the flood | The layers are disjoint non-empty subsets of the walkable interior, so `depth()` is at most the number of walkable interior tiles: **at most 182 on 15 × 16** (13 × 14), and at most `(W − 2)(H − 2) ≤ 187` (19 × 13) on any board of the engine. It is not 15 (audit pass 1, finding 9). Whether the game truncates the flood, and what a walker beyond the truncation does, is a **game decision** (D-25, §11 Q-5) that this library does not take |
| Domain coverage | Bounds parameterised by the input: the flood by `depth()` (`55,000 + 19,300 × depth()`, `depth() ≤ (W − 2)(H − 2)`); each selection by its number of scanned layers (below). The **game-sized fixtures** are the cave and the pinned serpentines on 15 × 16 (the deepest, 45 layers, is also the deepest executable fixture supplied); the domain-wide figures **182 layers on 15 × 16 and 187 on 19 × 13 are cardinality bounds, not fixtures** (audit pass 4, finding 39): no supplied board attains them, and a board that does (one path through every interior tile) is left to LIB-05 if a measurement at the bound is wanted |
| Why one flood | The design ("one flood per tick, not one per goblin", `grimworld:docs/design/02-core-loop.md` § Simulation budget); rule (b) of LIB-02 §5.9 costs up to 8 floods |
| Oracle | The scalar queue BFS of `src/finders/bfs.cairo:1183` (`reference_all`) for the layers, **filtered to interior destinations** (it records open edge destinations at `:1238-1242`, which D-32 excludes; audit pass 3, finding 33), with an edge source seeded by its open interior neighbours; the scalar definitions above for `next_step`, `next_step_away` and `distance` over every walkable and every obstacle tile of the fixtures and of the pinned corridor below, with ties checked against the lowest index; a property: a step is never a wall, never blocked, is adjacent, and is **interior or equal to `from`** (the only ring tile a layer can hold is the source, in layer 0, and the selection rule may return it; audit pass 4, finding 33) |
| The pinned corridor `SERPENTINE_15X16` | 15 × 16; open tiles: rows 2, 4, 6, 8, 10 and 12 at columns 1 to 13 (`6 × 13 = 78` tiles), and the five joints `(13, 3)`, `(1, 5)`, `(13, 7)`, `(1, 9)`, `(13, 11)`: **83 open tiles**. Source `(7, 8)`. Distances by hand (each corridor row is one tile wide; a joint on an odd row `y` touches the two tiles `(x, y ± 1)` and `(x + 1, y ± 1)`): east branch, `(13, 8)` 6, `(13, 7)` 7, `(13, 6)` 8, along row 6 `(x, 6) = 8 + (13 − x)`, so `(2, 6)` 19 and `(1, 6)` 20; `(1, 5)` 20 (from `(2, 6)`); `(2, 4)` 21, along row 4 `(x, 4) = 21 + (x − 2)`, so `(13, 4)` 32; `(13, 3)` 33; `(13, 2)` 34, along row 2 `(x, 2) = 34 + (13 − x)`, so `(2, 2)` **45** and `(1, 2)` **46**. West branch: `(2, 8)` 5, `(1, 9)` 6 (the `NE` of `(2, 8)`), `(1, 10)` 7 and `(2, 10)` 7, along row 10 `(x, 10) = 7 + (x − 2)` for `x ≥ 2`, so `(13, 10)` 18; `(13, 11)` 19; `(13, 12)` 20, along row 12 `(x, 12) = 20 + (13 − x)`, so `(6, 12)` 27 and `(1, 12)` 32. With the walker `(1, 2)` frozen (`obstacles = 2^(2·15 + 1) = 2^31`): `83 − 1 = 82` reachable tiles, `depth() = 45`; with `(1, 2)` and `(3, 2)` frozen: `83 − 3 = 80` reachable tiles (`(2, 2)` cut off), `depth() = 43` (`(4, 2)`) |
| The pinned eight-walker benchmark `SERPENTINE_15X16_8` | Source `(7, 8)`; the eight walkers, in ascending id order: `W1 (5, 2)`, `W2 (4, 2)`, `W3 (3, 2)`, `W4 (2, 2)`, `W5 (5, 12)`, `W6 (4, 12)`, `W7 (3, 12)`, `W8 (2, 12)`; `obstacles` = the eight tiles; `depth = 182`; `blocked` starts as the eight tiles and is updated after each move. Layers: the east branch is cut at `(5, 2)`, so its farthest reachable tile is `(6, 2)` at 41; the west branch is cut at `(5, 12)`, farthest `(6, 12)` at 27; `depth() = 41`; reachable tiles `83 − 8 − 2 = 73` (the eight walkers and the tiles `(1, 2)`, `(1, 12)` beyond them). Expected moves: `W1 (5, 2)`: `N(W1) = {(4, 2), (6, 2)}` (its four diagonal neighbours on rows 1 and 3 are walls); the least layer touched is 41 with `(6, 2)`; `(6, 2)` is not blocked: `next_step = Some(2·15 + 6) = Some(36)`; `blocked` becomes the seven other walkers plus `(6, 2)`. `W2 (4, 2)`: `N = {(3, 2), (5, 2)}`, neither in any layer (both were obstacles when the flood ran): `None`. `W3`, `W4`: `None` likewise. `W5 (5, 12)`: `N = {(4, 12), (6, 12)}`, `(6, 12)` at 27, free: `Some(12·15 + 6) = Some(186)`. `W6`, `W7`, `W8`: `None`. `distance`: `W1` `Some(42)`, `W2` to `W4` `None`, `W5` `Some(28)`, `W6` to `W8` `None`. This is the frozen-occupancy rule as the project manager decided it: a walker behind another walker in a corridor waits |
| Worst case | Four benchmarks. **Cave**: 15 × 16 cave assembled from 4 chunks, the adventurer at `(7, 8)`, 8 walkers at pinned positions at distances 3 to 15 (pinned by M1-T9 from the `CAVE` fixture with the expected moves computed by the scalar oracle), `depth = 30`, `blocked` changing after each walker. **Serpentine, deep**: `SERPENTINE_15X16_8`, as pinned above. **Serpentine, near, reverse**: the flood of R-N8-1 (one obstacle, `depth() = 45`), `next_step_away((4, 8), blocked)` with `blocked = {(3, 8), (5, 8)}`: `(4, 8)` is at distance 3, its two open neighbours are at 4 and 2, both blocked, so the reverse scan visits every layer from 45 down to 0, **46 scans**, and returns `None` (audit pass 3, finding 38). **Serpentine, distance of a far obstacle**: `distance((1, 2))` on the same flood, 46 scans |
| Regression cases | **R-N8-1** (audit pass 1, finding 9; pass 2 recount): `SERPENTINE_15X16`, source `(7, 8)`, `obstacles = 2^31` (`(1, 2)`), `depth = 182`: `depth() = 45`, `distance((2, 2)) = Some(45)`, `distance((1, 2)) = Some(46)`, `next_step((1, 2), 0) = Some(32)` (`(2, 2) = 2·15 + 2`). **R-N8-2**: the same with `depth = 15`: `depth() = 15`, `next_step((1, 2), 0) = None`, `distance((1, 2)) = None`. **R-N8-3** (pass 2, finding 9): the same with `obstacles = 2^31 + 2^33` (`(1, 2)` and `(3, 2)`), `depth = 182`: `(2, 2)` is unreachable, `next_step((1, 2), ·) = None` and `distance((1, 2)) = None` at every depth; `depth() = 43`. **R-N8-4**: `SERPENTINE_15X16_8` as pinned: the eight results above. **R-N8-5**: a walker on the ring (`(0, 8)` of a 15 × 16 window whose `(1, 8)` is open and in layer 6) gets `next_step((0, 8), 0) = Some(8·15 + 1)` through its in-board neighbours. **R-N8-6** (audit pass 3, finding 38): the reverse all-blocked case above: `next_step_away((4, 8), {(3, 8), (5, 8)}) = None` after 46 scans. **R-N8-7** (finding 33, D-32; audit pass 4, finding 33): 7 × 7, `grid` with the open tiles `(1, 3)` (bit 22) and `(0, 3)` (bit 21, an open edge tile), `obstacles = 0`, **`depth = 25`** (the interior count of 7 × 7, so nothing is truncated): with source `(1, 3)`: `layers[0] = 2^22`, `depth() = 0` (no other interior open tile), `distance((0, 3)) = Some(1)` by inference (its neighbour `(1, 3)` is in layer 0), `next_step((0, 3), 0) = Some(22)`; with source `(0, 3)`: `layers[0] = 2^21`, `layers[1] = 2^22`, `depth() = 1`, `distance((1, 3)) = Some(1)`, and **`next_step((1, 3), 0) = Some(21)`**: `N((1, 3))` on the odd row 3 is `E = 22 − 1 = 21` (`(0, 3)`), `W = 23`, `NE = 22 + 7 = 29`, `NW = 30`, `SE = 22 − 7 = 15`, `SW = 16`; the least `k` with `N ∩ layers[k] ≠ ∅` is `k = 0` (bit 21), the candidates `{21} − ∅ = {21}`, lowest index 21: the walker steps onto the open edge source, the one ring tile a step may be |

**Design sketch (not normative)**

| | |
|---|---|
| Algorithm | Bitwise: the layer loop of `Bfs` (`hexmap:src/finders/bfs.cairo:1-16`) on `grid & ~obstacles`, storing every layer (`ArrayStore`, `:87`) up to `depth` or until the frontier is empty; an edge source is seeded by its open interior neighbours as `Bfs::search` does (`:183-187`). `next_step`: `around = neighbor_mask(position)` for an interior position, `LayoutTrait::edge_neighbors` on the ring; scan the layers from 0 upward for the first `k` with `around & layers[k] != 0`; `candidates = around & layers[k] & ~blocked`; if empty, `around & layers[k + 1] & ~blocked` when layer `k + 1` exists; the lowest set bit. `next_step_away`: scan from the highest computed layer downward, testing `around & layers[k] & ~blocked` at each layer, until a non-empty result; the lowest set bit; the scan visits every layer when every candidate is blocked (finding 38). `distance`: **one pass, no membership scan**: test `bit(p) & layers[0]` once (the source), then scan upward for the first `k` with `around & layers[k] != 0` and return `k + 1`: a tile in layer `k ≥ 1` has a neighbour in layer `k − 1`, so the neighbour scan alone gives `k`, and an obstacle tile gets the inferred value; the two-scan form of the previous draft would have visited 92 layers for `(1, 2)` (finding 38) |
| Operations, summed (exact lower bound of the target) | Flood: **19,300 per layer** (measured "~19.3k" on two limbs, `GAS.md:156`; 240 tiles are on the path of the 238-tile measurement, `window-parity-check.md` §3) plus **55,000 fixed** (measured "~55k", `:162`): **`flood = 55,000 + 19,300 × depth()`**. Cave benchmark, **pinned input `depth() = 25`** (the far path of the fixture `bench_bfs_search_cave_far_17x14` has 24 steps, `:178`, and the flood runs one layer past it before the frontier empties; the `depth()` of the cave pinned by M1-T9 replaces 25 in `GAS.md`): `19,300 × 25 = 482,500`, `55,000 + 482,500 = ` **537,500**. `SERPENTINE_15X16`, 45 layers: `55,000 + 868,500 = ` **923,500**; `SERPENTINE_15X16_8`, 41 layers: `55,000 + 791,300 = ` **846,300**; the cardinality bounds (not fixtures): on 15 × 16, 182 layers: `55,000 + 3,512,600 = ` **3,567,600**; on 19 × 13, 187 layers: `55,000 + 3,609,100 = ` **3,664,100**. Per layer scanned by `next_step` and `distance`: 1 AND on two limbs (3,392 measured, `:57`) and a loop iteration (1,270, `:45`): **4,662**. `next_step`, `s` layers scanned (`s` = the inferred distance of the walker): `4,662 × s` + `neighbor_mask` (2,563) + the candidates AND (3,392) + the fallback AND (3,392) + the lowest-bit step (8,400 measured, `:159`): **`17,747 + 4,662 × s`**; `s = 15`: `17,747 + 69,930 = ` **87,677**; `s = 46`: `17,747 + 214,452 = ` **232,199**; on the ring, `edge_neighbors` (30,378, §6.6) replaces `neighbor_mask` (2,563): `+27,815`. `distance`, `s` scans: `2,563 + 1,696` (the layer-0 bit test, 1 limb) `+ 4,662 × s`: **`4,259 + 4,662 × s`**; `s = 46`: **218,711**. `next_step_away`, per layer: the `around` AND (3,392), the `~blocked` AND (3,392), the iteration (1,270): **8,054**; `s` layers scanned from the top, `s ≤ depth() + 1`: **`2,563 + 8,054 × s` + 8,400 when found**; all blocked on the 45-layer flood, `s = 46`: `2,563 + 370,484 = ` **373,047** (`None`, no lowest-bit step). **Tick, cave benchmark**: `window` 98,762 + flood 537,500 + `8 × 87,677 = 701,416` (**pinned input**: every walker charged at `s = 15`, the farthest of the pinned distances 3 to 15; the positions pinned by M1-T9 scan at most that many layers): **1,337,678**. Eight `search_path` calls would cost `8 × 706,135 = 5,649,080` (measured per call, `GAS.md:1207`). LIB-02 §5.9 estimated 300–450k without the per-walker scans and without the assembly; the first draft of this plan 740k; the plan after the first audit 1,310,000; after the second 1,310,838; now 1,337,678, each step from an operation the previous sum had omitted; §7 gives the range |

## 7. Gas targets of milestone L-M1

**No figure of this plan is a budget.** Budgets are set from measurements in LIB-05, by the
rule of the game's `docs/CAIRO.md` §2 (`ceil(1.05 × measured)`); every figure below that is
not marked "measured" is a planning target derived from the design sketches of §6 and the
unit costs of `GAS.md`, and no test, review or gate may treat it as a limit. **The tick range
`[1,337,678, 1,672,098]` is conditional on its stated inputs**: (1) the unit costs measured on
`origami_hexmap` 1.8.0 with Scarb 2.19.4 and snforge 0.61.0 (`GAS.md`); (2) the design
sketches of §6.4 and §6.9 as the algorithms (a window of 4 chunks and 2 layers assembled
without a loop, a flood that stores every layer, one-pass selections); (3) the pinned inputs
of §6.9: the cave flood at `depth() = 25`, eight walkers each scanning `s = 15` layers, all
interior, `blocked` as pinned, no walker on the ring and no line call in the tick; (4) the
range rule `U = ceil(1.25 × L)`. A different sketch, a different fixture depth, a walker on
the ring or a change of toolchain moves it; only the measurement of LIB-05 and the game's
SPK-7 settle it (accepted by the project manager, fix loop 4).

Every public function of L-M1, with its target and the origin of the figure, or an explicit
reference to the target it shares. Budgets on the tests are `ceil(1.05 × measured)` once
measured (`grimworld:docs/CAIRO.md` §2). **A figure that is not measured is a target given
as a range `[L, U]`**: `L` is the **exact** sum of the operations of the design sketch of §6
(the sums are shown there to the unit, with the unit costs they use), `U = ceil(1.25 × L)`;
no figure is rounded, and where a rounded figure is given for reading it is marked `≈`.
**Totals** (the tick) are computed as the exact sum of their components' lower bounds, and
their upper bound is one global uplift `ceil(1.25 × L)`, not the sum of the components' upper
bounds (which differs by rounding). Where the cost depends on an input (order, radius,
height, layers, steps), the row gives the **parameterised bound** of §6 with the two
instances that are benchmarked: the **game-sized fixture** and the **domain-wide worst case**.
**LIB-05 replaces every target by a measurement**; a measurement above `U` is **reported to
the orchestrator before the budget is set**, with the operation that explains it; the budget
is then set on the measurement, never on the target. Three audit passes moved several of
these figures upward as omitted operations were found; they are sums of a sketch, not
measurements, and may move again. "Fixture" marks a measured figure taken on a fixture of
1.8.0, which is not always the worst case of the function (the worst cases of the take-over
are those of `GAS.md`).

| Function | Module | Worst case or fixture | Target: measured, or range [L, U] | Origin |
|---|---|---|---:|---|
| `HexMapTrait::new_empty` | board | fixture 17 × 14 | 18,480 | measured `GAS.md:1198` |
| `new_maze` | board | fixture 17 × 14, order 0 | 2,873,670 | measured `:1199` |
| `new_cave` | board | fixture 17 × 14, order 3 | 144,927 | measured `:1200` |
| `new_random_walk` | board | fixture 17 × 14, 200 steps | 999,629 | measured `:1201` |
| `new_hexagon` | board | radius 6 (the largest) | 125,770 | measured `:1202` |
| `open_with_corridor` / `open_with_maze` | board | fixture 17 × 14 cave, entrance 8 | 63,018 / 61,858 | measured `:1203-1204` |
| `keep_component` / `reachable` | board | fixture 17 × 14 cave; serpentine 1,843,335 | 555,119 | measured `:1205`, `:230` |
| `compute_distribution` | board | fixture 17 × 14 cave, 10 objects | 193,168 | measured `:1855` |
| `search_path` | board | fixture 17 × 14 cave, 24 steps; serpentine 2,532,090 | 706,135 | measured `:1207`, `:182` |
| `search_path_weighted` | board | fixture 17 × 14 cave, 2 classes | 1,427,654 | measured `:1208` |
| `field_of_movement` | board | fixture 17 × 14 cave, budget 6, 2 classes | 261,829 | measured `:1209` |
| `distance_to` | board | fixture 17 × 14 cave, 24 steps | 501,642 | measured `:1210` |
| `range` / `ring` | board | fixture 17 × 14 cave, radius 4 | 103,793 / 99,903 | measured `:1212, :1318` |
| `hex_distance` / `neighbor` / `is_walkable` | board | per call | 10,393 / 6,959 / 7,073 | measured `:1878, :1869, :1874` |
| `HexMapTrait::new` | board | any | [400, 500]: the struct construction only, four field moves at 100 each (`hexmap:src/map.cairo:90-92`: no assertion, no layout) | sketch (audit pass 4, finding 14) |
| `LayoutTrait::{new, board, even, interior, hexagon, with_interior, expand, expand_small, dilation, index, coords, parity, neighbor}`, `DilationTrait::*`, `Bits::*` (the 18 functions), `Set`, `WideSet`, `SmallSet` (the 8 methods each), `Rng::*`, `Asserter::*`, `Geometry::{to_axial, distance}`, `Direction::{opposite, next, pop_front}` (taken over) | board | as in `GAS.md` L0, L3, P1 | the budgets of their existing benches, unchanged (`Layout::new` 12.9k `:630`, `expand` 18,613 `:1543`, `expand_small` 7,816 `:1544`, `popcount` 13,448 `:1542`, `Rng::draw6` 3,737 `:1538`, `shuffle6` 5,769 `:1541`, the `Set` impls inside the Dial step 26.5k–38.0k per time step § L3, `Geometry::distance` = `hex_distance` minus the checks) | measured |
| `HexPrinter::*` | board | — | none: `#[cfg(test)]` only, never in a class | — |
| `LayoutTrait::neighbor_mask` (renamed) | board | odd row | [2,563, 3,204] | §6.1 |
| `LayoutTrait::edge_neighbors` / `neighbor_in` (renamed) | board | corner tile | shares the `Bfs` edge-endpoint budgets (`GAS.md:162`, in the 55k fixed cost); as a standalone call [30,378, 37,973] (6 × (`LayoutTrait::neighbor` 3,696 + lookup 1,269 + addition 98)) | measured; §6.6 |
| `LayoutTrait::new_odd` | board | any | [13,200, 16,500] (`Layout::new` 12,900 + one subtraction 300) | §6.2 |
| `Geometry::distance_between` | board | `(0, 0)`–`(255, 255)`, result 383 | [5,196, 6,495] | §6.1 |
| `Geometry::chunk_of` | board | any | [2,196, 2,745] | §6.1 |
| `Geometry::to_hex` / `from_hex` | board | any | `to_hex` [1,998, 2,498] (1 `DivRem` 1,098 + 3 `i32` operations 900); `from_hex` [2,198, 2,748] (the same 1,998 + 2 `try_into` to `u8` 200) | §3.5 |
| `Geometry::index_to_hex` / `hex_to_index` | board | any | `index_to_hex` [4,194, 5,243] (2 `DivRem` 2,196 + `to_hex` 1,998); `hex_to_index` [2,998, 3,748] (`from_hex` 2,198 + 2 comparisons against `W` and `H` 200 + `y·W + x` 600); the loop path of `line` charges exactly these per call: `2 × 4,194 = 8,388` for the endpoints and 2,998 per step | §3.5, §6.6 |
| `LayoutTrait::neighbor_direction` | board | odd row, non-adjacent pair | [4,294, 5,368] | §6.1 |
| `Caver::generate_with_margins` | generators | bound `48,650 + 61,938 × order`; fixture order 3; domain-wide order 255 | order 3: [234,464, 293,080]; order 255: [15,842,840, 19,803,550] | §6.2 |
| `HexMapTrait::new_cave_with_margins` | board | same | shares `generate_with_margins` (the facade adds nothing, `GAS.md:1191`) | — |
| `HexMapTrait::smooth` | board | bound `12,900 + 65,330 × order`; fixture order 3, ring + 20 held tiles; domain-wide order 255 | order 3: [208,890, 261,113]; order 255: [16,672,050, 20,840,063] | §6.2 |
| `seams::side` | board | any | [3,032, 3,790] | §6.3 |
| `seams::openings` | board | East seam, even, both open, 15 × 16 (the worst of the domain: fixed operations) | [33,871, 42,339]; horizontal seam [23,287, 29,109] | §6.3 |
| `seams::is_open_across` | board | same | shares `openings` plus a zero test (100) | — |
| `assembly::origin` | board | any | [3,996, 4,995] | §6.4 |
| `assembly::local` | board | any | [2,600, 3,250] | §6.4 |
| `assembly::assemble` (one layer, 4 chunks) | board | `ox = oy = 7`, odd chunk row (the worst of the domain) | [46,532, 58,165] | §6.4 |
| `assembly::window` (2 layers, 4 chunks, ring) | board | same, **at each tick** | [98,762, 123,453]; two chunks [53,530, 66,913] | §6.4 |
| `HexMapTrait::cut` | board | any | [16,905, 21,132] | §6.5 |
| `HexMapTrait::line` (table) | board | width 15, distance 6, ties, from `(7, 7)` | [7,399, 9,249] | §6.6 |
| `HexMapTrait::line` (loop) | board | bound `8,388 + 6,835 × N`; fixtures `(0, 0) → (14, 15)` (22) and interior `(1, 14) → (13, 1)` (19); domain-wide fixture `(0, 0) → (82, 2)` on 83 × 3 (83, the diameter); the bound `N ≤ W + H − 2 = 84` is not a fixture | 22: [158,758, 198,448]; 19: [138,253, 172,817]; 83: [575,693, 719,617]; bound at 84: 582,528 (not benchmarked) | §6.6 |
| `line_of_sight` | board | table case | [14,509, 18,137] (loop case: `line` + 7,110) | §6.6 |
| `approach` | board | table case, interior target; ring target | [29,666, 37,083]; [57,481, 71,852] (loop case: `line` instead of 7,399) | §6.6 |
| `hexagon` / `hexagon_ring` (table) | board | radius 7, centre `(1, 1)`, odd; radius 6 from `(7, 8)` | [31,627, 39,534] each | §6.7 |
| `hexagon` (loop) | board | bound `4,504 × rows`, `rows ≤ H`; fixture radius 8, centre `(7, 8)`, 16 rows; domain-wide 83 rows (3 × 83, radius 255) | 16 rows: [72,064, 90,080]; 83 rows: [373,832, 467,290] | §6.7 |
| `hexagon_ring` (loop, one loop for both extents) | board | bound `7,738 × rows`; the same fixtures | 16 rows: [123,808, 154,760]; 83 rows: [642,254, 802,818] | §6.7 |
| `Direction::rotate` / `arc` | board | `steps = 255`; any pair | [2,496, 3,120] / [1,998, 2,498] | §6.8 |
| `Into<Direction, EdgeDirection>` and back | board | any | [500, 625] (a `match`) | estimate |
| `Bfs::flood` | finders | bound `55,000 + 19,300 × depth()`; fixtures: cave 25 layers (pinned input), `SERPENTINE_15X16` 45 layers, `SERPENTINE_15X16_8` 41 layers; the cardinality bounds 182 layers on 15 × 16 and 187 on 19 × 13 are bounds, not fixtures | cave: [537,500, 671,875]; serpentine: [923,500, 1,154,375]; eight walkers: [846,300, 1,057,875]; bounds, not benchmarked: 3,567,600 and 3,664,100 | §6.9 |
| `FloodTrait::next_step` | finders | bound `17,747 + 4,662 × s` (`s` = the walker's inferred distance); fixture `s = 15` (cave); deep `s = 46` (`(1, 2)` of R-N8-1) | [87,677, 109,597]; [232,199, 290,249]; on the ring `+ 27,815` | §6.9 |
| `FloodTrait::distance` | finders | bound `4,259 + 4,662 × s`; `s = 46` | [218,711, 273,389] | §6.9 |
| `FloodTrait::next_step_away` | finders | bound `2,563 + 8,054 × s (+ 8,400 when found)`, `s ≤ depth() + 1`; the all-blocked case R-N8-6, `s = 46` | [373,047, 466,309] | §6.9 |
| `FloodTrait::depth` | finders | any | [200, 250] (a length) | estimate |
| **One tick, cave: `window` + `flood` (25 layers) + 8 × `next_step` at `s = 15`** | — | 4 chunks, two layers | **L = 98,762 + 537,500 + 701,416 = 1,337,678; U = ceil(1.25 × L) = 1,672,098** (the components' upper bounds sum to `123,453 + 671,875 + 876,776 = 1,672,104`, which the global uplift replaces) | §6.4, §6.9 |
| `HexTrait::{new, x, y, z, const_sub, length, ulength, distance_to, unsigned_distance_to}` | hex | any | [1,500, 1,875] each (at most 5 `i32` operations at 300) | §3.1 |
| `HexTrait::line_to` | hex | bound `2,970 × (N + 1)` (per element: accumulator 600, tie test 600, append 500, iteration 1,270); fixture `N = 22` | [68,310, 85,388] | §6.6 |
| `Hex::from_offset_coordinates` / `to_offset_coordinates` (Even, Pointy) | hex | any | [1,500, 1,875] each | §3.5 |
| `EdgeDirection::index` | direction | any | [100, 125] (one field read) | §6.8 |
| `EdgeDirection::into_hex` | direction | any | [1,269, 1,587] (one lookup in `NEIGHBORS_COORDS`, 1,269) | §6.8 |
| `EdgeDirection::{const_neg, clockwise, counter_clockwise}` | direction | any | [1,398, 1,748] each (one addition 300 and one `DivRem` 1,098: `(index + 3) mod 6`, `(index + 1) mod 6`, `(index + 5) mod 6`) | §6.8 |
| `EdgeDirection::rotate_cw` / `rotate_ccw` | direction | `steps = 255` | [2,496, 3,120] each | §6.8 |
| `EdgeDirection::iter` (counterpart: `ALL_DIRECTIONS.span()`) | direction | — | no cost (a span over a constant) | — |
| `EdgeDirection::ALL_DIRECTIONS`, the constants, `HexOrientation`, `OffsetHexMode`, `Hex::ZERO`, `NEIGHBORS_COORDS` | direction, orientation, conversions, hex | — | no cost (constants) | — |

The tick figure is the one that matters to the game and the one that moved most: LIB-02
estimated 300–450k, the first draft of this plan 740k, the plan after the first audit
1,310,000, after the second 1,310,838, and the range above starts at 1,337,678 after the
third. Each move came from an omitted operation, not from a new algorithm. **Only
measurement settles it**: LIB-05 measures every function on the fixtures and the domain-wide
worst cases of §6, and the game's spike SPK-7 measures the tick on the game's own contracts
(ADR-0006 § Cost). Until then the range is a planning figure, and the game should plan on
its upper bound.

Tables: entries as declared, and the compiled class size as an estimate (one CASM felt per
entry plus a constant per array; the release check is the consumer-size measurement of R-11):

| Table | Entries (declared) | Used by | Estimated class cost |
|---|---:|---|---:|
| `POW: [felt252; 252]`, `INV: [felt252; 252]`, `POW128: [u128; 128]` (taken over, `hexmap:src/helpers/bits.cairo:403, 537, 791`) | 252 + 252 + 128 | every shift | already paid by the game today (~700 felts) |
| `PERMUTATIONS: [u32; 720]` (taken over, `hexmap:src/helpers/rng.cairo:199`), `SUBSETS: [u8; 511]`, `SUBSET_OFFSETS: [u16; 90]`, `NIBBLE_SELECT: [felt252; 64]`, `NIBBLE_COUNT: [u8; 16]` (`hexmap:src/generators/spreader.cairo:61-100`) | 720 + 511 + 90 + 64 + 16 | `Rng::shuffle6`, `Spreader` | already paid by the game today (~1,500 felts) |
| `LINES: [felt252; 254]` (canonical starts `(7, 7)` and `(7, 8)` of 15 × 16), `LINE_SPANS: [u8; 254]` | 254 + 254 | `line`, `line_of_sight`, `approach` | ~560 felts (0.7 %) |
| `HEXAGONS: [felt252; 14]`, `HEXAGON_RINGS: [felt252; 14]` | 14 + 14 | `hexagon`, `hexagon_ring` | ~35 felts |
| `COL_FROM`, `COL_TO: [felt252; 16]`; `ROW_FROM_15`, `ROW_TO_15: [felt252; 16]`; `ROW_FROM_16`, `ROW_TO_16: [felt252; 17]` (`board::tables`, §6.4) | 98 | `assemble` (15-row bands), `hexagon` (16-row bands) | ~110 felts |
| `arc` | 6 arms of a `match` | `arc` | negligible |
| **New tables of L-M1** | **634** | | **~705 felts (0.9 %)** |
| Variant, not shipped by default: per-position sight table | 240 per radius | `hexagon` | ~280 felts per radius |

## 8. Milestones

### L-M1 — What the game needs first (release 0.1.0)

| | |
|---|---|
| Content | The take-over of the engine with identical results (§5); the extensions N-1 to N-8, distance and neighbours (§6); **need N-9, reduced** (ADR-0007): `snforge_std` under `[dev-dependencies]`, so that the library resolves next to any test setup of its consumer, verified on the published package; and the **mirror items that the extensions depend on**, each traced below. Nothing else of the mirror is in L-M1 |
| The mirror items of L-M1, each with its trace (the canonical list; §4.4 and §7 follow it) | `Hex` (the struct, its fields, `new`, `x`, `y`, `z`, `ZERO`, `const_sub`, `length`, `ulength`, `distance_to`, `unsigned_distance_to`): the frame in which N-5's line and its tie rule are defined and in which the `refgen` vectors are generated; `to_hex`/`from_hex` (§3.5) return it; the loop path of `line` runs on it (`length` and `ulength` are what `distance_to` and `unsigned_distance_to` call, `src/hex/mod.rs:615-627`). `HexTrait::line_to`: the definition of N-5 (the board `line` is proved against it). `OffsetHexMode`, `HexOrientation` (the enums, with `Default` and `Not`), `from_offset_coordinates`, `to_offset_coordinates`: the two calls that define the board mapping of §3.5. `EdgeDirection` (the struct, `ALL_DIRECTIONS`, `iter` as `ALL_DIRECTIONS.span()`, the 30 constants, `index`, `into_hex`, `NEIGHBORS_COORDS` that `into_hex` reads, `const_neg`, `clockwise`, `counter_clockwise`, `rotate_cw`, `rotate_ccw`, `Into<EdgeDirection, Hex>`): N-7's "rotation by steps of 60°" is specified against `hexx`'s rotation and tested equal to `Direction::rotate` (§6.8), and the conversions of §3.2 need the type. Every other item of §4.4 that carried "L-M1" in the first version of this plan (`hex()`, the other constants, `splat`, `new_cubic`, the array conversions, `const_neg`, `const_add`, `neighbor`, `all_neighbors`, `neighbor_direction`, the `Hex` rotations, `range_count`, the operators, `mul_scalar`, `add_direction`, `DoubledHexMode`, the `Neg`, `mul_scalar` and `Debug` of `EdgeDirection`) has no game need and no implementation dependency and moves to L-M2 (audit pass 1, finding 18). The alternative, publishing the wider foundation in 0.1.0, is D-5 for the owner |
| Depends on | LIB-04 (repository, CI, parity script, `refgen`, gas tooling, publication pipeline) |
| Exit criterion | (1) `crates/takeover_tests` green against `origami_hexmap` 1.8.0 on every function (§5.4); (2) every extension has a scalar oracle, the worst-case benches of §6 and a budget within 5 % of its measurement, and every estimate of §7 is replaced by a measurement in `GAS.md` (a target missed by more than 25 % is reported to the owner before release); (3) `api_parity.py --check`, `deviations.py --check`, `bench.py check` green, every item scheduled for L-M1 `ported` or `renamed`, the items scheduled later listed as such; (4) `docs/deviations/line_ties.md` generated; (5) the pinned streams of `generate_with_margins` committed; (6) the two design tasks below closed (§6.2 planes and masks, §6.3 formulas) with their oracles green; (7) `0.1.0` published on scarbs.xyz and consumed by the game's SPK-7 branch; (8) **N-9 demonstrated on the published package**: the two consumer packages of `tools/consumer_check/` (outside the workspace, `hexx = "0.1.0-rc.N"` then `"0.1.0"` from the registry; one with `cairo_test` as its only dev-dependency and no `snforge_std`, one with `snforge_std` of another version than the library's) each resolve (`scarb metadata`) and build (`scarb build`), and the registry index entry of the version lists no `snforge_std` dependency; the check runs in CI on every publication |
| Size | 11 tasks (below), sequential by default (1 agent at a time in wave 1, `PLAN.md`); the pairs marked "can run with" have disjoint allowlists and may run together when the budget allows |

Tasks of L-M1. Every task owns the files of its allowlist exclusively; a file appears in one
allowlist only; the facade `board/map.cairo`, `lib.cairo`, `Scarb.toml`, `scripts/**`,
`README.md`, `CHANGELOG.md` and `docs/API_PARITY.md` belong to the orchestrator, who adds the
one-line forwarding methods of the facade after each task merges (`hexmap:src/map.cairo:1-4`).

| Task | Content | Allowlist (exclusive) | Runs after | Can run with |
|---|---|---|---|---|
| M1-T1 | Take-over: move the sources and tests, `takeover_tests`, `docs/GAS.md`, budgets unchanged; the file split of `hex` is not touched here. **Initial ownership exception**: M1-T1 moves `board/map.cairo` into place and touches nothing in it; from the merge of M1-T1 the file belongs to the orchestrator alone (audit pass 2, finding 19) | `crates/hexx/src/board/{map,direction,layout,geometry,asserter,bits,rng,printer}.cairo` (the move only), `crates/hexx/src/finders/{bfs,dial}.cairo`, `crates/hexx/src/generators/**`, `crates/hexx/src/tests/**`, `crates/hexx/tests/readme.cairo`, `crates/takeover_tests/**`, `docs/GAS.md` | — | — |
| M1-T2 | Mirror items of L-M1 except `line_to`: `hex.cairo` (`HexTrait`), `direction/edge_direction.cairo`, `conversions.cairo`, `orientation.cairo`, their `refgen` specs and golden tests | `crates/hexx/src/hex.cairo`, `crates/hexx/src/direction/edge_direction.cairo`, `crates/hexx/src/conversions.cairo`, `crates/hexx/src/orientation.cairo`, `tools/refgen/specs/{hex,direction,conversions}.toml`, `crates/hexx/tests/golden_{hex,direction,conversions}.cairo` | M1-T1 | M1-T4, M1-N9 |
| M1-T3 | N-7 and distance: `rotate`, `arc`, `Arc`, the `Into` conversions with `EdgeDirection`; `distance_between`, `chunk_of`, `to_hex`, `from_hex`, `index_to_hex`, `hex_to_index`; `neighbor_direction`, `new_odd`, the three renames | `crates/hexx/src/board/direction.cairo`, `crates/hexx/src/board/geometry.cairo`, `crates/hexx/src/board/layout.cairo` (both taken from M1-T1's ownership once M1-T1 is merged), `crates/hexx/src/tests/{test_direction,test_geometry,test_layout}.cairo` | **M1-T2** (it consumes `Hex`, `EdgeDirection` and the offset conversions; audit pass 2, finding 27) | M1-T4 |
| M1-T4 | N-3 and N-4: `board/tables.cairo` (the band tables), `board/assembly.cairo` (`Origin`, `origin` with its own Euclidean split, `local`, `assemble`, `window`, the odd-origin panic, the assembly bench with 4 chunks and two layers), `board/cut.cairo` | `crates/hexx/src/board/{tables,assembly,cut}.cairo`, `crates/hexx/src/tests/{test_assembly,test_cut,bench_assembly}.cairo` | M1-T1 (no mirror type and no `chunk_of` is used, finding 28) | M1-T2, M1-T3 |
| M1-T5 | N-6: `board/hexagon.cairo`, the `HEXAGONS` tables generated by `tools/refgen`, the table path and the loop path, the per-position variant in the benches | `crates/hexx/src/board/hexagon.cairo`, `tools/refgen/src/hexagon.rs`, `crates/hexx/src/tests/{test_hexagon,bench_hexagon}.cairo` | M1-T4 (uses `board/tables.cairo`) | M1-T6, M1-T7 |
| M1-T6 | N-5: `HexTrait::line_to` (added to `hex.cairo`, which this task owns once M1-T2 is merged), `board/line.cairo` with `LINES` and `LINE_SPANS`, `docs/deviations/line_ties.md`, the exhaustive off-chain comparison and the adversarial large-coordinate vectors | `crates/hexx/src/hex.cairo`, `crates/hexx/src/board/line.cairo`, `tools/refgen/src/line.rs`, `tools/refgen/specs/line.toml`, `crates/hexx/tests/golden_line.cairo`, `crates/hexx/src/tests/{test_line,bench_line}.cairo`, `docs/deviations/line_ties.md` | M1-T2, M1-T3 (`index_to_hex`, `neighbor_direction`, `edge_neighbors`) | M1-T5, M1-T7 |
| M1-T7 | N-2: `board/seams.cairo`, the four formulas of §6.3, the scalar oracle on global coordinates, every dimension class | `crates/hexx/src/board/seams.cairo`, `crates/hexx/src/tests/{test_seams,bench_seams}.cairo` | M1-T3 (`new_odd`) | M1-T5, M1-T6 |
| M1-T8 | N-1: `Caver::generate_with_margins`, `smooth`, the derived planes and masks of §6.2, the extended scalar automaton, the plane tests, the pinned streams | `crates/hexx/src/generators/caver.cairo` (taken from M1-T1's ownership), `crates/hexx/src/tests/{test_caver_margins,bench_caver_margins}.cairo` | M1-T3 (`new_odd`) | M1-T9 |
| M1-T9 | N-8: `Bfs::flood`, `finders/flood.cairo`, the `SERPENTINE_15X16` fixture, the cave and serpentine benches, the scalar oracles of the three selection functions, **and the tick bench**, which assembles the window with M1-T4's `window` | `crates/hexx/src/finders/bfs.cairo` (taken from M1-T1's ownership), `crates/hexx/src/finders/flood.cairo`, `crates/hexx/src/tests/{test_flood,bench_flood,bench_tick}.cairo` | M1-T3 (`neighbor_direction`, `edge_neighbors`) and **M1-T4** (`window`, for `bench_tick`; audit pass 2, finding 27) | M1-T8 |
| M1-N9 | N-9: `snforge_std` under `[dev-dependencies]` in `crates/hexx/Scarb.toml`; the two consumer packages of `tools/consumer_check/` and their CI job against the first release candidate; the cause of the 1.8.0 defect found and written down | `tools/consumer_check/**`, `.github/workflows/consumer_check.yml` (the manifest itself is the orchestrator's: this task proposes the line, the orchestrator applies it) | M1-T1 | any task |
| M1-R | Release 0.1.0: the facade entries of the tasks above, README, CHANGELOG, `API_PARITY.md`, publication, the consumer check green against `0.1.0` | orchestrator | all | — |

**Dependency graph of L-M1**, as edges `A → B` (B runs after A), for checking; it is acyclic
(every edge goes from a lower task number to a higher one, `N9` and `R` last):
`T1 → T2`, `T1 → T3`, `T2 → T3`, `T1 → T4`, `T4 → T5`, `T2 → T6`, `T3 → T6`, `T3 → T7`,
`T3 → T8`, `T3 → T9`, `T4 → T9`, `T1 → N9`, `T2 … T9, N9 → R`. **File ownership of L-M1**, one
owner per file at any time, with the transfers: `hex.cairo`: T2, then T6 (after T2's merge);
`board/layout.cairo`, `board/geometry.cairo`, `board/direction.cairo`: T1 (the move), then T3;
`generators/caver.cairo`: T1, then T8; `finders/bfs.cairo`: T1, then T9; `board/map.cairo`: T1
(the move), then the orchestrator; every other file: its single task above.

Two of these are **design tasks** as well as implementation tasks, because the plan states
their formulas but their correctness is only certain once the oracle passes: M1-T8 (the
planes and the divisibility masks of §6.2, oracle (1), (2) and (4)) and M1-T7 (the four seam
formulas of §6.3, the scalar oracle on global coordinates). Their briefs say so, and a formula
that the oracle refutes is corrected in the task, with the plan updated in the same pull
request.

### L-M2 — The mirror completed (release 0.2.0)

| | |
|---|---|
| Content | Every remaining port and counterpart of §4.4 marked L-M2: the rest of `Hex` (constants, constructors, arrays, operators, swizzles, rings, wedges, spirals, ranges, rotations, reflections, resolution, `way_to`, packing, euclidean), the rest of `EdgeDirection`, `VertexDirection`, `DirectionWay`, `HexBounds`, `shapes`, `HexSpanExt`, `GridEdge`, `GridVertex`, the doubled and hexmod conversions, `DoubledHexMode` |
| Depends on | L-M1 (0.1.0 released) |
| File split | The mirror follows `hexx`'s file split so that tasks own whole files: one trait per file, `HexTrait` in `hex.cairo` (`src/hex/mod.rs`), `HexRingsTrait` in `hex/rings.cairo`, `HexSwizzleTrait` in `hex/swizzle.cairo`, `HexEuclideanTrait` in `hex/euclidean.cairo`, `HexConvertTrait` in `hex/convert.cairo`, the operator impls in `hex/impls.cairo`, `HexSpanExt` in `hex/iter.cairo`, the conversions in `conversions.cairo` (§2.2). Cairo allows one `impl` block per trait, not one trait split across files, hence one trait per source file of `hexx` |
| Exit criterion | `API_PARITY.md`: every item scheduled for L-M2 in §4.4 is `ported` or `renamed`; the only `missing` items are those scheduled for L-M3 (`as_ivec2`, `as_ivec3`, the three `IVec` `From` impls, the four `algorithms` functions), listed as scheduled; golden tests from `refgen` for every ported item; every deviation documented and inventoried; benches for every non-trivial function; 0.2.0 published |
| Tasks, exclusive files, dependency edges | Every task below was checked against the upstream source for calls to items owned by another task (audit pass 3, finding 27; pass 4, finding 27); the items it uses from other tasks are listed with their owner, and every such owner precedes it. **M2-T0, the bootstrap**: the shared constructors, constants and helpers that the other tasks consume, all in `hex.cairo`: the constants `ORIGIN`, `ONE`, `NEG_ONE`, `X`, `NEG_X`, `Y`, `NEG_Y`, `INCR_*`, `DECR_*`, `DIAGONAL_COORDS`; `hex()`, `splat`, `new_cubic`, `from_array`, `to_array`, `to_cubic_array`, `const_neg`, `const_add`, `abs`, `min`, `max`, `dot`, `signum`; **`range_count`, `shift`** (`src/hex/mod.rs:1160-1171`, pure `u32` arithmetic), **`ring_count`, `wedge_count`** (`src/hex/rings.rs:540, 285`, pure arithmetic), **`mul_scalar`** (the counterpart of `Mul<i32> for Hex`, `src/hex/impls.rs:174-184`: two `i32` products), **`neighbor_coord`, `add_dir`, `neighbor`, `all_neighbors`** (`:633-666, 760`: they read `EdgeDirection` and `NEIGHBORS_COORDS`, both of L-M1). Uses L-M1 items only; after nothing. **M2-T1** `direction/vertex_direction.cairo`, `direction/way.cairo`, `direction/impls.cairo` and, in L-M2, `direction/edge_direction.cairo`: `VertexDirection` (its `into_hex` reads `DIAGONAL_COORDS`: T0, `vertex_direction.rs:239-240`), `DirectionWay` and `Way`, `EdgeDirection::{vertex_cw, vertex_ccw}` and `VertexDirection::{direction_cw, direction_ccw, edge_cw, edge_ccw, edge_directions}`, and every direction impl of `src/direction/impls.rs` (`Neg`, the rotation operators, `Debug` for both types, and `Mul<i32>` for both types, `:53-67`, which calls `Hex::mul_scalar`: T0). Uses T0; **after T0**. **M2-T3** `hex/impls.cairo`, `hex/swizzle.cairo`, `hex/euclidean.cairo`, `hex/convert.cairo`, `conversions.cairo`: the operator impls of `src/hex/impls.rs` (`Add`/`Sub` of `Hex` and of `i32`: `const_add` T0, `const_sub` L-M1; **`Add<VertexDirection>`, `Sub<VertexDirection>`, `:46-53, 125-132`, take T1's type and are implemented as `self.const_add(rhs.into_hex())` and `self.const_sub(rhs.into_hex())`, not through `add_diag_dir` of T2**; `Sum`, `Product`: `ZERO`, `ONE` T0; `Mul<i32>` forwards to `mul_scalar` T0; `div_scalar`, `rem_scalar`: `length` L-M1 and their own exact rational; `Neg`: `const_neg` T0; the bitwise and shift operators: per component), the swizzles (`splat` T0, `z` L-M1), `squared_euclidean_length`, `euclidean_length`, `squared_euclidean_distance_to`, `euclidean_distance_to` (`const_sub` L-M1), `from_u64`, `as_u64`, the tuple and array conversions (`from_array` T0), the doubled conversions (arithmetic), **`to_hexmod_coordinates` and `from_hexmod_coordinates` (`src/conversions.rs:92-120`: `range_count` and `shift`, T0)**. **`circular_range_squared` is not in T3**: upstream `circular_range` calls `range` (`euclidean.rs:115`), owned by T2, so it lives in `hex/rings.cairo` and belongs to T4. Uses T0, T1; **after T0 and T1**. **M2-T2** `hex.cairo` (owned by T0 first, then by T2): the remaining `HexTrait` items: `diagonal_neighbor_coord`, `add_diag_dir`, `diagonal_neighbor`, `all_diagonals` (`VertexDirection` T1), `neighbor_direction` (`neighbor` T0, `EdgeDirection::iter` L-M1), `main_diagonal_to`, `diagonal_way_to`, `main_direction_to`, `way_to` (`DirectionWay`, `VertexDirection` T1), the rotations and reflections (`const_neg` T0, `const_sub` L-M1), `rectiline_to` (`:936-962`: `main_diagonal_to` own, `VertexDirection::edge_directions` and the direction `mul_scalar` T1, `distance_to` L-M1, `add_dir` T0), `range`, `xrange` (`range_count` T0), `to_lower_res`, `to_higher_res`, `to_local`, `wrap_in_range` (`range_count`, `shift`, `to_cubic_array` T0), `Debug`. It calls the named methods, never an operator impl of T3, so **the edge `T3 → T2` of the previous version is dropped** (it existed for `mul_scalar`, now in T0). Uses T0, T1; **after T0 and T1**. **M2-T4** `hex/rings.cairo` (rings, ring edges, wedges, spirals, the cached forms as arrays, and `circular_range_squared`): `custom_ring` (`NEIGHBORS_COORDS`, `EdgeDirection::index` L-M1, the direction `mul_scalar` T1, `const_add` and `ring_count` T0), `__vertex_dir_to_edge_dir` (`direction_cw`, `direction_ccw` T1, the `EdgeDirection` rotations L-M1), `custom_wedge_to`, `corner_wedge_to` (`unsigned_distance_to` L-M1, `diagonal_way_to`, `way_to` T2), `wedge_count` T0, `circular_range_squared` (`range` T2, `squared_euclidean_distance_to` T3). Uses T0, T1, T2, T3; **after T1, T2 and T3**. **M2-T5** `bounds.cairo`, `hex/iter.cairo`: `from_min_max` (`div_scalar` T3, `unsigned_distance_to` L-M1), `positive_radius` (`splat` T0), `hex_count` (`range_count` T0), `all_coords` (`range` T2), `wrap_local`, `wrap` (`wrap_in_range` T2), `corners` (the direction `mul_scalar` T1, `const_add` T0), the bounds of a span (`to_cubic_array` T0 in place of `as_ivec3`, which is L-M3), `HexSpanExt::average` (`div_scalar` T3). Uses T0, T1, T2, T3; **after T1, T2 and T3**. **M2-T6** `shapes.cairo`: `parallelogram` (`x`, `y`, `new` L-M1), `triangle` (`wedge_count` T0), `hexagon` (`range` T2), `rombus` (`const_add` T0), the two rectangles (`new`). Uses T0, T2; **after T2**. **M2-T7** `hex/grid/edge.cairo`, `hex/grid/vertex.cairo`: `GridEdge` (`add_dir` T0; `EdgeDirection::{const_neg, clockwise, counter_clockwise, rotate_cw, rotate_ccw, ALL_DIRECTIONS}` L-M1; `vertex_cw`, `vertex_ccw` T1; `ZERO` L-M1), `GridVertex` (`VertexDirection::{direction_cw, direction_ccw, edge_cw, edge_ccw, rotate_cw, rotate_ccw, const_neg, clockwise, counter_clockwise, ALL_DIRECTIONS}` T1; `add_dir` T0 for `origin + direction`). Uses T0, T1; **after T1**. Each task also owns `tools/refgen/specs/<file>.toml`, `crates/hexx/tests/golden_<file>.cairo` and its bench file. **Edges** (`A → B`, B after A), the direct prerequisites of each task: `T0 → T1`, `T0 → T2`, `T1 → T2`, `T0 → T3`, `T1 → T3`, `T1 → T4`, `T2 → T4`, `T3 → T4`, `T1 → T5`, `T2 → T5`, `T3 → T5`, `T2 → T6`, `T1 → T7` (`T0` precedes every task through `T1` or `T2`; the transitive edges `T0 → T4 … T0 → T7` are implied). **Acyclic**: every edge goes from a lower task number to a higher one, so `T0, T1, T2, T3, T4, T5, T6, T7` is a topological order; **no task uses an item of a task that does not precede it** (checked item by item above). **Ownership**: `hex.cairo`: T0, then T2; `direction/edge_direction.cairo`: M1-T2 in L-M1, then M2-T1; every other file: one task. Parallel groups: `T0`; `T1`; `T2` with `T3` (disjoint files, neither uses the other); then `T4`, `T5`, `T6`, `T7` together |

### L-M3 — Algorithms, interop, closure of the table (release 0.3.0)

| | |
|---|---|
| Content | `algorithms` counterparts on boards (`range_fov`, `directional_fov`, `field_of_movement`, `a_star`, §4.4); the companion package `hexx_glam` (`Into` between `Hex` and `IVec2`/`IVec3` of `glam-cairo`, published separately, like `nalgebra_glam`); the `uint252` dependency if the owner decides on `u252`-typed bitmaps (§12); whatever new need the game files in `docs/needs/hexmap.md` during phases 1 and 2 |
| Depends on | L-M2 |
| Exit criterion | No `missing` item in any kept or adapted module (the items scheduled for L-M3 in §4.4 `ported` or `renamed`); every exclusion has its reason in the generated table; `hexx_glam` published; 0.3.0 published |
| Size | 4 tasks with exclusive files: `algorithms/fov.cairo`; `algorithms/{field_of_movement,pathfinding}.cairo`; `crates/hexx_glam/**`; the game's new needs (one task and one new file per need) |

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
| `0.1.0-rc.1` | The take-over alone (M1-T1) with N-9 (M1-N9), results identical to 1.8.0 | SPK-7, which runs inside the game's workspace on Cairo 2.19 (ADR-0007). Meanwhile the game, on Scarb 2.19.4 and snforge 0.61 since ADR-0007, can build `origami_hexmap` 1.8.0 only while its own `snforge_std` stays within `0.61.x`, because the published 1.8.0 resolves `snforge_std` as a regular dependency (N-9); `0.1.0-rc.1` removes that constraint |
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
(a packed storage struct, a `StorePacking`, or the owner's decision to type the bitmaps), as a MINOR
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
| 1. Pre-releases | `0.1.0-rc.1` published | SPK-7 (in the game's workspace, Cairo 2.19, ADR-0007) consumes it, or 1.8.0 while the game's `snforge_std` stays within `0.61.x`: both give the same results. The game's `docs/CAIRO.md` §4 still names `origami_hexmap` | Game's orchestrator |
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
| R-1 | **The window is assembled at each tick** (D-120): its cost is paid at every action, and this plan's target range ([98,762, 123,453] for 4 chunks and two layers, §6.4, §7) is well above the ADR's "about 40k" | ADR-0006 § Cost; §6.4 | SPK-7 measures the assembly with and without a stored window, as the ADR says; the plan's function is the same in both cases. If the tick does not fit, the ADR's fallback is sight 5 on 13 × 14, which this plan does not design (§6.4b): its width differs from the chunk's, so the one-dimensional shift no longer applies | SPK-7 measures; owner decides |
| R-18 | **The tick estimate roughly doubled between the first draft of this plan (740k) and the audited plan (a range `[1,337,678, 1,672,098]`, §7), and may move again**: each of the three audit passes found operations the sums had omitted, and the sums are those of design sketches that LIB-05 may replace | §7, §6.4, §6.9; the three audit passes | Only measurement settles it: LIB-05 measures every function on the fixtures and the domain-wide worst cases of §6 and reports any measurement above its range before a budget is set; the game's SPK-7 measures the tick on the game's own contracts. The game's budget for the tick (its risk R-2) should be planned on the upper bound of the range, not on the lower | LIB-05 and SPK-7 measure; the owner and the game decide on the figures |
| R-2 | **Closed.** The `u252` type was published on 2026-09-28 as the package `uint252` 0.1.0 (§3.4); L-M1 does not depend on it anyway (§9.3) | L-G1, question 3 | Nothing to do | — |
| R-3 | scarbs.xyz may refuse pre-release identifiers | Not verified | Fallback `0.0.N` (§9.1) | LIB-04 verifies |
| R-4 | The name `hexx` may be taken before publication | Free on 2026-09-28 | LIB-04 publishes an empty `0.0.1` at repository setup to reserve it, if the owner agrees | Owner |
| R-5 | The targets of §7 are exceeded by measurement, in particular the tick ([1,337,678, 1,672,098] on the cave benchmark, §6.9), the window ([98,762, 123,453] per tick) and N-1 (+63 % over `generate` at order 3) | Every non-measured figure is a range whose lower bound is the exact sum of a sketch's operations; the tick budget is the game's R-2 (`grimworld:PLAN.md`) | Every target is replaced by a measurement in LIB-05; a measurement above the upper bound of its range is reported to the orchestrator before the budget is set (§7); the fallback of ADR-0006 (sight 5 on 13 × 14, not designed here, §6.4b) stays the game's | LIB-05 reports; owner decides |
| R-6 | The row-parity trap: a chunk-level function (N-1, N-2) called with the wrong `odd` flag, or a window built on an odd origin, runs on a different hex grid than the map | LIB-02 §5.4; ADR-0006 §4; `window-parity-check.md` §1 | The flag is explicit on the two chunk-level functions and nowhere else; `assembly::origin` cannot produce an odd origin and `assemble` panics on one (`'Assembly: odd origin'`); the seam and generation oracles run on signed global coordinates with the true global parity | LIB-05 |
| R-14 | The window's origin can lie before the location's first tile (adventurer within 7 columns or 8 rows of the location's edge) | §6.4; audit pass 2, finding 28 | `origin` takes the location's `u8` coordinates and returns a Euclidean chunk index in `−1..=16` with a positive offset (`origin(0, 0) = (−1, −1, 8, 7)`, regression case R-N3-1); a chunk outside the location is passed as 0 (wall), which the location's closed border already implies | LIB-05 |
| R-15 | **The flood has no small bound**: on a winding board it reaches up to 182 layers on 15 × 16 (3.57M), and the per-walker scans grow with the distance (§6.9) | Audit finding 9; `GAS.md:182` (a 90-step path on the serpentine fixture) | The library exposes `depth` and benchmarks both a cave and a serpentine; whether the game truncates, and what a truncated walker does, is Q-5 | Game decides Q-5; SPK-7 measures |
| R-16 | The formulas of N-1 (planes and divisibility masks) and N-2 (four seam formulas) are derived here and checked by reasoning only; a wrong term would give wrong boards | §6.2, §6.3; audit findings 1, 2, 4 | M1-T8 and M1-T7 are design tasks with their oracles (§8); a refuted formula is corrected in the task and the plan | LIB-05 |
| R-7 | The tie rule at column 0 (the preferred tile can be off the board) | §6.6 (inferred), audit finding 7 | `line` returns `None` when a tile of the line lies outside the board and `line_of_sight` treats `None` as blocked (D-27); no clipping; the property `line(a, b) == line(b, a)` is tested on every pair, `None` included | LIB-05 |
| R-8 | `hexx`'s `f32` ties in `Div<i32>` and `to_lower_res` cannot be reproduced bit for bit where `f32` error decides | LIB-02 §4; §4.4 | Exact rational counterparts; the vectors list the inputs where `hexx` deviates from its own rule; they are deviations, not misses | Owner accepts at L-G2 |
| R-9 | Toolchain drift: every measured figure is at scarb 2.19.4 / snforge 0.61.0; the game is on the same Cairo 2.19 since ADR-0007, its exact pins set by SPK-5b | `GAS.md:140`; ADR-0007 § Decision | LIB-04 pins scarb 2.19.4 and snforge 0.61 in `.tool-versions`; a bump is a dedicated pull request that regenerates every snapshot (house rule); the game's pins and the library's are reconciled when SPK-5b reports | LIB-04; SPK-5b |
| R-17 | The published package carries `snforge_std` as a regular dependency although the manifest declares a dev-dependency, as happened to 1.8.0 (§2.1, N-9) | `grimworld:docs/needs/hexmap.md` § "N-9 in detail" against `hexmap:Scarb.toml:14-15` | The consumer check of M1-N9 runs against the published artefact of every release candidate and release, not against the manifest; LIB-04 records the cause | M1-N9; LIB-04 |
| R-10 | The local `extern fn bitwise` declaration (`hexmap:src/helpers/bits.cairo:54`) is a private corelib libfunc; a compiler version could refuse it | Allowed by the owner for `origami_hexmap` | Kept; the fallback is the corelib operators at +30 % per generation (`GAS.md:654`) | Owner, if a compiler refuses it |
| R-11 | Class size of the game's contract with the tables | §7: 634 new entries (`254 + 254 + 14 + 14 + 98`), ~705 CASM felts (estimate: `560 + 35 + 110`) for L-M1's new tables, on top of the ~2,200 felts of the taken-over tables the game already pays | A `consumer` fixture and `bytecode_size.py check` as in `glam-cairo`, from LIB-04; the compiled size is what counts, the entry counts are declarations | LIB-04 |
| R-12 | Two direction types (§3.2) may confuse consumers | — | One table in the README (§3.2), conversions in both directions, the compass note on `EdgeDirection` | Owner may reverse (§12) |
| R-13 | The mirror's `Span<Hex>` outputs allocate per element; a consumer that calls them in a hot path pays for it | LIB-02 §4 | Documented on the type: the bitmap forms of `board` are the on-chain tools; the mirror's spans are for parity, tests and the client | — |
| Q-1 | Does the game need `hexagon(8)` (earshot) on the window, where the adventurer at `(7, 7)` or `(7, 8)` is 7 tiles from the ring? | `grimworld:docs/design/04-combat.md` § Ranges | `hexagon` clips at the board; earshot beyond the window is a distance test on global coordinates (`distance_between`), which the game can do without a board. To confirm with the game | Game |
| Q-3 | **Closed by ADR-0007**: the game and the library share Cairo 2.19 (Scarb 2.19.4, snforge 0.61); LIB-04 pins `origami_hexmap`'s versions, and the game's exact pins (SPK-5b) are reconciled in one dedicated bump if they differ | R-9 | Nothing to decide | — |
| Q-4 | Should the release candidates be consumed by SPK-7, or should SPK-7 stay on 1.8.0 and switch at 0.1.0? | `grimworld:PLAN.md` R-18 | Recommendation: switch at `0.1.0-rc.1` (identical results, no risk) so that the extensions are exercised as they land | Game's orchestrator |
| Q-5 | **Does the tick truncate the flood, and what does a walker beyond the truncation do?** The library computes up to `depth` layers and gives no move to a walker whose neighbours are in no computed layer (§6.9, D-25) | Audit finding 9: a valid route of 45 layers on a 15 × 16 serpentine; the true bound is 182 layers | Two answers, each with its cost (the models of §6.9 and §7). (a) **Full flooding** (`depth = 182` on 15 × 16): the flood computes **every reachable layer** (`depth()` is the largest defined distance, at most 182); it costs `55,000 + 19,300 × depth()`: 537,500 on the cave at the pinned `depth() = 25`, 923,500 on `SERPENTINE_15X16`, at most 3,567,600 (a bound, not a fixture); a walker whose inferred distance is `s` costs `17,747 + 4,662 × s` to scan. Full flooding does not mean that every walker moves: a walker whose candidates are all blocked (R-N8-6) or that stands behind another walker (R-N8-4) still gets `None`. (b) **Truncation at `D`** (for example 15 or 30): the flood costs at most `55,000 + 19,300 × D`, and a scan at most `17,747 + 4,662 × (D + 1)` (the layers `0..=D` permit `D + 1` scans when no neighbour is found), but a walker beyond `D` gets `None` and the game must say what it does (waits, walks by `hex_distance`, is frozen); that is a gameplay rule and a numeric result of the tick, frozen at 0.1.0. The plan decides nothing here | Game (project manager), before 0.1.0 |

The former Q-2 (goblins on the ring as targets) is closed by D-120: a tile of the ring is 7
tiles or more from the adventurer, never in sight and never in ranged range (ADR-0006 §4).

None of the decisions of L-G1 or D-120 leads to a problem this plan cannot honour; no
reopening is asked, and no point of L-G1 is open any more.

## 12. Recommendation for gate L-G2

**What the owner is asked to accept.** A Cairo package named `hexx`, in this repository, in
which:

1. the **mirror** follows `hexx` 0.25.0 name for name on integer coordinates `Hex { x: i32,
   y: i32 }` and `EdgeDirection`; every departure from `hexx` belongs to a documented
   category of §1.1 and §4.4 and is listed in a generated table checked in CI: floating-point,
   host and allocator items are absent; iterators become spans and callbacks become bitmaps;
   `f32` items with an exact rational meaning get exact counterparts (`div_scalar`,
   `to_lower_res`); an overflow panics where Rust wraps (§3.1); `line_to` resolves exact ties
   by the game's rule and is the exact integer line where `hexx` interpolates in `f32`, so
   that it differs from `hexx` at ties and wherever `f32` rounding decides, with every
   difference listed by an off-chain comparison against `hexx` (§6.6);
2. the **extension** is the engine of `origami_hexmap` 1.8.0 moved here under `board`,
   `finders` and `generators` with every result and every gas budget unchanged, proved by a
   test package that compares it with the registry package, plus the ten functions of L-M1
   (§6), each specified by a **normative contract** (domain, semantics over a scalar oracle,
   tie-breaks, worst case, regression cases) with a **design sketch** that LIB-05 proves
   against the oracle before keeping it and may replace (§1.4), among them the assembly of
   the 15 × 16 window of D-120 from 2 or 4 chunks at each tick, without a loop, refusing an
   odd origin; **the gas figures of §7 are ranges, not measurements: the tick roughly doubled
   between the first draft (740k) and the audited plan (`[1,337,678, 1,672,098]`) and may
   move again; only LIB-05 and SPK-7 settle it** (§7, R-18). **No figure of this plan is a
   budget**: budgets are set from measurements in LIB-05 by the game's `docs/CAIRO.md` §2,
   and the tick range is conditional on the inputs listed at the head of §7 (the unit costs
   measured on 1.8.0 with Scarb 2.19.4 and snforge 0.61.0, the sketches of §6.4 and §6.9 as
   the algorithms, the pinned cave depth of 25 layers and eight interior walkers scanning 15
   layers each, the range rule `U = ceil(1.25 × L)`);
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
| D-5 | L-M1 carries only the mirror items its extensions depend on (`Hex` core, `line_to`, the offset conversions and enums, `EdgeDirection` and its rotations), each traced in §8; the rest of the mirror is L-M2 | Either narrower (L-M1 = extensions only, the line defined on the board alone and the parity table starting at 0.2.0) or wider (the first version's foundation: constructors, constants, `neighbor`, the `Hex` rotations, operators, in 0.1.0); the owner chooses, since L-G1 says "L-M1 unchanged" |
| D-6 | `Hex::line_to` carries the game's tie rule as a documented deviation (§6.6) | A separately named `line_between`, leaving `line_to` unported (it cannot be reproduced without an `f32` model) |
| D-7 | Geometric bitmaps named `hexagon` and `hexagon_ring` on the facade (§6.7) | `range_geometric` / `ring_geometric` |
| D-8 | Canonical hexagon tables for radius ≤ 7 on width 15, clipped before the shift with 16-row bands; the row loop elsewhere (§6.7, a design sketch) | Per-position table for radius 6 (~2k instead of ~32k per query, +280 felts of class) |
| D-9 | Line table for distance ≤ 6 on width 15, with the extent test; the loop beyond and on other widths (§6.6, a design sketch) | Loop only, no table: `8,388 + 6,835 × N` per query, 138,253 for the 19-step interior fixture against 7,399 on the table path (§7) |
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
| D-20 | `assemble` takes the chunk offsets `(ox, oy)` and the chunk-row parity; the helper `origin(x, y)` on the location's `u8` coordinates computes them by a Euclidean split (chunk index `−1..=16`, offset `0..15`), independently of the unsigned `chunk_of`, and can never produce an odd origin (§6.4) | `assemble` on global coordinates directly, with the two `DivRem` inside the per-tick call |
| D-21 | The rectangle masks of the assembly are the product of band tables (98 felts: 16-entry column and 15-row bands, 17-entry 16-row bands, shared with `hexagon`) (§6.4) | One 225-entry table per chunk role (900 felts), or a field division per call |

**Behavioural decisions that become numeric results at 0.1.0**, each with who accepts it:

| # | Decision (section) | Alternative | Game-mandated or library policy | Decides |
|---|---|---|---|---|
| D-22 | The ring tiles of a chunk that face no generated neighbour are drawn from the seed with the interior and then frozen (§6.2) | Left as wall until a neighbour is generated (the chunk's free sides closed, opened later by seams); or evolved with an assumed wall beyond the chunk | Library policy, derived from ADR-0006 § Joining chunks ("draws its other edges") | Game confirms, owner at L-G2 |
| D-23 | `cut` clears the ring as well as the tiles outside the mask (§6.5) | Keep the ring bits that the mask allows: a valid board, since the finders accept open edge tiles as endpoints (`README.md:63-66`); the consumer would then impose the window's ring itself | The chosen policy of `cut`, not a requirement of the finders (audit pass 2, finding 29) | Library; game confirms its masks never open the ring |
| D-24 | `line_of_sight` never tests the endpoints: only the tiles strictly between are tested against walls (§6.6) | Test `to` as well (a target standing on a wall tile is never visible) | **Proposed library policy, to be confirmed by the game**: the design sentence "walls block, actors do not" (`grimworld:docs/design/04-combat.md:40-41`) speaks of the tiles between and of the occupancy layer; it does not decide what a wall at an endpoint means (audit pass 2, finding 29) | Game, before 0.1.0 |
| D-25 | The flood is computed to `depth` layers and gives no move to a walker beyond them; the library does not choose `depth` (§6.9, Q-5) | The library floods to exhaustion always (no `depth`), at up to 3.57M on a serpentine | Game question | Game, before 0.1.0 |
| D-26 | `FloodTrait::distance` of a tile that is not in any layer (an obstacle, a walker) is the lowest layer of a neighbour plus one (§6.9) | `None` for every tile outside the layers | Library policy (it is what the walker's own distance means under the frozen-occupancy rule) | Library; game confirms |
| D-27 | A line that leaves the board is `None`, and `None` blocks sight; nothing is clipped (§6.6) | Clip the line to the board and test what remains (reports clear sight for the tied midpoint of `(0, 0) → (0, 2)` on a 7 × 7) | Library policy, forced by the game's tie rule at column 0 | Library; game confirms |
| D-28 | `smooth` holds the tiles of `held` and the whole ring; its domain is that of `generate_with_margins` (§6.2) | Hold `held` only, letting ring tiles evolve against an assumed wall outside | Library policy | Library |
| D-29 | `distance_between` returns `u16` and computes on `u16`; `neighbor_direction` validates adjacency through coordinates; `rotate` reduces its offset first (§6.1, §6.8) | A bounded `u8` domain for coordinates (below 128 per side), documented and asserted | Library policy | Library |
| D-30 | `Caver::generate_with_margins` and `smooth` refuse boards with `W·(H + 1) + 1 > 251` (`'Caver: dimensions too large'`), so 17 × 14 is refused while every chunk of 15 × 15 passes (§6.2) | Mask the top rows before the up-shifts at the cost of two more ANDs per generation, to accept every board of the engine | Library policy | Library; owner if a larger chunk is ever wanted |
| D-31 | Compiler target Cairo 2.19 (Scarb 2.19.4, snforge 0.61), `BoundedInt` kept, one code base, no floor at Cairo 2.13, no separate class; `snforge_std` a dev-dependency verified on the published package; no Dojo dependency, model or world anywhere (§0, §2.1, §8 N-9) | A floor at Cairo 2.13 with `BoundedInt` replaced, for a consumer that is not on 2.19: none exists since ADR-0007 | Follows the owner's D-123 | Owner at L-G2 |
| D-32 | The layers of a flood hold interior tiles only, except layer 0 which is the source even when the source is an open edge tile; an open edge tile other than the source is never in a layer and never a step; the source itself is a step for a walker adjacent to it (R-N8-7, §6.9) | Include the open edge tiles reachable in one step as terminal members of their layer, as `reachable` and `tiles_within_range` do (`README.md:63-66`), so that a walker could step onto an entrance | Library policy: the walkers of the game stand inside the window whose ring is imposed as wall (ADR-0006 §4), and a layer must stay expandable by the dilation | Library; game confirms |

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
| L-G1 consequences: milestone L-M1 unchanged | §8: the extensions N-1 to N-8, distance and neighbours, plus only the mirror items they depend on, each traced; the width of that mirror set is D-5 for the owner |
| L-G1 consequences: decommissioning steps and condition in the release plan | §10 |
| Point 1: margins inside the chunk, 13 × 13 interior evolves | §6.2 |
| Point 2: a parity flag in the layout; chunks stay 15 × 15 | §6.2 (`LayoutTrait::new_odd`), §3.3 (a parameter, not a field), §6.3 |
| Point 3: the library's axis convention is kept (`+x` West, odd-r); the client mirrors | §3.3, §3.5 (the negation of `x` in the conversion) |
| Point 4, decided by D-120 (owner, 2026-09-28): the window follows the adventurer, is 15 × 16, is recomputed at each tick and not stored; chunks stay 15 × 15; the origin on an even global row is an explicit constraint; the adventurer is on local `(7, 7)` or `(7, 8)`; the parity flag serves N-1 and N-2 only; the fallback is sight 5 on 13 × 14 | §6.4 (assembly, the refusal of an odd origin, the worst case at each tick), §6.4b (the fallback, not designed), §6.6 and §6.7 (local position as input), §6.9 and §7 (figures on 15 × 16), §3.3 and §5.3 (the flag never reaches the finders), §11 R-1 and R-6 |
| Point 5: one flood per tick on frozen occupancy; current occupancy filters; id order; fallback to the same layer; frozen at the first release | §6.9, §9.2; the depth of the flood is the game's open question Q-5 (§11) and D-25 (§12) |
| Point 6: the game's tie rule; a documented deviation from `line_to`, excluded from the table at ties | §6.6, §4.3 (the tie list), §4.4 (`line_to` row) |
| Point 7: `hexx`'s names and semantics kept in the mirror; the game's arcs written with directions | §3.2, §6.8, §2.4 (the clash table) |
| N-9, reduced (`grimworld:docs/needs/hexmap.md` row N-9 and § "N-9 in detail"): `snforge_std` as a dev-dependency so that the library resolves next to any test setup of its consumer; part of L-M1 | §2.1 (the manifest, the defect of the published 1.8.0), §8 (L-M1 content, exit (8), task M1-N9), §11 R-17 |
| ADR-0007, D-123 (owner, 2026-09-28): the game is a set of plain Starknet contracts on Cairo 2.19, without Dojo; the compiler part of N-9 is void | §0 (compiler target: Cairo 2.19, `BoundedInt` kept, no floor, no separate class), §2.1 (no Dojo dependency; description and keywords), §5.5, §9.1 and §10 (what the game does meanwhile), §11 R-9, Q-3 closed, §12 D-31 |
| COMMON.md §5: parity table generated and checked in CI; deviations documented; numeric results are API; what is taken over keeps its results | §4.2, §9.2, §5.4 |
| `grimworld:docs/CAIRO.md`: test-driven, gas as a test result, execution cost first, arithmetic then bitwise then loops, tables, oracles, determinism (lowest tile index) | §6 (each entry), §7, §6.9 |

## 14. Open points after the audit

Added by the orchestrator (`[Fable 5.1]`, 2026-09-28), not by the author of the plan. The plan
went through five audit passes by `[GPT-6-Astra]` and four fix loops. By decision of the
project manager (`docs/decisions/` of this repository, LIB-03 fix loops), no further loop is
run: the findings open after pass 5 are listed here and **carried into the briefs** of the
tasks they concern. Where this section and the body disagree, this section wins.

| # | Severity | Where | What is wrong | What holds instead | Carried into |
|---|---|---|---|---|---|
| 43 | major | §8, L-M2, task M2-T3 | The task's description includes the bit and shift operators on `Hex` and `euclidean_length`, `euclidean_distance_to`, which §4.4 and D-13 exclude | **§4.4 and D-13 hold**: those items are excluded. M2-T3 keeps the squared Euclidean methods and the included operators and counterparts only | The brief of M2-T3 (LIB-06) |
| 44 | minor | §6.4, §7 | The construction of a `HexMap` is charged 300 inside `window` and 400 in its own row | With 400 everywhere: `window` 98,862, tick range `[1,337,778, 1,672,223]`. The difference is below what a measurement will move | LIB-05 measures |
| 30 | minor | §12, D-9 | The two costs compared are for different workloads (a 19-step line by the loop, a line of distance ≤ 6 by the table) | At distance 6: 49,398 by the loop against 7,399 by the table (targets, not measurements) | The brief of N-5 (LIB-05) |
| 39 | minor | §6.9 | The text suggests that a board can attain the cardinality bounds of 182 and 187 flood layers | They are analytic bounds, not attainable: on a fully open interior the deepest flood is 20 layers on 15 × 16 and 22 on 19 × 13 (auditor's exhaustive check). The executable worst cases are the fixtures of §6.9 | The brief of N-8 (LIB-05) |
| D-23 | decision reversed by the game | §6.5 (N-4), §12 D-23, regression cases R-N4-1 to R-N4-3 | The plan's `cut` clears the ring as well as the tiles outside the mask | **For the game, `cut` keeps the ring tiles that are inside the mask: `cut(grid, mask) = grid & mask`** (project manager, 2026-09-28, `bal7hazar/grimworld` `docs/needs/hexmap.md` § *Answers to the questions of LIB-03*). The ring of a chunk is a seam that holds the openings to its neighbours, and the game opens edges before it cuts by the outline. The window's ring is imposed by the assembly, not by `cut`. A variant that clears the ring, if kept, has another name. R-N4-1 to R-N4-3 are rewritten for `grid & mask` in the task | The brief of N-4 (LIB-05, M1-T4) |
| R-4 | risk closed by the owner | §11, R-4 | The plan proposes that LIB-04 publishes an empty `0.0.1` to reserve the name `hexx` | **Declined by the owner on 2026-09-28: no empty `hexx` 0.0.1 is published.** The first publication of `hexx` is 0.1.0, release candidates included, and each publication needs the owner's go through the project manager. The risk that the name is taken before then is accepted | LIB-04 (nothing is published), M1-R |
| D-134 (N-1) | input of the game | §6.2 (N-1), §6.3 (N-2) | The plan lets the generator draw or copy every tile of the ring, corners included | **The four corner tiles of a chunk are always wall; openings are on the edges, never on a corner** (game, 2026-09-28, D-134, from its spike SPK-7; `docs/needs/hexmap.md` § *Chunk borders*). A regression case asserts it on generated chunks and on the openings of a seam | The briefs of N-1 (M1-T8) and N-2 (M1-T7) |
| D-134 (N-3) | input of the game | §6.4 (N-3) | The plan passes a chunk outside the location as the value 0 | **A chunk the window overlaps may be void** (beyond the edge of a location, or outside a zone's outline): the assembly takes a flag or an absent chunk for it and assembles wall **without a read**; **the window is never clamped**. A regression case covers a window with 1, 2 and 3 void chunks | The brief of N-3 (M1-T4a) |
| D-143 | owner's rule on the organisation of Cairo code | §6 (every extension), §2.2 | Some signatures of §6 are written as free functions of a module (`distance_between`, `chunk_of`, `origin`, `local`, `assemble`, `window`, `cut`, `line`, `line_of_sight`, `approach`, `hexagon`, `hexagon_ring`, `sides`, `openings`…) | **Every function is scoped in a trait and its impl, with a short name** (owner, 2026-09-29, D-143; game's `docs/CAIRO.md` §7 and §8): for example `AssemblyTrait::{origin, local, assemble, window}`, `LineTrait::{line, line_of_sight, approach}`, `SeamTrait::{sides, openings}`, facade methods on `HexMapTrait` where the plan puts them on the facade. A free function needs a written reason. Names and contracts of §6 are otherwise unchanged. The mirror is already methods on types | Every brief of LIB-05 from M1-T1c on; the organisation lens is part of every audit |
| Accepted figures | measurements above their range, accepted by the orchestrator | §7 | The ranges of the mirror assumed about 300 per `i32` operation | **Measured and accepted, 2026-09-30 (M1-T2)**: `Hex::length` 7,257, `ulength` 9,579, `distance_to` 8,722, `unsigned_distance_to` 11,043, `to_offset_coordinates` and `from_offset_coordinates` 7,183, `EdgeDirection::const_neg` 1,785, `counter_clockwise` 1,868. The mirror is not on the hot path of the tick. Earlier: `FloodTrait::depth` 670 (M1-T9a). A measurement accepted above its range is written here, so that audits and reviews read it | — |
| Accepted figures (M1-T3) | measurements above their range, accepted by the orchestrator | §7, §6.1, §3.5 | The sketches of §6.1 and §3.5 charge 300 per `u8`, `u16` or `i32` operation and 100 per `try_into`; the measured operations cost several hundred each | **Measured and accepted, 2026-09-30 (M1-T3)**, per call, `twice − once` of `bench_assembly`'s method (the `assert!` comparison of the second call included): `Geometry::chunk_of` 3,020 ([2,196, 2,745]), `to_hex` 2,750 ([1,998, 2,498]), `from_hex` 3,840 ([2,198, 2,748]), `hex_to_index` 5,370 ([2,998, 3,748], inherits `from_hex`), `LayoutTrait::neighbor_direction` 9,640 ([4,294, 5,368]; the two bounds checks against `H` the contract requires are not in the sketch). One optimisation attempt each for the last three: the `bounded_int` `from_hex` measured 3,990 and the single `DivRem` by `2W` of `neighbor_direction` 12,020, both dropped. `distance_between` on `bounded_int` measures **4,220**, down from 7,220 on `u16`, and is now below its range [5,196, 6,495] (engine's `Geometry::distance` 5,040 on the same method). In range or below: `Direction::rotate` 2,588, `arc` 1,246, both `Into` between `Direction` and `EdgeDirection` 467, `index_to_hex` 3,760 | — |
| Accepted figures (M1-T6) | measurements above their range, accepted by the orchestrator | §7, §6.6 | The table path's sum (7,399) counts neither the check that both positions lie in the board nor the call; `edge_neighbors` and the mirror's accumulators cost several times their sketch | **Measured and accepted, 2026-10-01 (M1-T6)**, per call, `twice − once` of `bench_assembly`'s method: `LineTrait::line`, table path (width 15, distance 6, ties at steps 1, 3, 5, from `(7, 7)`) **11,150** ([7,399, 9,249]; the lookup 7,110 with `Bits::pow` 1,870, the bounds check `'Asserter: position not inside'` 1,940, the call taking a `HexMap` by value about 2,100; no optimisation attempt, the orchestrator's decision); `approach`, ring target at distance 6, **86,046** ([62,827, 78,534]; six `LayoutTrait::neighbor` calls in `edge_neighbors`); `HexTrait::line_to`, `N = 22`, **169,230** ([68,310, 85,388], under twice its bound; two `u64` accumulators, two `i32` steps and an append per element). In range or below: `line_of_sight` table 17,706 ([14,509, 18,137]), `approach` interior target 38,446, the loop path of `line` 181,590 (`N = 19`), 202,870 (`N = 22`), 665,820 (`N = 83` on 83 × 3) | — |
| Accepted figures (M1-T5) | measurements above their range, accepted by the orchestrator | §7, §6.7 | The sketch charged 4,504 per row of the loop path | **Measured and accepted, 2026-10-01 (M1-T5)**: `HexagonTrait::hexagon` on the loop path 128,670 at 16 rows ([72,064, 90,080]) and 519,840 at 83 rows ([373,832, 467,290]), about 5,840 per row. In range or below: the table path (sight 16,430, radius 7 at `(1, 1)` 29,936), `hexagon_ring` on the loop path 134,220 (radius 8 at `(7, 8)`, 16 rows) and 547,670 (83 rows on 3 × 83, radius 41 at `(1, 41)`: at radius 255 the ring is empty there). The tick reads the table path only | — |
| N-9 (M1-N9) | the cause found, the plan's wording corrected | §2.1 "Need N-9", §8 L-M1 exit (8), §9.1 (`0.1.0-rc.1`), §10 step 1, R-17 | The plan says the defect of 1.8.0 is in the published artefact, that the index entry of a good release lists no `snforge_std`, and that rc.1 removes the constraint | **The cause is the consumer's resolver** (`docs/research/N-9-cause.md`, reproduced on 2026-10-01): Scarb 2.13.1 counts a dependency's `kind: test` index entries as constraints, Scarb 2.19.4 does not, for `origami_hexmap` 1.8.0 and `hexx` 0.1.0-rc.1 alike. Exit (8) reads: the index lists `snforge_std` **only as `kind: test`**, and the two consumer packages of `tools/consumer_check/` resolve and build against the published version on Scarb 2.19.4 (`.github/workflows/consumer_check.yml`, green for 0.1.0-rc.1, runs `36836722939` and `36838966149`). A consumer on Scarb 2.13 cannot build `hexx` anyway (`cairo-version = "2.19.4"`) | M1-N9, `docs/RELEASING.md` |

None of the findings blocks LIB-04 or LIB-05 (auditor's statement, pass 5). The answers of the
game to the other questions of the plan (D-22, D-24, D-32, Q-1, Q-4) confirm the plan; Q-5,
the truncation of the flood, is with the owner, and `depth` stays a parameter whatever the
answer.
