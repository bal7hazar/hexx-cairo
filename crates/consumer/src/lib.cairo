//! Unpublished fixture: minimal Starknet contracts that consume `hexx`, so that
//! `scripts/bytecode_size.py` can track class size against the Starknet limits (plan, R-11).
//! Not part of what `hexx` publishes; depends on `starknet`, which `hexx` itself never does.
//!
//! One call site per public function of `HexMapTrait` (the 20 of the facade of the board
//! engine), so that the tracked class size follows the engine: a removed or dead-code-eliminated
//! item would otherwise go on shrinking it unnoticed (AGENTS.md, principle 11). Split over three
//! contracts: the 20 in one exceed the 81,920 CASM felts a class may hold. The extensions of
//! milestone L-M1 add their own contracts (`HexxAssembly`: N-3).

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
