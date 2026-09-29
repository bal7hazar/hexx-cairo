//! Tests of N-8, the steps of the walkers (plan §6.9): `next_step`, `next_step_away` and
//! `distance` against a scalar oracle over every tile of the fixtures (both limb paths, 15 × 16
//! included) and several `blocked` sets, the regression cases R-N8-*, the tie-break, the
//! fallback to the walker's own layer, the `None` cases, and the two ticks of `bench_tick`: the
//! window assembled from 4 chunks, the flood capped at 15 layers (D-127) and the walkers in
//! ascending id order, `blocked` updated after each move.

// Internal imports

use hexx::board::assembly::{AssemblyTrait, Origin};
use hexx::board::bits::Bits;
use hexx::board::direction::Direction;
use hexx::board::layout::LayoutTrait;
use hexx::finders::bfs::Bfs;
use hexx::finders::flood::{Flood, FloodInternal, FloodTrait};
use hexx::generators::caver::Caver;
use hexx::tests::fixtures::*;
use hexx::tests::test_flood::{CAVE_15X16, CAVE_15X16_FROM, Oracle};

// Constants

const DIRECTIONS: [Direction; 6] = [
    Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
    Direction::SouthWest, Direction::SouthEast,
];

/// A spread pattern of blocked tiles: one tile in 5.
const SPREAD: felt252 = 0x84210842108421084210842108421084210842108421084210842108421084;

/// The origin of both windows of the ticks: `ox = oy = 7` on an odd chunk row, the worst case
/// of the assembly (`bench_assembly`).
const ORIGIN: Origin = Origin { cx: 3, cy: 5, ox: 7, oy: 7 };

// Oracle

/// The layers of a flood, tile by tile, from the scalar BFS (`Oracle::distances`).
#[derive(Drop)]
struct Board {
    grid: felt252,
    width: u8,
    height: u8,
    from: u8,
    depth: u8,
    /// The layer of each tile, `None` when it is in none.
    layers: Array<Option<u8>>,
    /// The board neighbours of each tile, lowest index first.
    around: Array<Span<u8>>,
    interior: u256,
}

/// The plain version of the contract (plan §6.9), neighbour by neighbour.
#[generate_trait]
impl Steps of StepsTrait {
    /// The flood, checked against the scalar BFS by `Oracle::check`, and its layers by tile.
    fn board(
        grid: felt252, width: u8, height: u8, from: u8, obstacles: felt252, depth: u8,
    ) -> (Flood, Board) {
        let flood = Oracle::check(grid, width, height, from, obstacles, depth);
        let mut distances = Oracle::distances(grid, width, height, from, obstacles);
        let deepest = flood.depth();
        let mut layers: Array<Option<u8>> = array![];
        let mut around: Array<Span<u8>> = array![];
        let size: u16 = width.into() * height.into();
        let mut tile: u16 = 0;
        while tile != size {
            let distance = distances.get(tile.into());
            if distance != 0 && distance - 1 <= deepest {
                layers.append(Option::Some(distance - 1));
            } else {
                layers.append(Option::None);
            }
            around.append(Self::sorted(width, height, tile.try_into().unwrap()).span());
            tile += 1;
        }
        let interior: u256 = LayoutTrait::interior(width, height).into();
        (flood, Board { grid, width, height, from, depth: deepest, layers, around, interior })
    }

    /// The board neighbours of a tile, lowest index first.
    fn neighbours(board: @Board, position: u8) -> Span<u8> {
        *board.around[position.into()]
    }

    /// The board neighbours of a tile, sorted.
    fn sorted(width: u8, height: u8, position: u8) -> Array<u8> {
        let mut found: Array<u8> = array![];
        for direction in DIRECTIONS.span() {
            if let Option::Some(next) = LayoutTrait::neighbor(width, height, position, *direction) {
                found.append(next);
            }
        }
        // [Compute] Sorted by selection: the least of those above the previous one
        let mut neighbours: Array<u8> = array![];
        let mut previous: u16 = 0;
        let mut first = true;
        loop {
            let mut least: u16 = 256;
            for next in found.span() {
                let next: u16 = (*next).into();
                if (first || next > previous) && next < least {
                    least = next;
                }
            }
            if least == 256 {
                break;
            }
            neighbours.append(least.try_into().unwrap());
            previous = least;
            first = false;
        }
        neighbours
    }

    fn layer(board: @Board, position: u8) -> Option<u8> {
        *board.layers[position.into()]
    }

    /// The least layer of the neighbours, `None` when none is in a layer.
    fn least(board: @Board, neighbours: Span<u8>) -> Option<u8> {
        let mut least: Option<u8> = Option::None;
        for next in neighbours {
            if let Option::Some(layer) = Self::layer(board, *next) {
                least = match least {
                    Option::Some(current) => if layer < current {
                        Option::Some(layer)
                    } else {
                        Option::Some(current)
                    },
                    Option::None => Option::Some(layer),
                };
            }
        }
        least
    }

    /// The lowest free neighbour in a layer.
    fn pick(board: @Board, neighbours: Span<u8>, layer: u8, blocked: u256) -> Option<u8> {
        for next in neighbours {
            if Self::layer(board, *next) == Option::Some(layer) && !Bits::get(blocked, *next) {
                return Option::Some(*next);
            }
        }
        Option::None
    }

    fn next_step(board: @Board, position: u8, blocked: felt252) -> Option<u8> {
        if position.into() >= board.layers.len() {
            return Option::None;
        }
        let neighbours = Self::neighbours(board, position);
        let blocked: u256 = blocked.into();
        let least = Self::least(board, neighbours)?;
        if let Option::Some(step) = Self::pick(board, neighbours, least, blocked) {
            return Option::Some(step);
        }
        if least + 1 <= *board.depth {
            return Self::pick(board, neighbours, least + 1, blocked);
        }
        Option::None
    }

    fn next_step_away(board: @Board, position: u8, blocked: felt252) -> Option<u8> {
        if position.into() >= board.layers.len() {
            return Option::None;
        }
        // [Compute] The free neighbour in the greatest layer, the first one met (lowest index)
        let blocked: u256 = blocked.into();
        let mut best: Option<(u8, u8)> = Option::None;
        for next in Self::neighbours(board, position) {
            let next = *next;
            if Bits::get(blocked, next) {
                continue;
            }
            if let Option::Some(layer) = Self::layer(board, next) {
                best = match best {
                    Option::Some((tile, current)) => if layer > current {
                        Option::Some((next, layer))
                    } else {
                        Option::Some((tile, current))
                    },
                    Option::None => Option::Some((next, layer)),
                };
            }
        }
        let (tile, _) = best?;
        Option::Some(tile)
    }

    fn distance(board: @Board, position: u8) -> Option<u8> {
        if position.into() >= board.layers.len() {
            return Option::None;
        }
        if let Option::Some(layer) = Self::layer(board, position) {
            return Option::Some(layer);
        }
        let least = Self::least(board, Self::neighbours(board, position))?;
        Option::Some(least + 1)
    }

    /// The property of a step: adjacent, walkable, not blocked, and interior or the source.
    fn assert_step(board: @Board, position: u8, blocked: felt252, step: u8) {
        let neighbours = Self::neighbours(board, position);
        let mut adjacent = false;
        for next in neighbours {
            adjacent = adjacent || *next == step;
        }
        assert!(adjacent, "{} -> {}: not adjacent", position, step);
        assert!(Bits::get((*board.grid).into(), step), "{} -> {}: wall", position, step);
        assert!(!Bits::get(blocked.into(), step), "{} -> {}: blocked", position, step);
        assert!(
            Bits::get(*board.interior, step) || step == *board.from,
            "{} -> {}: ring",
            position,
            step,
        );
    }

    /// Every function against its oracle, on every tile of the board and two tiles beyond it.
    fn check(flood: @Flood, board: @Board, blocked: felt252) {
        let size = *board.width * *board.height;
        let mut position: u8 = 0;
        loop {
            let step = flood.next_step(position, blocked);
            assert!(
                step == Self::next_step(board, position, blocked),
                "next_step({}, {}) {:?}",
                position,
                blocked,
                step,
            );
            let away = flood.next_step_away(position, blocked);
            assert!(
                away == Self::next_step_away(board, position, blocked),
                "next_step_away({}, {}) {:?}",
                position,
                blocked,
                away,
            );
            let distance = flood.distance(position);
            assert!(distance == Self::distance(board, position), "distance({})", position);
            if let Option::Some(step) = step {
                Self::assert_step(board, position, blocked, step);
            }
            if let Option::Some(step) = away {
                Self::assert_step(board, position, blocked, step);
            }
            if position == size + 1 || position == 255 {
                break;
            }
            position += 1;
        }
        assert!(flood.next_step(255, blocked).is_none());
    }

    /// The flood against the oracle, then every tile with no tile blocked, with the obstacles
    /// blocked, with a spread pattern and with every tile blocked.
    fn sweep(grid: felt252, width: u8, height: u8, from: u8, obstacles: felt252, depth: u8) {
        let (flood, board) = Self::board(grid, width, height, from, obstacles, depth);
        Self::check(@flood, @board, 0);
        Self::check(@flood, @board, obstacles);
        Self::check(@flood, @board, SPREAD);
        Self::check(@flood, @board, LayoutTrait::board(width, height));
    }

    /// The tick of the game: every walker, in ascending id order, takes `next_step` filtered by
    /// the current occupancy, which is updated after each move; checked move by move against
    /// the oracle, whose occupancy is updated the same way. Returns the moves.
    fn tick(
        flood: @Flood, board: @Board, walkers: Span<u8>, occupied: felt252,
    ) -> Array<Option<u8>> {
        let mut blocked = occupied;
        let mut moves: Array<Option<u8>> = array![];
        for walker in walkers {
            let step = flood.next_step(*walker, blocked);
            assert!(step == Self::next_step(board, *walker, blocked), "walker {}", *walker);
            if let Option::Some(step) = step {
                Self::assert_step(board, *walker, blocked, step);
                blocked = blocked - Bits::pow(*walker) + Bits::pow(step);
            }
            moves.append(step);
        }
        moves
    }

    /// The window of a tick, from its 4 chunks: the terrain and the occupancy.
    fn window(terrain: [felt252; 4], occupied: [felt252; 4]) -> (felt252, felt252) {
        let [t0, t1, t2, t3] = terrain;
        let [o0, o1, o2, o3] = occupied;
        let (map, occupied) = AssemblyTrait::window(
            [Option::Some(t0), Option::Some(t1), Option::Some(t2), Option::Some(t3)],
            [Option::Some(o0), Option::Some(o1), Option::Some(o2), Option::Some(o3)],
            @ORIGIN,
            0,
        );
        (map.grid, occupied)
    }

    /// The occupancy of walkers.
    fn occupancy(walkers: Span<u8>) -> felt252 {
        let mut occupied: felt252 = 0;
        for walker in walkers {
            occupied += Bits::pow(*walker);
        }
        occupied
    }

    /// The tile `(x, y)` of the window, `y · 15 + x`.
    fn at(x: u8, y: u8) -> u8 {
        LayoutTrait::index(15, x, y)
    }
}

// The regression cases of plan §6.9

#[test]
#[available_gas(l2_gas: 607545021)]
fn test_steps_r_n8_1() {
    // (1, 2) frozen, depth 182: 45 layers, (2, 2) at 45, (1, 2) inferred at 46 and steps onto 32
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 182);
    assert!(flood.depth() == 45);
    assert!(flood.distance(32) == Option::Some(45));
    assert!(flood.distance(31) == Option::Some(46));
    assert!(flood.next_step(31, 0) == Option::Some(32));
    Steps::sweep(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 182);
}

#[test]
#[available_gas(l2_gas: 437749454)]
fn test_steps_r_n8_2() {
    // The same at depth 15: (1, 2) is beyond the cap, it holds its position (D-127)
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 15);
    assert!(flood.depth() == 15);
    assert!(flood.next_step(31, 0) == Option::None);
    assert!(flood.distance(31) == Option::None);
    Steps::sweep(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 15);
}

#[test]
#[available_gas(l2_gas: 607975651)]
fn test_steps_r_n8_3() {
    // (1, 2) and (3, 2) frozen: (2, 2) is cut off, so (1, 2) gets None at every depth
    let obstacles: felt252 = 0x280000000;
    for depth in array![0_u8, 1, 15, 42, 43, 44, 182, 255] {
        let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, depth);
        assert!(flood.next_step(31, 0) == Option::None);
        assert!(flood.next_step(31, obstacles) == Option::None);
        assert!(flood.next_step_away(31, 0) == Option::None);
        assert!(flood.distance(31) == Option::None);
    }
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, 182);
    assert!(flood.depth() == 43);
    Steps::sweep(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, 182);
}

#[test]
#[available_gas(l2_gas: 74804008)]
fn test_steps_r_n8_4() {
    // The eight walkers of `SERPENTINE_15X16_8`, in ascending id order, `blocked` updated after
    // each move: W1 steps to (6, 2), W5 to (6, 12), the six behind them wait
    let walkers = SERPENTINE_15X16_WALKERS.span();
    assert!(Steps::occupancy(walkers) == SERPENTINE_15X16_8);
    let (flood, board) = Steps::board(
        SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, SERPENTINE_15X16_8, 182,
    );
    assert!(flood.depth() == 41);
    let moves = Steps::tick(@flood, @board, walkers, SERPENTINE_15X16_8);
    let none = Option::None;
    let expected = array![Option::Some(36), none, none, none, Option::Some(186), none, none, none];
    assert!(moves == expected);
    let mut distances: Array<Option<u8>> = array![];
    for walker in walkers {
        distances.append(flood.distance(*walker));
    }
    let expected = array![Option::Some(42), none, none, none, Option::Some(28), none, none, none];
    assert!(distances == expected);
}

#[test]
#[available_gas(l2_gas: 610975481)]
fn test_steps_r_n8_5() {
    // A walker on the ring, (0, 8), steps through its in-board neighbour (1, 8), in layer 6
    let grid = SERPENTINE_15X16 + Bits::pow(Steps::at(0, 8));
    let flood = Bfs::flood(grid, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    assert!(flood.next_step(Steps::at(0, 8), 0) == Option::Some(8 * 15 + 1));
    assert!(flood.distance(Steps::at(0, 8)) == Option::Some(7));
    // Every corner and every other ring tile of both boards, against the oracle
    Steps::sweep(grid, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
}

#[test]
#[available_gas(l2_gas: 1739124)]
fn test_steps_r_n8_6() {
    // (4, 8) at 3 on the flood of R-N8-1, both open neighbours blocked: the reverse scan visits
    // every layer from 45 down to 0 and finds nothing
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 182);
    let blocked = Bits::pow(Steps::at(3, 8)) + Bits::pow(Steps::at(5, 8));
    assert!(flood.distance(Steps::at(4, 8)) == Option::Some(3));
    assert!(flood.next_step_away(Steps::at(4, 8), blocked) == Option::None);
    // Unblocked, away is (3, 8) at 4 and towards is (5, 8) at 2
    assert!(flood.next_step_away(Steps::at(4, 8), 0) == Option::Some(Steps::at(3, 8)));
    assert!(flood.next_step(Steps::at(4, 8), 0) == Option::Some(Steps::at(5, 8)));
    // The one blocked towards the source leaves the walker's own layer, where nothing is free
    let blocked = Bits::pow(Steps::at(5, 8));
    assert!(flood.next_step(Steps::at(4, 8), blocked) == Option::None);
}

#[test]
#[available_gas(l2_gas: 109621010)]
fn test_steps_r_n8_7() {
    // 7 × 7, (1, 3) interior and (0, 3) an open edge tile
    let grid: felt252 = 0x600000;
    // From (1, 3): the edge tile is in no layer, inferred at 1, and steps onto the source
    let flood = Bfs::flood(grid, 7, 7, 22, 0, 25);
    assert!(flood.distance(21) == Option::Some(1));
    assert!(flood.next_step(21, 0) == Option::Some(22));
    assert!(flood.distance(22) == Option::Some(0));
    // From (0, 3): the walker on (1, 3), in layer 1, steps onto the open edge source
    let flood = Bfs::flood(grid, 7, 7, 21, 0, 25);
    assert!(flood.depth() == 1);
    assert!(flood.distance(22) == Option::Some(1));
    assert!(flood.distance(21) == Option::Some(0));
    assert!(flood.next_step(22, 0) == Option::Some(21));
    assert!(flood.next_step(22, Bits::pow(21)) == Option::None);
    assert!(flood.next_step_away(22, 0) == Option::Some(21));
    Steps::sweep(grid, 7, 7, 22, 0, 25);
    Steps::sweep(grid, 7, 7, 21, 0, 25);
}

// The tie-break, the fallback and the cap

#[test]
#[available_gas(l2_gas: 76048368)]
fn test_steps_ties_and_fallback() {
    // The empty 7 × 7 from (1, 1): (3, 2), in layer 2, has two neighbours in layer 1, 9 and 16
    let flood = Bfs::flood(EMPTY_7X7, 7, 7, 8, 0, 25);
    assert!(flood.next_step(17, 0) == Option::Some(9));
    assert!(flood.next_step(17, Bits::pow(9)) == Option::Some(16));
    // Both blocked: the free neighbour in the walker's own layer, 10
    assert!(flood.next_step(17, Bits::pow(9) + Bits::pow(16)) == Option::Some(10));
    // (5, 5), in the last layer (6): no layer 7 to fall back to
    assert!(flood.depth() == 6);
    assert!(flood.next_step(40, Bits::pow(33) + Bits::pow(39)) == Option::None);
    // Away from the source, the tie in the greatest layer goes to the lowest index as well:
    // (3, 2) has 18 and 24 in layer 3, (3, 3) has 25 and 32 in layer 4
    assert!(flood.next_step_away(17, 0) == Option::Some(18));
    assert!(flood.next_step_away(24, 0) == Option::Some(25));
    assert!(flood.next_step_away(24, Bits::pow(25)) == Option::Some(32));
    Steps::sweep(EMPTY_7X7, 7, 7, 8, 0, 25);
}

#[test]
#[available_gas(l2_gas: 288669646)]
fn test_steps_beyond_the_cap() {
    // Capped at 15: (5, 6) touches (6, 6) in layer 15 and steps onto it; blocked, it has no
    // layer 16 to fall back to
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 15);
    assert!(flood.distance(Steps::at(5, 6)) == Option::Some(16));
    assert!(flood.next_step(Steps::at(5, 6), 0) == Option::Some(Steps::at(6, 6)));
    assert!(flood.next_step(Steps::at(5, 6), Bits::pow(Steps::at(6, 6))) == Option::None);
    // (4, 6) is at 17: beyond the cap, None
    assert!(flood.next_step(Steps::at(4, 6), 0) == Option::None);
    assert!(flood.distance(Steps::at(4, 6)) == Option::None);
    // depth 0: the source's neighbours step onto it, nothing else moves
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 0);
    assert!(flood.next_step(Steps::at(8, 8), 0) == Option::Some(SERPENTINE_15X16_FROM));
    assert!(flood.next_step(Steps::at(9, 8), 0) == Option::None);
    assert!(flood.next_step(SERPENTINE_15X16_FROM, 0) == Option::None);
    assert!(flood.distance(SERPENTINE_15X16_FROM) == Option::Some(0));
    Steps::sweep(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 0);
}

#[test]
#[available_gas(l2_gas: 1355794)]
fn test_steps_outside() {
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    for position in array![240_u8, 241, 250, 251, 255] {
        assert!(flood.next_step(position, 0) == Option::None);
        assert!(flood.next_step_away(position, 0) == Option::None);
        assert!(flood.distance(position) == Option::None);
    }
    let flood = Bfs::flood(EMPTY_7X7, 7, 7, 8, 0, 25);
    for position in array![49_u8, 50, 127, 128, 255] {
        assert!(flood.next_step(position, 0) == Option::None);
        assert!(flood.next_step_away(position, 0) == Option::None);
        assert!(flood.distance(position) == Option::None);
    }
}

#[test]
#[available_gas(l2_gas: 66129066)]
fn test_steps_deterministic() {
    let flood = Bfs::flood(CAVE_15X16, 15, 16, CAVE_15X16_FROM, 0, 15);
    let mut position: u8 = 0;
    while position != 240 {
        assert!(flood.next_step(position, SPREAD) == flood.next_step(position, SPREAD));
        assert!(flood.next_step_away(position, SPREAD) == flood.next_step_away(position, SPREAD));
        position += 1;
    }
}

// The ticks of `bench_tick`

#[test]
#[available_gas(l2_gas: 268355833)]
fn test_steps_tick_cave() {
    // The window assembled from its 4 chunks is the cave, its occupancy the eight walkers
    let walkers = CAVE_15X16_WALKERS.span();
    let (grid, occupied) = Steps::window(CAVE_15X16_CHUNKS, CAVE_15X16_8_CHUNKS);
    assert!(grid == CAVE_15X16);
    assert!(occupied == CAVE_15X16_8);
    assert!(Steps::occupancy(walkers) == CAVE_15X16_8);
    // The flood capped at 15 on the occupancy frozen: the walkers at distances 3 to 15
    let (flood, board) = Steps::board(grid, 15, 16, CAVE_15X16_FROM, occupied, 15);
    assert!(flood.depth() == 15);
    let mut distances: Array<Option<u8>> = array![];
    for walker in walkers {
        distances.append(flood.distance(*walker));
    }
    let expected: Array<Option<u8>> = array![
        Option::Some(15), Option::Some(15), Option::Some(15), Option::Some(14), Option::Some(14),
        Option::Some(13), Option::Some(3), Option::Some(12),
    ];
    assert!(distances == expected);
    // Ascending id order: W1 takes 55, which W2 wanted, so W2 steps onto 42
    let moves = Steps::tick(@flood, @board, walkers, occupied);
    let expected: Array<Option<u8>> = array![
        Option::Some(55), Option::Some(42), Option::Some(57), Option::Some(71), Option::Some(73),
        Option::Some(86), Option::Some(96), Option::Some(102),
    ];
    assert!(moves == expected);
    assert!(flood.next_step(41, occupied) == Option::Some(55));
    // Every tile against the oracle, on the frozen and on the final occupancy
    Steps::check(@flood, @board, occupied);
    Steps::check(@flood, @board, Steps::occupancy(array![55, 42, 57, 71, 73, 86, 96, 102].span()));
}

#[test]
#[available_gas(l2_gas: 166742452)]
fn test_steps_tick_serpentine() {
    // The window assembled from its 4 chunks is the serpentine, its occupancy the eight walkers
    let walkers = SERPENTINE_15X16_WALKERS.span();
    let (grid, occupied) = Steps::window(SERPENTINE_15X16_CHUNKS, SERPENTINE_15X16_8_CHUNKS);
    assert!(grid == SERPENTINE_15X16);
    assert!(occupied == SERPENTINE_15X16_8);
    // Capped at 15, no walker is reached: each holds its position (D-127)
    let (flood, board) = Steps::board(grid, 15, 16, SERPENTINE_15X16_FROM, occupied, 15);
    assert!(flood.depth() == 15);
    let moves = Steps::tick(@flood, @board, walkers, occupied);
    let none: Option<u8> = Option::None;
    assert!(moves == array![none, none, none, none, none, none, none, none]);
    Steps::check(@flood, @board, occupied);
}

// Both limb paths, on the fixtures

#[test]
#[available_gas(l2_gas: 357841725)]
fn test_steps_sweep_7x7() {
    // The single limb
    Steps::sweep(EMPTY_7X7, 7, 7, EMPTY_7X7_FAR_FROM, 0, 25);
    Steps::sweep(CAVE_7X7, 7, 7, CAVE_7X7_NEAR_FROM, 0, 25);
    Steps::sweep(MAZE_7X7, 7, 7, MAZE_7X7_FAR_FROM, 0, 5);
    Steps::sweep(SERPENTINE_7X7, 7, 7, SERPENTINE_7X7_FAR_FROM, Bits::pow(22), 25);
    Steps::sweep(UNREACHABLE_7X7, 7, 7, UNREACHABLE_7X7_NEAR_FROM, 0, 25);
}

#[test]
#[available_gas(l2_gas: 194141466)]
fn test_steps_sweep_11x11() {
    // The single limb, 121 bits: the neighbourhoods of the last rows reach bit 120
    let grid = Caver::generate(11, 11, 3, 1);
    let mut from: u8 = 60;
    while !Bits::get(grid.into(), from) {
        from += 1;
    }
    Steps::sweep(grid, 11, 11, from, 0, 255);
}

#[test]
#[available_gas(l2_gas: 442519231)]
fn test_steps_sweep_cave_15x16() {
    // Two limbs: neighbourhoods in the low limb, the high limb and across both
    Steps::sweep(CAVE_15X16, 15, 16, CAVE_15X16_FROM, CAVE_15X16_8, 15);
}

#[test]
#[available_gas(l2_gas: 498594189)]
fn test_steps_sweep_cave_17x14() {
    Steps::sweep(CAVE_17X14, 17, 14, CAVE_17X14_FAR_FROM, 0, 255);
}

#[test]
#[available_gas(l2_gas: 276928822)]
fn test_steps_sweep_19x13() {
    // The largest board of the engine, 247 bits, from an open edge source (D-32)
    let grid = Caver::generate(19, 13, 3, 1);
    let edge: u8 = 19 * 6;
    Steps::sweep(grid + Bits::pow(edge), 19, 13, edge, 0, 255);
}

#[test]
#[available_gas(l2_gas: 465691399)]
fn test_steps_sweep_edge_source_17x14() {
    // An entrance: its interior neighbours step onto it, the other open edge tiles never are a
    // step
    let grid = EMPTY_17X14 + Bits::pow(85) + Bits::pow(16) + Bits::pow(8);
    Steps::sweep(grid, 17, 14, 85, 0, 255);
}

// The ring: the neighbourhood of a walker without the per-direction loop

#[test]
#[available_gas(l2_gas: 80581711)]
fn test_steps_tick_cave_ring() {
    // The cave tick with W8 on the ring, (14, 4), inferred at 13: it steps onto (13, 5)
    let walkers = CAVE_15X16_RING_WALKERS.span();
    let (grid, occupied) = Steps::window(CAVE_15X16_CHUNKS, CAVE_15X16_RING_CHUNKS);
    assert!(grid == CAVE_15X16);
    assert!(occupied == CAVE_15X16_RING);
    assert!(Steps::occupancy(walkers) == CAVE_15X16_RING);
    let (flood, board) = Steps::board(grid, 15, 16, CAVE_15X16_FROM, occupied, 15);
    assert!(flood.distance(74) == Option::Some(13));
    let moves = Steps::tick(@flood, @board, walkers, occupied);
    let expected: Array<Option<u8>> = array![
        Option::Some(55), Option::Some(42), Option::Some(57), Option::Some(71), Option::Some(73),
        Option::Some(86), Option::Some(96), Option::Some(88),
    ];
    assert!(moves == expected);
}

#[test]
#[available_gas(l2_gas: 108185581)]
fn test_steps_ring_neighbourhoods() {
    // Every tile of both limb paths, both row parities, odd and even heights: the walker's
    // neighbour bits are those of `LayoutTrait::edge_neighbours`, the taken-over reference
    let sizes: Array<(u8, u8)> = array![
        (3, 3), (7, 7), (11, 11), (8, 16), (15, 15), (15, 16), (17, 14), (19, 13),
    ];
    for (width, height) in sizes {
        let size = width * height;
        let flood = Bfs::flood(LayoutTrait::board(width, height), width, height, 0, 0, 0);
        let mut position: u8 = 0;
        while position != size {
            let (_, walker) = FloodInternal::walker(@flood, position).unwrap();
            let (x, y) = LayoutTrait::coords(width, position);
            assert!(walker.x == x && walker.y == y && walker.odd == (y % 2 == 1));
            assert!(
                walker.around == LayoutTrait::edge_neighbours(width, height, position),
                "{} x {}: {}",
                width,
                height,
                position,
            );
            position += 1;
        }
        assert!(FloodInternal::walker(@flood, size).is_none());
    }
}

#[test]
#[available_gas(l2_gas: 917906)]
fn test_steps_ring_corners() {
    // The four corners of 15 × 16, by hand: (0, 0) and (14, 0) on an even row, (0, 15) and
    // (14, 15) on an odd row
    let flood = Bfs::flood(LayoutTrait::board(15, 16), 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    let corners: Array<(u8, felt252)> = array![
        (0, Bits::pow(1) + Bits::pow(15)), (14, Bits::pow(13) + Bits::pow(28) + Bits::pow(29)),
        (225, Bits::pow(210) + Bits::pow(211) + Bits::pow(226)),
        (239, Bits::pow(224) + Bits::pow(238)),
    ];
    for (corner, around) in corners {
        let (_, walker) = FloodInternal::walker(@flood, corner).unwrap();
        assert!(walker.around == around, "corner {}", corner);
    }
    // On an open board flooded from its centre: (14, 0) and (0, 15) touch one interior tile
    // each, (0, 0) and (14, 15) none (their neighbours are ring tiles, in no layer)
    assert!(flood.next_step(0, 0) == Option::None);
    assert!(flood.next_step(14, 0) == Option::Some(28));
    assert!(flood.next_step(225, 0) == Option::Some(211));
    assert!(flood.next_step(239, 0) == Option::None);
    assert!(flood.next_step(14, Bits::pow(28)) == Option::None);
    assert!(flood.distance(0) == Option::None);
    assert!(flood.distance(14) == flood.distance(28).map(|d| d + 1));
}

#[test]
#[available_gas(l2_gas: 268604921)]
fn test_steps_ring_open_7x7_11x11() {
    // Every tile open, the ring included, against the oracle. The single limb
    Steps::sweep(LayoutTrait::board(7, 7), 7, 7, 24, 0, 25);
    Steps::sweep(LayoutTrait::board(11, 11), 11, 11, 60, SPREAD, 255);
}

#[test]
#[available_gas(l2_gas: 432184550)]
fn test_steps_ring_open_15x16() {
    Steps::sweep(LayoutTrait::board(15, 16), 15, 16, SERPENTINE_15X16_FROM, 0, 255);
}

#[test]
#[available_gas(l2_gas: 449399923)]
fn test_steps_ring_open_19x13() {
    Steps::sweep(LayoutTrait::board(19, 13), 19, 13, 123, 0, 255);
}
