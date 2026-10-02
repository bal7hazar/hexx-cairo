//! `map` of 1.8.0 against `hexx::board::map`: `HexMap` and the 20 functions of `HexMapTrait`
//! (`new`, `new_empty`, `new_maze`, `new_cave`, `new_random_walk`, `new_hexagon`,
//! `open_with_corridor`, `open_with_maze`, `keep_component`, `compute_distribution`,
//! `search_path`, `search_path_weighted`, `field_of_movement`, `distance_to`, `hex_distance`,
//! `reachable`, `range`, `ring`, `neighbor`, `is_walkable`), through the root re-exports of both
//! packages (`origami_hexmap::{HexMap, HexMapTrait}`, `hexx::{HexMap, HexMapTrait}`).
//!
//! Inputs: the generators as in `caver`, `mazer`, `walker`, `digger` and `spreader`; the finders
//! as in `bfs` and `dial`, the boards with several entrances included; the queries on
//! `common::query_positions` and `common::query_pairs`.

use hexx::HexMapTrait as H;
use origami_hexmap::HexMapTrait as O;
use crate::common::{
    RADII, SEEDS, assert_maps, below, costs, endpoints, entrance_pairs, generator_seed,
    hexx_direction, identical_endpoints, input_grid, open_pairs, origami_direction, query_pairs,
    query_positions, sides, sources, tiles, valid_dimensions,
};
use crate::fixtures::{
    Board, EMPTY_17X14, EMPTY_7X7, ENDPOINTS, ENTRANCES_7X7_AUDIT, UNREACHABLE_7X7, boards,
    edge_boards, entrance_boards,
};
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

// Entrances (fix loop 1, finding 1).

/// The pairs of an entrance board: every ordered pair of distinct entrances, then the seeded
/// endpoints of `common::endpoints` (board index `100 + k`).
fn entrance_endpoints(index: u32, board: Board) -> Array<(u8, u8)> {
    let (grid, width, height) = (board.grid, board.width, board.height);
    let mut pairs = entrance_pairs(grid, width, height);
    for pair in endpoints(100 + index, grid, width, height) {
        pairs.append(pair);
    }
    pairs
}

/// `search_path`, `distance_to` and `search_path_weighted` (0 to 3 cost classes) between distinct
/// entrances and on the seeded endpoints of the boards `[first, last)` of
/// `fixtures::entrance_boards`; returns the number of distinct-entrance pairs joined by a path.
fn check_paths_entrances(first: u32, last: u32) -> u32 {
    let boards = entrance_boards();
    let mut joined: u32 = 0;
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let distinct = entrance_pairs(grid, width, height).len();
        let mut input: u32 = 500000 + 1000 * index;
        let mut count: u32 = 0;
        for (from, to) in entrance_endpoints(index, board) {
            let left = O::search_path(lhs, from, to);
            assert(left == H::search_path(rhs, from, to), 'search_path');
            assert(O::distance_to(lhs, from, to) == H::distance_to(rhs, from, to), 'distance_to');
            let costs = costs(input, width, height);
            let weighted = O::search_path_weighted(lhs, from, to, costs);
            assert(weighted == H::search_path_weighted(rhs, from, to, costs), 'weighted');
            if count < distinct && left.len() != 0 {
                joined += 1;
            }
            input += 1;
            count += 1;
        }
        index += 1;
    }
    joined
}

/// `reachable`, `keep_component`, and `range` and `ring` at every radius of `common::RADII`, from
/// every entrance and the seeded sources.
fn check_floods_entrances(first: u32, last: u32) {
    let boards = entrance_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for from in sources(100 + index, grid, width, height) {
            assert(O::reachable(lhs, from) == H::reachable(rhs, from), 'reachable');
            let (mut left, mut right) = (lhs, rhs);
            O::keep_component(ref left, from);
            H::keep_component(ref right, from);
            assert_maps(left, right);
            for radius in RADII.span() {
                assert(O::range(lhs, from, *radius) == H::range(rhs, from, *radius), 'range');
                assert(O::ring(lhs, from, *radius) == H::ring(rhs, from, *radius), 'ring');
            }
        }
        index += 1;
    }
}

/// `field_of_movement` from every entrance and the seeded sources, every budget of
/// `common::RADII`, 0 to 3 cost classes.
fn check_field_of_movement_entrances(first: u32, last: u32) {
    let boards = entrance_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut input: u32 = 500000 + 1000 * index + 500;
        for from in sources(100 + index, grid, width, height) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let left = O::field_of_movement(lhs, from, *budget, costs);
                assert(left == H::field_of_movement(rhs, from, *budget, costs), 'field');
                input += 1;
            }
        }
        index += 1;
    }
}

/// The auditor's scenario through the facade: `EMPTY_7X7` with the side tiles 1 and 43 open,
/// from 1 to 43 (both entrances, joined through the interior).
#[test]
#[available_gas(l2_gas: 1848042)]
fn test_map_audit_scenario() {
    let (lhs, rhs) = (O::new(ENTRANCES_7X7_AUDIT, 7, 7, 0), H::new(ENTRANCES_7X7_AUDIT, 7, 7, 0));
    let path = O::search_path(lhs, 1, 43);
    assert(path.len() != 0, 'path expected');
    assert(path == H::search_path(rhs, 1, 43), 'search_path');
    assert(O::distance_to(lhs, 1, 43).is_some(), 'distance expected');
    assert(O::distance_to(lhs, 1, 43) == H::distance_to(rhs, 1, 43), 'distance_to');
    let costs: Span<felt252> = [].span();
    let weighted = O::search_path_weighted(lhs, 1, 43, costs);
    assert(weighted.len() != 0, 'weighted path expected');
    assert(weighted == H::search_path_weighted(rhs, 1, 43, costs), 'weighted');
}

/// `search_path`, `distance_to`, `search_path_weighted` on identical endpoints (the early
/// return), a seeded tile and every entrance of the 42 boards and of the 15 entrance boards.
#[test]
#[available_gas(l2_gas: 273716298)]
fn test_map_identical_endpoints() {
    let mut all = boards();
    for board in entrance_boards() {
        all.append(board);
    }
    let mut index: u32 = 0;
    let mut input: u32 = 600000;
    for board in all {
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for (from, to) in identical_endpoints(index, grid, width, height) {
            assert(O::search_path(lhs, from, to) == H::search_path(rhs, from, to), 'search_path');
            assert(O::distance_to(lhs, from, to) == H::distance_to(rhs, from, to), 'distance_to');
            let costs = costs(input, width, height);
            let left = O::search_path_weighted(lhs, from, to, costs);
            assert(left == H::search_path_weighted(rhs, from, to, costs), 'weighted');
            input += 1;
        }
        index += 1;
    }
}

// Constructors and queries.

/// Every board of `fixtures::boards` with a seed, and the boundary grids 0 and `-1` (the raw
/// constructor checks nothing).
#[test]
#[available_gas(l2_gas: 572601)]
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
#[available_gas(l2_gas: 19780121)]
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
#[available_gas(l2_gas: 78428339)]
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
#[available_gas(l2_gas: 193714536)]
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
#[available_gas(l2_gas: 120869276)]
fn test_map_hex_distance() {
    for (width, height, from, to) in query_pairs() {
        let (lhs, rhs) = (O::new(0, width, height, 0), H::new(0, width, height, 0));
        assert(O::hex_distance(lhs, from, to) == H::hex_distance(rhs, from, to), 'hex_distance');
    }
}

/// Every position of the queries in every direction, then every position outside the board
/// (`W * H` to 255) of the `7x7`, the `17x14` and the `15x16` in every direction.
#[test]
#[available_gas(l2_gas: 169311921)]
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
#[available_gas(l2_gas: 164517207)]
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
#[available_gas(l2_gas: 25091561)]
fn test_map_new_maze_3x3() {
    check_new_maze(3, 3, 0, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 114399579)]
fn test_map_new_maze_7x7() {
    check_new_maze(7, 7, 0, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `15x15`.
#[test]
#[available_gas(l2_gas: 286753163)]
fn test_map_new_maze_15x15_0() {
    check_new_maze(15, 15, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 275065512)]
fn test_map_new_maze_15x15_1() {
    check_new_maze(15, 15, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `15x16`.
#[test]
#[available_gas(l2_gas: 302287100)]
fn test_map_new_maze_15x16_0() {
    check_new_maze(15, 16, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 310413577)]
fn test_map_new_maze_15x16_1() {
    check_new_maze(15, 16, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `17x14`.
#[test]
#[available_gas(l2_gas: 299646548)]
fn test_map_new_maze_17x14_0() {
    check_new_maze(17, 14, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 299213389)]
fn test_map_new_maze_17x14_1() {
    check_new_maze(17, 14, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `19x13`.
#[test]
#[available_gas(l2_gas: 318989448)]
fn test_map_new_maze_19x13_0() {
    check_new_maze(19, 13, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 320698010)]
fn test_map_new_maze_19x13_1() {
    check_new_maze(19, 13, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `25x10`.
#[test]
#[available_gas(l2_gas: 316157535)]
fn test_map_new_maze_25x10_0() {
    check_new_maze(25, 10, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 315339398)]
fn test_map_new_maze_25x10_1() {
    check_new_maze(25, 10, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `83x3`.
#[test]
#[available_gas(l2_gas: 324366542)]
fn test_map_new_maze_83x3_0() {
    check_new_maze(83, 3, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 319732556)]
fn test_map_new_maze_83x3_1() {
    check_new_maze(83, 3, 32, 64);
}

/// `new_maze`, orders 0 and 1. Seeds 0 to 31 on `3x83`.
#[test]
#[available_gas(l2_gas: 269825943)]
fn test_map_new_maze_3x83_0() {
    check_new_maze(3, 83, 0, 32);
}

/// `new_maze`, orders 0 and 1. Seeds 32 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 275715025)]
fn test_map_new_maze_3x83_1() {
    check_new_maze(3, 83, 32, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 48529577)]
fn test_map_new_cave_3x3() {
    check_new_cave(3, 3, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 48529577)]
fn test_map_new_cave_7x7() {
    check_new_cave(7, 7, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 89669417)]
fn test_map_new_cave_15x15() {
    check_new_cave(15, 15, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 89602217)]
fn test_map_new_cave_15x16() {
    check_new_cave(15, 16, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 89602217)]
fn test_map_new_cave_17x14() {
    check_new_cave(17, 14, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 89669417)]
fn test_map_new_cave_19x13() {
    check_new_cave(19, 13, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 89602217)]
fn test_map_new_cave_25x10() {
    check_new_cave(25, 10, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 84835091)]
fn test_map_new_cave_83x3() {
    check_new_cave(83, 3, 0, 64);
}

/// `new_cave`, orders 0 to 5. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 86585336)]
fn test_map_new_cave_3x83() {
    check_new_cave(3, 83, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 319265235)]
fn test_map_new_random_walk_3x3() {
    check_new_random_walk(3, 3, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 317003871)]
fn test_map_new_random_walk_7x7() {
    check_new_random_walk(7, 7, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 324822927)]
fn test_map_new_random_walk_15x15() {
    check_new_random_walk(15, 15, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 324536991)]
fn test_map_new_random_walk_15x16() {
    check_new_random_walk(15, 16, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 324895398)]
fn test_map_new_random_walk_17x14() {
    check_new_random_walk(17, 14, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 325079526)]
fn test_map_new_random_walk_19x13() {
    check_new_random_walk(19, 13, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 325193598)]
fn test_map_new_random_walk_25x10() {
    check_new_random_walk(25, 10, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 320562153)]
fn test_map_new_random_walk_83x3() {
    check_new_random_walk(83, 3, 0, 64);
}

/// `new_random_walk`, every step count of `walker::STEPS`. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 326498559)]
fn test_map_new_random_walk_3x83() {
    check_new_random_walk(3, 83, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 28261290)]
fn test_map_open_with_corridor_3x3() {
    check_open_with_corridor(3, 3, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 44065815)]
fn test_map_open_with_corridor_7x7() {
    check_open_with_corridor(7, 7, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 95803300)]
fn test_map_open_with_corridor_15x15() {
    check_open_with_corridor(15, 15, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 111072438)]
fn test_map_open_with_corridor_15x16() {
    check_open_with_corridor(15, 16, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 99974444)]
fn test_map_open_with_corridor_17x14() {
    check_open_with_corridor(17, 14, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 93338532)]
fn test_map_open_with_corridor_19x13() {
    check_open_with_corridor(19, 13, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 117272915)]
fn test_map_open_with_corridor_25x10() {
    check_open_with_corridor(25, 10, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 324793096)]
fn test_map_open_with_corridor_83x3() {
    check_open_with_corridor(83, 3, 0, 64);
}

/// `open_with_corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0
/// to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 259574388)]
fn test_map_open_with_corridor_3x83() {
    check_open_with_corridor(3, 83, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 28279434)]
fn test_map_open_with_maze_3x3() {
    check_open_with_maze(3, 3, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 52916374)]
fn test_map_open_with_maze_7x7() {
    check_open_with_maze(7, 7, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 148578188)]
fn test_map_open_with_maze_15x15() {
    check_open_with_maze(15, 15, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 179004441)]
fn test_map_open_with_maze_15x16() {
    check_open_with_maze(15, 16, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 151154517)]
fn test_map_open_with_maze_17x14() {
    check_open_with_maze(17, 14, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 129515310)]
fn test_map_open_with_maze_19x13() {
    check_open_with_maze(19, 13, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 159801836)]
fn test_map_open_with_maze_25x10() {
    check_open_with_maze(25, 10, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 328762210)]
fn test_map_open_with_maze_83x3() {
    check_open_with_maze(83, 3, 0, 64);
}

/// `open_with_maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 282145162)]
fn test_map_open_with_maze_3x83() {
    check_open_with_maze(3, 83, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 11440712)]
fn test_map_keep_component_3x3() {
    check_keep_component(3, 3, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 45352986)]
fn test_map_keep_component_7x7() {
    check_keep_component(7, 7, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 214179391)]
fn test_map_keep_component_15x15() {
    check_keep_component(15, 15, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 229014478)]
fn test_map_keep_component_15x16() {
    check_keep_component(15, 16, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 230239750)]
fn test_map_keep_component_17x14() {
    check_keep_component(17, 14, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 237245172)]
fn test_map_keep_component_19x13() {
    check_keep_component(19, 13, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 234919260)]
fn test_map_keep_component_25x10() {
    check_keep_component(25, 10, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 122025954)]
fn test_map_keep_component_83x3() {
    check_keep_component(83, 3, 0, 64);
}

/// `keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 127300793)]
fn test_map_keep_component_3x83() {
    check_keep_component(3, 83, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 18206089)]
fn test_map_compute_distribution_3x3() {
    check_compute_distribution(3, 3, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 53200651)]
fn test_map_compute_distribution_7x7() {
    check_compute_distribution(7, 7, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 206276251)]
fn test_map_compute_distribution_15x15() {
    check_compute_distribution(15, 15, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 219064655)]
fn test_map_compute_distribution_15x16() {
    check_compute_distribution(15, 16, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 218555050)]
fn test_map_compute_distribution_17x14() {
    check_compute_distribution(17, 14, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 223793701)]
fn test_map_compute_distribution_19x13() {
    check_compute_distribution(19, 13, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 222859770)]
fn test_map_compute_distribution_25x10() {
    check_compute_distribution(25, 10, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 121162415)]
fn test_map_compute_distribution_83x3() {
    check_compute_distribution(83, 3, 0, 64);
}

/// `compute_distribution` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 125223282)]
fn test_map_compute_distribution_3x83() {
    check_compute_distribution(3, 83, 0, 64);
}

/// `search_path` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 108085890)]
fn test_map_search_path_fixtures() {
    check_search_path(0, 10);
}

/// `search_path` on `common::endpoints`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 416626833)]
fn test_map_search_path_boards() {
    check_search_path(10, 42);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 216170233)]
fn test_map_search_path_weighted_fixtures() {
    check_search_path_weighted(0, 10);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 10 to 20 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 360810211)]
fn test_map_search_path_weighted_boards_0() {
    check_search_path_weighted(10, 21);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 21 to 30 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 257399913)]
fn test_map_search_path_weighted_boards_1() {
    check_search_path_weighted(21, 31);
}

/// `search_path_weighted` on `common::endpoints`, 0 to 3 cost classes. Boards 31 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 204381190)]
fn test_map_search_path_weighted_boards_2() {
    check_search_path_weighted(31, 42);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 0 to 9 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 370969927)]
fn test_map_field_of_movement_fixtures() {
    check_field_of_movement(0, 10);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 10 to 17 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 394496865)]
fn test_map_field_of_movement_boards_0() {
    check_field_of_movement(10, 18);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 18 to 25 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 420781969)]
fn test_map_field_of_movement_boards_1() {
    check_field_of_movement(18, 26);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 26 to 33 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 414960861)]
fn test_map_field_of_movement_boards_2() {
    check_field_of_movement(26, 34);
}

/// `field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 34 to 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 302810303)]
fn test_map_field_of_movement_boards_3() {
    check_field_of_movement(34, 42);
}

/// `distance_to` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 87499686)]
fn test_map_distance_to_fixtures() {
    check_distance_to(0, 10);
}

/// `distance_to` on `common::endpoints`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 340144214)]
fn test_map_distance_to_boards() {
    check_distance_to(10, 42);
}

/// `reachable` from `common::sources`. Boards 0 to 9 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 80640546)]
fn test_map_reachable_fixtures() {
    check_reachable(0, 10);
}

/// `reachable` from `common::sources`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 335302981)]
fn test_map_reachable_boards() {
    check_reachable(10, 42);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 174594105)]
fn test_map_range_fixtures() {
    check_range(0, 10);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 10 to 25 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 429142273)]
fn test_map_range_boards_0() {
    check_range(10, 26);
}

/// `range` from `common::sources`, every radius of `common::RADII`. Boards 26 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 359000544)]
fn test_map_range_boards_1() {
    check_range(26, 42);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 174675686)]
fn test_map_ring_fixtures() {
    check_ring(0, 10);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 10 to 20 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 320212910)]
fn test_map_ring_boards_0() {
    check_ring(10, 21);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 21 to 30 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 288812200)]
fn test_map_ring_boards_1() {
    check_ring(21, 31);
}

/// `ring` from `common::sources`, every radius of `common::RADII`. Boards 31 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 245844516)]
fn test_map_ring_boards_2() {
    check_ring(31, 42);
}

/// `keep_component` from `common::sources` (entrances included). Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 80641596)]
fn test_map_keep_component_boards_fixtures() {
    check_keep_component_boards(0, 10);
}

/// `keep_component` from `common::sources` (entrances included). Boards 10 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 335303821)]
fn test_map_keep_component_boards_boards() {
    check_keep_component_boards(10, 42);
}

/// `compute_distribution`, 8 seeded counts per board, entrances included. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 39509260)]
fn test_map_compute_distribution_boards_fixtures() {
    check_compute_distribution_boards(0, 10);
}

/// `compute_distribution`, 8 seeded counts per board, entrances included. Boards 10 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 154965725)]
fn test_map_compute_distribution_boards_boards() {
    check_compute_distribution_boards(10, 42);
}

/// All 128 tiles of a 16x8 or 8x16 board, the last board of the single-limb path.
const FULL_128: felt252 = 0xffffffffffffffffffffffffffffffff;

/// `compute_distribution` on the boards of exactly 128 tiles, 16x8 and 8x16 (fix loop 1, finding
/// 4): the empty mask (count 0), the full mask of the 128 tiles, the interior, and 8 caves of
/// order 3; on each mask the count 0, the full count and 8 seeded counts (tag `'count128'`).
#[test]
#[available_gas(l2_gas: 73470319)]
fn test_map_compute_distribution_128_tiles() {
    let mut input: u32 = 0;
    for (width, height) in [(16_u8, 8_u8), (8, 16)].span() {
        let (width, height) = (*width, *height);
        let mut masks: Array<felt252> = array![0, FULL_128, interior_mask(width, height)];
        let mut seed: u32 = 0;
        while seed != 8 {
            masks.append(input_grid(width, height, 2 * seed));
            seed += 1;
        }
        for grid in masks {
            let total = tiles(grid).len();
            let mut counts: Array<u8> = array![0, total.try_into().unwrap()];
            let mut draw: u32 = 0;
            while draw != 8 {
                counts.append(below('count128', input * 8 + draw, total + 1).try_into().unwrap());
                draw += 1;
            }
            let lhs = O::new(grid, width, height, 0);
            let rhs = H::new(grid, width, height, 0);
            for count in counts {
                let seed = generator_seed(700000 + input);
                assert(
                    O::compute_distribution(
                        lhs, count, seed,
                    ) == H::compute_distribution(rhs, count, seed),
                    'compute_distribution',
                );
                input += 1;
            }
        }
    }
}

/// The interior mask of a board, from 1.8.0.
fn interior_mask(width: u8, height: u8) -> felt252 {
    origami_hexmap::helpers::layout::LayoutTrait::interior(width, height)
}

/// `search_path`, `distance_to`, `search_path_weighted` between distinct entrances and on the
/// seeded endpoints (hand-made boards). Entrance boards 0 to 2 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 117780680)]
fn test_map_paths_entrances_hand_0() {
    assert(check_paths_entrances(0, 3) != 0, 'no joined entrances');
}

/// `search_path`, `distance_to`, `search_path_weighted` between distinct entrances and on the
/// seeded endpoints (hand-made boards). Entrance boards 3 to 5 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 345900969)]
fn test_map_paths_entrances_hand_1() {
    assert(check_paths_entrances(3, 6) != 0, 'no joined entrances');
}

/// `search_path`, `distance_to`, `search_path_weighted` between distinct entrances and on the
/// seeded endpoints (hand-made boards). Entrance boards 6 to 8 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 413641490)]
fn test_map_paths_entrances_hand_2() {
    assert(check_paths_entrances(6, 9) != 0, 'no joined entrances');
}

/// The same on the generated boards. Entrance boards 9 to 11 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 328873306)]
fn test_map_paths_entrances_generated_0() {
    assert(check_paths_entrances(9, 12) != 0, 'no joined entrances');
}

/// The same on the generated boards. Entrance boards 12 to 14 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 321138872)]
fn test_map_paths_entrances_generated_1() {
    assert(check_paths_entrances(12, 15) != 0, 'no joined entrances');
}

/// `reachable`, `keep_component`, `range`, `ring` from every entrance and the seeded sources
/// (hand-made boards). Entrance boards 0 to 2 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 185504532)]
fn test_map_floods_entrances_hand_0() {
    check_floods_entrances(0, 3);
}

/// `reachable`, `keep_component`, `range`, `ring` from every entrance and the seeded sources
/// (hand-made boards). Entrance boards 3 to 5 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 312949760)]
fn test_map_floods_entrances_hand_1() {
    check_floods_entrances(3, 6);
}

/// `reachable`, `keep_component`, `range`, `ring` from every entrance and the seeded sources
/// (hand-made boards). Entrance boards 6 to 8 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 370643388)]
fn test_map_floods_entrances_hand_2() {
    check_floods_entrances(6, 9);
}

/// The same on the generated boards. Entrance boards 9 to 11 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 364818200)]
fn test_map_floods_entrances_generated_0() {
    check_floods_entrances(9, 12);
}

/// The same on the generated boards. Entrance boards 12 to 14 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 357480861)]
fn test_map_floods_entrances_generated_1() {
    check_floods_entrances(12, 15);
}

/// `field_of_movement` from every entrance and the seeded sources (hand-made boards). Entrance
/// boards 0 to 3 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 189976148)]
fn test_map_field_of_movement_entrances_hand_0() {
    check_field_of_movement_entrances(0, 4);
}

/// `field_of_movement` from every entrance and the seeded sources (hand-made boards). Entrance
/// boards 4 to 8 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 407404738)]
fn test_map_field_of_movement_entrances_hand_1() {
    check_field_of_movement_entrances(4, 9);
}

/// The same on the generated boards. Entrance boards 9 to 14 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 422321114)]
fn test_map_field_of_movement_entrances_generated() {
    check_field_of_movement_entrances(9, 15);
}

// Adjacent edge tiles (fix loop 2, finding 7).

/// `reachable`, `keep_component`, `range` and `ring` (every radius of `common::RADII`) from every
/// open tile of the boards `[first, last)` of `fixtures::edge_boards`.
fn check_floods_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        for from in tiles(grid) {
            assert(O::reachable(lhs, from) == H::reachable(rhs, from), 'reachable');
            let (mut left, mut right) = (lhs, rhs);
            O::keep_component(ref left, from);
            H::keep_component(ref right, from);
            assert_maps(left, right);
            for radius in RADII.span() {
                assert(O::range(lhs, from, *radius) == H::range(rhs, from, *radius), 'range');
                assert(O::ring(lhs, from, *radius) == H::ring(rhs, from, *radius), 'ring');
            }
        }
        index += 1;
    }
}

/// `search_path`, `distance_to` and `search_path_weighted` (0 to 3 cost classes) between every
/// ordered pair of distinct open tiles of the boards `[first, last)` of `fixtures::edge_boards`.
fn check_paths_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut input: u32 = 1000000 + 1000 * index;
        for (from, to) in open_pairs(grid) {
            assert(O::search_path(lhs, from, to) == H::search_path(rhs, from, to), 'search_path');
            assert(O::distance_to(lhs, from, to) == H::distance_to(rhs, from, to), 'distance_to');
            let costs = costs(input, width, height);
            let left = O::search_path_weighted(lhs, from, to, costs);
            assert(left == H::search_path_weighted(rhs, from, to, costs), 'weighted');
            input += 1;
        }
        index += 1;
    }
}

/// `field_of_movement` from every open tile of the boards `[first, last)` of
/// `fixtures::edge_boards`, every budget of `common::RADII`, 0 to 3 cost classes.
fn check_field_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let (lhs, rhs) = (O::new(grid, width, height, 0), H::new(grid, width, height, 0));
        let mut input: u32 = 1100000 + 1000 * index;
        for from in tiles(grid) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let left = O::field_of_movement(lhs, from, *budget, costs);
                assert(left == H::field_of_movement(rhs, from, *budget, costs), 'field');
                input += 1;
            }
        }
        index += 1;
    }
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 171283451)]
fn test_map_floods_edges_7x7() {
    check_floods_edges(0, 2);
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 172990930)]
fn test_map_floods_edges_16x8() {
    check_floods_edges(2, 4);
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 173157250)]
fn test_map_floods_edges_8x16() {
    check_floods_edges(4, 6);
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 197557545)]
fn test_map_floods_edges_15x16() {
    check_floods_edges(6, 8);
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 197469345)]
fn test_map_floods_edges_17x14() {
    check_floods_edges(8, 10);
}

/// `reachable`, `keep_component`, `range`, `ring` from every open tile of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 197363715)]
fn test_map_floods_edges_19x13() {
    check_floods_edges(10, 12);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_7X7` and `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 320541014)]
fn test_map_paths_edges_7x7() {
    check_paths_edges(0, 2);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_16X8` and `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 325149462)]
fn test_map_paths_edges_16x8() {
    check_paths_edges(2, 4);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_8X16` and `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 325128076)]
fn test_map_paths_edges_8x16() {
    check_paths_edges(4, 6);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_15X16` and `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 361999105)]
fn test_map_paths_edges_15x16() {
    check_paths_edges(6, 8);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_17X14` and `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 370088416)]
fn test_map_paths_edges_17x14() {
    check_paths_edges(8, 10);
}

/// `search_path`, `distance_to`, `search_path_weighted` between every pair of open tiles of
/// `EDGES_19X13` and `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 374544776)]
fn test_map_paths_edges_19x13() {
    check_paths_edges(10, 12);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 98397909)]
fn test_map_field_of_movement_edges_7x7() {
    check_field_edges(0, 2);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 101915382)]
fn test_map_field_of_movement_edges_16x8() {
    check_field_edges(2, 4);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 102053822)]
fn test_map_field_of_movement_edges_8x16() {
    check_field_edges(4, 6);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 126450509)]
fn test_map_field_of_movement_edges_15x16() {
    check_field_edges(6, 8);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 131829277)]
fn test_map_field_of_movement_edges_17x14() {
    check_field_edges(8, 10);
}

/// `field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 135168613)]
fn test_map_field_of_movement_edges_19x13() {
    check_field_edges(10, 12);
}

// Panics: one test per side, same input, same message (README of 1.8.0, § Panics).

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_empty_revert_dimension_origami() {
    let _ = O::new_empty(2, 7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_empty_revert_dimension_hexx() {
    let _ = H::new_empty(2, 7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_maze_revert_dimension_origami() {
    let _ = O::new_maze(7, 2, 0, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_maze_revert_dimension_hexx() {
    let _ = H::new_maze(7, 2, 0, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_new_maze_revert_order_origami() {
    let _ = O::new_maze(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_new_maze_revert_order_hexx() {
    let _ = H::new_maze(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_cave_revert_dimension_origami() {
    let _ = O::new_cave(12, 21, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_cave_revert_dimension_hexx() {
    let _ = H::new_cave(12, 21, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_random_walk_revert_dimension_origami() {
    let _ = O::new_random_walk(2, 2, 10, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_random_walk_revert_dimension_hexx() {
    let _ = H::new_random_walk(2, 2, 10, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_hexagon_revert_radius_origami() {
    let _ = O::new_hexagon(7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_new_hexagon_revert_radius_hexx() {
    let _ = H::new_hexagon(7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_corridor_revert_not_edge_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_corridor_revert_not_edge_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_corridor_revert_corner_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_corridor_revert_corner_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_corridor_revert_order_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_corridor_revert_order_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_corridor_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_corridor(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_corridor_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_corridor(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_corridor_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = O::open_with_corridor(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_corridor_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = H::open_with_corridor(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_maze_revert_not_edge_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_map_open_with_maze_revert_not_edge_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 24, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_maze_revert_corner_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_map_open_with_maze_revert_corner_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 0, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_maze_revert_order_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_map_open_with_maze_revert_order_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 3, 2);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_maze_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::open_with_maze(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_open_with_maze_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::open_with_maze(ref map, 49, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_maze_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = O::open_with_maze(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_open_with_maze_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 2, 'seed');
    let _ = H::open_with_maze(ref map, 3, 0);
}

#[test]
#[available_gas(l2_gas: 53632)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_keep_component_revert_wall_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::keep_component(ref map, 17);
}

#[test]
#[available_gas(l2_gas: 53632)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_keep_component_revert_wall_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::keep_component(ref map, 17);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_keep_component_revert_outside_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = O::keep_component(ref map, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_keep_component_revert_outside_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 7, 'seed');
    let _ = H::keep_component(ref map, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_keep_component_revert_dimension_origami() {
    let mut map = O::new(UNREACHABLE_7X7, 7, 36, 'seed');
    let _ = O::keep_component(ref map, 8);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_keep_component_revert_dimension_hexx() {
    let mut map = H::new(UNREACHABLE_7X7, 7, 36, 'seed');
    let _ = H::keep_component(ref map, 8);
}

#[test]
#[available_gas(l2_gas: 59642)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_map_compute_distribution_revert_not_enough_place_origami() {
    let _ = O::compute_distribution(O::new(EMPTY_7X7, 7, 7, 'seed'), 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 59642)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_map_compute_distribution_revert_not_enough_place_hexx() {
    let _ = H::compute_distribution(H::new(EMPTY_7X7, 7, 7, 'seed'), 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 69951)]
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
#[available_gas(l2_gas: 69951)]
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
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_compute_distribution_revert_dimension_origami() {
    let _ = O::compute_distribution(O::new(EMPTY_7X7, 2, 7, 'seed'), 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_compute_distribution_revert_dimension_hexx() {
    let _ = H::compute_distribution(H::new(EMPTY_7X7, 2, 7, 'seed'), 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 14053)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_from_wall_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 14053)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_from_wall_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 16040)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_to_wall_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17);
}

#[test]
#[available_gas(l2_gas: 16040)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_search_path_revert_to_wall_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_revert_outside_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_revert_outside_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_revert_dimension_origami() {
    let _ = O::search_path(O::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_revert_dimension_hexx() {
    let _ = H::search_path(H::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_search_path_weighted_revert_too_many_costs_origami() {
    let _ = O::search_path_weighted(
        O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 40, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_search_path_weighted_revert_too_many_costs_hexx() {
    let _ = H::search_path_weighted(
        H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 40, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 13475)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_from_wall_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 13475)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_from_wall_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 15526)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_to_wall_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 15526)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_search_path_weighted_revert_to_wall_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_weighted_revert_outside_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_search_path_weighted_revert_outside_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_weighted_revert_dimension_origami() {
    let _ = O::search_path_weighted(O::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_search_path_weighted_revert_dimension_hexx() {
    let _ = H::search_path_weighted(H::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_field_of_movement_revert_too_many_costs_origami() {
    let _ = O::field_of_movement(
        O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 3, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_map_field_of_movement_revert_too_many_costs_hexx() {
    let _ = H::field_of_movement(
        H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 3, array![0, 0, 0, 0].span(),
    );
}

#[test]
#[available_gas(l2_gas: 42984)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_field_of_movement_revert_wall_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 42984)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_map_field_of_movement_revert_wall_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_field_of_movement_revert_outside_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_field_of_movement_revert_outside_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_field_of_movement_revert_dimension_origami() {
    let _ = O::field_of_movement(O::new(UNREACHABLE_7X7, 36, 7, 'seed'), 8, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_field_of_movement_revert_dimension_hexx() {
    let _ = H::field_of_movement(H::new(UNREACHABLE_7X7, 36, 7, 'seed'), 8, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 13769)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_distance_to_revert_wall_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 13769)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_distance_to_revert_wall_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 40);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_distance_to_revert_outside_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_distance_to_revert_outside_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 40);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_distance_to_revert_dimension_origami() {
    let _ = O::distance_to(O::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_distance_to_revert_dimension_hexx() {
    let _ = H::distance_to(H::new(UNREACHABLE_7X7, 7, 2, 'seed'), 8, 9);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_from_outside_origami() {
    let _ = O::hex_distance(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 8);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_from_outside_hexx() {
    let _ = H::hex_distance(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 8);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_to_outside_origami() {
    let _ = O::hex_distance(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_hex_distance_revert_to_outside_hexx() {
    let _ = H::hex_distance(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 8, 49);
}

#[test]
#[available_gas(l2_gas: 53632)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_reachable_revert_wall_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17);
}

#[test]
#[available_gas(l2_gas: 53632)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_reachable_revert_wall_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_reachable_revert_outside_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_reachable_revert_outside_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_reachable_revert_dimension_origami() {
    let _ = O::reachable(O::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_reachable_revert_dimension_hexx() {
    let _ = H::reachable(H::new(UNREACHABLE_7X7, 2, 7, 'seed'), 8);
}

#[test]
#[available_gas(l2_gas: 55417)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_range_revert_wall_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 55417)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_range_revert_wall_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_range_revert_outside_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_range_revert_outside_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_range_revert_dimension_origami() {
    let _ = O::range(O::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_range_revert_dimension_hexx() {
    let _ = H::range(H::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 53156)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_ring_revert_wall_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 53156)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_map_ring_revert_wall_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 17, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_ring_revert_outside_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_map_ring_revert_outside_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 7, 'seed'), 49, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_ring_revert_dimension_origami() {
    let _ = O::ring(O::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_map_ring_revert_dimension_hexx() {
    let _ = H::ring(H::new(UNREACHABLE_7X7, 7, 36, 'seed'), 8, 2);
}

/// Radius 127: `2 * 127 + 3` overflows a `u8` in the addition (fix loop 1, finding 2; the message
/// was read from a run of both libraries).
#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'u8_add Overflow')]
fn test_map_new_hexagon_revert_radius_127_origami() {
    let _ = O::new_hexagon(127, 'seed');
}

/// Radius 127: `2 * 127 + 3` overflows a `u8` in the addition (fix loop 1, finding 2; the message
/// was read from a run of both libraries).
#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'u8_add Overflow')]
fn test_map_new_hexagon_revert_radius_127_hexx() {
    let _ = H::new_hexagon(127, 'seed');
}

/// Radius 128: `2 * 128` overflows a `u8` in the product (fix loop 1, finding 2; the message was
/// read from a run of both libraries).
#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'u8_mul Overflow')]
fn test_map_new_hexagon_revert_radius_128_origami() {
    let _ = O::new_hexagon(128, 'seed');
}

/// Radius 128: `2 * 128` overflows a `u8` in the product (fix loop 1, finding 2; the message was
/// read from a run of both libraries).
#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'u8_mul Overflow')]
fn test_map_new_hexagon_revert_radius_128_hexx() {
    let _ = H::new_hexagon(128, 'seed');
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 12621)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_small_bit_128_origami() {
    let _ = O::compute_distribution(
        O::new(EMPTY_7X7 + 0x100000000000000000000000000000000, 7, 7, 'seed'), 1, 'seed',
    );
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 12621)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_small_bit_128_hexx() {
    let _ = H::compute_distribution(
        H::new(EMPTY_7X7 + 0x100000000000000000000000000000000, 7, 7, 'seed'), 1, 'seed',
    );
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 58592)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_128_tiles_bit_128_origami() {
    let _ = O::compute_distribution(
        O::new(FULL_128 + 0x100000000000000000000000000000000, 16, 8, 'seed'), 1, 'seed',
    );
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 58592)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_map_compute_distribution_revert_128_tiles_bit_128_hexx() {
    let _ = H::compute_distribution(
        H::new(FULL_128 + 0x100000000000000000000000000000000, 16, 8, 'seed'), 1, 'seed',
    );
}
