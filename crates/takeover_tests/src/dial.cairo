//! `finders::dial` of 1.8.0 against `hexx::finders::dial`: `Dial::{search,
//! field_of_movement}`, `errors::{DIAL_TOO_MANY_COSTS, DIAL_POSITION_NOT_WALKABLE}`.
//!
//! Inputs: the 10 fixtures of 1.8.0 with their endpoints (`fixtures::ENDPOINTS`) and the 32
//! generated boards (`fixtures::boards`); on each board the endpoints of `common::endpoints` and
//! the sources of `common::sources` (entrances included), every budget of `common::RADII`, with
//! 0 to 3 seeded cost classes (`common::costs`); the 15 boards of `fixtures::entrance_boards`
//! between distinct entrances; identical endpoints apart.

use hexx::finders::dial as h;
use hexx::finders::dial::Dial as H;
use origami_hexmap::finders::dial as o;
use origami_hexmap::finders::dial::Dial as O;
use crate::common::{
    RADII, costs, endpoints, entrance_pairs, identical_endpoints, open_pairs, sources, tiles,
};
use crate::fixtures::{ENDPOINTS, UNREACHABLE_7X7, boards, edge_boards, entrance_boards};

fn check_search(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let mut input: u32 = 1000 * index;
        for (from, to) in endpoints(index, grid, width, height) {
            let costs = costs(input, width, height);
            let lhs = O::search(grid, width, height, from, to, costs);
            let rhs = H::search(grid, width, height, from, to, costs);
            assert(lhs == rhs, 'search');
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
        let mut input: u32 = 1000 * index + 500;
        for from in sources(index, grid, width, height) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let lhs = O::field_of_movement(grid, width, height, from, *budget, costs);
                let rhs = H::field_of_movement(grid, width, height, from, *budget, costs);
                assert(lhs == rhs, 'field_of_movement');
                input += 1;
            }
        }
        index += 1;
    }
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_dial_errors() {
    assert(o::errors::DIAL_TOO_MANY_COSTS == h::errors::DIAL_TOO_MANY_COSTS, 'costs');
    assert(
        o::errors::DIAL_POSITION_NOT_WALKABLE == h::errors::DIAL_POSITION_NOT_WALKABLE, 'walkable',
    );
}

/// `Dial::search` on the 20 endpoints of the fixtures of 1.8.0, 0 to 3 cost classes.
#[test]
#[available_gas(l2_gas: 162277158)]
fn test_dial_fixture_endpoints() {
    let mut input: u32 = 100000;
    for (grid, width, from, to) in ENDPOINTS.span() {
        let (grid, width, from, to) = (*grid, *width, *from, *to);
        let height = if width == 17 {
            14
        } else {
            7
        };
        let mut classes: u32 = 0;
        while classes != 4 {
            let costs = costs(input + classes, width, height);
            let lhs = O::search(grid, width, height, from, to, costs);
            let rhs = H::search(grid, width, height, from, to, costs);
            assert(lhs == rhs, 'search');
            classes += 1;
        }
        input += 4;
    }
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 0 to 9
/// of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 216082569)]
fn test_dial_search_fixtures() {
    check_search(0, 10);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 10 to
/// 20 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 360707112)]
fn test_dial_search_boards_0() {
    check_search(10, 21);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 21 to
/// 30 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 257306369)]
fn test_dial_search_boards_1() {
    check_search(21, 31);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 31 to
/// 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 204276621)]
fn test_dial_search_boards_2() {
    check_search(31, 42);
}

/// `Dial::field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 0 to 9 of `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 370485363)]
fn test_dial_field_of_movement_fixtures() {
    check_field_of_movement(0, 10);
}

/// `Dial::field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 10 to 17 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 394086536)]
fn test_dial_field_of_movement_boards_0() {
    check_field_of_movement(10, 18);
}

/// `Dial::field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 18 to 25 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 420371640)]
fn test_dial_field_of_movement_boards_1() {
    check_field_of_movement(18, 26);
}

/// `Dial::field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 26 to 33 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 414550532)]
fn test_dial_field_of_movement_boards_2() {
    check_field_of_movement(26, 34);
}

/// `Dial::field_of_movement` from `common::sources`, every budget of `common::RADII`, 0 to 3 cost
/// classes. Boards 34 to 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 302391888)]
fn test_dial_field_of_movement_boards_3() {
    check_field_of_movement(34, 42);
}

// Entrances (fix loop 1, finding 1).

/// `Dial::search` between every ordered pair of distinct entrances and on the seeded endpoints
/// (board index `100 + k`) of the boards `[first, last)` of `fixtures::entrance_boards`, with 0
/// to 3 cost classes; returns the number of distinct-entrance pairs joined by a path.
fn check_search_entrances(first: u32, last: u32) -> u32 {
    let boards = entrance_boards();
    let mut joined: u32 = 0;
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let mut pairs = entrance_pairs(grid, width, height);
        let distinct = pairs.len();
        for pair in endpoints(100 + index, grid, width, height) {
            pairs.append(pair);
        }
        let mut input: u32 = 300000 + 1000 * index;
        let mut count: u32 = 0;
        for (from, to) in pairs {
            let costs = costs(input, width, height);
            let lhs = O::search(grid, width, height, from, to, costs);
            let rhs = H::search(grid, width, height, from, to, costs);
            assert(lhs == rhs, 'search');
            if count < distinct && lhs.len() != 0 {
                joined += 1;
            }
            input += 1;
            count += 1;
        }
        index += 1;
    }
    joined
}

/// `Dial::field_of_movement` from every entrance and the seeded sources, every budget of
/// `common::RADII`, 0 to 3 cost classes.
fn check_field_of_movement_entrances(first: u32, last: u32) {
    let boards = entrance_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let mut input: u32 = 300000 + 1000 * index + 500;
        for from in sources(100 + index, grid, width, height) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let lhs = O::field_of_movement(grid, width, height, from, *budget, costs);
                let rhs = H::field_of_movement(grid, width, height, from, *budget, costs);
                assert(lhs == rhs, 'field_of_movement');
                input += 1;
            }
        }
        index += 1;
    }
}

/// `Dial::search` between distinct entrances and on the seeded endpoints, the 9 hand-made entrance
/// boards.
#[test]
#[available_gas(l2_gas: 496494086)]
fn test_dial_search_entrances_hand() {
    assert(check_search_entrances(0, 9) != 0, 'no joined entrances');
}

/// The same on the 6 generated entrance boards.
#[test]
#[available_gas(l2_gas: 371680924)]
fn test_dial_search_entrances_generated() {
    assert(check_search_entrances(9, 15) != 0, 'no joined entrances');
}

/// `Dial::search` on identical endpoints (the early return), a seeded tile and every entrance of
/// the 42 boards and of the 15 entrance boards, 0 to 3 cost classes.
#[test]
#[available_gas(l2_gas: 264432147)]
fn test_dial_identical_endpoints() {
    let mut all = boards();
    for board in entrance_boards() {
        all.append(board);
    }
    let mut index: u32 = 0;
    let mut input: u32 = 400000;
    for board in all {
        let (grid, width, height) = (board.grid, board.width, board.height);
        for (from, to) in identical_endpoints(index, grid, width, height) {
            let costs = costs(input, width, height);
            let lhs = O::search(grid, width, height, from, to, costs);
            assert(lhs == H::search(grid, width, height, from, to, costs), 'search');
            input += 1;
        }
        index += 1;
    }
}

/// `Dial::field_of_movement` from every entrance and the seeded sources (hand-made boards).
/// Entrance boards 0 to 3 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 190261187)]
fn test_dial_field_of_movement_entrances_hand_0() {
    check_field_of_movement_entrances(0, 4);
}

/// `Dial::field_of_movement` from every entrance and the seeded sources (hand-made boards).
/// Entrance boards 4 to 8 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 407180395)]
fn test_dial_field_of_movement_entrances_hand_1() {
    check_field_of_movement_entrances(4, 9);
}

/// The same on the generated boards. Entrance boards 9 to 14 of `fixtures::entrance_boards`.
#[test]
#[available_gas(l2_gas: 421406675)]
fn test_dial_field_of_movement_entrances_generated() {
    check_field_of_movement_entrances(9, 15);
}

// Adjacent edge tiles (fix loop 2, finding 7).

/// `Dial::search` between every ordered pair of distinct open tiles of the boards `[first, last)`
/// of `fixtures::edge_boards`, 0 to 3 cost classes (`common::costs`).
fn check_search_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let mut input: u32 = 900000 + 1000 * index;
        for (from, to) in open_pairs(grid) {
            let costs = costs(input, width, height);
            let lhs = O::search(grid, width, height, from, to, costs);
            assert(lhs == H::search(grid, width, height, from, to, costs), 'search');
            input += 1;
        }
        index += 1;
    }
}

/// `Dial::field_of_movement` from every open tile, every budget of `common::RADII`, 0 to 3 cost
/// classes.
fn check_field_of_movement_edges(first: u32, last: u32) {
    let boards = edge_boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let (grid, width, height) = (board.grid, board.width, board.height);
        let mut input: u32 = 950000 + 1000 * index;
        for from in tiles(grid) {
            for budget in RADII.span() {
                let costs = costs(input, width, height);
                let lhs = O::field_of_movement(grid, width, height, from, *budget, costs);
                let rhs = H::field_of_movement(grid, width, height, from, *budget, costs);
                assert(lhs == rhs, 'field_of_movement');
                input += 1;
            }
        }
        index += 1;
    }
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 139621319)]
fn test_dial_search_edges_7x7() {
    check_search_edges(0, 2);
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 143739440)]
fn test_dial_search_edges_16x8() {
    check_search_edges(2, 4);
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 144003103)]
fn test_dial_search_edges_8x16() {
    check_search_edges(4, 6);
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 173271868)]
fn test_dial_search_edges_15x16() {
    check_search_edges(6, 8);
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 180948136)]
fn test_dial_search_edges_17x14() {
    check_search_edges(8, 10);
}

/// `Dial::search` between every pair of open tiles, 0 to 3 cost classes, of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 184489137)]
fn test_dial_search_edges_19x13() {
    check_search_edges(10, 12);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_7X7` and
/// `EDGES_POCKET_7X7` (single-limb path).
#[test]
#[available_gas(l2_gas: 98116759)]
fn test_dial_field_of_movement_edges_7x7() {
    check_field_of_movement_edges(0, 2);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_16X8` and
/// `EDGES_POCKET_16X8` (single-limb path).
#[test]
#[available_gas(l2_gas: 101587530)]
fn test_dial_field_of_movement_edges_16x8() {
    check_field_of_movement_edges(2, 4);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_8X16` and
/// `EDGES_POCKET_8X16` (single-limb path).
#[test]
#[available_gas(l2_gas: 102000577)]
fn test_dial_field_of_movement_edges_8x16() {
    check_field_of_movement_edges(4, 6);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_15X16` and
/// `EDGES_POCKET_15X16` (two-limb path).
#[test]
#[available_gas(l2_gas: 125458881)]
fn test_dial_field_of_movement_edges_15x16() {
    check_field_of_movement_edges(6, 8);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_17X14` and
/// `EDGES_POCKET_17X14` (two-limb path).
#[test]
#[available_gas(l2_gas: 131841835)]
fn test_dial_field_of_movement_edges_17x14() {
    check_field_of_movement_edges(8, 10);
}

/// `Dial::field_of_movement` from every open tile, 0 to 3 cost classes, of `EDGES_19X13` and
/// `EDGES_POCKET_19X13` (two-limb path).
#[test]
#[available_gas(l2_gas: 135152628)]
fn test_dial_field_of_movement_edges_19x13() {
    check_field_of_movement_edges(10, 12);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_dial_search_revert_too_many_costs_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 8, 40, array![0, 0, 0, 0].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_dial_search_revert_too_many_costs_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 8, 40, array![0, 0, 0, 0].span());
}

#[test]
#[available_gas(l2_gas: 21466)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_search_revert_from_wall_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 21466)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_search_revert_from_wall_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 17, 40, array![].span());
}

#[test]
#[available_gas(l2_gas: 23516)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_search_revert_to_wall_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 23516)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_search_revert_to_wall_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 8, 17, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_dial_search_revert_outside_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 7, 8, 49, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_dial_search_revert_outside_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 7, 8, 49, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_dial_search_revert_dimension_origami() {
    let _ = O::search(UNREACHABLE_7X7, 7, 2, 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_dial_search_revert_dimension_hexx() {
    let _ = H::search(UNREACHABLE_7X7, 7, 2, 8, 9, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_dial_field_of_movement_revert_too_many_costs_origami() {
    let _ = O::field_of_movement(UNREACHABLE_7X7, 7, 7, 8, 3, array![0, 0, 0, 0].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Dial: too many costs')]
fn test_dial_field_of_movement_revert_too_many_costs_hexx() {
    let _ = H::field_of_movement(UNREACHABLE_7X7, 7, 7, 8, 3, array![0, 0, 0, 0].span());
}

#[test]
#[available_gas(l2_gas: 50975)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_field_of_movement_revert_wall_origami() {
    let _ = O::field_of_movement(UNREACHABLE_7X7, 7, 7, 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 50975)]
#[should_panic(expected: 'Dial: position not walkable')]
fn test_dial_field_of_movement_revert_wall_hexx() {
    let _ = H::field_of_movement(UNREACHABLE_7X7, 7, 7, 17, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_dial_field_of_movement_revert_outside_origami() {
    let _ = O::field_of_movement(UNREACHABLE_7X7, 7, 7, 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_dial_field_of_movement_revert_outside_hexx() {
    let _ = H::field_of_movement(UNREACHABLE_7X7, 7, 7, 49, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_dial_field_of_movement_revert_dimension_origami() {
    let _ = O::field_of_movement(UNREACHABLE_7X7, 36, 7, 8, 3, array![].span());
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_dial_field_of_movement_revert_dimension_hexx() {
    let _ = H::field_of_movement(UNREACHABLE_7X7, 36, 7, 8, 3, array![].span());
}
