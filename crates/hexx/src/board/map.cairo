//! HexMap struct and generation methods.
//!
//! The facade mirrors `origami_map::map::MapTrait` name for name, plus the hex additions. Every
//! method forwards to one library call (see `tests/bench_map.cairo` for the facade overhead).

// Core imports

#[feature("bounded-int-utils")]
use core::internal::bounded_int::{
    BoundedInt, ConstrainHelper, MulHelper, SubHelper, constrain, mul, sub,
};
use hexx::board::asserter::{Asserter, errors};
use hexx::board::bits::Bits;
use hexx::board::direction::Direction;
use hexx::board::geometry::Geometry;
use hexx::board::layout::{DilationTrait, LayoutTrait};

// Internal imports

use hexx::finders::bfs::{Bfs, BfsInternal};
use hexx::finders::dial::Dial;
use hexx::generators::caver::Caver;
use hexx::generators::digger::Digger;
use hexx::generators::mazer::Mazer;
use hexx::generators::spreader::Spreader;
use hexx::generators::walker::Walker;

// Constants

/// Largest board of the single-limb path, as in `finders::bfs`.
const SMALL_SIZE: u8 = 128;

/// `W * H` for any `u8` dimensions.
impl SizeMul of MulHelper<u8, u8> {
    type Result = BoundedInt<0, 65025>;
}

/// `position - W * H`.
impl PositionSub of SubHelper<u8, BoundedInt<0, 65025>> {
    type Result = BoundedInt<-65025, 255>;
}

/// Sign of `position - W * H`.
impl PositionConstrain of ConstrainHelper<BoundedInt<-65025, 255>, 0> {
    type LowT = BoundedInt<-65025, -1>;
    type HighT = BoundedInt<0, 255>;
}

/// Whether a position lies in the board, `position < W * H`, for any `u8` dimensions: a
/// `bounded_int` product, difference and sign, cheaper than a `u16` product and comparison (see
/// `GAS.md`, F1).
#[feature("bounded-int-utils")]
#[inline(always)]
fn is_inside(width: u8, height: u8, position: u8) -> bool {
    let size = mul::<_, _, SizeMul>(width, height);
    match constrain::<_, 0, PositionConstrain>(sub::<_, _, PositionSub>(position, size)) {
        Ok(_) => true,
        Err(_) => false,
    }
}

/// Types.
#[derive(Copy, Drop, Serde)]
pub struct HexMap {
    pub width: u8,
    pub height: u8,
    pub grid: felt252,
    pub seed: felt252,
}

/// Implementation of the `HexMapTrait` trait for the `HexMap` struct.
#[generate_trait]
pub impl HexMapImpl of HexMapTrait {
    /// Create a map from an existing grid, unchecked (the raw constructor, as in `origami_map`).
    /// The caller is responsible for valid dimensions (`W, H >= 3`, `W * H <= 251`) and for a grid
    /// without bits at or above `W * H`; the border ring is expected to be wall except for
    /// entrances. The dimensions are validated later by the functions that take them in charge:
    /// `open_with_corridor`, `open_with_maze`, `compute_distribution`, `search_path`,
    /// `search_path_weighted`, `field_of_movement`, `distance_to`, `reachable`, `range`, `ring` and
    /// `keep_component` (they panic on invalid dimensions or positions); `hex_distance`,
    /// `neighbor` and `is_walkable` only check their positions against `W * H`.
    /// # Arguments
    /// * `grid` - The grid of the map, `1` is walkable
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The corresponding map
    #[inline]
    fn new(grid: felt252, width: u8, height: u8, seed: felt252) -> HexMap {
        HexMap { width, height, grid, seed }
    }

    /// Create an empty map: every interior tile is walkable.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If the dimensions are invalid
    #[inline]
    fn new_empty(width: u8, height: u8, seed: felt252) -> HexMap {
        // [Check] Valid dimensions
        Asserter::assert_valid_dimension(width, height);
        // [Return] Interior mask
        HexMap { width, height, grid: LayoutTrait::interior(width, height), seed }
    }

    /// Create a map with a maze.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The order of the maze, 0 or 1, the higher the less dense
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If the dimensions are invalid or the order is above 1
    #[inline]
    fn new_maze(width: u8, height: u8, order: u8, seed: felt252) -> HexMap {
        let grid = Mazer::generate(width, height, order, seed);
        HexMap { width, height, grid, seed }
    }

    /// Create a map with a cave.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The number of generations of the automaton, 3 is a good default
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If the dimensions are invalid
    #[inline]
    fn new_cave(width: u8, height: u8, order: u8, seed: felt252) -> HexMap {
        let grid = Caver::generate(width, height, order, seed);
        HexMap { width, height, grid, seed }
    }

    /// Create a map with a random walk.
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `steps` - The number of steps
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If the dimensions are invalid
    #[inline]
    fn new_random_walk(width: u8, height: u8, steps: u16, seed: felt252) -> HexMap {
        let grid = Walker::generate(width, height, steps, seed);
        HexMap { width, height, grid, seed }
    }

    /// Create an empty hexagon of radius `radius` in its `(2R+3) x (2R+3)` rectangle.
    /// # Arguments
    /// * `radius` - The radius, at most 6
    /// * `seed` - The seed of the map
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If the radius is above 6
    #[inline]
    fn new_hexagon(radius: u8, seed: felt252) -> HexMap {
        // [Check] The rectangle fits in 251 bits
        let width = 2 * radius + 3;
        Asserter::assert_valid_dimension(width, width);
        // [Return] Hexagon mask
        HexMap { width, height: width, grid: LayoutTrait::hexagon(radius), seed }
    }

    /// Open the map with a corridor from an edge tile, until it touches an open tile.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The edge tile, not a corner
    /// * `order` - The order of the corridor, 0 or 1
    /// # Effects
    /// * The grid is updated
    /// # Panics
    /// * If the order is above 1, or the position is not an edge tile or is a corner
    #[inline]
    fn open_with_corridor(ref self: HexMap, position: u8, order: u8) {
        self
            .grid =
                Digger::corridor(self.width, self.height, order, position, self.grid, self.seed);
    }

    /// Open the map with a maze from an edge tile, merged with the open tiles it touches.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The edge tile, not a corner
    /// * `order` - The order of the maze, 0 or 1
    /// # Effects
    /// * The grid is updated
    /// # Panics
    /// * If the order is above 1, or the position is not an edge tile or is a corner
    #[inline]
    fn open_with_maze(ref self: HexMap, position: u8, order: u8) {
        self.grid = Digger::maze(self.width, self.height, order, position, self.grid, self.seed);
    }

    /// Keep only the walkable tiles reachable from a position (flood fill).
    /// # Arguments
    /// * `self` - The map
    /// * `position` - A walkable position
    /// # Effects
    /// * The grid is updated
    /// # Panics
    /// * If the position is outside the board or not walkable
    #[inline]
    fn keep_component(ref self: HexMap, position: u8) {
        self.grid = Bfs::reachable(self.grid, self.width, self.height, position);
    }

    /// Pick `count` walkable tiles uniformly.
    /// # Arguments
    /// * `self` - The map
    /// * `count` - The number of tiles to pick
    /// * `seed` - The seed of the draw
    /// # Returns
    /// * The bitmap of the picked tiles
    /// # Panics
    /// * If `count` exceeds the number of walkable tiles
    #[inline]
    fn compute_distribution(self: HexMap, count: u8, seed: felt252) -> felt252 {
        Spreader::generate(self.grid, self.width, self.height, count, seed)
    }

    /// Search the shortest path between two tiles (bit-parallel BFS).
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The starting position
    /// * `to` - The target position
    /// # Returns
    /// * The path from the target (included) to the start (excluded), empty if unreachable
    /// # Panics
    /// * If an endpoint is outside the board or not walkable
    #[inline]
    fn search_path(self: HexMap, from: u8, to: u8) -> Span<u8> {
        Bfs::search(self.grid, self.width, self.height, from, to)
    }

    /// Search the cheapest path between two tiles (bit-parallel Dial).
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The starting position
    /// * `to` - The target position
    /// * `costs` - `costs[k]` is the bitmap of the tiles of cost `k + 2`, at most 3 items, the
    /// other walkable tiles cost 1; a tile in several bitmaps takes the highest cost
    /// # Returns
    /// * The path from the target (included) to the start (excluded), empty if unreachable
    /// # Panics
    /// * If there are more than 3 cost classes, or an endpoint is outside the board or not
    /// walkable
    #[inline]
    fn search_path_weighted(self: HexMap, from: u8, to: u8, costs: Span<felt252>) -> Span<u8> {
        Dial::search(self.grid, self.width, self.height, from, to, costs)
    }

    /// Every tile reachable from a position with a total entry cost of at most `budget`.
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The starting position
    /// * `budget` - The movement budget
    /// * `costs` - The cost classes, as in `search_path_weighted`
    /// # Returns
    /// * The bitmap of the reachable tiles, `from` included
    /// # Panics
    /// * If there are more than 3 cost classes, or `from` is outside the board or not walkable
    #[inline]
    fn field_of_movement(self: HexMap, from: u8, budget: u8, costs: Span<felt252>) -> felt252 {
        Dial::field_of_movement(self.grid, self.width, self.height, from, budget, costs)
    }

    /// Length of the shortest path between two tiles through walkable tiles: walls block, as in
    /// `search_path`.
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The starting position
    /// * `to` - The target position
    /// # Returns
    /// * The number of steps, `None` if unreachable
    /// # Panics
    /// * If an endpoint is outside the board or not walkable
    #[inline]
    fn distance_to(self: HexMap, from: u8, to: u8) -> Option<u8> {
        Bfs::distance(self.grid, self.width, self.height, from, to)
    }

    /// Grid distance between two positions, ignoring walls.
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The first position
    /// * `to` - The second position
    /// # Returns
    /// * The distance
    /// # Panics
    /// * If a position is outside the board (`position >= W * H`)
    #[inline]
    fn hex_distance(self: HexMap, from: u8, to: u8) -> u8 {
        // [Check] Positions, a distance has no neutral value
        let (width, height) = (self.width, self.height);
        assert(
            is_inside(width, height, from) && is_inside(width, height, to),
            errors::ASSERTER_POSITION_NOT_INSIDE,
        );
        // [Return] Distance
        Geometry::distance(width, from, to)
    }

    /// Every tile reachable from a position.
    /// # Arguments
    /// * `self` - The map
    /// * `from` - The starting position
    /// # Returns
    /// * The bitmap of the reachable tiles, `from` included
    /// # Panics
    /// * If `from` is outside the board or not walkable
    #[inline]
    fn reachable(self: HexMap, from: u8) -> felt252 {
        Bfs::reachable(self.grid, self.width, self.height, from)
    }

    /// Every tile reachable within `range` steps of a position.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The centre position
    /// * `range` - The number of steps
    /// # Returns
    /// * The bitmap of the tiles in range, `position` included
    /// # Panics
    /// * If `position` is outside the board or not walkable
    #[inline]
    fn range(self: HexMap, position: u8, range: u8) -> felt252 {
        Bfs::tiles_within_range(self.grid, self.width, self.height, position, range)
    }

    /// Every tile at exactly `radius` steps of a position, `range(radius)` minus
    /// `range(radius - 1)`, in one flood: the flood of `radius - 2` layers returns the balls of
    /// radius `radius - 1` and `radius - 2`, one dilation of the first gives the ring, and the open
    /// edge tiles next to the first but not to the second are the edge tiles of the ring.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The centre position
    /// * `radius` - The number of steps
    /// # Returns
    /// * The bitmap of the ring, `position` alone for radius 0
    /// # Panics
    /// * If `position` is outside the board or not walkable
    fn ring(self: HexMap, position: u8, radius: u8) -> felt252 {
        // [Check] Dimensions and position
        let (grid, width, height) = (self.grid, self.width, self.height);
        let open: u256 = BfsInternal::check_one(grid, width, height, position);
        let power = Bits::pow(position);
        if radius == 0 {
            return power;
        }
        // [Compute] Constants and centre
        let (step, back, free) = BfsInternal::constants(open, width, height);
        let centre = BfsInternal::endpoint(@back, height, position);
        if !centre.interior {
            // [Return] An open edge centre: the inner ball is a subset of the outer one
            let outer = Bfs::tiles_within_range(grid, width, height, position, radius);
            return outer - Bfs::tiles_within_range(grid, width, height, position, radius - 1);
        }
        if radius == 1 {
            return Bits::to_felt(Bits::and(centre.around.into(), open));
        }
        // [Compute] Balls of radius `radius - 1` and `radius - 2`
        let first = Bits::and((centre.around + power).into(), free);
        let edges = grid - Bits::to_felt(free);
        if width * height <= SMALL_SIZE {
            let (ball, inner) = BfsInternal::flood_small(@step, first.low, free.low, radius - 2);
            let inner = if radius == 2 {
                power
            } else {
                inner
            };
            // [Compute] Interior tiles of the ring
            let near = step.expand_small(ball.try_into().unwrap());
            let ring: felt252 = (near & free.low).into() - ball;
            if edges == 0 {
                return ring;
            }
            // [Return] Plus the edge tiles next to the ball but not to the inner ball
            let edges: u128 = edges.try_into().unwrap();
            let far = step.expand_small(inner.try_into().unwrap());
            return ring + (near & edges).into() - (far & edges).into();
        }
        let (ball, inner) = BfsInternal::flood(@step, first, free, radius - 2);
        let inner = if radius == 2 {
            power
        } else {
            inner
        };
        // [Compute] Interior tiles of the ring
        let wide: u256 = ball.into();
        let (low, high) = step.dilate(wide.low, wide.high, ball);
        let near = u256 { low, high };
        let ring = Bits::to_felt(Bits::and(near, free)) - ball;
        if edges == 0 {
            return ring;
        }
        // [Return] Plus the edge tiles next to the ball but not to the inner ball
        let edges: u256 = edges.into();
        let wide: u256 = inner.into();
        let (low, high) = step.dilate(wide.low, wide.high, inner);
        let far = u256 { low, high };
        ring + Bits::to_felt(Bits::and(near, edges)) - Bits::to_felt(Bits::and(far, edges))
    }

    /// Neighbour of a position, `None` if the neighbour or the position is outside the board.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The position
    /// * `direction` - The direction
    /// # Returns
    /// * The neighbour position, `None` if `position >= W * H` or the neighbour is off the board
    #[inline]
    fn neighbor(self: HexMap, position: u8, direction: Direction) -> Option<u8> {
        let (width, height) = (self.width, self.height);
        if !is_inside(width, height, position) {
            return None;
        }
        LayoutTrait::neighbor(width, height, position, direction)
    }

    /// Whether a position is walkable.
    /// # Arguments
    /// * `self` - The map
    /// * `position` - The position
    /// # Returns
    /// * `true` if the tile is walkable, `false` if it is a wall or `position >= W * H`
    #[inline]
    fn is_walkable(self: HexMap, position: u8) -> bool {
        is_inside(self.width, self.height, position) && Bits::get(self.grid.into(), position)
    }

    /// Create a map with a cave given its margins (plan §6.2, N-1): the ring tiles of `fixed`
    /// take their value from `values` (the sides that face an already generated neighbour), the
    /// other tiles are drawn from the seed, and the automaton runs on the interior with the ring
    /// frozen and the global parity of the rows. The four corners are always wall (D-134).
    /// # Arguments
    /// * `width` - The width of the map
    /// * `height` - The height of the map
    /// * `order` - The number of generations of the automaton, 3 is a good default
    /// * `seed` - The seed of the map
    /// * `fixed` - The ring tiles whose value is given, masked to the ring
    /// * `values` - Their values, masked to `fixed`
    /// * `odd` - Whether local row 0 is a global odd row
    /// # Returns
    /// * The generated map
    /// # Panics
    /// * If `W < 3`, `H < 3` or `W * (H + 1) + 1 > 251`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.2, N-1).
    #[inline]
    fn new_cave_with_margins(
        width: u8, height: u8, order: u8, seed: felt252, fixed: felt252, values: felt252, odd: bool,
    ) -> HexMap {
        let grid = Caver::generate_with_margins(width, height, order, seed, fixed, values, odd);
        HexMap { width, height, grid, seed }
    }

    /// Run `order` generations of the cave automaton on the map (plan §6.2, N-1): the ring and
    /// the tiles of `held` keep their value (D-28), the rows have their global parity.
    /// # Arguments
    /// * `self` - The map
    /// * `order` - The number of generations
    /// * `held` - The tiles that keep their value, any tiles; the ring is always held
    /// * `odd` - Whether local row 0 is a global odd row
    /// # Returns
    /// * The smoothed map, same dimensions and seed
    /// # Panics
    /// * If `W < 3`, `H < 3` or `W * (H + 1) + 1 > 251`
    ///
    /// Mirrors nothing in `hexx`: an extension (plan §6.2, N-1).
    #[inline]
    fn smooth(self: HexMap, order: u8, held: felt252, odd: bool) -> HexMap {
        let (width, height) = (self.width, self.height);
        let grid = Caver::smooth(self.grid, width, height, order, held, odd);
        HexMap { width, height, grid, seed: self.seed }
    }
}

#[cfg(test)]
mod tests {
    // Internal imports

    use hexx::board::bits::Bits;
    use hexx::board::direction::Direction;
    use hexx::board::geometry::Geometry;
    use hexx::board::layout::LayoutTrait;
    use hexx::finders::bfs::Bfs;
    use hexx::finders::dial::Dial;
    use hexx::generators::caver::Caver;
    use hexx::generators::digger::Digger;
    use hexx::generators::mazer::Mazer;
    use hexx::generators::spreader::Spreader;
    use hexx::generators::walker::Walker;
    use hexx::tests::bench_dial::{CAVE_17X14_COST_2, CAVE_17X14_COST_3};
    use hexx::tests::fixtures::*;

    // Local imports

    use super::{HexMap, HexMapTrait};

    // Constants

    const SEED: felt252 = 'SEED';

    /// A map on the cave fixture.
    fn cave() -> HexMap {
        HexMapTrait::new(CAVE_17X14, 17, 14, SEED)
    }

    /// Every ring up to `max` equals `range(r) - range(r - 1)`.
    fn check_rings(map: HexMap, position: u8, max: u8) {
        assert!(map.ring(position, 0) == Bits::pow(position));
        let mut radius: u8 = 1;
        while radius != max {
            let expected = map.range(position, radius) - map.range(position, radius - 1);
            assert!(map.ring(position, radius) == expected);
            radius += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_map_new() {
        let map = HexMapTrait::new(CAVE_17X14, 17, 14, SEED);
        assert!(map.width == 17);
        assert!(map.height == 14);
        assert!(map.grid == CAVE_17X14);
        assert!(map.seed == SEED);
    }

    #[test]
    #[available_gas(l2_gas: 19740)]
    fn test_map_new_empty() {
        assert!(HexMapTrait::new_empty(17, 14, SEED).grid == EMPTY_17X14);
        assert!(HexMapTrait::new_empty(7, 7, SEED).grid == EMPTY_7X7);
        assert!(HexMapTrait::new_empty(3, 3, SEED).grid == Bits::pow(4));
    }

    #[test]
    #[available_gas(l2_gas: 11062076)]
    fn test_map_new_generators() {
        assert!(HexMapTrait::new_maze(17, 14, 0, SEED).grid == Mazer::generate(17, 14, 0, SEED));
        assert!(HexMapTrait::new_maze(19, 13, 1, SEED).grid == Mazer::generate(19, 13, 1, SEED));
        assert!(HexMapTrait::new_cave(17, 14, 3, SEED).grid == Caver::generate(17, 14, 3, SEED));
        let map = HexMapTrait::new_random_walk(7, 7, 50, SEED);
        assert!(map.grid == Walker::generate(7, 7, 50, SEED));
        assert!(map.width == 7 && map.height == 7 && map.seed == SEED);
    }

    #[test]
    #[available_gas(l2_gas: 438360)]
    fn test_map_new_hexagon() {
        //  0 0 0 0 0 0 0
        // 0 0 1 1 1 0 0
        //  0 1 1 1 1 0 0
        // 0 1 1 1 1 1 0
        //  0 1 1 1 1 0 0
        // 0 0 1 1 1 0 0
        //  0 0 0 0 0 0 0
        let map = HexMapTrait::new_hexagon(2, SEED);
        assert!(map.width == 7 && map.height == 7);
        assert!(map.grid == 0xe3c7cf0e00);
        let map = HexMapTrait::new_hexagon(6, SEED);
        assert!(map.width == 15 && map.height == 15);
        assert!(map.grid == LayoutTrait::hexagon(6));
        // Every tile of the hexagon is within `radius` of the centre
        assert!(map.range(112, 6) == map.grid);
    }

    #[test]
    #[available_gas(l2_gas: 188807)]
    fn test_map_open() {
        let mut map = cave();
        map.open_with_corridor(8, 0);
        assert!(map.grid == Digger::corridor(17, 14, 0, 8, CAVE_17X14, SEED));
        let mut map = HexMapTrait::new_empty(17, 14, SEED);
        map.open_with_maze(8, 1);
        assert!(map.grid == Digger::maze(17, 14, 1, 8, EMPTY_17X14, SEED));
    }

    #[test]
    #[available_gas(l2_gas: 711639)]
    fn test_map_keep_component() {
        let mut map = HexMapTrait::new(UNREACHABLE_17X14, 17, 14, SEED);
        map.keep_component(UNREACHABLE_17X14_FAR_FROM);
        let expected = Caver::keep_component(UNREACHABLE_17X14, 17, 14, UNREACHABLE_17X14_FAR_FROM);
        assert!(map.grid == expected);
        assert!(map.grid != UNREACHABLE_17X14);
        assert!(!map.is_walkable(UNREACHABLE_17X14_FAR_TO));
        let mut map = HexMapTrait::new(CAVE_7X7, 7, 7, SEED);
        map.keep_component(CAVE_7X7_FAR_FROM);
        assert!(map.grid == Caver::keep_component(CAVE_7X7, 7, 7, CAVE_7X7_FAR_FROM));
    }

    #[test]
    #[available_gas(l2_gas: 396779)]
    fn test_map_compute_distribution() {
        let objects = cave().compute_distribution(10, SEED);
        assert!(objects == Spreader::generate(CAVE_17X14, 17, 14, 10, SEED));
        assert!(Bits::popcount(objects.into()) == 10);
    }

    #[test]
    #[available_gas(l2_gas: 6795666)]
    fn test_map_finders() {
        let map = cave();
        let (from, to) = (CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO);
        let path = map.search_path(from, to);
        assert!(path == Bfs::search(CAVE_17X14, 17, 14, from, to));
        assert!(path.len() == CAVE_17X14_FAR_DISTANCE);
        assert!(map.distance_to(from, to) == Some(24));
        assert!(map.hex_distance(from, to) == Geometry::distance(17, from, to));
        let costs = array![CAVE_17X14_COST_2, CAVE_17X14_COST_3].span();
        let weighted = map.search_path_weighted(from, to, costs);
        assert!(weighted == Dial::search(CAVE_17X14, 17, 14, from, to, costs));
        let field = map.field_of_movement(from, 6, costs);
        assert!(field == Dial::field_of_movement(CAVE_17X14, 17, 14, from, 6, costs));
        assert!(map.reachable(from) == Bfs::reachable(CAVE_17X14, 17, 14, from));
        assert!(map.range(from, 4) == Bfs::tiles_within_range(CAVE_17X14, 17, 14, from, 4));
    }

    #[test]
    #[available_gas(l2_gas: 524727)]
    fn test_map_distance_unreachable() {
        let map = HexMapTrait::new(UNREACHABLE_17X14, 17, 14, SEED);
        let distance = map.distance_to(UNREACHABLE_17X14_FAR_FROM, UNREACHABLE_17X14_FAR_TO);
        assert!(distance.is_none());
        assert!(map.search_path(UNREACHABLE_17X14_FAR_FROM, UNREACHABLE_17X14_FAR_TO).len() == 0);
    }

    #[test]
    #[available_gas(l2_gas: 155508453)]
    fn test_map_ring_fused() {
        // No open edge tile, both limbs and single limb
        check_rings(cave(), CAVE_17X14_FAR_FROM, 30);
        check_rings(HexMapTrait::new(MAZE_17X14, 17, 14, SEED), MAZE_17X14_FAR_FROM, 60);
        check_rings(HexMapTrait::new(CAVE_7X7, 7, 7, SEED), CAVE_7X7_FAR_FROM, 8);
        check_rings(HexMapTrait::new(MAZE_7X7, 7, 7, SEED), MAZE_7X7_FAR_FROM, 16);
    }

    #[test]
    #[available_gas(l2_gas: 89899400)]
    fn test_map_ring_open_edge() {
        // Open edge tiles: one flood from the interior, two `range` calls from the entrance
        let mut map = cave();
        map.open_with_corridor(8, 0);
        check_rings(map, CAVE_17X14_FAR_FROM, 30);
        check_rings(map, 8, 30);
        let mut map = HexMapTrait::new(CAVE_7X7, 7, 7, SEED);
        map.open_with_corridor(3, 0);
        check_rings(map, CAVE_7X7_FAR_FROM, 8);
        check_rings(map, 3, 8);
    }

    #[test]
    #[available_gas(l2_gas: 231217)]
    fn test_map_ring_values() {
        //  0 0 0 0 0 0 0
        // 0 0 1 1 1 0 0
        //  0 1 0 0 1 0 0
        // 0 1 0 0 0 1 0
        //  0 1 0 0 1 0 0
        // 0 0 1 1 1 0 0
        //  0 0 0 0 0 0 0
        let map = HexMapTrait::new_empty(7, 7, SEED);
        assert!(map.ring(24, 2) == 0xe244490e00);
        assert!(Bits::popcount(map.ring(24, 1).into()) == 6);
        // The corners of the rectangle are at distance 3, nothing beyond
        assert!(map.ring(24, 3) == EMPTY_7X7 - LayoutTrait::hexagon(2));
        assert!(map.ring(24, 4) == 0);
    }

    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_map_neighbor() {
        let map = cave();
        assert!(map.neighbor(0, Direction::East).is_none());
        assert!(map.neighbor(0, Direction::West) == Some(1));
        assert!(
            map
                .neighbor(
                    20, Direction::NorthEast,
                ) == LayoutTrait::neighbor(17, 14, 20, Direction::NorthEast),
        );
        assert!(map.neighbor(237, Direction::NorthWest).is_none());
    }

    #[test]
    #[available_gas(l2_gas: 26148)]
    fn test_map_is_walkable() {
        let map = cave();
        assert!(map.is_walkable(CAVE_17X14_FAR_FROM));
        assert!(map.is_walkable(CAVE_17X14_FAR_TO));
        assert!(!map.is_walkable(0));
        assert!(!map.is_walkable(237));
    }

    #[test]
    #[available_gas(l2_gas: 43617)]
    fn test_map_neighbor_outside() {
        // Audit A4: position 9 is outside a 3x3 board (0..=8), `LayoutTrait::neighbor` alone
        // returns `Some(10)` West
        let map = HexMapTrait::new_empty(3, 3, 0);
        assert!(map.neighbor(9, Direction::West).is_none());
        let directions = array![
            Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
            Direction::SouthWest, Direction::SouthEast,
        ]
            .span();
        for direction in directions {
            assert!(map.neighbor(9, *direction).is_none());
            assert!(map.neighbor(255, *direction).is_none());
        }
        // The last tile of the board still has neighbours
        assert!(map.neighbor(8, Direction::SouthEast) == Some(4));
        assert!(map.neighbor(8, Direction::West).is_none());
    }

    #[test]
    #[available_gas(l2_gas: 19603)]
    fn test_map_is_walkable_outside() {
        // Audit A4: an unchecked grid with bit 9 set on a 3x3 board
        let map = HexMapTrait::new(0x200, 3, 3, 0);
        assert!(!map.is_walkable(9));
        assert!(!map.is_walkable(255));
        let map = HexMapTrait::new(0x1ff, 3, 3, 0);
        assert!(map.is_walkable(8));
        // Dimensions beyond `u8` products: every `u8` position is inside, no overflow
        let map = HexMapTrait::new(0x1, 255, 255, 0);
        assert!(map.is_walkable(0));
        assert!(!map.is_walkable(255));
    }

    #[test]
    #[available_gas(l2_gas: 57435)]
    fn test_map_distance_to_walls_block() {
        // Audit A4: 5x3, walkable 6 and 8, wall 7 between them: no path, walls are not crossed
        let map = HexMapTrait::new(0x140, 5, 3, 0);
        assert!(map.distance_to(6, 8).is_none());
        assert!(map.search_path(6, 8).len() == 0);
        // The grid distance ignores the wall
        assert!(map.hex_distance(6, 8) == 2);
    }

    #[test]
    #[available_gas(l2_gas: 10658)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_map_hex_distance_revert_from_outside() {
        HexMapTrait::new_empty(3, 3, 0).hex_distance(9, 0);
    }

    #[test]
    #[available_gas(l2_gas: 10658)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_map_hex_distance_revert_to_outside() {
        HexMapTrait::new_empty(3, 3, 0).hex_distance(4, 9);
    }

    #[test]
    #[available_gas(l2_gas: 1557670)]
    fn test_map_scenario_17x14() {
        // Cave, component of 113, corridor from 8, 10 objects, path from 8 to 202:
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        //  0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 E 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0
        //  0 * 1 1 1 1 0 1 1 1 1 0 0 0 0 0 0
        // 0 0 * 1 1 1 1 1 1 1 1 0 0 0 0 0 0
        //  0 0 * 1 1 1 1 1 1 0 0 0 0 0 0 0 0
        // 0 0 1 * 1 1 1 1 1 0 0 0 0 0 0 0 0
        //  0 1 1 * 1 1 1 1 1 1 0 0 0 0 0 0 0
        // 0 0 1 1 * * * * * 1 1 0 0 0 0 0 0
        //  0 1 1 1 0 0 0 0 * 0 0 0 0 0 0 0 0
        // 0 1 1 1 0 0 0 0 0 * 0 0 0 0 0 0 0
        //  0 1 1 1 0 0 0 0 0 * 0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0 0 0 * 0 0 0 0 0 0 0
        //  0 0 0 0 0 0 0 0 S 0 0 0 0 0 0 0 0
        let mut map = HexMapTrait::new_cave(17, 14, 3, SEED);
        map.keep_component(113);
        map.open_with_corridor(8, 0);
        assert!(map.grid == 0x400070003ef00ff807f003f803fe00ff80e10070403820001000100);
        let objects = map.compute_distribution(10, SEED);
        assert!(objects == 0x20000280000000000240000c00000010002800000000000);
        let path = map.search_path(8, 202);
        assert!(path.len() == 15);
        assert!(map.distance_to(8, 202) == Some(15));
    }

    #[test]
    #[available_gas(l2_gas: 487041)]
    fn test_map_scenario_7x7() {
        //  0 0 0 0 0 0 0
        // 0 0 0 1 1 0 0
        //  0 0 1 1 1 0 0
        // S * * * * 1 0
        //  0 0 0 0 * 1 0
        // 0 0 0 0 0 E 0
        //  0 0 0 0 0 0 0
        let mut map = HexMapTrait::new_cave(7, 7, 3, 'ORIGAMI');
        map.keep_component(24);
        map.open_with_corridor(27, 0);
        assert!(map.grid == 0x61cfc18100);
        // The open entrance is walkable: it can receive an object
        let objects = map.compute_distribution(10, 'ORIGAMI');
        assert!(objects == 0x6149c10100);
        assert!(map.search_path(27, 8).len() == 6);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_map_new_empty_revert_invalid_dimension() {
        HexMapTrait::new_empty(16, 16, SEED);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: invalid dimension')]
    fn test_map_new_hexagon_revert_radius() {
        HexMapTrait::new_hexagon(7, SEED);
    }

    #[test]
    #[available_gas(l2_gas: 69892)]
    #[should_panic(expected: 'Bfs: position not walkable')]
    fn test_map_keep_component_revert_wall() {
        let mut map = cave();
        map.keep_component(0);
    }

    #[test]
    #[available_gas(l2_gas: 133906)]
    #[should_panic(expected: 'Bfs: position not walkable')]
    fn test_map_ring_revert_wall() {
        cave().ring(0, 2);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_map_ring_revert_outside() {
        cave().ring(238, 2);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Dial: too many costs')]
    fn test_map_search_path_weighted_revert_costs() {
        let costs = array![0, 0, 0, 0].span();
        cave().search_path_weighted(CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO, costs);
    }

    #[test]
    #[available_gas(l2_gas: 10868)]
    #[should_panic(expected: 'Asserter: position is a corner')]
    fn test_map_open_with_corridor_revert_corner() {
        let mut map = cave();
        map.open_with_corridor(0, 0);
    }

    // N-1 (plan §6.2): `new_cave_with_margins` and `smooth`. The oracles of the automaton are in
    // `generators::caver`; here, the facade and the regression cases stated on `smooth`.

    /// The ring of 15 x 15.
    const RING_15X15: felt252 = 0x1fffe000c00180030006000c00180030006000c00180030006000ffff;
    /// The values of the sides in `test_caver_margins_stream`: two tiles in three open.
    const PATTERN: felt252 = 0x6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db6db;
    /// A chunk with open side tiles, as pinned by `test_caver_margins_stream`:
    /// `generate_with_margins(15, 15, 3, 'CAVE', ring, PATTERN, true)`.
    const CHUNK_15X15: felt252 = 0xdb69fff81ff47fec67dc8f9c1f7ffefffdff79fe73f9e7f05fe0b6da;
    /// The ring of 15 x 15 and 20 interior tiles.
    const HELD_15X15: felt252 = 0x1fffe100c0118003940f000d25180030006842c80189030806880ffff;

    #[test]
    #[available_gas(l2_gas: 965783)]
    fn test_map_new_cave_with_margins() {
        for odd in [false, true].span() {
            let map = HexMapTrait::new_cave_with_margins(
                15, 15, 3, SEED, RING_15X15, CHUNK_15X15, *odd,
            );
            let grid = Caver::generate_with_margins(15, 15, 3, SEED, RING_15X15, CHUNK_15X15, *odd);
            assert!(map.grid == grid);
            assert!(map.width == 15 && map.height == 15 && map.seed == SEED);
            // The given sides are those of the chunk, whose corners are wall (D-134)
            let ring: u256 = RING_15X15.into();
            assert!(Bits::and(map.grid.into(), ring) == Bits::and(CHUNK_15X15.into(), ring));
            assert!(!map.is_walkable(0) && !map.is_walkable(14));
            assert!(!map.is_walkable(210) && !map.is_walkable(224));
        }
        // The pinned stream, through the facade
        let map = HexMapTrait::new_cave_with_margins(15, 15, 3, 'CAVE', RING_15X15, PATTERN, true);
        assert!(map.grid == CHUNK_15X15);
    }

    #[test]
    #[available_gas(l2_gas: 1045068)]
    fn test_map_smooth() {
        let map = HexMapTrait::new(CHUNK_15X15, 15, 15, SEED);
        for odd in [false, true].span() {
            let smoothed = map.smooth(3, HELD_15X15, *odd);
            assert!(smoothed.grid == Caver::smooth(CHUNK_15X15, 15, 15, 3, HELD_15X15, *odd));
            assert!(smoothed.width == 15 && smoothed.height == 15 && smoothed.seed == SEED);
            // The ring and the held tiles keep their value
            let held: u256 = HELD_15X15.into();
            assert!(Bits::and(smoothed.grid.into(), held) == Bits::and(CHUNK_15X15.into(), held));
        }
        // No generation: the map itself
        assert!(map.smooth(0, 0, true).grid == CHUNK_15X15);
        // The parity of the rows matters
        assert!(map.smooth(3, 0, true).grid != map.smooth(3, 0, false).grid);
    }

    /// R-N1-1: 15 x 15, `odd = false`, live tiles `(0, 0)`, `(10, 12)`, `(11, 12)`, the ring
    /// held, one generation: the two interior tiles have one live neighbour each and die.
    #[test]
    #[available_gas(l2_gas: 92155)]
    fn test_map_smooth_r_n1_1() {
        let grid = 1 + Bits::pow(12 * 15 + 10) + Bits::pow(12 * 15 + 11);
        let map = HexMapTrait::new(grid, 15, 15, SEED);
        assert!(map.smooth(1, RING_15X15, false).grid == 1);
    }

    /// R-N1-3: 15 x 15, `odd = false`, live tiles `(14, 11)`, `(1, 12)`, `(1, 13)`, the ring
    /// held, one generation: no carry invents a neighbour of `(1, 13)`, both interior tiles die.
    #[test]
    #[available_gas(l2_gas: 94160)]
    fn test_map_smooth_r_n1_3() {
        let ring = Bits::pow(11 * 15 + 14);
        let grid = ring + Bits::pow(12 * 15 + 1) + Bits::pow(13 * 15 + 1);
        let map = HexMapTrait::new(grid, 15, 15, SEED);
        assert!(map.smooth(1, RING_15X15, false).grid == ring);
    }

    /// R-N1-6: 15 x 15, `odd = false`, the single live ring tile `(1, 0)`, the ring held, one
    /// generation: the grid is unchanged.
    #[test]
    #[available_gas(l2_gas: 83681)]
    fn test_map_smooth_r_n1_6() {
        let map = HexMapTrait::new(2, 15, 15, SEED);
        assert!(map.smooth(1, RING_15X15, false).grid == 2);
    }

    /// R-N1-5 (D-30): 17 x 14 is refused, by both functions.
    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_map_new_cave_with_margins_revert_too_large() {
        HexMapTrait::new_cave_with_margins(17, 14, 3, SEED, 0, 0, false);
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Caver: dimensions too large')]
    fn test_map_smooth_revert_too_large() {
        cave().smooth(3, 0, false);
    }

    // Benchmarks of `smooth` (plan §6.2, "Worst case"): 15 x 15, `held` the ring and 20 interior
    // tiles, `odd = true`, a chunk with open side tiles so that every plane has bits in both
    // limbs. A generation performs the same operations whatever the tiles. `(order 5 - order 1)
    // / 4` is a generation, `twice - once` a call; `new_cave_with_margins` on the inputs of
    // `bench_caver_generate_with_margins_15x15_order_3` gives the overhead of the facade.

    #[derive(Copy, Drop)]
    struct Bench {
        maps: [HexMap; 2],
        held: felt252,
        fixed: felt252,
        odd: bool,
    }

    #[generate_trait]
    impl Inputs of InputsTrait {
        /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
        #[inline(never)]
        fn get() -> Bench {
            Bench {
                maps: [
                    HexMap { width: 15, height: 15, grid: CHUNK_15X15, seed: 'CAVE' },
                    HexMap { width: 15, height: 15, grid: CHUNK_15X15 - 0x200, seed: 'CAVER' },
                ],
                held: HELD_15X15,
                fixed: RING_15X15,
                odd: true,
            }
        }

        /// A generation count, opaque as well.
        #[inline(never)]
        fn order(order: u8) -> u8 {
            order
        }

        /// `smooth` on the inputs, on one of the two maps.
        #[inline(never)]
        fn smooth(order: u8, second: bool) -> felt252 {
            let bench = Self::get();
            let [map, other] = bench.maps;
            let map = if second {
                other
            } else {
                map
            };
            map.smooth(Self::order(order), bench.held, bench.odd).grid
        }
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 99568)]
    fn bench_map_smooth_15x15_order_1() {
        assert!(Inputs::smooth(1, false) != 0);
    }

    /// The game-sized fixture.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 182887)]
    fn bench_map_smooth_15x15_order_3() {
        assert!(Inputs::smooth(3, false) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 357584)]
    fn bench_map_smooth_15x15_order_3_twice() {
        assert!(Inputs::smooth(3, false) != 0);
        assert!(Inputs::smooth(3, true) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 266207)]
    fn bench_map_smooth_15x15_order_5() {
        assert!(Inputs::smooth(5, false) != 0);
    }

    /// The domain-wide worst case.
    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 10681157)]
    fn bench_map_smooth_15x15_order_255() {
        assert!(Inputs::smooth(255, false) != 0);
    }

    #[test]
    #[inline(never)]
    #[available_gas(l2_gas: 193926)]
    fn bench_map_new_cave_with_margins_15x15_order_3() {
        let bench = Inputs::get();
        let [map, _] = bench.maps;
        let map = HexMapTrait::new_cave_with_margins(
            map.width, map.height, Inputs::order(3), map.seed, bench.fixed, bench.fixed, bench.odd,
        );
        assert!(map.grid != 0);
    }
}
