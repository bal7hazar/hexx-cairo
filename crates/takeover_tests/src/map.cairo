//! `map` of 1.8.0 against `hexx::board::map`: `HexMap` and the 20 functions of `HexMapTrait`
//! (`new`, `new_empty`, `new_maze`, `new_cave`, `new_random_walk`, `new_hexagon`,
//! `open_with_corridor`, `open_with_maze`, `keep_component`, `compute_distribution`,
//! `search_path`, `search_path_weighted`, `field_of_movement`, `distance_to`, `hex_distance`,
//! `reachable`, `range`, `ring`, `neighbor`, `is_walkable`), through the root re-exports of both
//! packages (`origami_hexmap::{HexMap, HexMapTrait}`, `hexx::{HexMap, HexMapTrait}`).
//!
//! Inputs: the generators as in `caver`, `mazer`, `walker`, `digger` and `spreader`; the finders
//! as in `bfs` and `dial`; the queries on `common::query_positions` and `common::query_pairs`.

use hexx::HexMapTrait as H;
use origami_hexmap::HexMapTrait as O;
use crate::common::{
    RADII, SEEDS, assert_maps, below, costs, endpoints, generator_seed, hexx_direction, input_grid,
    origami_direction, query_pairs, query_positions, sides, sources, tiles, valid_dimensions,
};
use crate::fixtures::{EMPTY_17X14, EMPTY_7X7, ENDPOINTS, UNREACHABLE_7X7, boards};
use crate::walker::STEPS;

// Generators.

fn check_new_maze(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let mut order: u8 = 0;
        while order != 2 {
            assert_maps(
                O::new_maze(width, height, order, seed), H::new_maze(width, height, order, seed),
            );
            order += 1;
        }
        index += 1;
    }
}

fn check_new_cave(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let mut order: u8 = 0;
        while order != 6 {
            assert_maps(
                O::new_cave(width, height, order, seed), H::new_cave(width, height, order, seed),
            );
            order += 1;
        }
        index += 1;
    }
}

fn check_new_random_walk(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        for steps in STEPS.span() {
            assert_maps(
                O::new_random_walk(width, height, *steps, seed),
                H::new_random_walk(width, height, *steps, seed),
            );
        }
        index += 1;
    }
}

/// Both orders from a seeded side tile of `common::input_grid`, `corridor` or `maze`.
fn check_open(width: u8, height: u8, corridor: bool, first: u32, last: u32) {
    let sides = sides(width, height);
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let grid = input_grid(width, height, index);
        let start = *sides.at(below('start', index, sides.len()));
        let mut order: u8 = 0;
        while order != 2 {
            let mut lhs = O::new(grid, width, height, seed);
            let mut rhs = H::new(grid, width, height, seed);
            if corridor {
                O::open_with_corridor(ref lhs, start, order);
                H::open_with_corridor(ref rhs, start, order);
            } else {
                O::open_with_maze(ref lhs, start, order);
                H::open_with_maze(ref rhs, start, order);
            }
            assert_maps(lhs, rhs);
            order += 1;
        }
        index += 1;
    }
}

fn check_open_with_corridor(width: u8, height: u8, first: u32, last: u32) {
    check_open(width, height, true, first, last);
}

fn check_open_with_maze(width: u8, height: u8, first: u32, last: u32) {
    check_open(width, height, false, first, last);
}

/// From a seeded floor tile of `common::input_grid` (tag `'floor'`, as in `caver`).
fn check_keep_component(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let grid = input_grid(width, height, index);
        let floor = tiles(grid);
        if floor.len() != 0 {
            let from = *floor.at(below('floor', index, floor.len()));
            let mut lhs = O::new(grid, width, height, seed);
            let mut rhs = H::new(grid, width, height, seed);
            O::keep_component(ref lhs, from);
            H::keep_component(ref rhs, from);
            assert_maps(lhs, rhs);
        }
        index += 1;
    }
}

/// A seeded count (tag `'count'`, as in `spreader`) and the full count.
fn check_compute_distribution(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let grid = input_grid(width, height, index);
        let total = tiles(grid).len();
        let count: u8 = below('count', index, total + 1).try_into().unwrap();
        let full: u8 = total.try_into().unwrap();
        let (lhs, rhs) = (O::new(grid, width, height, seed), H::new(grid, width, height, seed));
        for count in [count, full].span() {
            assert(
                O::compute_distribution(
                    lhs, *count, seed,
                ) == H::compute_distribution(rhs, *count, seed),
                'compute_distribution',
            );
        }
        index += 1;
    }
}

// Finders.

fn check_search_path(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for (from, to) in endpoints(index, grid, width, height) {
            assert(O::search_path(lhs, from, to) == H::search_path(rhs, from, to), 'search_path');
        }
        index += 1;
    }
}

fn check_search_path_weighted(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut input: u32 = 1000 * index;
        for (from, to) in endpoints(index, grid, width, height) {
            let costs = costs(input, width, height);
            let left = O::search_path_weighted(lhs, from, to, costs);
            let right = H::search_path_weighted(rhs, from, to, costs);
            assert(left == right, 'search_path_weighted');
            input += 1;
        }
        index += 1;
    }
}

fn check_field_of_movement(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut input: u32 = 1000 * index + 500;
        for from in sources(index, grid, width, height) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let left = O::field_of_movement(lhs, from, *budget, costs);
                let right = H::field_of_movement(rhs, from, *budget, costs);
                assert(left == right, 'field_of_movement');
                input += 1;
            }
        }
        index += 1;
    }
}

fn check_distance_to(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for (from, to) in endpoints(index, grid, width, height) {
            assert(O::distance_to(lhs, from, to) == H::distance_to(rhs, from, to), 'distance_to');
        }
        index += 1;
    }
}

fn check_reachable(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for from in sources(index, grid, width, height) {
            assert(O::reachable(lhs, from) == H::reachable(rhs, from), 'reachable');
        }
        index += 1;
    }
}

fn check_range(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for from in sources(index, grid, width, height) {
            for radius in RADII.span() {
                assert(O::range(lhs, from, *radius) == H::range(rhs, from, *radius), 'range');
            }
        }
        index += 1;
    }
}

fn check_ring(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for from in sources(index, grid, width, height) {
            for radius in RADII.span() {
                assert(O::ring(lhs, from, *radius) == H::ring(rhs, from, *radius), 'ring');
            }
        }
        index += 1;
    }
}

/// `keep_component` on the boards, entrances included, from every source.
fn check_keep_component_boards(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for from in sources(index, grid, width, height) {
            let mut lhs = O::new(grid, width, height, 0);
            let mut rhs = H::new(grid, width, height, 0);
            O::keep_component(ref lhs, from);
            H::keep_component(ref rhs, from);
            assert_maps(lhs, rhs);
        }
        index += 1;
    }
}

/// 8 seeded counts and 0, as in `spreader`.
fn check_compute_distribution_boards(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let total = tiles(grid).len();
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut draw: u32 = 0;
        while draw != 9 {
            let count: u8 = if draw == 8 {
                0
            } else {
                below('count', 1000 * (index + 1) + draw, total + 1).try_into().unwrap()
            };
            let seed = generator_seed(1000 * (index + 1) + draw);
            assert(
                O::compute_distribution(
                    lhs, count, seed,
                ) == H::compute_distribution(rhs, count, seed),
                'compute_distribution',
            );
            draw += 1;
        }
        index += 1;
    }
}

// Constructors and queries.

/// Every board of `fixtures::boards` with a seed, and the boundary grids 0 and `-1` (the raw
/// constructor checks nothing).
#[test]
#[available_gas(l2_gas: 580592)]
fn test_map_new() {
    let mut index: u32 = 0;
    for board in boards() {
        let seed = generator_seed(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        assert_maps(O::new(grid, width, height, seed), H::new(grid, width, height, seed));
        index += 1;
    }
    assert_maps(O::new(0, 0, 0, 0), H::new(0, 0, 0, 0));
    assert_maps(O::new(-1, 255, 255, -1), H::new(-1, 255, 255, -1));
}

/// Every valid dimension (675), one seed each.
#[test]
#[available_gas(l2_gas: 19788111)]
fn test_map_new_empty() {
    let mut index: u32 = 0;
    for (width, height) in valid_dimensions() {
        let seed = generator_seed(index);
        assert_maps(O::new_empty(width, height, seed), H::new_empty(width, height, seed));
        index += 1;
    }
}

/// Every radius the function accepts (0 to 6), 64 seeds each.
#[test]
#[available_gas(l2_gas: 78436330)]
fn test_map_new_hexagon() {
    let mut radius: u8 = 0;
    while radius != 7 {
        let mut index: u32 = 0;
        while index != SEEDS {
            let seed = generator_seed(index);
            assert_maps(O::new_hexagon(radius, seed), H::new_hexagon(radius, seed));
            index += 1;
        }
        radius += 1;
    }
}

/// `search_path`, `search_path_weighted` (0 to 3 cost classes) and `distance_to` on the 20
/// endpoints of the fixtures of 1.8.0.
#[test]
#[available_gas(l2_gas: 193722422)]
fn test_map_fixture_endpoints() {
    let mut input: u32 = 200000;
    for (grid, width, from, to) in ENDPOINTS.span() {
        let (grid, width, from, to) = (*grid, *width, *from, *to);
        let height = if width == 17 {
            14
        } else {
            7
        };
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        assert(O::search_path(lhs, from, to) == H::search_path(rhs, from, to), 'search_path');
        assert(O::distance_to(lhs, from, to) == H::distance_to(rhs, from, to), 'distance_to');
        let mut classes: u32 = 0;
        while classes != 4 {
            let costs = costs(input + classes, width, height);
            let left = O::search_path_weighted(lhs, from, to, costs);
            let right = H::search_path_weighted(rhs, from, to, costs);
            assert(left == right, 'search_path_weighted');
            classes += 1;
        }
        input += 4;
    }
}

/// Every pair of the queries (`common::query_pairs`): every pair of a `7x7`, 512 seeded pairs of
/// a `17x14` and of a `15x16`.
#[test]
#[available_gas(l2_gas: 120877256)]
fn test_map_hex_distance() {
    for (width, height, from, to) in query_pairs() {
        let (lhs, rhs) = (O::new(0, width, height, 0), H::new(0, width, height, 0));
        assert(O::hex_distance(lhs, from, to) == H::hex_distance(rhs, from, to), 'hex_distance');
    }
}

/// Every position of the queries in every direction, then every position outside the board
/// (`W * H` to 255) of the `7x7`, the `17x14` and the `15x16` in every direction.
#[test]
#[available_gas(l2_gas: 169320037)]
fn test_map_neighbor() {
    let mut inputs = query_positions();
    for (width, height) in [(7_u8, 7_u8), (17, 14), (15, 16)].span() {
        let (width, height) = (*width, *height);
        let mut position: u16 = width.into() * height.into();
        while position != 256 {
            inputs.append((width, height, position.try_into().unwrap()));
            position += 1;
        }
    }
    for (width, height, position) in inputs {
        let (lhs, rhs) = (O::new(0, width, height, 0), H::new(0, width, height, 0));
        let mut index: u8 = 0;
        while index != 6 {
            let left = O::neighbor(lhs, position, origami_direction(index));
            let right = H::neighbor(rhs, position, hexx_direction(index));
            assert(left == right, 'neighbor');
            index += 1;
        }
    }
}

/// Every position from 0 to 255 of every board of `fixtures::boards` (inside and outside).
#[test]
#[available_gas(l2_gas: 164525198)]
fn test_map_is_walkable() {
    for board in boards() {
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut value: u16 = 0;
        while value != 256 {
            let position: u8 = value.try_into().unwrap();
            assert(O::is_walkable(lhs, position) == H::is_walkable(rhs, position), 'is_walkable');
            value += 1;
        }
    }
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 25099446)]
fn test_map_new_maze_3x3() {
    check_new_maze(3, 3, 0, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 114407465)]
fn test_map_new_maze_7x7() {
    check_new_maze(7, 7, 0, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `15x15`.
#[test]
#[available_gas(l2_gas: 286761048)]
fn test_map_new_maze_15x15_0() {
    check_new_maze(15, 15, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 275073398)]
fn test_map_new_maze_15x15_1() {
    check_new_maze(15, 15, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `15x16`.
#[test]
#[available_gas(l2_gas: 302294986)]
fn test_map_new_maze_15x16_0() {
    check_new_maze(15, 16, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 310421463)]
fn test_map_new_maze_15x16_1() {
    check_new_maze(15, 16, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `17x14`.
#[test]
#[available_gas(l2_gas: 299654433)]
fn test_map_new_maze_17x14_0() {
    check_new_maze(17, 14, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 299221275)]
fn test_map_new_maze_17x14_1() {
    check_new_maze(17, 14, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `19x13`.
#[test]
#[available_gas(l2_gas: 318997334)]
fn test_map_new_maze_19x13_0() {
    check_new_maze(19, 13, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 320705896)]
fn test_map_new_maze_19x13_1() {
    check_new_maze(19, 13, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `25x10`.
#[test]
#[available_gas(l2_gas: 316165421)]
fn test_map_new_maze_25x10_0() {
    check_new_maze(25, 10, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 315347284)]
fn test_map_new_maze_25x10_1() {
    check_new_maze(25, 10, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `83x3`.
#[test]
#[available_gas(l2_gas: 324374428)]
fn test_map_new_maze_83x3_0() {
    check_new_maze(83, 3, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 319740442)]
fn test_map_new_maze_83x3_1() {
    check_new_maze(83, 3, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `3x83`.
#[test]
#[available_gas(l2_gas: 269833828)]
fn test_map_new_maze_3x83_0() {
    check_new_maze(3, 83, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 275722911)]
fn test_map_new_maze_3x83_1() {
    check_new_maze(3, 83, 32, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 48537462)]
fn test_map_new_cave_3x3() {
    check_new_cave(3, 3, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 48537462)]
fn test_map_new_cave_7x7() {
    check_new_cave(7, 7, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 89677302)]
fn test_map_new_cave_15x15() {
    check_new_cave(15, 15, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 89610102)]
fn test_map_new_cave_15x16() {
    check_new_cave(15, 16, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 89610102)]
fn test_map_new_cave_17x14() {
    check_new_cave(17, 14, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 89677302)]
fn test_map_new_cave_19x13() {
    check_new_cave(19, 13, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 89610102)]
fn test_map_new_cave_25x10() {
    check_new_cave(25, 10, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 84842976)]
fn test_map_new_cave_83x3() {
    check_new_cave(83, 3, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 86593221)]
fn test_map_new_cave_3x83() {
    check_new_cave(3, 83, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `3x3`.
#[test]
#[available_gas(l2_gas: 293975813)]
fn test_map_new_random_walk_3x3_0() {
    check_new_random_walk(3, 3, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `3x3`.
#[test]
#[available_gas(l2_gas: 308003785)]
fn test_map_new_random_walk_3x3_1() {
    check_new_random_walk(3, 3, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 294098957)]
fn test_map_new_random_walk_3x3_2() {
    check_new_random_walk(3, 3, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `7x7`.
#[test]
#[available_gas(l2_gas: 291561149)]
fn test_map_new_random_walk_7x7_0() {
    check_new_random_walk(7, 7, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `7x7`.
#[test]
#[available_gas(l2_gas: 305498233)]
fn test_map_new_random_walk_7x7_1() {
    check_new_random_walk(7, 7, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 291681374)]
fn test_map_new_random_walk_7x7_2() {
    check_new_random_walk(7, 7, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `15x15`.
#[test]
#[available_gas(l2_gas: 298372877)]
fn test_map_new_random_walk_15x15_0() {
    check_new_random_walk(15, 15, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `15x15`.
#[test]
#[available_gas(l2_gas: 312592600)]
fn test_map_new_random_walk_15x15_1() {
    check_new_random_walk(15, 15, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 298459250)]
fn test_map_new_random_walk_15x15_2() {
    check_new_random_walk(15, 15, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `15x16`.
#[test]
#[available_gas(l2_gas: 298627817)]
fn test_map_new_random_walk_15x16_0() {
    check_new_random_walk(15, 16, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `15x16`.
#[test]
#[available_gas(l2_gas: 313269283)]
fn test_map_new_random_walk_15x16_1() {
    check_new_random_walk(15, 16, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 298477772)]
fn test_map_new_random_walk_15x16_2() {
    check_new_random_walk(15, 16, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `17x14`.
#[test]
#[available_gas(l2_gas: 298958903)]
fn test_map_new_random_walk_17x14_0() {
    check_new_random_walk(17, 14, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `17x14`.
#[test]
#[available_gas(l2_gas: 312786199)]
fn test_map_new_random_walk_17x14_1() {
    check_new_random_walk(17, 14, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 298901867)]
fn test_map_new_random_walk_17x14_2() {
    check_new_random_walk(17, 14, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `19x13`.
#[test]
#[available_gas(l2_gas: 299048531)]
fn test_map_new_random_walk_19x13_0() {
    check_new_random_walk(19, 13, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `19x13`.
#[test]
#[available_gas(l2_gas: 313205443)]
fn test_map_new_random_walk_19x13_1() {
    check_new_random_walk(19, 13, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 299281232)]
fn test_map_new_random_walk_19x13_2() {
    check_new_random_walk(19, 13, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `25x10`.
#[test]
#[available_gas(l2_gas: 299402591)]
fn test_map_new_random_walk_25x10_0() {
    check_new_random_walk(25, 10, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `25x10`.
#[test]
#[available_gas(l2_gas: 313917574)]
fn test_map_new_random_walk_25x10_1() {
    check_new_random_walk(25, 10, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 299387471)]
fn test_map_new_random_walk_25x10_2() {
    check_new_random_walk(25, 10, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `83x3`.
#[test]
#[available_gas(l2_gas: 294882404)]
fn test_map_new_random_walk_83x3_0() {
    check_new_random_walk(83, 3, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `83x3`.
#[test]
#[available_gas(l2_gas: 309815707)]
fn test_map_new_random_walk_83x3_1() {
    check_new_random_walk(83, 3, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 295860647)]
fn test_map_new_random_walk_83x3_2() {
    check_new_random_walk(83, 3, 43, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 20 on `3x83`.
#[test]
#[available_gas(l2_gas: 300915557)]
fn test_map_new_random_walk_3x83_0() {
    check_new_random_walk(3, 83, 0, 21);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 21 to 42 on `3x83`.
#[test]
#[available_gas(l2_gas: 316202395)]
fn test_map_new_random_walk_3x83_1() {
    check_new_random_walk(3, 83, 21, 43);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 43 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 300886031)]
fn test_map_new_random_walk_3x83_2() {
    check_new_random_walk(3, 83, 43, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 28269176)]
fn test_map_open_with_corridor_3x3() {
    check_open_with_corridor(3, 3, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 44073700)]
fn test_map_open_with_corridor_7x7() {
    check_open_with_corridor(7, 7, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 95811186)]
fn test_map_open_with_corridor_15x15() {
    check_open_with_corridor(15, 15, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 111080324)]
fn test_map_open_with_corridor_15x16() {
    check_open_with_corridor(15, 16, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 99982330)]
fn test_map_open_with_corridor_17x14() {
    check_open_with_corridor(17, 14, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 93346418)]
fn test_map_open_with_corridor_19x13() {
    check_open_with_corridor(19, 13, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 117280800)]
fn test_map_open_with_corridor_25x10() {
    check_open_with_corridor(25, 10, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 31 on `83x3`.
#[test]
#[available_gas(l2_gas: 138741255)]
fn test_map_open_with_corridor_83x3_0() {
    check_open_with_corridor(83, 3, 0, 32);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 32
/// to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 187083257)]
fn test_map_open_with_corridor_83x3_1() {
    check_open_with_corridor(83, 3, 32, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 259582273)]
fn test_map_open_with_corridor_3x83() {
    check_open_with_corridor(3, 83, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 28287320)]
fn test_map_open_with_maze_3x3() {
    check_open_with_maze(3, 3, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 52924259)]
fn test_map_open_with_maze_7x7() {
    check_open_with_maze(7, 7, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 148586074)]
fn test_map_open_with_maze_15x15() {
    check_open_with_maze(15, 15, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 179012327)]
fn test_map_open_with_maze_15x16() {
    check_open_with_maze(15, 16, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 151162402)]
fn test_map_open_with_maze_17x14() {
    check_open_with_maze(17, 14, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 129523196)]
fn test_map_open_with_maze_19x13() {
    check_open_with_maze(19, 13, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 159809721)]
fn test_map_open_with_maze_25x10() {
    check_open_with_maze(25, 10, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 31
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 140513541)]
fn test_map_open_with_maze_83x3_0() {
    check_open_with_maze(83, 3, 0, 32);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 32 to
/// 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 189280084)]
fn test_map_open_with_maze_83x3_1() {
    check_open_with_maze(83, 3, 32, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 282153048)]
fn test_map_open_with_maze_3x83() {
    check_open_with_maze(3, 83, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 11448598)]
fn test_map_keep_component_3x3() {
    check_keep_component(3, 3, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 45360872)]
fn test_map_keep_component_7x7() {
    check_keep_component(7, 7, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 214187277)]
fn test_map_keep_component_15x15() {
    check_keep_component(15, 15, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 229022363)]
fn test_map_keep_component_15x16() {
    check_keep_component(15, 16, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 230247636)]
fn test_map_keep_component_17x14() {
    check_keep_component(17, 14, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 237253057)]
fn test_map_keep_component_19x13() {
    check_keep_component(19, 13, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 234927145)]
fn test_map_keep_component_25x10() {
    check_keep_component(25, 10, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 122033840)]
fn test_map_keep_component_83x3() {
    check_keep_component(83, 3, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 127308678)]
fn test_map_keep_component_3x83() {
    check_keep_component(3, 83, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 18213975)]
fn test_map_compute_distribution_3x3() {
    check_compute_distribution(3, 3, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 53208536)]
fn test_map_compute_distribution_7x7() {
    check_compute_distribution(7, 7, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 206284137)]
fn test_map_compute_distribution_15x15() {
    check_compute_distribution(15, 15, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 219072540)]
fn test_map_compute_distribution_15x16() {
    check_compute_distribution(15, 16, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 218562935)]
fn test_map_compute_distribution_17x14() {
    check_compute_distribution(17, 14, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 223801587)]
fn test_map_compute_distribution_19x13() {
    check_compute_distribution(19, 13, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 222867656)]
fn test_map_compute_distribution_25x10() {
    check_compute_distribution(25, 10, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 121170301)]
fn test_map_compute_distribution_83x3() {
    check_compute_distribution(83, 3, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 125231167)]
fn test_map_compute_distribution_3x83() {
    check_compute_distribution(3, 83, 0, 64);
}

/// `search_path` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 108655882)]
fn test_map_search_path_fixtures() {
    check_search_path(0, 10);
}

/// `search_path` on `common::endpoints`. Boards 10 to 25 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 245051854)]
fn test_map_search_path_boards_0() {
    check_search_path(10, 26);
}

/// `search_path` on `common::endpoints`. Boards 26 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 174067421)]
fn test_map_search_path_boards_1() {
    check_search_path(26, 42);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 218742471)]
fn test_map_search_path_weighted_fixtures() {
    check_search_path_weighted(0, 10);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 10 to 20 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 369523266)]
fn test_map_search_path_weighted_boards_0() {
    check_search_path_weighted(10, 21);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 21 to 30 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 265704498)]
fn test_map_search_path_weighted_boards_1() {
    check_search_path_weighted(21, 31);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 31 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 210949719)]
fn test_map_search_path_weighted_boards_2() {
    check_search_path_weighted(31, 42);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 0 to 4 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 247051210)]
fn test_map_field_of_movement_fixtures_0() {
    check_field_of_movement(0, 5);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 5 to 9 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 124018268)]
fn test_map_field_of_movement_fixtures_1() {
    check_field_of_movement(5, 10);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 10 to 14 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 252514110)]
fn test_map_field_of_movement_boards_0() {
    check_field_of_movement(10, 15);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 15 to 20 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 298229993)]
fn test_map_field_of_movement_boards_1() {
    check_field_of_movement(15, 21);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 21 to 25 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 264642168)]
fn test_map_field_of_movement_boards_2() {
    check_field_of_movement(21, 26);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 26 to 30 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 264980747)]
fn test_map_field_of_movement_boards_3() {
    check_field_of_movement(26, 31);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 31 to 36 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 274704010)]
fn test_map_field_of_movement_boards_4() {
    check_field_of_movement(31, 37);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 37 to 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 178193844)]
fn test_map_field_of_movement_boards_5() {
    check_field_of_movement(37, 42);
}

/// `distance_to` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 88029254)]
fn test_map_distance_to_fixtures() {
    check_distance_to(0, 10);
}

/// `distance_to` on `common::endpoints`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 342359991)]
fn test_map_distance_to_boards() {
    check_distance_to(10, 42);
}

/// `reachable` from `common::sources`. Boards 0 to 9 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 80648432)]
fn test_map_reachable_fixtures() {
    check_reachable(0, 10);
}

/// `reachable` from `common::sources`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 335310867)]
fn test_map_reachable_boards() {
    check_reachable(10, 42);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 174601991)]
fn test_map_range_fixtures() {
    check_range(0, 10);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 10 to 20 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 298661625)]
fn test_map_range_boards_0() {
    check_range(10, 21);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 21 to 30 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 268001316)]
fn test_map_range_boards_1() {
    check_range(21, 31);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 31 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 221589140)]
fn test_map_range_boards_2() {
    check_range(31, 42);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 174683572)]
fn test_map_ring_fixtures() {
    check_ring(0, 10);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 10 to 20 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 320220796)]
fn test_map_ring_boards_0() {
    check_ring(10, 21);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 21 to 30 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 288820086)]
fn test_map_ring_boards_1() {
    check_ring(21, 31);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 31 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 245852402)]
fn test_map_ring_boards_2() {
    check_ring(31, 42);
}

/// `keep_component` from `common::sources` (entrances included). Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 80649482)]
fn test_map_keep_component_boards_fixtures() {
    check_keep_component_boards(0, 10);
}

/// `keep_component` from `common::sources` (entrances included). Boards 10 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 335311707)]
fn test_map_keep_component_boards_boards() {
    check_keep_component_boards(10, 42);
}

/// `compute_distribution`, 8 seeded counts per board, entrances included. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 39517145)]
fn test_map_compute_distribution_boards_fixtures() {
    check_compute_distribution_boards(0, 10);
}

/// `compute_distribution`, 8 seeded counts per board, entrances included. Boards 10 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 154973610)]
fn test_map_compute_distribution_boards_boards() {
    check_compute_distribution_boards(10, 42);
}

// Panics: one test per side, same input, same message (README of 1.8.0, § Panics).

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_empty_revert_dimension_origami() {
    let _ = O::new_empty(2, 7, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_empty_revert_dimension_hexx() {
    let _ = H::new_empty(2, 7, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_maze_revert_dimension_origami() {
    let _ = O::new_maze(7, 2, 0, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_maze_revert_dimension_hexx() {
    let _ = H::new_maze(7, 2, 0, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_new_maze_revert_order_origami() {
    let _ = O::new_maze(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_new_maze_revert_order_hexx() {
    let _ = H::new_maze(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_cave_revert_dimension_origami() {
    let _ = O::new_cave(12, 21, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_cave_revert_dimension_hexx() {
    let _ = H::new_cave(12, 21, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_random_walk_revert_dimension_origami() {
    let _ = O::new_random_walk(2, 2, 10, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_random_walk_revert_dimension_hexx() {
    let _ = H::new_random_walk(2, 2, 10, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_hexagon_revert_radius_origami() {
    let _ = O::new_hexagon(7, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_hexagon_revert_radius_hexx() {
    let _ = H::new_hexagon(7, 'seed');
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_corridor_revert_not_edge_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_corridor_revert_not_edge_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_corridor_revert_corner_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_corridor_revert_corner_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_corridor_revert_order_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_corridor_revert_order_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_corridor_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_corridor_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_corridor_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = O::open_with_corridor(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_corridor_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = H::open_with_corridor(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_maze_revert_not_edge_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_maze_revert_not_edge_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_maze_revert_corner_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_maze_revert_corner_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_maze_revert_order_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_maze_revert_order_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_maze_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 19089)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_maze_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_maze_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = O::open_with_maze(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_maze_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = H::open_with_maze(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_keep_component_revert_wall_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::keep_component(ref map, 17);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_keep_component_revert_wall_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::keep_component(ref map, 17);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_keep_component_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::keep_component(ref map, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_keep_component_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::keep_component(ref map, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_keep_component_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 36, 'seed');
    let _ = O::keep_component(ref map, 8);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_keep_component_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 36, 'seed');
    let _ = H::keep_component(ref map, 8);
}

#[test]
#[available_gas(l2_gas: 67653)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_map_compute_distribution_revert_not_enough_place_origami() {
    let _ = O::compute_distribution(O::new(EMPTY_7X7, 7, 7, 'seed'), 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 67653)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_map_compute_distribution_revert_not_enough_place_hexx() {
    let _ = H::compute_distribution(H::new(EMPTY_7X7, 7, 7, 'seed'), 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 77963)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_invalid_grid_origami() {
    let _ = O::compute_distribution(
        O::new(
            EMPTY_17X14 + 0x400000000000000000000000000000000000000000000000000000000000,
            17,
            14,
            'seed',
        ),
        1,
        'seed',
    );
}

#[test]
#[available_gas(l2_gas: 77963)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_invalid_grid_hexx() {
    let _ = H::compute_distribution(
        H::new(
            EMPTY_17X14 + 0x400000000000000000000000000000000000000000000000000000000000,
            17,
            14,
            'seed',
        ),
        1,
        'seed',
    );
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_compute_distribution_revert_dimension_origami() {
    let _ = O::compute_distribution(O::new(EMPTY_7X7, 2, 7, 'seed'), 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_compute_distribution_revert_dimension_hexx() {
    let _ = H::compute_distribution(H::new(EMPTY_7X7, 2, 7, 'seed'), 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 22043)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_from_wall_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 22043)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_from_wall_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 24031)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_to_wall_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17);
}

#[test]
#[available_gas(l2_gas: 24031)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_to_wall_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_revert_outside_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_revert_outside_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_revert_dimension_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_revert_dimension_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_search_path_weighted_revert_too_many_costs_origami() {
    let _ = O::search_path_weighted(
        O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 40, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_search_path_weighted_revert_too_many_costs_hexx() {
    let _ = H::search_path_weighted(
        H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 40, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 21466)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_from_wall_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 21466)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_from_wall_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 23516)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_to_wall_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 23516)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_to_wall_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_weighted_revert_outside_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_weighted_revert_outside_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_weighted_revert_dimension_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_weighted_revert_dimension_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_field_of_movement_revert_too_many_costs_origami() {
    let _ = O::field_of_movement(
        O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 3, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_field_of_movement_revert_too_many_costs_hexx() {
    let _ = H::field_of_movement(
        H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 3, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 50975)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_field_of_movement_revert_wall_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 50975)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_field_of_movement_revert_wall_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_field_of_movement_revert_outside_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_field_of_movement_revert_outside_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_field_of_movement_revert_dimension_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 36, 7, 'seed'), 8, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_field_of_movement_revert_dimension_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 36, 7, 'seed'), 8, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 21760)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_distance_to_revert_wall_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 21760)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_distance_to_revert_wall_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_distance_to_revert_outside_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_distance_to_revert_outside_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_distance_to_revert_dimension_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_distance_to_revert_dimension_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_from_outside_origami() {
    let _ = O::hex_distance(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 8);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_from_outside_hexx() {
    let _ = H::hex_distance(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 8);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_to_outside_origami() {
    let _ = O::hex_distance(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_to_outside_hexx() {
    let _ = H::hex_distance(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_reachable_revert_wall_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_reachable_revert_wall_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_reachable_revert_outside_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_reachable_revert_outside_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_reachable_revert_dimension_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_reachable_revert_dimension_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8);
}

#[test]
#[available_gas(l2_gas: 63408)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_range_revert_wall_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 63408)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_range_revert_wall_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_range_revert_outside_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_range_revert_outside_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_range_revert_dimension_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_range_revert_dimension_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 61146)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_ring_revert_wall_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 61146)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_ring_revert_wall_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_ring_revert_outside_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_ring_revert_outside_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_ring_revert_dimension_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_ring_revert_dimension_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}
