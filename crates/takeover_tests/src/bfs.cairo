//! `finders::bfs` of 1.8.0 against `hexx::finders::bfs`: `Bfs::{search, distance, reachable,
//! tiles_within_range}`, `errors::BFS_POSITION_NOT_WALKABLE`.
//!
//! Inputs: the 10 fixtures of 1.8.0 with their endpoints (`fixtures::ENDPOINTS`) and the 32
//! generated boards (`fixtures::boards`); on each board the endpoints of `common::endpoints` and
//! the sources of `common::sources` (entrances included), every radius of `common::RADII`.

use hexx::finders::bfs as h;
use hexx::finders::bfs::Bfs as H;
use origami_hexmap::finders::bfs as o;
use origami_hexmap::finders::bfs::Bfs as O;
use crate::common::{RADII, endpoints, sources};
use crate::fixtures::{ENDPOINTS, UNREACHABLE_7X7, boards};

fn check_search(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in endpoints(index, grid, width, height) {
            let lhs = O::search(grid, width, height, from, to);
            let rhs = H::search(grid, width, height, from, to);
            assert(lhs == rhs, 'search');
        }
        index += 1;
    }
}

fn check_distance(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in endpoints(index, grid, width, height) {
            let lhs = O::distance(grid, width, height, from, to);
            let rhs = H::distance(grid, width, height, from, to);
            assert(lhs == rhs, 'distance');
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
        for from in sources(index, grid, width, height) {
            let lhs = O::reachable(grid, width, height, from);
            let rhs = H::reachable(grid, width, height, from);
            assert(lhs == rhs, 'reachable');
        }
        index += 1;
    }
}

fn check_tiles_within_range(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for from in sources(index, grid, width, height) {
            for radius in RADII.span() {
                let lhs = O::tiles_within_range(grid, width, height, from, *radius);
                let rhs = H::tiles_within_range(grid, width, height, from, *radius);
                assert(lhs == rhs, 'tiles_within_range');
            }
        }
        index += 1;
    }
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_bfs_errors() {
    assert(o::errors::BFS_POSITION_NOT_WALKABLE == h::errors::BFS_POSITION_NOT_WALKABLE, 'errors');
}

/// `Bfs::search` and `Bfs::distance` on the 20 endpoints of the fixtures of 1.8.0.
#[test]
#[available_gas(l2_gas: 29508843)]
fn test_bfs_fixture_endpoints() {
    for (grid, width, from, to) in ENDPOINTS.span() {
        let (grid, width, from, to) = (*grid, *width, *from, *to);
        let height = if width == 17 {
            14
        } else {
            7
        };
        let lhs = O::search(grid, width, height, from, to);
        let rhs = H::search(grid, width, height, from, to);
        assert(lhs == rhs, 'search');
        let lhs = O::distance(grid, width, height, from, to);
        let rhs = H::distance(grid, width, height, from, to);
        assert(lhs == rhs, 'distance');
    }
}

/// `Bfs::search` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 108582382)]
fn test_bfs_search_fixtures() {
    check_search(0, 10);
}

/// `Bfs::search` on `common::endpoints`. Boards 10 to 20 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 183101472)]
fn test_bfs_search_boards_0() {
    check_search(10, 21);
}

/// `Bfs::search` on `common::endpoints`. Boards 21 to 30 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 130924248)]
fn test_bfs_search_boards_1() {
    check_search(21, 31);
}

/// `Bfs::search` on `common::endpoints`. Boards 31 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 104927697)]
fn test_bfs_search_boards_2() {
    check_search(31, 42);
}

/// `Bfs::distance` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 87955754)]
fn test_bfs_distance_fixtures() {
    check_distance(0, 10);
}

/// `Bfs::distance` on `common::endpoints`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 342100431)]
fn test_bfs_distance_boards() {
    check_distance(10, 42);
}

/// `Bfs::reachable` from `common::sources`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 80611682)]
fn test_bfs_reachable_fixtures() {
    check_reachable(0, 10);
}

/// `Bfs::reachable` from `common::sources`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 335182557)]
fn test_bfs_reachable_boards() {
    check_reachable(10, 42);
}

/// `Bfs::tiles_within_range` from `common::sources`, every radius of `common::RADII`. Boards 0 to 9
/// of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 174250241)]
fn test_bfs_tiles_within_range_fixtures() {
    check_tiles_within_range(0, 10);
}

/// `Bfs::tiles_within_range` from `common::sources`, every radius of `common::RADII`. Boards 10 to
/// 25 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 428550503)]
fn test_bfs_tiles_within_range_boards_0() {
    check_tiles_within_range(10, 26);
}

/// `Bfs::tiles_within_range` from `common::sources`, every radius of `common::RADII`. Boards 26 to
/// 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 358403000)]
fn test_bfs_tiles_within_range_boards_1() {
    check_tiles_within_range(26, 42);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 22043)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_from_wall_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 17, 40);
}

#[test]
#[available_gas(l2_gas: 22043)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_from_wall_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 17, 40);
}

#[test]
#[available_gas(l2_gas: 24031)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_to_wall_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 8, 17);
}

#[test]
#[available_gas(l2_gas: 24031)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_to_wall_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 8, 17);
}

#[test]
#[available_gas(l2_gas: 21518)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_edge_wall_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 0, 40);
}

#[test]
#[available_gas(l2_gas: 21518)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_search_revert_edge_wall_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 0, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_search_revert_outside_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 8, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_search_revert_outside_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 8, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_bfs_search_revert_dimension_origami() {
    let _ = O::search(UNREACHABLE_7X7, 2, 7, 8, 9);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_bfs_search_revert_dimension_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 2, 7, 8, 9);
}

#[test]
#[available_gas(l2_gas: 21760)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_distance_revert_wall_origami() {
    let _ = O::distance(UNREACHABLE_7X7, 7, 7, 17, 40);
}

#[test]
#[available_gas(l2_gas: 21760)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_distance_revert_wall_hexx() {
    let _ = H::distance(UNREACHABLE_7X7, 7, 7, 17, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_distance_revert_outside_origami() {
    let _ = O::distance(UNREACHABLE_7X7, 7, 7, 49, 40);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_distance_revert_outside_hexx() {
    let _ = H::distance(UNREACHABLE_7X7, 7, 7, 49, 40);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_reachable_revert_wall_origami() {
    let _ = O::reachable(UNREACHABLE_7X7, 7, 7, 17);
}

#[test]
#[available_gas(l2_gas: 61623)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_reachable_revert_wall_hexx() {
    let _ = H::reachable(UNREACHABLE_7X7, 7, 7, 17);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_reachable_revert_outside_origami() {
    let _ = O::reachable(UNREACHABLE_7X7, 7, 7, 49);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_reachable_revert_outside_hexx() {
    let _ = H::reachable(UNREACHABLE_7X7, 7, 7, 49);
}

#[test]
#[available_gas(l2_gas: 63408)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_tiles_within_range_revert_wall_origami() {
    let _ = O::tiles_within_range(UNREACHABLE_7X7, 7, 7, 17, 2);
}

#[test]
#[available_gas(l2_gas: 63408)]
#[should_panic(expected: 'Bfs: position not walkable')]
fn test_bfs_tiles_within_range_revert_wall_hexx() {
    let _ = H::tiles_within_range(UNREACHABLE_7X7, 7, 7, 17, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_tiles_within_range_revert_outside_origami() {
    let _ = O::tiles_within_range(UNREACHABLE_7X7, 7, 7, 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_bfs_tiles_within_range_revert_outside_hexx() {
    let _ = H::tiles_within_range(UNREACHABLE_7X7, 7, 7, 49, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_bfs_tiles_within_range_revert_dimension_origami() {
    let _ = O::tiles_within_range(UNREACHABLE_7X7, 7, 36, 8, 2);
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_bfs_tiles_within_range_revert_dimension_hexx() {
    let _ = H::tiles_within_range(UNREACHABLE_7X7, 7, 36, 8, 2);
}
