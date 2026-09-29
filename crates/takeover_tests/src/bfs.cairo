//! `finders::bfs` of 1.8.0 against `hexx::finders::bfs`: `Bfs::{search, distance, reachable,
//! tiles_within_range}`, `errors::BFS_POSITION_NOT_WALKABLE`.
//!
//! Inputs: the 10 fixtures of 1.8.0 with their endpoints (`fixtures::ENDPOINTS`) and the 32
//! generated boards (`fixtures::boards`); on each board the endpoints of `common::endpoints` and
//! the sources of `common::sources` (entrances included), every radius of `common::RADII`; the 15
//! boards of `fixtures::entrance_boards` between distinct entrances; identical endpoints apart.

use hexx::finders::bfs as h;
use hexx::finders::bfs::Bfs as H;
use origami_hexmap::finders::bfs as o;
use origami_hexmap::finders::bfs::Bfs as O;
use crate::common::{
    RADII, endpoints, entrance_pairs, identical_endpoints, open_pairs, sources, tiles,
};
use crate::fixtures::{
    Board, ENDPOINTS, ENTRANCES_7X7_AUDIT, UNREACHABLE_7X7, boards, edge_boards, entrance_boards,
};

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
#[available_gas(l2_gas: 108025525)]
fn test_bfs_search_fixtures() {
    check_search(0, 10);
}

/// `Bfs::search` on `common::endpoints`. Boards 10 to 20 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 182301790)]
fn test_bfs_search_boards_0() {
    check_search(10, 21);
}

/// `Bfs::search` on `common::endpoints`. Boards 21 to 30 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 130176703)]
fn test_bfs_search_boards_1() {
    check_search(21, 31);
}

/// `Bfs::search` on `common::endpoints`. Boards 31 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 104106226)]
fn test_bfs_search_boards_2() {
    check_search(31, 42);
}

/// `Bfs::distance` on `common::endpoints`. Boards 0 to 9 of `fixtures::boards` (the fixtures of
/// 1.8.0).
#[test]
#[available_gas(l2_gas: 87439322)]
fn test_bfs_distance_fixtures() {
    check_distance(0, 10);
}

/// `Bfs::distance` on `common::endpoints`. Boards 10 to 41 of `fixtures::boards` (the generated
/// boards).
#[test]
#[available_gas(l2_gas: 339916164)]
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

/// The auditor's witness of fix loop 2 (finding 7): on a `15x16` whose only open tiles are the
/// adjacent edge tiles 1 and 2, the flood from 1 reaches 2 directly (through the neighbours of
/// the edge centre, no interior tile involved): `Bfs::reachable(6, 15, 16, 1) == 6`.
#[test]
#[available_gas(l2_gas: 243953)]
fn test_bfs_reachable_audit_witness() {
    let lhs = O::reachable(6, 15, 16, 1);
    assert(lhs == 6, 'value of 1.8.0');
    assert(lhs == H::reachable(6, 15, 16, 1), 'reachable');
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

/// `Bfs::search` on the boards `[first, last)` of `fixtures::entrance_boards`; returns the number
/// of distinct-entrance pairs joined by a path and the number without one.
fn check_search_entrances(first: u32, last: u32) -> (u32, u32) {
    let boards = entrance_boards();
    let (mut joined, mut apart) = (0, 0);
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let distinct = entrance_pairs(grid, width, height).len();
        let mut count: u32 = 0;
        for (from, to) in entrance_endpoints(index, board) {
            let lhs = O::search(grid, width, height, from, to);
            let rhs = H::search(grid, width, height, from, to);
            assert(lhs == rhs, 'search');
            if count < distinct {
                if lhs.len() == 0 {
                    apart += 1;
                } else {
                    joined += 1;
                }
            }
            count += 1;
        }
        index += 1;
    }
    (joined, apart)
}

fn check_distance_entrances(first: u32, last: u32) {
    let boards = entrance_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in entrance_endpoints(index, board) {
            let lhs = O::distance(grid, width, height, from, to);
            let rhs = H::distance(grid, width, height, from, to);
            assert(lhs == rhs, 'distance');
        }
        index += 1;
    }
}

/// `Bfs::reachable` and `Bfs::tiles_within_range` (every radius of `common::RADII`) from every
/// entrance and the seeded sources.
fn check_floods_entrances(first: u32, last: u32) {
    let boards = entrance_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for from in sources(100 + index, grid, width, height) {
            let lhs = O::reachable(grid, width, height, from);
            let rhs = H::reachable(grid, width, height, from);
            assert(lhs == rhs, 'reachable');
            for radius in RADII.span() {
                let lhs = O::tiles_within_range(grid, width, height, from, *radius);
                let rhs = H::tiles_within_range(grid, width, height, from, *radius);
                assert(lhs == rhs, 'tiles_within_range');
            }
        }
        index += 1;
    }
}

/// The auditor's scenario: `EMPTY_7X7` with the side tiles 1 and 43 open, from 1 to 43. Both
/// endpoints are entrances, joined through the interior: 1.8.0 returns the path
/// `[43, 36, 29, 22, 15, 8]` (target included, start excluded, read from a run), so a finder that
/// returned early on two edge endpoints fails here.
#[test]
#[available_gas(l2_gas: 1074434)]
fn test_bfs_audit_scenario() {
    let lhs = O::search(ENTRANCES_7X7_AUDIT, 7, 7, 1, 43);
    let rhs = H::search(ENTRANCES_7X7_AUDIT, 7, 7, 1, 43);
    assert(lhs.len() != 0, 'path expected');
    assert(lhs == rhs, 'search');
    assert(lhs == [43, 36, 29, 22, 15, 8].span(), 'path of 1.8.0');
    let lhs = O::distance(ENTRANCES_7X7_AUDIT, 7, 7, 1, 43);
    assert(lhs.is_some(), 'distance expected');
    assert(lhs == H::distance(ENTRANCES_7X7_AUDIT, 7, 7, 1, 43), 'distance');
}

/// `Bfs::search` between every ordered pair of distinct entrances and on the seeded endpoints of
/// the 9 hand-made entrance boards (both limb paths, the 15x16 twice); some distinct entrances
/// are joined by a path and some are not (disconnected components).
#[test]
#[available_gas(l2_gas: 280239467)]
fn test_bfs_search_entrances_hand() {
    let (joined, apart) = check_search_entrances(0, 9);
    assert(joined != 0, 'no joined entrances');
    assert(apart != 0, 'no separated entrances');
}

/// The same on the 6 generated entrance boards.
#[test]
#[available_gas(l2_gas: 216730475)]
fn test_bfs_search_entrances_generated() {
    let (joined, _) = check_search_entrances(9, 15);
    assert(joined != 0, 'no joined entrances');
}

/// `Bfs::distance` on the same pairs, the 9 hand-made entrance boards.
#[test]
#[available_gas(l2_gas: 212161505)]
fn test_bfs_distance_entrances_hand() {
    check_distance_entrances(0, 9);
}

/// `Bfs::distance` on the same pairs, the 6 generated entrance boards.
#[test]
#[available_gas(l2_gas: 158745437)]
fn test_bfs_distance_entrances_generated() {
    check_distance_entrances(9, 15);
}

/// `Bfs::reachable` and `Bfs::tiles_within_range` from every entrance and 6 seeded sources, the 9
/// hand-made entrance boards.
#[test]
#[available_gas(l2_gas: 355799067)]
fn test_bfs_floods_entrances_hand() {
    check_floods_entrances(0, 9);
}

/// The same on the 6 generated entrance boards.
#[test]
#[available_gas(l2_gas: 313193576)]
fn test_bfs_floods_entrances_generated() {
    check_floods_entrances(9, 15);
}

/// `Bfs::search` and `Bfs::distance` on identical endpoints (the early return), a seeded tile
/// and every entrance of the 42 boards and of the 15 entrance boards.
#[test]
#[available_gas(l2_gas: 238676038)]
fn test_bfs_identical_endpoints() {
    let mut all = boards();
    for board in entrance_boards() {
        all.append(board);
    }
    let mut index: u32 = 0;
    for board in all {
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in identical_endpoints(index, grid, width, height) {
            let lhs = O::search(grid, width, height, from, to);
            assert(lhs == H::search(grid, width, height, from, to), 'search');
            let lhs = O::distance(grid, width, height, from, to);
            assert(lhs == H::distance(grid, width, height, from, to), 'distance');
        }
        index += 1;
    }
}

// Adjacent edge tiles (fix loop 2, finding 7).

/// `Bfs::reachable` and `Bfs::tiles_within_range` (every radius of `common::RADII`) from every
/// open tile of the boards `[first, last)` of `fixtures::edge_boards`. The flood from the edge
/// tile 1 is pinned to `{1, 2}` (value 6) on every board: it reaches the adjacent edge tile 2
/// directly and does not cross it to 3.
fn check_floods_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        assert(O::reachable(grid, width, height, 1) == 6, 'edge 1 reaches 2 only');
        for from in tiles(grid) {
            let lhs = O::reachable(grid, width, height, from);
            assert(lhs == H::reachable(grid, width, height, from), 'reachable');
            for radius in RADII.span() {
                let lhs = O::tiles_within_range(grid, width, height, from, *radius);
                let rhs = H::tiles_within_range(grid, width, height, from, *radius);
                assert(lhs == rhs, 'tiles_within_range');
            }
        }
        index += 1;
    }
}

/// `Bfs::search` and `Bfs::distance` between every ordered pair of distinct open tiles of the
/// boards `[first, last)` of `fixtures::edge_boards`.
fn check_paths_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in open_pairs(grid) {
            let lhs = O::search(grid, width, height, from, to);
            assert(lhs == H::search(grid, width, height, from, to), 'search');
            let lhs = O::distance(grid, width, height, from, to);
            assert(lhs == H::distance(grid, width, height, from, to), 'distance');
        }
        index += 1;
    }
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 53882892)]
fn test_bfs_floods_edges_7x7() {
    check_floods_edges(0, 2);
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 55410222)]
fn test_bfs_floods_edges_16x8() {
    check_floods_edges(2, 4);
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 55576542)]
fn test_bfs_floods_edges_8x16() {
    check_floods_edges(4, 6);
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 65826645)]
fn test_bfs_floods_edges_15x16() {
    check_floods_edges(6, 8);
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 65738445)]
fn test_bfs_floods_edges_17x14() {
    check_floods_edges(8, 10);
}

/// `Bfs::reachable`, `Bfs::tiles_within_range` from every open tile of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 65811525)]
fn test_bfs_floods_edges_19x13() {
    check_floods_edges(10, 12);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 183343724)]
fn test_bfs_paths_edges_7x7() {
    check_paths_edges(0, 2);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 185086050)]
fn test_bfs_paths_edges_16x8() {
    check_paths_edges(2, 4);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 185266482)]
fn test_bfs_paths_edges_8x16() {
    check_paths_edges(4, 6);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 195678000)]
fn test_bfs_paths_edges_15x16() {
    check_paths_edges(6, 8);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 195589800)]
fn test_bfs_paths_edges_17x14() {
    check_paths_edges(8, 10);
}

/// `Bfs::search`, `Bfs::distance` between every pair of open tiles of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 195446958)]
fn test_bfs_paths_edges_19x13() {
    check_paths_edges(10, 12);
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
