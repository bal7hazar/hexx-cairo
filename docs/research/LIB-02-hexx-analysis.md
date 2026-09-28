# [Opus 5.5] LIB-02 — Analysis of `hexx` and of its intersection with `origami_hexmap`

Task: [LIB-02](../briefs/LIB-02-hexx-analysis.md), under [COMMON.md](../briefs/COMMON.md) and
[PLAN.md](../../PLAN.md). The report prepares gate L-G1. It answers two questions: is a port of
`hexx` to Cairo relevant for Grim World, and where should that work land?

## 0. Sources, versions, method

| Source | Ref | Commit | Read |
|---|---|---|---|
| `hexx` (github.com/ManevilleF/hexx) | tag `0.25.0` | `b6b9afb1a6d413817509d00ce9ec6b9d52339a7c` | `Cargo.toml`, `src/` (every module), the test modules, the list of examples and benches |
| `origami` (github.com/dojoengine/origami), `crates/hexmap`, workspace version 1.8.0 | `main` | `04ab30caf02dcc8d2ecc46e9596b81732eedcec1` | `src/` (all), `tests/readme.cairo`, the test module names and oracles in `src/tests/`, `README.md`, `GAS.md` (sections L0, L1, L3, L4, L8, P1) |
| Grim World documents (`bal7hazar/grimworld`) | `origin/docs/pm-orchestrator-briefs` | `da2a30eca082aa2fad5a9616e7274e9010dff8fe` | `docs/CAIRO.md`, `PLAN.md` § Track LIB and § Milestone L-M1, `docs/needs/hexmap.md`, `docs/architecture/ADR-0006-chunked-maps.md`, `docs/design/02-core-loop.md`, `docs/design/04-combat.md`, `docs/design/18-rooms.md` |

The versions come from `sources/VERSIONS.md`, fetched on 2026-09-28.

Conventions of this report:

- A path such as `src/hex/mod.rs:903` is relative to the root of its source. `hexx` paths start
  with `src/` inside `sources/hexx/`. `origami_hexmap` paths are relative to
  `sources/origami/crates/hexmap/`; where this could be ambiguous they are prefixed with
  `hexmap:`. Game documents are prefixed with `grimworld:`.
- **(inferred)** marks a conclusion drawn from the code or from a hand computation, not stated
  by the source.
- **(estimate)** marks a cost that was reasoned, not measured. No measurement was made (brief,
  Scope *Out*).
- The mesh modules and the Bevy examples of `hexx` were read at the level of their public types.
  They are excluded from any port (part 4), so their internals were not studied.

---

## 1. What `hexx` offers

`hexx` 0.25.0 is a Rust 2024 crate (`Cargo.toml:3-4`). Its default features are `algorithms`,
`mesh` and `grid` (`Cargo.toml:17-40`). Its only mandatory dependency is `glam` 0.32, which
provides the float vectors (`Cargo.toml:43`). The crate is not `no_std`: `std::` is used
throughout, for example `src/hex/mod.rs:30`. It forbids unsafe code (`src/lib.rs:248`).

### 1.1 Coordinates

| Feature | Where | Main types and functions |
|---|---|---|
| Axial coordinates | `src/hex/mod.rs:62-74` | `struct Hex { pub x: i32, pub y: i32 }`. The coordinates are **signed 32-bit** and the plane is unbounded. Constants: `ZERO`, `ONE`, `X`, `Y`, `NEIGHBORS_COORDS` (`:159-166`) and `DIAGONAL_COORDS` (`:186-193`) |
| Cubic coordinates | `src/hex/mod.rs:247, 274, 333` | `new_cubic(x, y, z)` asserts `x + y + z == 0`. The third coordinate is derived, `z() = -x - y` (alias `s`). `to_cubic_array` |
| Offset coordinates | `src/conversions.rs:29, 65, 142` | `OffsetHexMode { Even, Odd }`, `to_offset_coordinates(mode, orientation)` and `from_offset_coordinates`. Rows or columns follow the orientation: pointy offsets rows, flat offsets columns. Integer division on even numerators only, so every conversion is exact |
| Doubled coordinates | `src/conversions.rs:12, 50, 128` | `DoubledHexMode { DoubledWidth, DoubledHeight }`, `to_doubled_coordinates` and `from_doubled_coordinates` |
| Hexmod coordinates | `src/conversions.rs:92, 110` | `to_hexmod_coordinates(radius)` is `(y + shift·x).rem_euclid(area)`, a bijection between a hexagon and `0..area` |
| Arithmetic | `src/hex/impls.rs` | `Add` and `Sub` with `Hex`, `i32` and the directions. `Mul<i32>` and `Mul<Hex>`. `Mul<f32>` rounds through `Hex::round` (`:186`). `Div<Hex>` truncates per component (`:229-239`). **`Div<i32>` is not a division per component:** it rescales the length through an `f32` lerp (`:241-252`). `Rem` follows `Div`. `Neg`, bit operations and shifts on coordinates (`:321-528`) |
| Length and distance | `src/hex/mod.rs:568, 594, 615, 625` | `length`, `ulength`, `distance_to`, `unsigned_distance_to`. These are cube distances, `max(|x|, |y|, |z|)`, and `const` |
| Rounding | `src/hex/mod.rs:474-484` | `Hex::round([f32; 2])`, Jacob Rus's hexround with `mul_add`; `f32::round` rounds half away from zero |
| Euclidean helpers | `src/hex/euclidean.rs:20-110` | `squared_euclidean_length` is an integer, `x² + y² + xy`. `euclidean_length` and `euclidean_distance_to` are `f32`. `circular_range(f32)` |
| Swizzles and packing | `src/hex/swizzle.rs`, `src/hex/convert.rs:76, 99` | `xx`, `yz`, and so on. `from_u64` and `as_u64` pack the two coordinates in a `u64`. Conversions to and from `IVec2`, `IVec3` and `Vec2` |

### 1.2 Directions

| Feature | Where | Main types and functions |
|---|---|---|
| Edge directions | `src/direction/edge_direction.rs:68-75, 79-190, 208-228` | `EdgeDirection(u8)` holds a value in `0..=5`. Index 0 is `(1, 0)`, and the indices follow `NEIGHBORS_COORDS`: `(1,0), (0,1), (-1,1), (-1,0), (0,-1), (1,-1)`. Constants: `ALL_DIRECTIONS`, `iter()`, `index()`, `into_hex()`. Compass aliases `FLAT_*` and `POINTY_*`. For example, index 1 is `FLAT_BOTTOM` and `POINTY_BOTTOM_RIGHT` |
| Vertex (diagonal) directions | `src/direction/vertex_direction.rs:74, 239-240` | `VertexDirection(u8)`, with the vectors of `DIAGONAL_COORDS` |
| Rotation of a direction | `src/direction/edge_direction.rs:243-313`, `src/direction/impls.rs` | `clockwise()` is `(i + 1) % 6` and `counter_clockwise()` is `(i + 5) % 6`. Also `rotate_cw(n)`, `rotate_ccw(n)` and `const_neg()`, which is `(i + 3) % 6`. Operators: `-`, `>>` (cw) and `<<` (ccw) |
| Direction toward a hex | `src/hex/mod.rs:700-755`, `src/direction/way.rs:30-92` | `neighbor_direction` (a search over the six directions). `way_to` and `diagonal_way_to` are pure integer code on cube coordinates and return `DirectionWay::{Single, Tie}`: **ties are reported, not broken**. `main_direction_to` keeps the first element of a tie |
| Angles | `src/direction/edge_direction.rs:326-553`, `src/direction/mod.rs:18-31` | Every function here returns or takes `f32`: `angle_*`, `unit_vector`, `from_angle*` |

`hexx` draws its compass names for a screen with y pointing down: `src/direction/edge_direction.rs:12-24`
shows `Y` at the bottom, and "clockwise" means `+1`. Its layout instead has y pointing up by
default (`src/layout.rs:9`). Under that default, index 1 `(0, 1)` is drawn up and to the right,
and `+1` turns counter-clockwise on screen **(inferred)**. Part 3 relates this to
`origami_hexmap`.

### 1.3 Rotation and reflection of coordinates

| Feature | Where | Functions |
|---|---|---|
| Rotation by 60° steps | `src/hex/mod.rs:784-860` | `clockwise()` is `(-y, -z)` and `counter_clockwise()` is `(-z, -x)`. `rotate_cw(m)` and `rotate_ccw(m)`, then `*_around(center, m)`. All integer and `const` |
| Reflection | `src/hex/mod.rs:868-884` | `reflect_x` (alias `reflect_q`), `reflect_y` and `reflect_z`, which swap two cube coordinates |

### 1.4 Lines, rings, spirals, ranges, wedges, shapes

| Feature | Where | Functions | Allocation |
|---|---|---|---|
| Line | `src/hex/mod.rs:903-911` | `line_to(other)`: `distance + 1` samples of an `f32` lerp, each rounded with `Hex::round` | Lazy iterator |
| Two-segment line | `src/hex/mod.rs:936-962` | `rectiline_to(other, clockwise)`, integer only | Lazy iterator |
| Ranges | `src/hex/mod.rs:993-1021, 1160` | `range(r)`, `xrange(r)` (without the centre), `range_count(r) = 3r(r+1)+1` | Lazy iterator |
| Rings | `src/hex/rings.rs:15-95` | `ring(r)` = `custom_ring(r, EdgeDirection(0), false)`, `custom_ring`, `rings(range)`, `custom_rings` | **Allocates** a `Vec` of steps (`:21`); `rings` yields one `Vec` per ring |
| Ring edges | `src/hex/rings.rs:113-211` | `ring_edge`, `ring_edges`, `custom_ring_edge(s)` | Lazy |
| Cached rings | `src/hex/rings.rs:382-500` | `cached_rings::<N>()`, `cached_ring_edges` | `[Vec<Hex>; N]` |
| Spirals | `src/hex/rings.rs:516-540` | `spiral_range`, `custom_spiral_range`, `ring_count` | One `Vec` per ring |
| Wedges | `src/hex/rings.rs:229-345` | `wedge`, `wedge_to`, `full_wedge`, `corner_wedge`, `corner_wedge_to`, `custom_*`, `wedge_count` | Lazy |
| Shapes | `src/shapes.rs:45-303` | `parallelogram`, `triangle`, `hexagon` (= `range`), `rombus`, `pointy_rectangle`, `flat_rectangle`, and their parameter structs | Lazy |
| Iterator helpers | `src/hex/iter.rs:4-69` | `HexIterExt::{average, center, bounds}`; `average` uses the `f32` `Div<i32>` | — |

### 1.5 Field of view, field of movement, pathfinding

These are in `src/algorithms/`, behind the `algorithms` feature. The module has no BFS and no
Dijkstra (`src/algorithms/mod.rs:5-7`).

| Feature | Where | Behaviour |
|---|---|---|
| Field of view | `src/algorithms/fov.rs:29-34` (`range_fov`), `:61-76` (`directional_fov`) | For every hex of `ring(range)`, casts `line_to(target)` and keeps it while `!blocking(h)` (`take_while`). The first blocking hex is excluded, and so is everything behind it. The result is the union of the rays as a `HashSet<Hex>`. `directional_fov` keeps the ring hexes whose `diagonal_way_to` matches the two vertex directions of the facing |
| Field of movement | `src/algorithms/field_of_movement.rs:63-101` | `(coord, budget, cost: Fn(Hex) -> Option<u32>) -> HashSet<Hex>`. Entering a hex costs `1 + cost(h)` (`:16-18, :90`); `None` means impassable. The costs are relaxed until nothing changes over `rings(1..=budget)`. The documentation itself calls it "naive … not suitable for production" (`:20-23`) |
| Pathfinding | `src/algorithms/pathfinding.rs:110-146` | `a_star(start, end, cost: Fn(Hex, Hex) -> Option<u32>) -> Option<Vec<Hex>>`: a `BinaryHeap` ordered by score only (`:28-31`), plus `HashMap`s. The path runs from start to end with both included (`:34-39`). Ties between equal scores follow the heap's internal order. The heuristic is the hex distance, which is not admissible when step costs are 0, as in the doc example (`:71-73`) **(inferred)** |

### 1.6 Layouts and orientation

| Feature | Where | Content |
|---|---|---|
| Orientation | `src/orientation.rs:52-130` | `HexOrientation { Pointy, Flat }` (default `Flat`). `HexOrientationData` holds the forward and inverse `Mat2` (`f32`). Pointy: `wx = √3·x + √3/2·y`, `wy = 1.5·y` |
| Layout | `src/layout.rs:61-315` | `HexLayout { orientation, origin: Vec2, scale: Vec2 }`: `hex_to_world_pos`, `world_pos_to_hex`, `hex_corners`, `rect_size`, `invert_x` / `invert_y` and the builders. With `grid`: `edge_coordinates`, `vertex_coordinates`. All `f32` |

### 1.7 Chunks, resolution, bounds, wrapping

| Feature | Where | Content |
|---|---|---|
| Resolution (hexagonal chunks) | `src/hex/mod.rs:1064-1147, 1183` | `to_lower_res(radius)` finds the hexagon of radius `radius` that contains a hex; hexagons of that radius tile the plane. It floor-divides in `f32` (`:1064-1080`). `to_higher_res` is integer and `const`. `to_local` and `wrap_in_range` give the position inside the chunk. **Chunks are hexagons, not rectangles** |
| Bounds | `src/bounds.rs:36-275` | `HexBounds { center, radius }`, a hexagon: `is_in_bounds`, `all_coords`, `intersecting_with`, `wrap` and `wrap_local` (through `wrap_in_range`), `corners`, `FromIterator<Hex>`. `from_min_max` goes through the `f32` `Div<i32>` (`:64`) |
| Rectangular wrapping | `src/storage/rect.rs:88, 369-397` | `WrapStrategy { Clamp, Cycle }` for `RectMap`. `Cycle` is implemented with `while` loops |

### 1.8 Edges and vertices as grid objects

This is the `grid` feature (`src/hex/mod.rs:10-11`).

| Type | Where | Methods |
|---|---|---|
| `GridEdge { origin, direction: EdgeDirection }` | `src/hex/grid/edge.rs:12-133` | `equivalent`, `destination`, `vertices`, `flipped`, rotations, and `Hex::all_edges`. There is no canonical form: equivalence is tested, not normalised |
| `GridVertex { origin, direction: VertexDirection }` | `src/hex/grid/vertex.rs:13-149` | `equivalent`, `coordinates` (3 hexes), `destinations`, `side_edges`, rotations, and `Hex::all_vertices` |

In `hexx`, an "edge" is the side shared by two hexes. It is **not** the edge of a board (need
N-2).

### 1.9 Storage helpers

These are in `src/storage/` and are not gated. Every map stores a generic `T` per hex: they are
**not** bit sets.

| Type | Where | Index |
|---|---|---|
| `HexStore<T>` trait | `src/storage/mod.rs:69-150` | `get`, `get_mut`, `values`, `iter`. Implemented for `HashMap<Hex, T>` |
| `HexagonalMap<T>` | `src/storage/hexagonal.rs:33-127` | `Vec<Vec<T>>` by rows; `new_parallel` uses `rayon` |
| `HexModMap<T>` | `src/storage/hexmod.rs:32-70` | A flat `Vec`, indexed with the hexmod index |
| `RombusMap<T>` | `src/storage/rombus.rs:31-58` | `y·columns + x` |
| `RectMap<T>`, `RectMetadata` | `src/storage/rect.rs:39-397` | Offset coordinates, row-major (`(ij - start).x + (ij - start).y·dim.x`, `:337-358`); default offset mode `Odd` |

### 1.10 Mesh and rendering helpers, optional features

| Feature | Where | Content |
|---|---|---|
| Meshes (`mesh`), shared types | `src/mesh/mod.rs` | Re-exports (`:3, 10-13`). `InsetOptions` (`:26`), `InsetScaleMode` (`:39`), `FaceOptions` with `new` (`:52, 63`). `MeshInfo { vertices: Vec<Vec3>, normals, uvs, indices: Vec<u16> }` (`:105`) with `rotated` (`:121`), `with_offset` (`:134`), `with_scale` (`:142`), `with_uv_scale` (`:150`), `centroid` (`:159`), `uv_centroid` (`:168`), `merge_with` (`:184`) and `cheap_hexagonal_column` (`:206`) |
| Meshes: column builder | `src/mesh/column_builder.rs` | `ColumnMeshBuilder` (`:41`): `new(layout, height: f32)` (`:73`), `at` (`:97`), `facing` (`:110`), `with_rotation` (`:117`), `with_offset` (`:140`), `with_scale` (`:147`), `with_subdivisions` (`:155`), `without_bottom_face` (`:163`), `without_top_face` (`:171`), `with_caps_uv_options` (`:182`), `with_caps_inset_options` (`:198`), `with_sides_options` (`:214`), `with_sides_options_fn` (`:225`), `with_multi_sides_options` (`:238`), `with_multi_custom_sides_options` (`:248`), `center_aligned` (`:260`), `build` (`:268`) |
| Meshes: plane builder | `src/mesh/plane_builder.rs` | `PlaneMeshBuilder` (`:21`): `new` (`:44`), `at` (`:63`), `facing` (`:75`), `with_rotation` (`:82`), `with_offset` (`:89`), `with_scale` (`:96`), `with_face_options` (`:103`), `with_uv_options` (`:110`), `with_inset_options` (`:118`), `center_aligned` (`:127`), `build` (`:134`) |
| Meshes: height-map builder | `src/mesh/heightmap_builder.rs` | `HeightMapMeshBuilder<HeightMap: HexStore<f32>>` (`:60`): `new` (`:109`), `with_height_range` (`:142`), `with_rotation` (`:149`), `with_offset` (`:158`), `with_scale` (`:165`), `without_top_face` (`:173`), `with_cap_options` (`:181`), `with_cap_uv_options` (`:195`), `with_cap_inset_options` (`:211`), `with_custom_cap_options` (`:230`), `without_sides` (`:241`), `with_side_options` (`:249`), `with_custom_sides_options` (`:269`), `with_fringe_heights` (`:293`), `with_default_height` (`:314`), `center_aligned` (`:323`), `build` (`:329`) |
| Meshes: UV mapping | `src/mesh/uv_mapping.rs` | `UVOptions` (`:27`): `new` (`:65`), `with_scale_factor` (`:79`), `with_offset` (`:89`), `with_rect` (`:98`), `flip_u` (`:106`), `flip_v` (`:114`), `alter_uv` (`:127`), `alter_uvs` (`:140`). `Rect` (`:51`) |
| Meshes: faces | `src/mesh/face.rs` | `Tri` with `flip` (`:14, 39`). `Face<VERTS, TRIS>` (`:20`) with `centroid` (`:126`), `uv_centroid` (`:134`), `apply_options` (`:140`), `inset` (`:158`), and `From<Face> for MeshInfo` (`:226`). `type Quad` with `new` (`:32, 55`). `type Hexagon` with `center_aligned` (`:34, 103`) |
| Integrations | `Cargo.toml:17-40` | `serde`, `facet`, `rayon`, `bevy` (`bevy_reflect`, `bevy_platform`, `bevy_ecs`: `Reflect` derives, `Component` on `Hex`, `bevy_platform` hash maps) and `packed` (`repr(C)`) |
| Examples and benches | `examples/`, `benches/` | 17 Bevy demos, among them `chunks`, `field_of_view`, `a_star` and `wrap_map`. 7 criterion benches |

`hexx` has **no** map generation, no noise, no bitmap board and no flood that returns distance
layers. There is no `tests/` directory: the tests are inline. The only exact tests of `line_to`
are `(0,0)→(5,0)` and `(0,0)→(5,5)` (`src/hex/tests.rs:361-401`). There is no test of symmetry,
translation or determinism.

---

## 2. What `origami_hexmap` 1.8.0 covers

`origami_hexmap` is a Cairo package built around one representation: **a board is a `felt252`
bitmap of at most 251 tiles**. Every algorithm acts on whole boards with field multiplications,
which serve as shifts, and with the bitwise builtin (`src/helpers/bits.cairo:1-6`). The facade
mirrors `origami_map`'s `Map` API "name for name" (`src/map.cairo:3`, `README.md`). It follows
`hexx` names "where they apply": `distance_to`, `range`, `ring`, `field_of_movement` and
`neighbor` (`README.md` § Usage).

Test discipline, from the source:
- Every benchmark carries a gas budget of measured + 5 % (`GAS.md:6-20`).
- Optimised algorithms have scalar oracles:
  - a scalar queue BFS (`src/finders/bfs.cairo:1183` onward, `reference_all` and `reference`);
  - a scalar Dijkstra (`src/tests/bench_dial.cairo:4`);
  - a scalar automaton (`src/tests/bench_caver.cairo:4`);
  - a reference walker (`src/generators/walker.cairo:535`).
- Property tests (`src/tests/properties.cairo`) check:
  - dilation against neighbours (`test_properties_expand_*`);
  - `distance` over all pairs of 7×7 (`:153`);
  - `neighbor` (`:226-241`), the masks (`:272`) and the hexagon (`:283`).
- Generator streams are pinned by tests, and "a change of those outputs is a breaking change"
  (`README.md` § Randomness).

### 2.1 Every public function

The facade is `HexMapTrait` (`src/map.cairo:73`), on `struct HexMap { width: u8, height: u8,
grid: felt252, seed: felt252 }` (`:64-69`), deriving `Copy, Drop, Serde` (`:63`). The helper
`is_inside` and the `bounded_int` helper impls (`:34-60`) are private.

| Function | Line | Semantics |
|---|---|---|
| `new(grid, w, h, seed)` | `:90` | Raw constructor, unchecked |
| `new_empty(w, h, seed)` | `:104` | The interior is walkable and the ring is wall |
| `new_maze(w, h, order, seed)` | `:122` | Randomised backtracker, order 0 or 1 |
| `new_cave(w, h, order, seed)` | `:138` | Cellular automaton B4/S2 |
| `new_random_walk(w, h, steps, seed)` | `:154` | Random walk |
| `new_hexagon(radius, seed)` | `:168` | A hexagon of radius ≤ 6 in a `(2R+3)²` board |
| `open_with_corridor(ref self, position, order)` | `:186` | Digs from an edge tile until it touches an open tile |
| `open_with_maze(ref self, position, order)` | `:202` | Grows a maze from an edge tile |
| `keep_component(ref self, position)` | `:215` | Flood fill |
| `compute_distribution(self, count, seed)` | `:229` | `count` walkable tiles, uniform, as a bitmap |
| `search_path(self, from, to)` | `:243` | BFS. The path runs from the target (included) to the start (excluded) |
| `search_path_weighted(self, from, to, costs)` | `:260` | Dial with up to 3 cost classes |
| `field_of_movement(self, from, budget, costs)` | `:275` | A bitmap within the budget |
| `distance_to(self, from, to)` | `:290` | **Path length, walls block** |
| `hex_distance(self, from, to)` | `:304` | Geometric distance, walls ignored |
| `reachable(self, from)` | `:324` | Component |
| `range(self, position, range)` | `:338` | **Walls block** (BFS ball) |
| `ring(self, position, radius)` | `:354` | **Walls block** (one flood) |
| `neighbor(self, position, direction)` | `:424` | `Option<u8>` |
| `is_walkable(self, position)` | `:439` | Bit test |

The library modules are public: `pub mod` in `src/lib.cairo`. Only `HexMap`, `HexMapTrait`,
`Direction`, `U252Trait` and `u252` are re-exported at the root (`src/lib.cairo:1-4`).

| Module | Public items (line) |
|---|---|
| `src/types/direction.cairo` | `DIRECTION_COUNT` (`:19`), `DIRECTION_SIZE` (`:21`). `enum Direction { East, NorthEast, NorthWest, West, SouthWest, SouthEast }` (`:25`), deriving `Copy, Drop, Serde, PartialEq, Debug` (`:24`). `DirectionTrait` (`:35`): `opposite` (`:42`), `next(position, width, odd)` (`:62`), `pop_front(ref u32)` (`:98`). `DirectionIntoU8::into`, `0..5` in the enum order (`:114`). `U8TryIntoDirection::try_into` (`:128`) |
| `src/finders/bfs.cairo` | `Bfs` (`:163`): `search` (`:175`), `distance` (`:207`), `reachable` (`:248`), `tiles_within_range` (`:300`). `errors::BFS_POSITION_NOT_WALKABLE` (`:33`). The flood internals, including `flood`, `layer` and the backtracking, are `pub(crate)` (`:351`), and so are `Back`, `Endpoint`, `Store`, `SmallStore` and `Goal` (`:38-133`) |
| `src/finders/dial.cairo` | `Dial` (`:160`): `search` (`:172`), `field_of_movement` (`:227`). `errors::DIAL_TOO_MANY_COSTS` (`:40`), `errors::DIAL_POSITION_NOT_WALKABLE` (`:41`). `DialInternal` and the `Frontier` impls are private (`:108, 142, 293`) |
| `src/generators/caver.cairo` | `Caver` (`:44`): `generate` (`:53`), `keep_component` (`:82`). `errors::CAVER_POSITION_NOT_FLOOR` (`:23`). The automaton (`evolve`, `step`, `rule`) is private (`:93`) |
| `src/generators/digger.cairo` | `Digger` (`:40`): `maze` (`:51`), `corridor` (`:65`). `DiggerInternal` is `pub(crate)` (`:73`) |
| `src/generators/mazer.cairo` | `Mazer` (`:530`): `generate` (`:541`). `errors::MAZER_INVALID_ORDER` (`:53`). `Carver`, `Heading` and `MazerInternal` are `pub(crate)` (`:58-585`) |
| `src/generators/spreader.cairo` | `Spreader` (`:403`): `generate` (`:431`). `errors::SPREADER_NOT_ENOUGH_PLACE` (`:109`), `errors::SPREADER_INVALID_GRID` (`:110`). `BitSetTrait` and `SpreaderInternal` are `pub(crate)` (`:127, 451`) |
| `src/generators/walker.cairo` | `Walker` (`:64`): `generate` (`:73`). `WalkImpl` is private (`:158`) |
| `src/helpers/layout.cairo` | `struct Layout` (`:31`), `struct Dilation` (`:48`), both with public fields. `LayoutTrait` (`:60`): `new` (`:68`), `board` (`:89`), `even` (`:101`), `interior` (`:121`), `hexagon` (`:134`), `with_interior` (`:161`), `expand` (`:192`), `expand_small` (`:206`), `dilation` (`:216`), `edge_neighbours` (`:234`), `neighbour_in` (`:253`), `neighbour_mask` (`:273`), `index` (`:294`), `coords` (`:305`), `parity` (`:317`), `neighbor` (`:334`). `DilationTrait` (`:389`): `dilate` (`:401`), `expand_small` (`:433`) |
| `src/helpers/geometry.cairo` | `Geometry` (`:12`): `to_axial` (`:20`, returns `(i16, i16)`), `distance` (`:35`) |
| `src/helpers/bits.cairo` | `Bits`: `bitwise` (`:65`), `and` (`:76`), `or` (`:89`), `xor` (`:102`), `pow` (`:114`), `inv` (`:124`), `shl` (`:135`), `shr_exact` (`:146`), `to_felt` (`:156`), `get` (`:167`), `set` (`:182`), `unset` (`:193`), `popcount` (`:202`), `popcount_small` (`:215`), `top_byte` (`:227`), `low_byte` (`:239`), `byte_counts` (`:250`), `popcount_sparse` (`:269`); `Bits` is declared at `:57`. `trait Set<T>` (`:287`), declaring `from_felt`, `from_wide`, `to_felt`, `and`, `sub`, `is_empty`, `hits` and `limb` (`:289-303`). `WideSet` for `u256` (`:306`): `from_felt` (`:308`), `from_wide` (`:313`), `to_felt` (`:318`), `and` (`:323`), `sub` (`:328`), `is_empty` (`:333`), `hits` (`:338`), `limb` (`:348`). `SmallSet` for `u128` (`:357`): `from_felt` (`:359`), `from_wide` (`:364`), `to_felt` (`:369`), `and` (`:374`), `sub` (`:380`), `is_empty` (`:385`), `hits` (`:390`), `limb` (`:396`). Constants `TWO_POW_128` (`:17`), `TWO_POW_32` (`:19`), `TWO_POW_64` (`:21`), `BYTES_ONE` (`:23`), `TWO_POW_120` (`:31`). Tables `POW` (`:403`), `INV` (`:537`), `POW128` (`:791`). The `DivRemHelper` impls (`:40, 46`) are private |
| `src/helpers/rng.cairo` | `struct Rng` (`:62`). `RngTrait` (`:68`): `new` (`:75`), `mix` (`:86`), `draw` (`:100`), `draw6` (`:116`), `draw_byte` (`:133`), `next_below` (`:149`), `shuffle6` (`:161`), `split216` (`:178`), `refill` (`:189`). `PERMUTATIONS` (`:199`). The `DivRemHelper` impls (`:37-55`) are private |
| `src/helpers/asserter.cairo` | `MAX_SIZE = 251` (`:6`). `errors::ASSERTER_INVALID_DIMENSION` (`:10`), `errors::ASSERTER_POSITION_IS_CORNER` (`:11`), `errors::ASSERTER_POSITION_NOT_EDGE` (`:12`), `errors::ASSERTER_POSITION_NOT_INSIDE` (`:13`). `Asserter` (`:17`): `is_edge` (`:27`), `is_corner` (`:40`), `assert_valid_dimension` (`:51`), `assert_on_edge` (`:66`), `assert_not_corner` (`:79`), `assert_inside` (`:92`) |
| `src/types/u252.cairo`, type and inherent methods | `PRIME` (`:28`). `struct u252` (`:36`), deriving `Copy, Drop, PartialEq, Serde, Debug, Default` (`:35`). `U252Trait` (`:41`): `new` (`:48`), `value` (`:58`), `shl` (`:72`), `shr_exact` (`:88`), `shr` (`:110`), `div_rem` (`:123`), `bit` (`:138`), `set_bit` (`:149`). The helpers `split`, `join`, `low_bits` and `product_fits` (`:175, 181, 188, 364`) are private |
| `src/types/u252.cairo`, conversions | `Felt252IntoU252::into` (`:202`), `U252IntoFelt252::into` (`:209`), `U252IntoU256::into` (`:216`), `U256TryIntoU252::try_into` (`:223`). `U128IntoU252::into` (`:234`), `U64IntoU252::into` (`:241`), `U32IntoU252::into` (`:248`), `U16IntoU252::into` (`:255`), `U8IntoU252::into` (`:262`). `U252TryIntoU128::try_into` (`:269`), `U252TryIntoU64::try_into` (`:276`), `U252TryIntoU32::try_into` (`:283`), `U252TryIntoU16::try_into` (`:290`), `U252TryIntoU8::try_into` (`:297`). `U252StorePacking::pack` (`:305`), `U252StorePacking::unpack` (`:310`) |
| `src/types/u252.cairo`, arithmetic | Checked: `U252CheckedAdd::checked_add` (`:320`), `U252CheckedSub::checked_sub` (`:342`), `U252CheckedMul::checked_mul` (`:383`). Operators, panicking on overflow: `U252Add::add` (`:332`), `U252Sub::sub` (`:354`), `U252Mul::mul` (`:394`), `U252Div::div` (`:402`), `U252Rem::rem` (`:409`). Wrapping: `U252WrappingAdd::wrapping_add` (`:417`), `U252WrappingSub::wrapping_sub` (`:424`), `U252WrappingMul::wrapping_mul` (`:431`) |
| `src/types/u252.cairo`, order, bits and constants | `U252PartialOrd`: `lt` (`:440`), `le` (`:445`), `gt` (`:450`), `ge` (`:455`). `U252BitAnd::bitand` (`:464`), `U252BitOr::bitor` (`:472`), `U252BitXor::bitxor` (`:481`). `U252Zero`: `zero` (`:492`), `is_zero` (`:497`), `is_non_zero` (`:502`). `U252One`: `one` (`:509`), `is_one` (`:514`), `is_non_one` (`:519`). `U252Bounded` (`:524`): `MIN` (`:525`), `MAX` (`:526`) |
| `src/helpers/printer.cairo` | `HexPrinter` (`:17`): `render` (`:25`), `render_with_path` (`:39`), `print` (`:90`), `print_with_path` (`:102`). **Compiled for tests only** (`src/lib.cairo:30-31`) |

### 2.2 How it names things

- The facade uses American spelling, following `hexx`: `neighbor` (`src/map.cairo:424`,
  `src/helpers/layout.cairo:334`).
- The helpers use British spelling: `neighbour_mask`, `edge_neighbours`, `neighbour_in`
  (`src/helpers/layout.cairo:234-273`).
- A tile is a `u8` **position** (an index). A set of tiles is a `felt252` bitmap.
- The generators are named `new_*`, mirroring `origami_map`. The helper modules are agent nouns:
  `Caver`, `Digger`, `Mazer`, `Spreader`, `Walker`.

### 2.3 Cost figures

These are measured figures, from `GAS.md` and `README.md` § Gas: Sierra gas, snforge 0.61.0,
scarb 2.19.4.

| Item | Figure | Source |
|---|---:|---|
| BFS forward layer, 17×14 (two limbs) | ~19.3k | `GAS.md:156` |
| BFS forward layer, ≤ 128 tiles (single limb) | ~9.9k | `GAS.md:161` |
| BFS backtracking step, 17×14 / ≤ 128 tiles | ~8.4k / ~6.4k | `GAS.md:159-161` |
| BFS fixed cost (checks, constants, endpoints) | ~55k | `GAS.md:162` |
| `tiles_within_range` radius 6, empty 17×14 | 159,255 | `GAS.md:242` |
| `ring` radius 4, cave 17×14 | 99,903 | `GAS.md` § L8 `ring` |
| One cave generation, 17×14 / ≤ 128 tiles | 35,710 / 16,030 | `GAS.md` § L4 |
| `new_cave` 17×14, order 3 | 142k | `README.md` § Gas |
| Dial time step, 17×14, 0 to 3 classes | 26.5k–38.0k | `GAS.md` § L3 |
| `search_path` cave 17×14, 24 steps | 706k | `README.md` § Gas |
| `hex_distance`, `neighbor`, `is_walkable` per call | 10.4k, 7.0k, 7.1k | `README.md` § Gas |
| felt mul by a constant; POW lookup; `shr_exact` | 98; 1,269; 1,469 | `GAS.md:46, 48, 50` |
| `u256 &`; felt → `u256` (wide); `u8` DivRem; loop iteration | 2,682; 1,809; 1,098; 1,270 | `GAS.md:58, 53, 63, 45` |
| Bit test `Bits::get`; `popcount` | 4,949; 13,448 | `GAS.md:65, 69` |

---

## 3. Conventions compared

| Topic | `hexx` 0.25.0 | `origami_hexmap` 1.8.0 |
|---|---|---|
| Coordinate system | Axial `Hex { x: i32, y: i32 }` on an unbounded plane. Offset, doubled and hexmod coordinates are conversions (`src/conversions.rs`) | An index `i = y·W + x` on a bounded board; `(x, y)` from `LayoutTrait::coords`. **`+x` is West and `+y` is North**; bit 0 is drawn bottom-right (`src/types/direction.cairo:3-5`, `README.md` § Index). The axial form exists only inside `Geometry::to_axial`: `q = x − ⌊y/2⌋`, `r = y` (`src/helpers/geometry.cairo:20-24`) |
| Offset parity | `OffsetHexMode::{Even, Odd}`. Pointy `Even` is `col = x + ⌈y/2⌉`; `Odd` is `col = x + ⌊y/2⌋` (`src/conversions.rs:70-83`) | Called "odd-r": odd rows are shifted half a tile toward increasing `x`, which is West (`README.md` § Index) |
| Orientation | Pointy and flat (`src/orientation.rs:124-130`). The default is **flat** | Pointy only. Flat maps come from the transpose (`README.md` § Limits) |
| Direction order | `EdgeDirection` 0..5: `(1,0), (0,1), (-1,1), (-1,0), (0,-1), (1,-1)` | `Direction` 0..5: `East, NorthEast, NorthWest, West, SouthWest, SouthEast` (`src/types/direction.cairo:112-124`) |
| Opposite | `const_neg` = `(i+3) % 6`; unary `-` | `opposite()`, a `match`, tested equal to `(i+3) % 6` (`src/types/direction.cairo:42, 150-160`) |
| Rotation | `clockwise`, `rotate_cw(n)` and so on, on directions and coordinates | **None** |
| Board storage | None as bits. `RectMap<T>` is row-major over offset coordinates (`src/storage/rect.rs:337-358`) | One `felt252` of `W·H ≤ 251` bits, `1` = walkable. The `u252` type holds felt-valued integers |
| Single-limb path | Not applicable | Boards of ≤ 128 tiles run on one `u128`, about half the cost per layer (`GAS.md:161`). **A 15 × 15 window has 225 tiles, so it uses the two-limb path.** The ADR's fallback window of 11 × 11 (121 tiles) would use the single limb (`grimworld:docs/architecture/ADR-0006-chunked-maps.md` § Cost) **(inferred)** |
| Border | None; the plane is unbounded | **The outer ring must be wall.** Only then is every neighbour shift an exact field multiplication (`src/helpers/layout.cairo:5-8`). Open edge tiles are entrances: they can start or end a path but never lie inside one (`README.md` § Border ring) |
| Tie-breaks | `line_to`: `f32::round` half away from zero plus `>=` in `Hex::round` (`src/hex/mod.rs:474-484`). `way_to`: returns `Tie`. `a_star`: heap order, unspecified | Lowest set bit, which is the lowest tile index, in every backtracking step (`src/finders/bfs.cairo:4-6`, `src/finders/dial.cairo:14-15`). The game adopts this rule: "by lowest entity id, then by lowest tile index, as the map library does" (`grimworld:docs/design/04-combat.md` § Goblin AI) |
| Signedness | `i32` everywhere; negative coordinates are normal | Unsigned `u8` positions. The distance avoids negative intermediates (`src/helpers/geometry.cairo:38-58`); `i16` appears only in `to_axial` |
| Errors | Mostly total functions; `new_cubic` asserts | Panics with named messages (`README.md` § Panics) |

### 3.1 How the two coordinate systems map

This mapping was derived by hand from the two neighbour tables and checked against all six
directions **(inferred)**. Take an `origami_hexmap` tile `(x, y)`, with a pointy `hexx`
layout and y up (`src/orientation.rs:86-101`, `src/layout.rs:9`). `hexx`'s default orientation
is flat (`src/orientation.rs:127-129`), so the layout has to be pointy explicitly.

```text
hexx Hex (keeping compass names) = ( -x - ceil(y/2) ,  y )  =  ( s_o , r_o )
where (q_o, r_o, s_o) are origami's own axial/cube coordinates from Geometry::to_axial.
Equivalently: origami (x, y)  <->  hexx pointy offset, OffsetHexMode::Even, column = C - x, row = y
(for any constant C, e.g. C = W - 1).
```

Four consequences follow:

1. **Parity.** In its own frame, `origami_hexmap` is "odd-r", because odd rows are shifted
   toward `+x`. But `+x` points West. On a north-up map this is `hexx`'s `Even` pointy mode,
   mirrored horizontally. The naive call `hexx::from_offset_coordinates([x, y], Odd, Pointy)`
   also gives a consistent hex grid, but it swaps East with West, NorthEast with NorthWest, and
   SouthEast with SouthWest.
2. **Direction numbering is identical.** Under the mapping above, `origami_hexmap`'s `East` = 0 …
   `SouthEast` = 5 are `hexx`'s `EdgeDirection` 0 … 5 exactly. Both go counter-clockwise on a
   north-up map.
3. **Only the names differ.** `hexx` calls index 1 `POINTY_BOTTOM_RIGHT` and calls `+1`
   "clockwise", because its names assume a y-down screen (§1.2). A port that keeps `hexx`'s
   function names (`clockwise`, `rotate_cw`) would turn **counter-clockwise** on the game's
   north-up map. This has to be documented as-is, or renamed as a deviation.
4. **Opposites agree:** `(i + 3) % 6` in both.

### 3.2 Where `origami_hexmap` already follows `hexx` names, and where it does not

| `origami_hexmap` | `hexx` | Same name, same meaning? |
|---|---|---|
| `neighbor(position, direction) -> Option<u8>` | `Hex::neighbor(direction) -> Hex` | Same name. `origami_hexmap` returns `None` off the board |
| `hex_distance(from, to)` | `Hex::distance_to(other)` | **Different name, same meaning** (geometric distance) |
| `distance_to(from, to) -> Option<u8>` | `Hex::distance_to` | **Same name, different meaning**: in `origami_hexmap` walls block, so this is a path length (`src/map.cairo:279-292`) |
| `range(position, r)` | `Hex::range(r)` | Same name. `hexx` is geometric; in `origami_hexmap` walls block. The two agree on an empty board inside it (`README.md` § Migration) |
| `ring(position, r)` | `Hex::ring(r)` | Same as `range`. `hexx` returns an ordered sequence, `origami_hexmap` a set |
| `field_of_movement(from, budget, costs)` | `algorithms::field_of_movement(coord, budget, cost)` | Same name, close meaning. `hexx` charges `1 + cost(h)` through a callback; `origami_hexmap` charges 1, or `k + 2` for class `k` ≤ 2 |
| `search_path` | `a_star` | Different names. The path orders are opposite, and `origami_hexmap` excludes the start |
| `Direction`, `opposite` | `EdgeDirection`, `const_neg` / `-` | Different names |
| `new_hexagon(radius)` | `shapes::hexagon`, `HexBounds` | Different names |
| `reachable`, `keep_component`, `is_walkable`, generators, `compute_distribution` | — | Not in `hexx` |

---

## 4. What has no meaning on-chain

| `hexx` item | Why not on-chain | Status |
|---|---|---|
| `HexLayout`, `HexOrientation` matrices, `hex_to_world_pos`, `world_pos_to_hex`, `hex_corners`, `rect_size` (`src/layout.rs`, `src/orientation.rs`) | Floating point; world and screen space belong to the client | **Excluded** |
| Direction angles: `angle_*`, `unit_vector`, `from_angle*`, the `angles` constants (`src/direction/*`) | `f32`; the contract works in directions, not angles | **Excluded**. The integer counterparts are `way_to`, `main_direction_to` and `DirectionWay` |
| `mesh` module (`src/mesh/`) | Rendering; `Vec<Vec3>` | **Excluded** |
| `bevy*`, `facet`, `rayon`, `serde` features; `glam` interop (`IVec2`, `Vec2`) | Engine and host integrations | **Excluded**. `serde` maps loosely onto Cairo's `Serde` and `StorePacking` derives |
| `Hex::round`, `lerp`, `Mul<f32>`, `Div<f32>`, and `From<(f32, f32)>` / `From<Vec2>` | Floating-point input | **Excluded**. What they compute has exact rational counterparts |
| `Hex::line_to` (`f32` lerp + round) | Floating point; `f32` noise decides exact ties | **Integer counterpart** (need N-5, §5.6) |
| `Div<i32>` for `Hex` (length rescale via `f32`), `HexIterExt::average`/`center`, `HexBounds::from_min_max` | Floating point | Integer counterpart possible (exact rational rounding). Low value; **defer** |
| `to_lower_res` (`f32` floor) | Floating point, exact only while values fit in 24 bits | **Integer counterpart**: floor division. Low value for the game, whose chunks are rectangles; **defer** |
| `euclidean_length`, `euclidean_distance_to`, `circular_range(f32)` | Floating point | `squared_euclidean_length` is an integer, so a circular range can compare against an integer `r²`. **Defer** |
| `ring`, `rings`, `spiral_range`, `cached_*` (`Vec` per ring) | Allocation per call; on-chain an `Array` costs per element | Counterpart: a **bitmap** on a bounded board (§5.7), or a `Span` for small radii |
| `range_fov`, `directional_fov`, `field_of_movement`, `a_star` (returning `HashSet`, `HashMap` or `BinaryHeap`) | Hash maps and heaps; `a_star` has no bound on an unbounded plane when the target is unreachable **(inferred)** | Counterpart: floods on a bounded bitmap. `origami_hexmap` already has `field_of_movement` and `search_path(_weighted)`, limited to per-tile costs in at most 3 classes (`hexmap:src/map.cairo:252-253`). The arbitrary cost of `a_star` for each directed step (`src/algorithms/pathfinding.rs:110`) has no counterpart |
| Cost callbacks `impl Fn(Hex) -> Option<u32>` | A per-tile call is the opposite of a whole-board operation | Counterpart: **cost-class bitmaps**, as in `origami_hexmap` (`src/finders/dial.cairo:3-4`) |
| `HexStore<T>`, `HexagonalMap`, `HexModMap`, `RombusMap`, `RectMap` (generic `T`, `Vec`) | A game stores state in Dojo models, not in in-memory vectors | Counterpart: **one bitmap per layer** (`origami_hexmap`). The index formulas (`hexmod`, row-major offset) remain portable as pure functions |
| `WrapStrategy::Cycle` (`while` loops) | Unbounded loop | Counterpart: `%` on bounded integers. Not needed by the game |
| Bit operations and shifts on `Hex` coordinates (`src/hex/impls.rs:330-528`) | Integer and portable, but with no use in the game | **Defer** |
| `i32` coordinates in general | Signed arithmetic costs more in Cairo than `u8`, and the rules ask for signed values only where needed (`grimworld:docs/CAIRO.md` §4) | Keep `i32` only in a coordinate-level API. Board algorithms stay on `u8` indices |
| `Debug`, `Hash`, `Reflect`, `Component` derives | Host-side | Excluded, except for Cairo's `Debug`/`PartialEq` derives |

---

## 5. The game's needs

Each section answers three questions: does `hexx` have it, does `origami_hexmap` have it, and
what would the work be. The board is the window of `grimworld:docs/architecture/ADR-0006-chunked-maps.md`
§1 and §4: 15 × 15 tiles, one felt, with an outer ring treated as wall.

### 5.1 Distance, neighbours

- **`hexx`:** it has these. `distance_to` / `length` (`src/hex/mod.rs:568-625`), plus
  `neighbor`, `all_neighbors` and `neighbor_direction` (`:633-702`). There is no `is_neighbor`.
- **`origami_hexmap`:** it has these on a board.
  - `hex_distance` (`src/map.cairo:304`), and `Geometry::distance` without the checks
    (`src/helpers/geometry.cairo:35`).
  - `neighbor` (`src/map.cairo:424`), and the six neighbours as one bitmap
    (`LayoutTrait::neighbour_mask`, `src/helpers/layout.cairo:273`).
  - The path distance `distance_to`.
- **Work:** almost none on a board. Two gaps remain.
  - **Global coordinates.** A 105 × 105 location has 11,025 tiles, which does not fit a `u8`
    index. "The nearest goblins, ties by id" (`grimworld:docs/design/02-core-loop.md` §
    Simulation budget) needs a distance on `(x, y)` pairs, not on board indices. That is one
    function on `u8` coordinates, with the same formula as `Geometry::distance`, which already
    works on coordinates internally (`:36-58`).
  - **Axis orientation.** The game says "tile `(x, y)` in its location" but does not state
    whether global `+x` is East. The index of `origami_hexmap` has `+x` West. This must be fixed
    once: it is an open question for LIB-03.

### 5.2 N-1 — Generation of a board given its margins

- **`hexx`:** absent. It has no generator and no noise (§1.10).
- **`origami_hexmap`:** partly.
  - `new_cave` is a bit-sliced B4/S2 automaton over the whole board (`src/generators/caver.cairo:1-5,
    53-69`). One generation costs 35.7k on 17×14 (`GAS.md` § L4). It draws its initial fill
    from `hades_permutation(seed, 0, 2)` (`:101-104`).
  - It has **no margin input**. The automaton is private (`CaverInternal`, `:93`). It relies on
    the wall ring: "born tiles are interior: a border tile has at most 3 interior neighbours"
    (`:227-229`), and the down-shifts are exact only because the low rows hold no bit
    (`src/helpers/layout.cairo:5-8`).
- **Work:** a generator that holds given margin tiles fixed while the interior evolves. There
  are two readings of "margins", and the design does not choose between them. This is an
  **ambiguity for LIB-03**:
  - **(a) The seam is inside the chunk.** The chunk's own outer ring holds the tiles copied
    from its neighbours ("a new chunk copies the edge of each neighbour",
    `grimworld:ADR-0006` § Joining chunks), and the 13 × 13 interior evolves. This fits one
    felt. Each generation needs one more AND to clear the rows that a down-shift would drop.
    Wrapped column bits always land on border-column tiles, which the interior mask removes.
    The extra cost is about +2 bitwise applications per generation **(inferred, estimate)**.
  - **(b) The margins are the neighbours' tiles outside the chunk.** Then a 15 × 15 chunk with
    a one-tile margin needs 17 × 17 = 289 bits, which is more than 251: **it does not fit one
    felt**. The margins would instead enter as extra neighbour planes, added to the border
    tiles' counts from each neighbour's edge row or column. That costs 1 to 4 extra shifted
    and masked planes per generation **(estimate)**.
- **Pin the stream.** The new generator's stream is API ("generator outputs are API",
  `grimworld:PLAN.md` § Releases, and `README.md` § Randomness). Its reference test vectors
  are needed from the first release.
- **Row parity of chunks is a trap** (§5.4). Chunks are 15 rows high, an odd number, so chunk
  `(cx, cy)` starts on global row `15·cy`, which is odd when `cy` is odd. Generating such a
  chunk with the library's even-origin layout smooths it over the wrong neighbourhoods
  **(inferred)**. Two fixes exist:
  - a layout with a parity flag: the complement `even` mask and swapped up/down factors, both
    constants;
  - generating in the window frame.

### 5.3 N-2 — Edges and openings between boards

- **`hexx`:** absent in this sense. Its `GridEdge` is the side between two hexes (§1.8), and
  `ring_edge` is a side of a hexagonal ring. Neither is the edge of a rectangular board.
- **`origami_hexmap`:** partly.
  - `open_with_corridor` and `open_with_maze` open **one edge tile** (not a corner) and dig
    inward until they reach the open area (`src/map.cairo:176-204`,
    `src/generators/digger.cairo:1-13`). That is exactly the tool to guarantee "at least one
    opening" once the opening tile is chosen.
  - `Asserter::is_edge` and `is_corner` (`src/helpers/asserter.cairo:27-40`).
  - Paths may end on open edge tiles (`README.md` § Border ring).
  - There is no function to read or write one side of a board, and none to compare two boards
    across a seam.
- **Work:**
  - **Side masks** for the four sides: row 0, row `H-1`, column 0, column `W-1`. These are
    constants.
  - **An `openings(a, b, side)` function** giving the bitmap of the tiles of `b` that are open
    and adjacent to an open tile of `a` across the seam. It needs no gathering of bits:
    - Left and right: shift `a`'s far column onto `b`'s near column. That is one masked field
      multiplication by `2^-(W-1)`. Then add the two diagonal contacts, which depend on the
      parity of the seam rows. Those are two more masked shifts by `±W`.
    - Top and bottom: shift one row by `(H-1)·W`, then take the two neighbours of each tile
      across.
    - Parity again: the seam between chunk rows `cy` and `cy+1` lies on global rows
      `15cy+14` and `15cy+15`, whose parities alternate with `cy` **(inferred)**.
  - **Opening policy.** Choosing where the opening goes is game policy. The library offers
    the primitives and the corridor digger.
  - **Cost.** A few `u256` ANDs and field products, about 10–20k per seam **(estimate)**.
    Reading a column tile by tile would be 15 × ~4.9k ≈ 75k.

### 5.4 N-3 — Assembly of a 15 × 15 board from up to 4 chunks

- **`hexx`:** absent. Its chunks are hexagons (`to_lower_res`, §1.7), not rectangles. It has no
  bitmaps.
- **`origami_hexmap`:** it has the primitives but not the function:
  - `Bits::pow` and `Bits::inv` (tables), `shr_exact`, `Bits::and` (`src/helpers/bits.cairo:76-146`);
  - `Layout.even` (`src/helpers/layout.cairo:35, 101`);
  - `LayoutTrait::board` (`:89`).
- **Work:** one function, `assemble`. The window and the chunks share the width 15, so moving
  a chunk by `(dx, dy)` into the window is a one-dimensional shift by `dy·15 + dx`. Per chunk
  and per layer:
  1. AND the chunk with the rectangle that lands inside the window. The rectangle is a
     constant, or it is computed as `(2^w − 1)·2^x0·Σ 2^(15k)`, which kills the bits that would
     wrap into another row or fall off the board.
  2. Multiply by `2^s` or `2^-s`, from the `POW` or `INV` table. This is exact because the
     dropped bits were masked first.
  3. Add the pieces. They are disjoint, so a felt addition is enough.

  The cost is about 5k per chunk and layer, so 4 chunks × 2 layers (terrain, occupied) ≈ 40k
  **(estimate)**, excluding storage reads. The window's wall ring is then imposed with one
  more AND.
- **Why the origin must be on an even row.** The library derives every neighbour from the row
  parity of the **local** index:
  - `LayoutTrait::parity` (`src/helpers/layout.cairo:317-324`);
  - the table in `src/types/direction.cairo:7-14`, for example NorthEast is `i + W − 1` on an
    even row and `i + W` on an odd one;
  - the `even` mask that splits every dilation (`src/helpers/layout.cairo:401-424`).

  If the window origin is on an odd global row, every local even row is a global odd row.
  Then every diagonal neighbour the library computes is off by one column. The library works
  on a **different hex grid** from the map: floods, distances, rings and paths are wrong, and
  a goblin could "step" onto a tile that is not adjacent to it on the map **(inferred)**. The
  copy itself does not care about parity; only the neighbourhood does.
- **Chunks start on odd rows.** Chunks are 15 rows high, so chunks with odd `cy` start on odd
  global rows. The copy is unaffected, but generation (§5.2) and seams (§5.3) are.
- **Horizontal offsets are free.** In a pointy-top layout the parity is per row, so any `dx`
  keeps it.

### 5.5 N-4 — Cutting a board by a mask

- **`hexx`:** absent. `HexBounds::intersecting_with` (`src/bounds.rs:116`) filters coordinates
  geometrically.
- **`origami_hexmap`:** it has the operation but not a named function. `Bits::and`
  (`src/helpers/bits.cairo:76`) on the two bitmaps costs about 2.7k (`u256 &`, `GAS.md:58`).
- **Work:** trivial. Possibly a named `cut(grid, mask)` that also keeps the wall ring, and a
  test that a cut board still satisfies the border invariant.

### 5.6 N-5 — Line of sight

- **`hexx`:** it has a line, in floating point. `line_to` samples `a.lerp(b, i / N)` in `f32`
  for `i = 0..=N`, where `N` is the hex distance, and rounds each sample with `Hex::round`
  (`src/hex/mod.rs:903-911, 474-484`). **`hexx` 0.25.0 applies no nudge.**
  - The whole of `src/` was searched for an epsilon or a nudge and none was found: the only
    `epsilon` hits are `assert_relative_eq!` in tests (`src/layout.rs:409`,
    `src/direction/tests.rs:215`).
  - The brief expected "the nudge `hexx` uses". The classic line algorithm adds a small offset
    so that no sample falls exactly on the boundary between two hexes. `hexx` does not. Exact
    ties are decided by `f32::round` rounding half away from zero, and then by `>=` in
    `Hex::round`.
  - Its field of view casts these lines to the outer ring (`src/algorithms/fov.rs:29-34`).
- **`origami_hexmap`:** absent. The game says so too: "This function is not part of
  `origami_hexmap` and is ours to write" (`grimworld:docs/design/04-combat.md` § Ranges).
- **Reproducing the line exactly with integers.** This part is a derivation **(inferred)**.
  - In cube coordinates, let `Δ = b − a` and `N = max(|Δx|, |Δy|, |Δz|)`. Choose an axis `k`
    with `|Δk| = N`.
    - At every sample, coordinate `k` is the integer `a_k + i·sign(Δk)`.
    - The other two coordinates `u` and `v` sum to an integer.
    - So a sample lies either inside one hex or **exactly on the edge between two hexes**,
      when the fraction of `u` is ½.
    - It **never lies on a vertex**, because a vertex needs all three fractions to be non-zero.
  - Scaled by `N`, the whole test is integer: `t = i·Δu`. Round `t/N` to the nearest integer.
    There is a tie exactly when `2·(t mod N) = N`, which is only possible when **`N` is even**.
  - The line is Bresenham-like: one accumulator update per step, with no division.
  - Away from ties, the integer line equals `hexx`'s. The rounding margin is at least `1/(2N)`,
    which is ≥ 1/28 on a 15 × 15 board and far above `f32` error.
  - At exact ties, `hexx`'s result depends on `f32` rounding, on "half away from zero" and on
    `>=`. **It is not translation-invariant.** Worked by hand from `src/hex/mod.rs:474-484`:
    - `(0,0) → (1,1)` passes through `(0.5, 0.5)` and picks `(0,1)`, which is `+(0,1)` from
      the start.
    - `(-2,-2) → (-1,-1)` passes through `(-1.5, -1.5)` and picks `(-1,-2)`, which is `+(1,0)`
      from the start.
  - **Parity check.** An exhaustive comparison over all pairs of a 15 × 15 window, about 50k
    pairs, run off-chain against `hexx` 0.25.0, can list the pairs where the two differ. LIB-03
    should do this for the parity table.
- **Game tie-break against `hexx`.** The game's rule is: "When the line passes exactly between
  two tiles, the lower tile index is taken" (`grimworld:docs/design/04-combat.md` § Ranges).
  - The two tied tiles are neighbours, so their index order depends only on their relative
    direction. `i = y·W + x` with `+x` West, so the rule means: **the southern tile, or on the
    same row the eastern tile.**
  - The rule is **symmetric**: `a → b` and `b → a` give the same set, so "A sees B" equals
    "B sees A". It is also **translation-invariant**. `hexx` guarantees neither. The game's line
    is therefore a **documented deviation** from `line_to`, or a separately named function
    **(inferred)**.
- **Work:** an integer line and a line-of-sight test (walls block, actors do not). Two forms
  are possible:
  - **Loop:** at most 6 steps for range 6, each a bit test (~5–7k), so about 40k per test
    **(estimate)**.
  - **Table:** because the tie rule is translation-invariant, the tiles strictly between the
    two ends depend only on the offset and the parity of the start row. A table of 2 × 126
    felts (radius 6) gives that "between" mask. Placing it is one multiplication (plus a
    clipping AND near the edges), and the test is one AND with the walls: about 5–10k
    **(estimate)**. This is the "tables over computation" preference of
    `grimworld:docs/CAIRO.md` §1.
  - The "arc the line arrives from" (`grimworld:docs/design/04-combat.md` § Facing) is the
    direction of the last step, which the table can store alongside.

### 5.7 N-6 — Range and ring as geometry, ignoring walls, as masks

- **`hexx`:** it has these as coordinate iterators: `range`, `ring`, `spiral_range`, `shapes::hexagon`,
  `HexBounds` (§1.4, §1.7). None of them is a mask.
- **`origami_hexmap`:** partly.
  - `range` and `ring` are masks, but **walls block** (`src/map.cairo:338-414`). Run on an
    empty board (`new_empty`), they give the geometric set clipped to the interior
    (`README.md` § Migration). That costs 159k for radius 6 on 17×14 (`GAS.md:242`): one
    dilation per unit of radius.
  - `LayoutTrait::hexagon(radius)` (`src/helpers/layout.cairo:134-151`) is a geometric
    hexagon, but only centred in its own `(2R+3)²` board.
- **Work:** geometric `range(position, r)` and `ring(position, r)` as bitmaps.
  - **Tables:** a hexagon mask per radius (1 to 8) and per centre-row parity. Place it by one
    field multiplication after masking what would fall off, then AND with a column-band mask
    to remove the bits that wrap to the next row. That is about 5–15k **(estimate)** against
    159k for the empty-board flood.
  - A ring is `range(r) − range(r−1)`, or its own table.
  - **Full table for sight:** radius 6 on a 15 × 15 window could even be one table of 225
    felts indexed by position, with no computation. That trades class size for gas, and the
    rules favour gas (`grimworld:docs/CAIRO.md` §1).
  - **Name clash:** `range` and `ring` already mean "walls block" in `origami_hexmap`. The
    geometric versions need other names, or they carry the `hexx` names in a separate module.
    LIB-03 decides.

### 5.8 N-7 — Directions, opposite, rotation by 60°, arcs relative to a facing

- **`hexx`:** it has all of this, in integers.
  - `EdgeDirection` with `const_neg`, `rotate_cw(n)`, `rotate_ccw(n)`, `clockwise` and
    `counter_clockwise`.
  - Coordinate rotation: `Hex::rotate_cw(m)` and `rotate_cw_around`.
  - `way_to` / `main_direction_to`, the direction of a distant hex, with explicit ties.
  - These are in `src/direction/edge_direction.rs:243-313`, `src/hex/mod.rs:734-860` and
    `src/direction/way.rs`.
- **`origami_hexmap`:** it has the directions and the opposite. `Direction`, `opposite` and
  the `u8` conversions are in `src/types/direction.cairo`. It has no rotation and no arcs.
- **Work:** small, and all arithmetic on `u8`:
  - `rotate(d, n) = (d + n) % 6`;
  - `arc(facing, tile_direction) = table[(tile_direction − facing + 6) % 6]`. The six entries,
    for the values 0 to 5, are front, front-side, rear-side, back, rear-side and front-side
    (`grimworld:docs/design/04-combat.md` § Facing: front `d`, front-side `d ± 1`, rear-side
    `d ± 2`, back `d + 3`);
  - the direction from a tile to a neighbour, from `neighbour_mask` or a 6-entry table.

  Each is about 1–3k **(estimate)**. The naming of rotation is the trap of §3.1: `hexx`'s
  `rotate_cw` turns counter-clockwise on the game's north-up map.

### 5.9 N-8 — One flood from the adventurer giving every walker its next step

- **`hexx`:** absent. `a_star` finds one path per call; `field_of_movement` returns a set, not
  distances (§1.5).
- **`origami_hexmap`:** it has the engine but not the function.
  - The BFS floods layer by layer and **stores every layer** for its backtracking, whose step
    is "the neighbour mask of the current tile intersected with the previous layer, lowest set
    bit" (`src/finders/bfs.cairo:1-15, 742-806, 855-909`). That is exactly "each goblin steps
    to its free neighbour closest to the target", with the game's lowest-index tie-break.
  - But the layers are internal (`pub(crate) impl BfsInternal`, `:351`).
  - The public entry points take **one** target (`search_path`, `distance_to`).
  - Endpoints on walls panic (`README.md` § Panics), so goblin tiles cannot simply be removed
    from the grid and then used as targets.
  - `field_of_movement` (Dial) floods in time buckets but returns only the union
    (`src/finders/dial.cairo:227`).
- **Work:** one function, for example `flood_layers(grid, from, depth) -> Span<felt252>` or
  `next_steps(grid, from, walkers) -> …`, built on the public `Dilation::dilate`
  (`src/helpers/layout.cairo:401`) or on `BfsInternal` if the work lands in the same crate.
  - **Extra obstacles** (occupied tiles) are removed from the grid before flooding. Walkers
    read the layers from outside, through their neighbour masks, so they need not be walkable.
  - **Moves in id order.** Goblins act one after another in ascending id order
    (`grimworld:docs/design/02-core-loop.md` § The tick), so a goblin that moved changes the
    occupancy seen by the next. The distances can follow that change in one of two ways:
    - **(a) One flood per tick, on frozen occupancy.** The distance layers are computed once
      per tick on the occupancy frozen at the start of the tick. The current occupancy only
      filters each walker's candidate tiles:
      `neighbour_mask(g) & layer(d−1) & ~occupied_now`. If that is empty, the walker falls back
      to `layer(d)`. Consequences:
      - A walker can be routed toward a tile, or through a corridor, that a previous walker has
        just blocked. The filter only stops it stepping *onto* that tile. Its distance may be
        stale, so it may wait or side-step where a fresh flood would send it another way.
      - A walker is not routed through a tile that a previous walker has just freed. That tile
        was occupied at the start of the tick, so it is absent from the layers, and a shorter
        way through it is ignored until the next tick.
      - Cost: **1 flood per tick.**
    - **(b) Distances follow current occupancy.** A new flood follows every move that changes
      occupancy, so each walker sees exact distances. Consequences:
      - A walker is never routed toward a tile a previous walker just blocked.
      - A walker can use a tile a previous walker just freed.
      - Cost: **up to 8 floods per tick**, one per awake goblin.
  - **Which rule the design implies.** The design says "one flood per tick, not one per goblin:
    a single breadth-first flood from the adventurer on the window gives every goblin its next
    step" (`grimworld:docs/design/02-core-loop.md` § Simulation budget; also
    `grimworld:docs/design/04-combat.md` § Goblin AI, "each goblin steps to its free neighbour
    closest to the target"). Both texts point to **rule (a)**: one flood, and "free" read as
    the filter on current occupancy **(inferred)**. This report assumes (a). **LIB-03 and the
    game must confirm it**, because the two rules give different moves and moves are numeric
    API.
  - **Kiting.** Profiles that want distance take the highest layer instead
    (`grimworld:docs/design/04-combat.md` § Goblin AI).
  - **Goblins on the ring.** They sit on the wall ring, 7 tiles out
    (`grimworld:ADR-0006` §4). This matches the "open edge tile as endpoint" rule of the
    library.
- **Cost compared with the present tools:** eight separate `search_path` calls cost about
  8 × 700k ≈ 5.6M on a 17×14 cave (`README.md` § Gas).
  - Rule (a): one flood of about 12–14 layers at ~19.3k, plus 8 steps at ~8–10k, is about
    300–450k per tick **(estimate)**.
  - Rule (b): up to 8 such floods, about 8 × 250–300k plus the steps, so about 2.1–2.5M per
    tick **(estimate)**.

### 5.10 Summary table

| Need | `hexx` 0.25.0 | `origami_hexmap` 1.8.0 | Work |
|---|---|---|---|
| Distance, neighbours | Yes: `distance_to`, `neighbor`, `all_neighbors` (`src/hex/mod.rs`) | Yes on a board: `hex_distance`, `neighbor`, `neighbour_mask` | Distance on global `(x, y)`; fix the global axis orientation |
| N-1 Generation with margins | No | Cave automaton without margins (`src/generators/caver.cairo`, automaton private) | New generator with fixed margin tiles; settle what "margin" means; parity flag for chunks on odd rows; pinned stream |
| N-2 Edges and openings | No (`GridEdge` is a hex side) | Edge-tile digger (`open_with_corridor`), `is_edge` | Side masks, `openings` across a seam (parity-aware), opening placement via the digger |
| N-3 Assembly from ≤ 4 chunks | No (hexagonal chunks only) | Primitives (`POW`/`INV`, `and`, `even`) | `assemble`: masked shifts, even origin; document why an odd origin breaks |
| N-4 Cut by a mask | No | `Bits::and` | A named `cut`, keeping the ring |
| N-5 Line of sight | `line_to` in `f32`, no nudge, ties not translation-invariant | No | Integer line with the lower-index tie rule (a deviation from `line_to`); LOS test, loop or table |
| N-6 Range and ring as geometry | Coordinate iterators (`range`, `ring`) | `range`/`ring` with walls; `hexagon` mask at fixed centre | Geometric masks at any position (tables + masked shift); resolve the name clash |
| N-7 Directions, rotation, arcs | Yes (`EdgeDirection`, `rotate_*`, `way_to`) | `Direction`, `opposite` | `rotate`, `arc`, direction to a neighbour; the naming of "clockwise" |
| N-8 One flood, many walkers | No | BFS layers exist but internal; single-target API | `flood_layers` / `next_steps` with extra obstacles and the id-order rule; one flood per tick on frozen occupancy (rule (a) of §5.9), to be confirmed |

---

## 6. A first view of cost

The rules of `grimworld:docs/CAIRO.md` §3 rank techniques: arithmetic first, then bitwise
operations, then bounded loops. The board is a 15 × 15 window held in one felt: 225 bits, so
it takes the **two-limb** path.

| Algorithm | Fits the preference? | Figure |
|---|---|---|
| Assembly (N-3), cut (N-4), side masks (N-2) | Yes: masked field shifts and ANDs | ~5k per chunk and layer; cut ~2.7k (`GAS.md:58`) **(estimate** except the AND) |
| Openings across a seam (N-2) | Yes: masked shifts by `±W`, `2^-(W-1)` | ~10–20k per seam **(estimate)** |
| Cave generation with margins (N-1) | Yes: bit-sliced automaton | 35.7k per generation on 17×14, measured (`GAS.md` § L4); +5–15 % with margins **(estimate)** |
| Flood for all walkers (N-8) | Yes: bit-parallel layers, one per step | ~19.3k per layer on two limbs, measured (`GAS.md:156`); ~300–450k per tick with 8 goblins under rule (a), one flood per tick; ~2.1–2.5M under rule (b), up to 8 floods (§5.9) **(estimate)** |
| Geometric range and ring (N-6) | Yes if **tabled**; the flood on an empty board costs 159k (r = 6, measured) | 5–15k with tables **(estimate)** |
| Line of sight (N-5) | Table: yes. Loop: per tile, ≤ 6 steps | 5–10k with a table, ~40k with a loop **(estimate)** |
| Rotation and arcs (N-7) | Yes: `u8` arithmetic and 6-entry tables | 1–3k **(estimate)** |
| Global distance, chunk of a tile `(x / 15, y / 15)` | Division by a constant: `bounded_int::div_rem` | ~1.1k per `u8` DivRem (`GAS.md:63`) |

These look expensive:
- **Per-tile loops.** A bit test is ~4.9k (`GAS.md:65`), so any loop over 225 tiles is
  ≥ 1.1M.
- **`hexx`-style `i32` coordinate code**, if carried over literally. Signed checked arithmetic
  on each step is a cost that bitmaps avoid.
- **`u256` shifts:** a multiplication by `2^17` on `u256` is 14k (`GAS.md:61`), against 98 for
  a felt multiplication.
- **Divisions** that a table can replace.

Tables are preferred to computation (`grimworld:docs/CAIRO.md` §1). The candidates are:
- line-of-sight masks (2 × 126 felts);
- hexagon masks per radius and parity (≈ 16 felts), or per position for sight (225 felts);
- side and rectangle masks for assembly (≈ 30 felts, or computed arithmetically);
- the arc table (6 entries).

`origami_hexmap` already uses the `POW` and `INV` tables for every shift
(`src/helpers/bits.cairo:403, 537`). Its measured lookup cost of 1,269 (`GAS.md:48`) is the
unit to keep in mind: a table pays off when it replaces more than one or two field operations.

---

## 7. Where the work should land, and under what name

| | A. `hexx-cairo`, a mirror, on its own | B. `origami_hexmap` extended in place | C. Both: a mirror, later a dependency of `origami_hexmap` | D. No port; the game writes helpers on top of `origami_hexmap` |
|---|---|---|---|---|
| What the game depends on | `hexx-cairo`, and still `origami_hexmap` for boards, flood and generators | `origami_hexmap` only | Both, then possibly `origami_hexmap` alone | `origami_hexmap` 1.8.0, frozen |
| Fit with the needs | Poor. `hexx` offers coordinates and iterators, while N-1, N-2, N-3, N-4, N-6 and N-8 are board and bitmap operations `hexx` does not have. They would be "extensions" that outweigh the mirror | **Good.** The needs extend the existing engine: dilation, automaton, layers, masks, tables | Mirror part poor, as in A; board part as in B | Good for the small helpers. The hard algorithms (N-1, N-5, N-8) would be written outside the library that owns the internals they need (`CaverInternal` private, `BfsInternal` crate-private) |
| Port conventions (parity table against `hexx`) | Natural, but it covers the part of little use to the game | The parity table covers only the `hexx`-named integer subset (directions, rotation, line, geometric range and ring). The rest is documented as extensions. `origami_hexmap` already mirrors `origami_map`'s names (`src/map.cairo:3`), so there are two naming duties | Complete in the mirror | None |
| Existing users of `origami_hexmap` | Unaffected | Additive functions, unaffected. Existing numeric results cannot change (streams are API from 1.8.0 on), so conventions (`+x` West, odd-r) stay | Unaffected until the dependency flips; then a transitive dependency appears | Unaffected |
| Publication on scarbs.xyz | Its own crate and cadence, in `bal7hazar/hexx-cairo` | Through the `origami` workspace release (`version.workspace = true`, `Scarb.toml`): every L-M1 pre-release is an `origami` release. The owner has maintainer rights | Two crates, two cadences, a cross-organisation dependency | None |
| Maintenance | Two libraries with overlapping geometry | One engine, one `GAS.md`, one set of oracles | The most | Game-side code to audit, with no reuse by other Dojo games |
| Owner's decision already on record | — | "Generation of a board given its margins is added to the map library by its author" (`grimworld:ADR-0006` § Joining chunks) | — | Conflicts with that decision for N-1 |

---

## Recommendation for gate L-G1

**Is a port relevant? Partly.**

A full port of `hexx` is not relevant to Grim World:
- Most of `hexx` is floating point, rendering, engine integration or heap-allocated iteration
  (part 4).
- The needs of L-M1 are board-level bitmap algorithms that `hexx` does not have (part 5).

The **integer geometric subset** of `hexx` is relevant and small: directions and rotation, the
line, and range and ring as geometry. It is worth carrying with `hexx` names and a parity table
where the semantics agree.

**Where it lands: B. Extend `origami_hexmap` in place, in `dojoengine/origami`.**

The needs grow out of its engine: the automaton for N-1, the stored BFS layers for N-8, masks
and shifts for N-2 to N-4, and tables for N-5 to N-7. The internals they reuse are private to
that crate. The game keeps one dependency, by published version. The owner's decision on N-1
already names "the map library". `bal7hazar/hexx-cairo` remains the home of the track: plans,
research, and the off-chain harness that generates the parity vectors from `hexx` 0.25.0.

**What L-M1 would contain** (additive, all within `origami_hexmap`):

1. N-7: rotation and arcs on `Direction`, named after `hexx` where the semantics agree, with the
   "clockwise" naming settled.
2. N-6: geometric range and ring masks.
3. N-5: the integer line and line of sight with the game's tie rule.
4. N-3: `assemble`. N-4: `cut`. N-2: side masks and `openings`.
5. N-1: a cave generator with margins and a parity flag.
6. N-8: `flood_layers` or `next_steps`, one flood per tick on the occupancy frozen at the
   start of the tick, with current occupancy filtering each goblin's candidates (rule (a) of
   §5.9, about 300–450k per tick, an estimate).
7. A distance on global coordinates.

Each item is test-driven with a gas budget and a scalar oracle.

**What stays out:**
- Everything in part 4: layout, orientation, angles, meshes, integrations, `f32` arithmetic,
  and allocating ring and spiral iterators.
- `a_star`. `search_path_weighted` covers the game's pathfinding needs, which are bounded
  per-tile costs: at most 3 cost classes (`hexmap:src/map.cairo:252-253`). It does not cover
  the full `a_star` semantics, which allow an arbitrary cost for each directed step
  (`src/algorithms/pathfinding.rs:110`).
- Hexagonal resolution and `HexBounds` wrapping.
- `GridEdge` and `GridVertex`.
- Generic storage.
- Wedges, shapes and reflections. They are integer, but no need asks for them; they are
  candidates for L-M2 if a full mirror is ever wanted.

**Main risks:**
1. Row parity: chunks are 15 rows high, so half the chunks start on odd global rows (§5.2,
   §5.4).
2. The meaning of "margins" (§5.2), and whether a margin outside the chunk fits a felt (it does
   not).
3. The release cadence and review of the `origami` workspace for each pre-release SPK-7 needs.
4. The two-limb cost of a 15 × 15 window (225 > 128 tiles).
5. Naming: `distance_to`, `range` and `ring` already mean "walls block", and `hexx`'s
   "clockwise" is counter-clockwise on a north-up map.
6. Numeric results are API: the line's tie rule and the new generator's stream freeze at their
   first release.

**What LIB-03 must settle:**
- The margin semantics and the parity flag of N-1.
- The global axis orientation.
- The names of the geometric range and ring, and of rotation.
- The output format of N-8 (layers, or next steps).
- With the game, the N-8 rule: one flood per tick on frozen occupancy (a), as the design
  implies, or distances that follow each move (b), at up to 8 floods per tick.
- Tables against dilations for N-5 and N-6, with class size stated.
- The parity-table method: vectors generated from `hexx` 0.25.0, and a deviation list at line
  ties.
- Gas targets per function, and the `origami` release numbering (1.9.x pre-releases).

**Alternatives, in one line each:**
- **A** would give a clean mirror of the part of `hexx` the game barely uses, and duplicate the
  engine.
- **C** costs the most, for a dependency flip whose benefit is not needed by L-M1.
- **D** is the cheapest now, but it contradicts the owner's decision on N-1 and puts the
  hardest algorithms outside the library that owns their internals.
