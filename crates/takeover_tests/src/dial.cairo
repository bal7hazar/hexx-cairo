//! `finders::dial` of 1.8.0 against `hexx::finders::dial`: `Dial::{search,
//! field_of_movement}`, `errors::{DIAL_TOO_MANY_COSTS, DIAL_POSITION_NOT_WALKABLE}`.
//!
//! Inputs: the 10 fixtures of 1.8.0 with their endpoints (`fixtures::ENDPOINTS`) and the 32
//! generated boards (`fixtures::boards`); on each board the endpoints of `common::endpoints` and
//! the sources of `common::sources` (entrances included), every budget of `common::RADII`, with
//! 0 to 3 seeded cost classes (`common::costs`).

use hexx::finders::dial as h;
use hexx::finders::dial::Dial as H;
use origami_hexmap::finders::dial as o;
use origami_hexmap::finders::dial::Dial as O;
use crate::common::{RADII, costs, endpoints, sources};
use crate::fixtures::{ENDPOINTS, UNREACHABLE_7X7, boards};

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
#[available_gas(l2_gas: 218639571)]
fn test_dial_search_fixtures() {
    check_search(0, 10);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 10 to
/// 20 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 369401256)]
fn test_dial_search_boards_0() {
    check_search(10, 21);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 21 to
/// 30 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 265592778)]
fn test_dial_search_boards_1() {
    check_search(21, 31);
}

/// `Dial::search` on `common::endpoints`, with 0 to 3 cost classes (`common::costs`). Boards 31 to
/// 41 of `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 210825504)]
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
