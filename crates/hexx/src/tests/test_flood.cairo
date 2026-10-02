//! Tests of N-8, the flood of the tick (plan §6.9): the layers against a scalar oracle on the
//! fixtures (both limb paths, 15 × 16 included), the regression cases R-N8-* for what the flood
//! holds, `depth` at its boundaries, a disconnected source and the open edge source of D-32.

// Core imports

use core::dict::{Felt252Dict, Felt252DictTrait};

// Internal imports

use hexx::board::bits::Bits;
use hexx::board::direction::Direction;
use hexx::board::layout::LayoutTrait;
use hexx::finders::bfs::Bfs;
use hexx::finders::flood::{Flood, FloodTrait};
use hexx::generators::caver::Caver;
use hexx::tests::fixtures::*;

// Constants

const DIRECTIONS: [Direction; 6] = [
    Direction::East, Direction::NorthEast, Direction::NorthWest, Direction::West,
    Direction::SouthWest, Direction::SouthEast,
];

/// A cave window of 15 × 16, `Caver::generate(15, 16, 3, CAVE_15X16_SEED)` (114 open tiles): from
/// the adventurer's tile `(7, 8)` its flood is 16 layers deep, so the cap of 15 layers (D-127)
/// truncates it. The benchmark window of `bench_flood`.
///
/// 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
///  0 1 1 1 1 1 1 0 0 0 0 0 0 0 0
/// 0 1 1 1 1 1 1 1 1 1 0 0 0 0 0
///  0 1 1 1 1 1 1 1 1 1 0 0 1 0 0
/// 0 0 1 1 1 0 1 1 1 1 0 0 1 1 0
///  0 0 1 1 0 0 1 1 1 0 0 1 1 0 0
/// 0 1 1 1 1 0 1 1 1 1 0 1 1 1 0
///  0 1 1 0 0 1 1 # 1 0 0 1 1 0 0
/// 0 0 1 0 0 1 1 1 1 1 0 1 1 0 0
///  0 1 1 0 0 1 1 1 1 1 1 1 0 0 0
/// 0 1 1 1 0 0 0 0 1 1 1 1 1 0 0
///  0 1 1 1 0 0 0 0 1 1 1 1 1 0 0
/// 0 1 1 1 1 0 0 0 1 1 1 1 1 1 0
///  0 1 1 1 1 0 0 0 0 0 1 1 1 1 0
/// 0 0 0 1 1 0 0 0 0 0 0 1 0 0 0
///  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
pub const CAVE_15X16: felt252 = 0xfc01ff03fe43bcc6731ef733cc27d8cfe1c3e387c78fcf0786040000;
pub const CAVE_15X16_SEED: felt252 = 30;
pub const CAVE_15X16_FROM: u8 = 127;

/// A spread pattern of obstacles: one tile in 7, every row shifted.
const SCATTER: felt252 = 0x81020408102040810204081020408102040810204081020408102040810;

// Oracle

/// The plain version of the contract (plan §6.9): a breadth-first flood tile by tile.
#[generate_trait]
pub impl Oracle of OracleTrait {
    /// Scalar queue BFS from `from` through the walkable interior tiles outside `obstacles`: the
    /// scalar BFS of `Bfs` (`reference_all`) restricted to interior destinations (D-32), an edge
    /// source seeded by its neighbours. Distances plus one, 0 when unreached, by position.
    fn distances(
        grid: felt252, width: u8, height: u8, from: u8, obstacles: felt252,
    ) -> Felt252Dict<u8> {
        let interior: u256 = LayoutTrait::interior(width, height).into();
        let grid: u256 = grid.into();
        let obstacles: u256 = obstacles.into();
        let open = grid & interior & ~obstacles;
        let mut distances: Felt252Dict<u8> = Default::default();
        distances.insert(from.into(), 1);
        let mut queue: Array<u8> = array![from];
        while let Option::Some(current) = queue.pop_front() {
            let next = distances.get(current.into()) + 1;
            for direction in DIRECTIONS.span() {
                if let Option::Some(tile) =
                    LayoutTrait::neighbor(width, height, current, *direction) {
                    if Bits::get(open, tile) && distances.get(tile.into()) == 0 {
                        distances.insert(tile.into(), next);
                        queue.append(tile);
                    }
                }
            }
        }
        distances
    }

    /// The flood, checked against the oracle: `depth()` is the smaller of `depth` and the largest
    /// distance, layer `k` is every tile at distance `k`, layer 0 is `from`, no layer is empty
    /// and no layer after 0 holds an edge tile.
    fn check(
        grid: felt252, width: u8, height: u8, from: u8, obstacles: felt252, depth: u8,
    ) -> Flood {
        let flood = Bfs::flood(grid, width, height, from, obstacles, depth);
        let mut distances = Self::distances(grid, width, height, from, obstacles);
        // [Compute] The expected layers
        let mut expected: Felt252Dict<felt252> = Default::default();
        let mut deepest: u8 = 0;
        let size: u16 = width.into() * height.into();
        let mut tile: u16 = 0;
        while tile != size {
            let distance = distances.get(tile.into());
            if distance != 0 {
                let layer = distance - 1;
                if layer <= depth {
                    let bits = expected.get(layer.into());
                    expected.insert(layer.into(), bits + Bits::pow(tile.try_into().unwrap()));
                }
                if layer > deepest {
                    deepest = layer;
                }
            }
            tile += 1;
        }
        let expected_depth = if depth < deepest {
            depth
        } else {
            deepest
        };
        // [Check] The layers
        assert!(flood.width == width && flood.height == height);
        assert!(flood.depth() == expected_depth, "depth {} != {}", flood.depth(), expected_depth);
        assert!(flood.layers.len() == expected_depth.into() + 1);
        assert!(*flood.layers[0] == Bits::pow(from).into());
        let interior: u256 = LayoutTrait::interior(width, height).into();
        let mut layer: u8 = 0;
        while layer <= expected_depth {
            let bits = *flood.layers[layer.into()];
            assert!(bits != 0, "empty layer {}", layer);
            assert!(Bits::to_felt(bits) == expected.get(layer.into()), "layer {}", layer);
            if layer != 0 {
                assert!(bits & ~interior == 0);
            }
            layer += 1;
        }
        flood
    }

    /// The layer holding a tile, `None` when none does.
    fn layer_of(flood: @Flood, position: u8) -> Option<u8> {
        let mut layers = *flood.layers;
        let mut index: u8 = 0;
        while let Option::Some(layer) = layers.pop_front() {
            if Bits::get(*layer, position) {
                return Option::Some(index);
            }
            index += 1;
        }
        Option::None
    }

    /// The tile `(x, y)` of the window, `y · 15 + x`.
    fn at(x: u8, y: u8) -> u8 {
        LayoutTrait::index(15, x, y)
    }

    /// `SCATTER` without a tile.
    fn scatter(position: u8) -> felt252 {
        let scatter: u256 = SCATTER.into();
        let power: u256 = Bits::pow(position).into();
        Bits::to_felt(scatter & ~power)
    }

    /// Every tile of the flood.
    fn count(flood: @Flood) -> u16 {
        let mut layers = *flood.layers;
        let mut count: u16 = 0;
        while let Option::Some(layer) = layers.pop_front() {
            count += Bits::popcount(*layer).into();
        }
        count
    }

    /// Check the flood from every walkable tile, one in `stride`, at each depth of `depths`, with
    /// and without the scattered obstacles (a source among them is left out of them).
    fn sweep(grid: felt252, width: u8, height: u8, stride: u16, depths: Span<u8>) {
        let open: u256 = grid.into();
        let size: u16 = width.into() * height.into();
        let mut from: u16 = 0;
        while from < size {
            let source: u8 = from.try_into().unwrap();
            if Bits::get(open, source) {
                let scattered = Self::scatter(source);
                for depth in depths {
                    Self::check(grid, width, height, source, 0, *depth);
                    Self::check(grid, width, height, source, scattered, *depth);
                }
            }
            from += stride;
        }
    }
}

// The pinned corridor `SERPENTINE_15X16` (plan §6.9)

#[test]
#[available_gas(l2_gas: 17382309)]
fn test_flood_serpentine_hand_distances() {
    // The distances by hand of the plan, no obstacle: the deepest tile is (1, 2), at 46
    let flood = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    assert!(flood.depth() == 46);
    let hand: Array<(u8, u8, u8)> = array![
        (7, 8, 0), (13, 8, 6), (13, 7, 7), (13, 6, 8), (2, 6, 19), (1, 6, 20), (1, 5, 20),
        (2, 4, 21), (13, 4, 32), (13, 3, 33), (13, 2, 34), (2, 2, 45), (1, 2, 46), (2, 8, 5),
        (1, 9, 6), (1, 10, 7), (2, 10, 7), (13, 10, 18), (13, 11, 19), (13, 12, 20), (6, 12, 27),
        (1, 12, 32),
    ];
    for (x, y, distance) in hand {
        assert!(
            Oracle::layer_of(@flood, Oracle::at(x, y)) == Option::Some(distance), "({}, {})", x, y,
        );
    }
    assert!(Oracle::count(@flood) == 83);
}

#[test]
#[available_gas(l2_gas: 14549794)]
fn test_flood_r_n8_1() {
    // (1, 2) frozen, depth 182: 82 tiles reached, (2, 2) at 45, (1, 2) in no layer
    let flood = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 182);
    assert!(flood.depth() == 45);
    assert!(Oracle::layer_of(@flood, 32) == Option::Some(45));
    assert!(Oracle::layer_of(@flood, 31) == Option::None);
    assert!(Oracle::count(@flood) == 82);
}

#[test]
#[available_gas(l2_gas: 12215367)]
fn test_flood_r_n8_2() {
    // The same at depth 15: truncated, neither (2, 2) nor (1, 2) in a layer
    let flood = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 15);
    assert!(flood.depth() == 15);
    assert!(Oracle::layer_of(@flood, 32) == Option::None);
    assert!(Oracle::layer_of(@flood, 31) == Option::None);
}

#[test]
#[available_gas(l2_gas: 91023383)]
fn test_flood_r_n8_3() {
    // (1, 2) and (3, 2) frozen: (2, 2) cut off at every depth, 80 tiles, (4, 2) the deepest at 43
    let obstacles: felt252 = 0x280000000;
    let flood = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, 182);
    assert!(flood.depth() == 43);
    assert!(Oracle::layer_of(@flood, Oracle::at(4, 2)) == Option::Some(43));
    assert!(Oracle::count(@flood) == 80);
    for depth in array![0_u8, 15, 42, 43, 44, 255] {
        let flood = Oracle::check(
            SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, depth,
        );
        assert!(Oracle::layer_of(@flood, 32) == Option::None);
        assert!(Oracle::layer_of(@flood, 31) == Option::None);
    }
}

#[test]
#[available_gas(l2_gas: 16041373)]
fn test_flood_r_n8_4() {
    // The eight walkers frozen: the east branch cut at (5, 2), the west one at (5, 12)
    let flood = Oracle::check(
        SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, SERPENTINE_15X16_8, 182,
    );
    assert!(flood.depth() == 41);
    assert!(Oracle::layer_of(@flood, Oracle::at(6, 2)) == Option::Some(41));
    assert!(Oracle::layer_of(@flood, Oracle::at(6, 12)) == Option::Some(27));
    assert!(Oracle::count(@flood) == 73);
    let walkers: Array<(u8, u8)> = array![
        (5, 2), (4, 2), (3, 2), (2, 2), (5, 12), (4, 12), (3, 12), (2, 12), (1, 2), (1, 12),
    ];
    for (x, y) in walkers {
        assert!(Oracle::layer_of(@flood, Oracle::at(x, y)) == Option::None);
    }
}

#[test]
#[available_gas(l2_gas: 13785875)]
fn test_flood_r_n8_5() {
    // A ring tile, even open, is in no layer; its in-board neighbour (1, 8) is in layer 6
    let grid = SERPENTINE_15X16 + Bits::pow(Oracle::at(0, 8));
    let flood = Oracle::check(grid, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    assert!(Oracle::layer_of(@flood, Oracle::at(1, 8)) == Option::Some(6));
    assert!(Oracle::layer_of(@flood, Oracle::at(0, 8)) == Option::None);
}

#[test]
#[available_gas(l2_gas: 13429099)]
fn test_flood_r_n8_6() {
    // The flood of R-N8-1 around (4, 8): (5, 8) at 2, (4, 8) at 3, (3, 8) at 4
    let flood = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, 182);
    assert!(Oracle::layer_of(@flood, Oracle::at(5, 8)) == Option::Some(2));
    assert!(Oracle::layer_of(@flood, Oracle::at(4, 8)) == Option::Some(3));
    assert!(Oracle::layer_of(@flood, Oracle::at(3, 8)) == Option::Some(4));
}

#[test]
#[available_gas(l2_gas: 671795)]
fn test_flood_r_n8_7_interior_source() {
    // 7 × 7, (1, 3) and the open edge tile (0, 3): from (1, 3), the edge tile is in no layer
    let grid: felt252 = 0x600000;
    let flood = Oracle::check(grid, 7, 7, 22, 0, 25);
    assert!(flood.depth() == 0);
    let expected: Array<u256> = array![0x400000];
    assert!(flood.layers == expected.span());
}

#[test]
#[available_gas(l2_gas: 869624)]
fn test_flood_r_n8_7_edge_source() {
    // From the open edge tile (0, 3): layer 0 is the source, layer 1 its interior neighbour
    let grid: felt252 = 0x600000;
    let flood = Oracle::check(grid, 7, 7, 21, 0, 25);
    assert!(flood.depth() == 1);
    let expected: Array<u256> = array![0x200000, 0x400000];
    assert!(flood.layers == expected.span());
}

// `depth` at its boundaries

#[test]
#[available_gas(l2_gas: 161004445)]
fn test_flood_depths_serpentine() {
    // 0, 1, the game's 15, around the reach (45 with (1, 2) frozen) and beyond it
    for depth in array![0_u8, 1, 2, 3, 4, 5, 15, 44, 45, 46, 47, 182, 255] {
        let flood = Oracle::check(
            SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0x80000000, depth,
        );
        let expected = if depth < 45 {
            depth
        } else {
            45
        };
        assert!(flood.depth() == expected);
    }
    // `depth = 0` is not special: layer 0 only
    let flood = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 0);
    let source: u256 = Bits::pow(SERPENTINE_15X16_FROM).into();
    assert!(flood.layers == array![source].span());
}

#[test]
#[available_gas(l2_gas: 42139451)]
fn test_flood_depths_small() {
    // The single-limb path: 0, 1, 15, and around the reach of the deepest fixtures (13 and 14)
    for depth in array![0_u8, 1, 2, 12, 13, 14, 15, 255] {
        Oracle::check(SERPENTINE_7X7, 7, 7, SERPENTINE_7X7_FAR_FROM, 0, depth);
        Oracle::check(MAZE_7X7, 7, 7, MAZE_7X7_FAR_FROM, 0, depth);
    }
}

// A disconnected source

#[test]
#[available_gas(l2_gas: 12335169)]
fn test_flood_disconnected_source() {
    // Every neighbour of the source frozen: layer 0 only, at every depth
    let obstacles = LayoutTrait::edge_neighbors(15, 16, SERPENTINE_15X16_FROM);
    for depth in array![0_u8, 1, 15, 255] {
        let flood = Oracle::check(
            SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, obstacles, depth,
        );
        assert!(flood.depth() == 0);
    }
    // A walled-in source on the single limb, and a corner source with no interior neighbour
    let obstacles = LayoutTrait::edge_neighbors(7, 7, UNREACHABLE_7X7_NEAR_FROM);
    let flood = Oracle::check(UNREACHABLE_7X7, 7, 7, UNREACHABLE_7X7_NEAR_FROM, obstacles, 255);
    assert!(flood.depth() == 0);
    let flood = Oracle::check(EMPTY_17X14 + 1, 17, 14, 0, 0, 255);
    assert!(flood.depth() == 0);
}

// Open edge sources (D-32)

#[test]
#[available_gas(l2_gas: 219569889)]
fn test_flood_edge_sources() {
    // Two limbs: an entrance on each side of an empty board and on a cave
    let edges: Array<u8> = array![85, 16, 8, 229];
    for edge in edges {
        let flood = Oracle::check(EMPTY_17X14 + Bits::pow(edge), 17, 14, edge, 0, 255);
        assert!(flood.depth() != 0);
        Oracle::check(EMPTY_17X14 + Bits::pow(edge), 17, 14, edge, SCATTER, 7);
    }
    // Other open edge tiles next to the flood never enter it
    let grid = EMPTY_17X14 + Bits::pow(85) + Bits::pow(16) + Bits::pow(8);
    Oracle::check(grid, 17, 14, 85, 0, 255);
    Oracle::check(grid, 17, 14, EMPTY_17X14_FAR_FROM, 0, 255);
    // One limb
    let grid = CAVE_7X7 + Bits::pow(14) + Bits::pow(20);
    Oracle::check(grid, 7, 7, 14, 0, 255);
    Oracle::check(grid, 7, 7, 20, 0, 1);
    Oracle::check(grid, 7, 7, 20, 0, 255);
}

// Obstacles

#[test]
#[available_gas(l2_gas: 14745373)]
fn test_flood_obstacles_off_the_interior() {
    // Obstacles on the ring and beyond the board change nothing
    let ring: felt252 = LayoutTrait::board(15, 16) - LayoutTrait::interior(15, 16);
    let beyond: felt252 = Bits::pow(240) + Bits::pow(250);
    let plain = Bfs::flood(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, 0, 255);
    let other = Oracle::check(SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, ring + beyond, 255);
    assert!(plain.layers == other.layers);
}

// The fixtures, both limb paths

#[test]
#[available_gas(l2_gas: 854892990)]
fn test_flood_fixtures_17x14() {
    let depths = array![0_u8, 1, 15, 255];
    let fixtures: Array<(felt252, u8, u8)> = array![
        (EMPTY_17X14, EMPTY_17X14_NEAR_FROM, EMPTY_17X14_FAR_FROM),
        (CAVE_17X14, CAVE_17X14_NEAR_FROM, CAVE_17X14_FAR_FROM),
        (MAZE_17X14, MAZE_17X14_NEAR_FROM, MAZE_17X14_FAR_FROM),
        (SERPENTINE_17X14, SERPENTINE_17X14_NEAR_FROM, SERPENTINE_17X14_FAR_FROM),
        (UNREACHABLE_17X14, UNREACHABLE_17X14_NEAR_FROM, UNREACHABLE_17X14_FAR_FROM),
    ];
    for (grid, near, far) in fixtures {
        for depth in depths.span() {
            Oracle::check(grid, 17, 14, near, 0, *depth);
            Oracle::check(grid, 17, 14, far, 0, *depth);
            Oracle::check(grid, 17, 14, far, Oracle::scatter(far), *depth);
        }
    }
}

#[test]
#[available_gas(l2_gas: 290190665)]
fn test_flood_sweep_empty_7x7() {
    Oracle::sweep(EMPTY_7X7, 7, 7, 1, array![1_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 247590514)]
fn test_flood_sweep_cave_7x7() {
    Oracle::sweep(CAVE_7X7, 7, 7, 1, array![1_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 128723143)]
fn test_flood_sweep_maze_7x7() {
    Oracle::sweep(MAZE_7X7, 7, 7, 1, array![3_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 130396032)]
fn test_flood_sweep_unreachable_7x7() {
    Oracle::sweep(UNREACHABLE_7X7, 7, 7, 1, array![1_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 227639744)]
fn test_flood_sweep_serpentine_15x16() {
    Oracle::sweep(SERPENTINE_15X16, 15, 16, 11, array![15_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 32865073)]
fn test_flood_cave_15x16() {
    assert!(Caver::generate(15, 16, 3, CAVE_15X16_SEED) == CAVE_15X16);
    // From the adventurer's tile: 16 layers, truncated at 15 by the game's cap
    let flood = Oracle::check(CAVE_15X16, 15, 16, CAVE_15X16_FROM, 0, 255);
    assert!(flood.depth() == 16);
    let flood = Oracle::check(CAVE_15X16, 15, 16, CAVE_15X16_FROM, 0, 15);
    assert!(flood.depth() == 15);
}

#[test]
#[available_gas(l2_gas: 551929856)]
fn test_flood_sweep_cave_15x16() {
    Oracle::sweep(CAVE_15X16, 15, 16, 13, array![15_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 259503099)]
fn test_flood_sweep_random_caves_11x11() {
    // The single limb, 121 bits
    Oracle::sweep(Caver::generate(11, 11, 3, 1), 11, 11, 5, array![4_u8, 255].span());
    Oracle::sweep(Caver::generate(11, 11, 3, 2), 11, 11, 5, array![4_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 242961565)]
fn test_flood_sweep_random_caves_19x13() {
    // Two limbs, 247 bits: the largest board of the engine
    Oracle::sweep(Caver::generate(19, 13, 3, 1), 19, 13, 29, array![4_u8, 255].span());
}

#[test]
#[available_gas(l2_gas: 970362)]
fn test_flood_deterministic() {
    let first = Bfs::flood(CAVE_15X16, 15, 16, CAVE_15X16_FROM, SCATTER, 255);
    let second = Bfs::flood(CAVE_15X16, 15, 16, CAVE_15X16_FROM, SCATTER, 255);
    assert!(first.layers == second.layers);
}

// Panics

#[test]
#[available_gas(l2_gas: 14777)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_flood_revert_wall() {
    Bfs::flood(SERPENTINE_15X16, 15, 16, Oracle::at(7, 7), 0, 15);
}

#[test]
#[available_gas(l2_gas: 19232)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_flood_revert_obstacle() {
    Bfs::flood(
        SERPENTINE_15X16, 15, 16, SERPENTINE_15X16_FROM, Bits::pow(SERPENTINE_15X16_FROM), 15,
    );
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_flood_revert_outside() {
    Bfs::flood(SERPENTINE_15X16, 15, 16, 240, 0, 15);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_flood_revert_dimension() {
    Bfs::flood(SERPENTINE_15X16, 16, 16, SERPENTINE_15X16_FROM, 0, 15);
}
