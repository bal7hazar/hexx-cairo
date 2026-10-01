//! Unpublished fixture: minimal Starknet contracts that consume `hexx`, so that
//! `scripts/bytecode_size.py` can track class size against the Starknet limits (plan, R-11).
//! Not part of what `hexx` publishes; depends on `starknet`, which `hexx` itself never does.
//!
//! One call site per public function of `HexMapTrait` (the 20 of the facade of the board
//! engine), so that the tracked class size follows the engine: a removed or dead-code-eliminated
//! item would otherwise go on shrinking it unnoticed (AGENTS.md, principle 11). Split over three
//! contracts: the 20 in one exceed the 81,920 CASM felts a class may hold. The extensions of
//! milestone L-M1 add their own contracts (`HexxAssembly`: N-3; `HexxCut`: N-4; `HexxFlood`: N-8);
//! `HexxMirror` holds the mirror items of L-M1 (`Hex`, `EdgeDirection`, the offset conversions,
//! `HexOrientation`); `HexxCoordinates` the directions and coordinates of the board (N-7, M1-T3);
//! `HexxLine` the line of sight (N-5, M1-T6) and the mirror's `line_to`; `HexxSeams` the seams
//! (N-2, M1-T7) and `LayoutTrait::new_odd`.

/// The queries, the finders on unit costs and the constructors that call no generator.
#[starknet::contract]
pub mod HexxSink {
    use hexx::{Direction, HexMap, HexMapTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn new(self: @ContractState, grid: felt252, width: u8, height: u8, seed: felt252) -> HexMap {
        HexMapTrait::new(grid, width, height, seed)
    }

    #[external(v0)]
    fn new_empty(self: @ContractState, width: u8, height: u8, seed: felt252) -> HexMap {
        HexMapTrait::new_empty(width, height, seed)
    }

    #[external(v0)]
    fn new_hexagon(self: @ContractState, radius: u8, seed: felt252) -> HexMap {
        HexMapTrait::new_hexagon(radius, seed)
    }

    #[external(v0)]
    fn keep_component(self: @ContractState, map: HexMap, position: u8) -> HexMap {
        let mut map = map;
        map.keep_component(position);
        map
    }

    #[external(v0)]
    fn search_path(self: @ContractState, map: HexMap, from: u8, to: u8) -> Span<u8> {
        map.search_path(from, to)
    }

    #[external(v0)]
    fn distance_to(self: @ContractState, map: HexMap, from: u8, to: u8) -> Option<u8> {
        map.distance_to(from, to)
    }

    #[external(v0)]
    fn hex_distance(self: @ContractState, map: HexMap, from: u8, to: u8) -> u8 {
        map.hex_distance(from, to)
    }

    #[external(v0)]
    fn reachable(self: @ContractState, map: HexMap, from: u8) -> felt252 {
        map.reachable(from)
    }

    #[external(v0)]
    fn range(self: @ContractState, map: HexMap, position: u8, range: u8) -> felt252 {
        map.range(position, range)
    }

    #[external(v0)]
    fn ring(self: @ContractState, map: HexMap, position: u8, radius: u8) -> felt252 {
        map.ring(position, radius)
    }

    #[external(v0)]
    fn neighbor(
        self: @ContractState, map: HexMap, position: u8, direction: Direction,
    ) -> Option<u8> {
        map.neighbor(position, direction)
    }

    #[external(v0)]
    fn is_walkable(self: @ContractState, map: HexMap, position: u8) -> bool {
        map.is_walkable(position)
    }
}

/// The generators: constructors, corridors and mazes, the distribution of objects.
#[starknet::contract]
pub mod HexxGenerators {
    use hexx::{HexMap, HexMapTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn new_maze(self: @ContractState, width: u8, height: u8, order: u8, seed: felt252) -> HexMap {
        HexMapTrait::new_maze(width, height, order, seed)
    }

    #[external(v0)]
    fn new_cave(self: @ContractState, width: u8, height: u8, order: u8, seed: felt252) -> HexMap {
        HexMapTrait::new_cave(width, height, order, seed)
    }

    #[external(v0)]
    fn new_random_walk(
        self: @ContractState, width: u8, height: u8, steps: u16, seed: felt252,
    ) -> HexMap {
        HexMapTrait::new_random_walk(width, height, steps, seed)
    }

    #[external(v0)]
    fn open_with_corridor(self: @ContractState, map: HexMap, position: u8, order: u8) -> HexMap {
        let mut map = map;
        map.open_with_corridor(position, order);
        map
    }

    #[external(v0)]
    fn open_with_maze(self: @ContractState, map: HexMap, position: u8, order: u8) -> HexMap {
        let mut map = map;
        map.open_with_maze(position, order);
        map
    }

    #[external(v0)]
    fn compute_distribution(
        self: @ContractState, map: HexMap, count: u8, seed: felt252,
    ) -> felt252 {
        map.compute_distribution(count, seed)
    }
}

/// N-3, the assembly of the window (`hexx::board::assembly`): one call site per function of
/// `AssemblyTrait`. The chunks are taken one by one: a fixed-size array is not an entry point
/// argument here.
#[starknet::contract]
pub mod HexxAssembly {
    use hexx::HexMap;
    use hexx::board::assembly::{AssemblyTrait, Origin};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn origin(self: @ContractState, x: u8, y: u8) -> Origin {
        AssemblyTrait::origin(x, y)
    }

    #[external(v0)]
    fn local(self: @ContractState, origin: Origin, x: u8, y: u8) -> Option<u8> {
        origin.local(x, y)
    }

    #[external(v0)]
    fn assemble(
        self: @ContractState,
        chunk: Option<felt252>,
        west: Option<felt252>,
        north: Option<felt252>,
        north_west: Option<felt252>,
        ox: u8,
        oy: u8,
        odd_chunk_row: bool,
    ) -> felt252 {
        AssemblyTrait::assemble([chunk, west, north, north_west], ox, oy, odd_chunk_row)
    }

    #[external(v0)]
    fn window(
        self: @ContractState,
        terrain: (Option<felt252>, Option<felt252>, Option<felt252>, Option<felt252>),
        occupied: (Option<felt252>, Option<felt252>, Option<felt252>, Option<felt252>),
        origin: Origin,
        seed: felt252,
    ) -> (HexMap, felt252) {
        let (t0, t1, t2, t3) = terrain;
        let (o0, o1, o2, o3) = occupied;
        AssemblyTrait::window([t0, t1, t2, t3], [o0, o1, o2, o3], @origin, seed)
    }
}

/// N-4, the cut of a board by a mask (`hexx::board::cut`): the one call site of `CutTrait::cut`.
#[starknet::contract]
pub mod HexxCut {
    use hexx::HexMap;
    use hexx::board::cut::CutTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn cut(self: @ContractState, map: HexMap, mask: felt252) -> HexMap {
        map.cut(mask)
    }
}

/// N-2 (M1-T7): the sides and openings between chunks, and the layout of an odd chunk.
#[starknet::contract]
pub mod HexxSeams {
    use hexx::board::layout::LayoutTrait;
    use hexx::board::seams::{SeamTrait, Side};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn side(self: @ContractState, width: u8, height: u8, side: Side) -> felt252 {
        SeamTrait::side(width, height, side)
    }

    #[external(v0)]
    fn openings(
        self: @ContractState,
        width: u8,
        height: u8,
        near: felt252,
        far: felt252,
        side: Side,
        odd: bool,
    ) -> felt252 {
        SeamTrait::openings(width, height, near, far, side, odd)
    }

    #[external(v0)]
    fn is_open_across(
        self: @ContractState,
        width: u8,
        height: u8,
        near: felt252,
        far: felt252,
        side: Side,
        odd: bool,
    ) -> bool {
        SeamTrait::is_open_across(width, height, near, far, side, odd)
    }

    #[external(v0)]
    fn new_odd(
        self: @ContractState, width: u8, height: u8,
    ) -> (u256, felt252, felt252, felt252, felt252) {
        let layout = LayoutTrait::new_odd(width, height);
        (layout.even, layout.up_even, layout.up_odd, layout.down_even, layout.down_odd)
    }
}

/// The weighted finders (`Dial`).
#[starknet::contract]
pub mod HexxDial {
    use hexx::{HexMap, HexMapTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn search_path_weighted(
        self: @ContractState, map: HexMap, from: u8, to: u8, costs: Span<felt252>,
    ) -> Span<u8> {
        map.search_path_weighted(from, to, costs)
    }

    #[external(v0)]
    fn field_of_movement(
        self: @ContractState, map: HexMap, from: u8, budget: u8, costs: Span<felt252>,
    ) -> felt252 {
        map.field_of_movement(from, budget, costs)
    }
}

/// N-8, the flood of the tick (`hexx::finders::flood`): one call site per new public function,
/// `Bfs::flood` and `FloodTrait::{depth, next_step, next_step_away, distance}`. A `Flood` is not
/// an entry point value: each entry point floods, then returns what it selects.
#[starknet::contract]
pub mod HexxFlood {
    use hexx::finders::bfs::Bfs;
    use hexx::finders::flood::FloodTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn flood(
        self: @ContractState,
        grid: felt252,
        width: u8,
        height: u8,
        from: u8,
        obstacles: felt252,
        depth: u8,
    ) -> u8 {
        Bfs::flood(grid, width, height, from, obstacles, depth).depth()
    }

    #[external(v0)]
    fn next_step(
        self: @ContractState,
        grid: felt252,
        width: u8,
        height: u8,
        from: u8,
        obstacles: felt252,
        depth: u8,
        position: u8,
        blocked: felt252,
    ) -> Option<u8> {
        Bfs::flood(grid, width, height, from, obstacles, depth).next_step(position, blocked)
    }

    #[external(v0)]
    fn next_step_away(
        self: @ContractState,
        grid: felt252,
        width: u8,
        height: u8,
        from: u8,
        obstacles: felt252,
        depth: u8,
        position: u8,
        blocked: felt252,
    ) -> Option<u8> {
        Bfs::flood(grid, width, height, from, obstacles, depth).next_step_away(position, blocked)
    }

    #[external(v0)]
    fn distance(
        self: @ContractState,
        grid: felt252,
        width: u8,
        height: u8,
        from: u8,
        obstacles: felt252,
        depth: u8,
        position: u8,
    ) -> Option<u8> {
        Bfs::flood(grid, width, height, from, obstacles, depth).distance(position)
    }
}

/// The mirror items of milestone L-M1 (`hexx::hex`, `hexx::direction::edge_direction`,
/// `hexx::conversions`, `hexx::orientation`): one call site per public item, the 30 compass
/// constants of `EdgeDirection` included, so that the tracked class size follows them.
#[starknet::contract]
pub mod HexxMirror {
    use hexx::conversions::{HexConversionsTrait, OffsetHexMode};
    use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use hexx::hex::{Hex, HexTrait};
    use hexx::orientation::HexOrientation;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn zero(self: @ContractState) -> Hex {
        HexTrait::ZERO
    }

    #[external(v0)]
    fn neighbors_coords(self: @ContractState) -> Span<Hex> {
        let neighbors = HexTrait::NEIGHBORS_COORDS;
        neighbors.span()
    }

    #[external(v0)]
    fn new(self: @ContractState, x: i32, y: i32) -> Hex {
        HexTrait::new(x, y)
    }

    #[external(v0)]
    fn x_y_z(self: @ContractState, hex: Hex) -> (i32, i32, i32) {
        (hex.x(), hex.y(), hex.z())
    }

    #[external(v0)]
    fn const_sub(self: @ContractState, hex: Hex, rhs: Hex) -> Hex {
        hex.const_sub(rhs)
    }

    #[external(v0)]
    fn length(self: @ContractState, hex: Hex) -> i32 {
        hex.length()
    }

    #[external(v0)]
    fn ulength(self: @ContractState, hex: Hex) -> u32 {
        hex.ulength()
    }

    #[external(v0)]
    fn hex_distance_to(self: @ContractState, hex: Hex, rhs: Hex) -> i32 {
        hex.distance_to(rhs)
    }

    #[external(v0)]
    fn unsigned_distance_to(self: @ContractState, hex: Hex, rhs: Hex) -> u32 {
        hex.unsigned_distance_to(rhs)
    }

    #[external(v0)]
    fn compass(self: @ContractState) -> Span<u8> {
        let mut indices = array![];
        indices.append(EdgeDirectionTrait::X_NEG_Y.index());
        indices.append(EdgeDirectionTrait::FLAT_TOP_RIGHT.index());
        indices.append(EdgeDirectionTrait::FLAT_NORTH_EAST.index());
        indices.append(EdgeDirectionTrait::POINTY_TOP_RIGHT.index());
        indices.append(EdgeDirectionTrait::POINTY_NORTH_EAST.index());
        indices.append(EdgeDirectionTrait::NEG_Y.index());
        indices.append(EdgeDirectionTrait::FLAT_TOP.index());
        indices.append(EdgeDirectionTrait::FLAT_NORTH.index());
        indices.append(EdgeDirectionTrait::POINTY_TOP_LEFT.index());
        indices.append(EdgeDirectionTrait::POINTY_NORTH_WEST.index());
        indices.append(EdgeDirectionTrait::NEG_X.index());
        indices.append(EdgeDirectionTrait::FLAT_TOP_LEFT.index());
        indices.append(EdgeDirectionTrait::FLAT_NORTH_WEST.index());
        indices.append(EdgeDirectionTrait::POINTY_LEFT.index());
        indices.append(EdgeDirectionTrait::POINTY_WEST.index());
        indices.append(EdgeDirectionTrait::NEG_X_Y.index());
        indices.append(EdgeDirectionTrait::FLAT_BOTTOM_LEFT.index());
        indices.append(EdgeDirectionTrait::FLAT_SOUTH_WEST.index());
        indices.append(EdgeDirectionTrait::POINTY_BOTTOM_LEFT.index());
        indices.append(EdgeDirectionTrait::POINTY_SOUTH_WEST.index());
        indices.append(EdgeDirectionTrait::Y.index());
        indices.append(EdgeDirectionTrait::FLAT_BOTTOM.index());
        indices.append(EdgeDirectionTrait::FLAT_SOUTH.index());
        indices.append(EdgeDirectionTrait::POINTY_BOTTOM_RIGHT.index());
        indices.append(EdgeDirectionTrait::POINTY_SOUTH_EAST.index());
        indices.append(EdgeDirectionTrait::X.index());
        indices.append(EdgeDirectionTrait::FLAT_BOTTOM_RIGHT.index());
        indices.append(EdgeDirectionTrait::FLAT_SOUTH_EAST.index());
        indices.append(EdgeDirectionTrait::POINTY_RIGHT.index());
        indices.append(EdgeDirectionTrait::POINTY_EAST.index());
        indices.span()
    }

    #[external(v0)]
    fn all_directions(self: @ContractState) -> Span<EdgeDirection> {
        let all = EdgeDirectionTrait::ALL_DIRECTIONS;
        all.span()
    }

    #[external(v0)]
    fn iter(self: @ContractState) -> Span<EdgeDirection> {
        EdgeDirectionTrait::iter()
    }

    #[external(v0)]
    fn direction_index(self: @ContractState, direction: EdgeDirection) -> u8 {
        direction.index()
    }

    #[external(v0)]
    fn into_hex(self: @ContractState, direction: EdgeDirection) -> Hex {
        direction.into_hex()
    }

    #[external(v0)]
    fn direction_into(self: @ContractState, direction: EdgeDirection) -> Hex {
        direction.into()
    }

    #[external(v0)]
    fn const_neg(self: @ContractState, direction: EdgeDirection) -> EdgeDirection {
        direction.const_neg()
    }

    #[external(v0)]
    fn clockwise(self: @ContractState, direction: EdgeDirection) -> EdgeDirection {
        direction.clockwise()
    }

    #[external(v0)]
    fn counter_clockwise(self: @ContractState, direction: EdgeDirection) -> EdgeDirection {
        direction.counter_clockwise()
    }

    #[external(v0)]
    fn rotate_cw(self: @ContractState, direction: EdgeDirection, offset: u8) -> EdgeDirection {
        direction.rotate_cw(offset)
    }

    #[external(v0)]
    fn rotate_ccw(self: @ContractState, direction: EdgeDirection, offset: u8) -> EdgeDirection {
        direction.rotate_ccw(offset)
    }

    #[external(v0)]
    fn to_offset_coordinates(
        self: @ContractState, hex: Hex, mode: OffsetHexMode, orientation: HexOrientation,
    ) -> (i32, i32) {
        let [col, row] = hex.to_offset_coordinates(mode, orientation);
        (col, row)
    }

    #[external(v0)]
    fn from_offset_coordinates(
        self: @ContractState, col: i32, row: i32, mode: OffsetHexMode, orientation: HexOrientation,
    ) -> Hex {
        HexConversionsTrait::from_offset_coordinates([col, row], mode, orientation)
    }

    #[external(v0)]
    fn other_orientation(self: @ContractState, orientation: HexOrientation) -> HexOrientation {
        !orientation
    }

    #[external(v0)]
    fn default_orientation(self: @ContractState) -> HexOrientation {
        Default::default()
    }
}

/// N-7 and the coordinates of the board (M1-T3): `DirectionTrait::{rotate, arc}`, the conversions
/// between `Direction` and `EdgeDirection`, `GeometryTrait::{distance_between, chunk_of, to_hex,
/// from_hex, index_to_hex, hex_to_index}` and `LayoutTrait::neighbor_direction`.
#[starknet::contract]
pub mod HexxCoordinates {
    use hexx::board::direction::DirectionTrait;
    use hexx::board::geometry::GeometryTrait;
    use hexx::board::layout::LayoutTrait;
    use hexx::{Arc, Direction, EdgeDirection, Hex};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn rotate(self: @ContractState, direction: Direction, steps: u8) -> Direction {
        direction.rotate(steps)
    }

    #[external(v0)]
    fn arc(self: @ContractState, direction: Direction, facing: Direction) -> Arc {
        direction.arc(facing)
    }

    #[external(v0)]
    fn into_edge_direction(self: @ContractState, direction: Direction) -> EdgeDirection {
        direction.into()
    }

    #[external(v0)]
    fn into_direction(self: @ContractState, direction: EdgeDirection) -> Direction {
        direction.into()
    }

    #[external(v0)]
    fn distance_between(self: @ContractState, x1: u8, y1: u8, x2: u8, y2: u8) -> u16 {
        GeometryTrait::distance_between(x1, y1, x2, y2)
    }

    #[external(v0)]
    fn chunk_of(self: @ContractState, x: u8, y: u8) -> (u8, u8) {
        GeometryTrait::chunk_of(x, y)
    }

    #[external(v0)]
    fn to_hex(self: @ContractState, x: u8, y: u8) -> Hex {
        GeometryTrait::to_hex(x, y)
    }

    #[external(v0)]
    fn from_hex(self: @ContractState, hex: Hex) -> Option<(u8, u8)> {
        GeometryTrait::from_hex(hex)
    }

    #[external(v0)]
    fn index_to_hex(self: @ContractState, width: u8, position: u8) -> Hex {
        GeometryTrait::index_to_hex(width, position)
    }

    #[external(v0)]
    fn hex_to_index(self: @ContractState, width: u8, height: u8, hex: Hex) -> Option<u8> {
        GeometryTrait::hex_to_index(width, height, hex)
    }

    #[external(v0)]
    fn neighbor_direction(
        self: @ContractState, width: u8, height: u8, from: u8, to: u8,
    ) -> Option<Direction> {
        LayoutTrait::neighbor_direction(width, height, from, to)
    }
}

/// The line of sight (N-5, M1-T6): `LineTrait` and the mirror's `HexTrait::line_to`.
#[starknet::contract]
pub mod HexxLine {
    use hexx::board::line::LineTrait;
    use hexx::{Direction, Hex, HexMap, HexTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn line(self: @ContractState, map: HexMap, from: u8, to: u8) -> Option<felt252> {
        map.line(from, to)
    }

    #[external(v0)]
    fn line_of_sight(self: @ContractState, map: HexMap, from: u8, to: u8) -> bool {
        map.line_of_sight(from, to)
    }

    #[external(v0)]
    fn approach(self: @ContractState, map: HexMap, from: u8, to: u8) -> Option<Direction> {
        map.approach(from, to)
    }

    #[external(v0)]
    fn line_to(self: @ContractState, hex: Hex, other: Hex) -> Span<Hex> {
        hex.line_to(other)
    }
}
