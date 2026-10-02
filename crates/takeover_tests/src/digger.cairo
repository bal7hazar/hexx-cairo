//! `generators::digger` of 1.8.0 against `hexx::generators::digger`: `Digger::{maze,
//! corridor}`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, both
//! orders the functions accept (0 and 1), the grid `common::input_grid` of the seed (a cave or a
//! random walk), the start a seeded side tile (tag `'start'`, `common::sides`).

use hexx::generators::digger::Digger as H;
use origami_hexmap::generators::digger::Digger as O;
use crate::common::{below, generator_seed, input_grid, sides};
use crate::fixtures::EMPTY_7X7;

/// Both orders on the seeds `[first, last)`, `corridor` or `maze`.
fn check(width: u8, height: u8, corridor: bool, first: u32, last: u32) {
    let sides = sides(width, height);
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let grid = input_grid(width, height, index);
        let start = *sides.at(below('start', index, sides.len()));
        let mut order: u8 = 0;
        while order != 2 {
            let (lhs, rhs) = if corridor {
                (
                    O::corridor(width, height, order, start, grid, seed),
                    H::corridor(width, height, order, start, grid, seed),
                )
            } else {
                (
                    O::maze(width, height, order, start, grid, seed),
                    H::maze(width, height, order, start, grid, seed),
                )
            };
            assert(lhs == rhs, 'dig');
            order += 1;
        }
        index += 1;
    }
}

fn check_maze(width: u8, height: u8, first: u32, last: u32) {
    check(width, height, false, first, last);
}

fn check_corridor(width: u8, height: u8, first: u32, last: u32) {
    check(width, height, true, first, last);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 28252554)]
fn test_digger_maze_3x3() {
    check_maze(3, 3, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 52889494)]
fn test_digger_maze_7x7() {
    check_maze(7, 7, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 148551308)]
fn test_digger_maze_15x15() {
    check_maze(15, 15, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 178977561)]
fn test_digger_maze_15x16() {
    check_maze(15, 16, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 151127637)]
fn test_digger_maze_17x14() {
    check_maze(17, 14, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 129488430)]
fn test_digger_maze_19x13() {
    check_maze(19, 13, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 159774956)]
fn test_digger_maze_25x10() {
    check_maze(25, 10, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 328735330)]
fn test_digger_maze_83x3() {
    check_maze(83, 3, 0, 64);
}

/// `Digger::maze`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 282118282)]
fn test_digger_maze_3x83() {
    check_maze(3, 83, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 28234410)]
fn test_digger_corridor_3x3() {
    check_corridor(3, 3, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 44038935)]
fn test_digger_corridor_7x7() {
    check_corridor(7, 7, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 95776420)]
fn test_digger_corridor_15x15() {
    check_corridor(15, 15, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 111045558)]
fn test_digger_corridor_15x16() {
    check_corridor(15, 16, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 99947564)]
fn test_digger_corridor_17x14() {
    check_corridor(17, 14, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 93311652)]
fn test_digger_corridor_19x13() {
    check_corridor(19, 13, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 117246035)]
fn test_digger_corridor_25x10() {
    check_corridor(25, 10, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 324766216)]
fn test_digger_corridor_83x3() {
    check_corridor(83, 3, 0, 64);
}

/// `Digger::corridor`, orders 0 and 1, on `common::input_grid` from a seeded side tile. Seeds 0 to
/// 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 259547508)]
fn test_digger_corridor_3x83() {
    check_corridor(3, 83, 0, 64);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_digger_maze_revert_dimension_origami() {
    let _ = O::maze(2, 7, 0, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_digger_maze_revert_dimension_hexx() {
    let _ = H::maze(2, 7, 0, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_digger_maze_revert_order_origami() {
    let _ = O::maze(7, 7, 2, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_digger_maze_revert_order_hexx() {
    let _ = H::maze(7, 7, 2, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_digger_maze_revert_outside_origami() {
    let _ = O::maze(7, 7, 0, 49, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_digger_maze_revert_outside_hexx() {
    let _ = H::maze(7, 7, 0, 49, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_digger_maze_revert_corner_origami() {
    let _ = O::maze(7, 7, 0, 0, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_digger_maze_revert_corner_hexx() {
    let _ = H::maze(7, 7, 0, 0, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_digger_maze_revert_not_edge_origami() {
    let _ = O::maze(7, 7, 0, 24, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_digger_maze_revert_not_edge_hexx() {
    let _ = H::maze(7, 7, 0, 24, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_digger_corridor_revert_dimension_origami() {
    let _ = O::corridor(2, 7, 0, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_digger_corridor_revert_dimension_hexx() {
    let _ = H::corridor(2, 7, 0, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_digger_corridor_revert_order_origami() {
    let _ = O::corridor(7, 7, 2, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_digger_corridor_revert_order_hexx() {
    let _ = H::corridor(7, 7, 2, 3, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_digger_corridor_revert_outside_origami() {
    let _ = O::corridor(7, 7, 0, 49, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_digger_corridor_revert_outside_hexx() {
    let _ = H::corridor(7, 7, 0, 49, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_digger_corridor_revert_corner_origami() {
    let _ = O::corridor(7, 7, 0, 0, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_digger_corridor_revert_corner_hexx() {
    let _ = H::corridor(7, 7, 0, 0, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_digger_corridor_revert_not_edge_origami() {
    let _ = O::corridor(7, 7, 0, 24, EMPTY_7X7, 'seed');
}

#[test]
#[available_gas(l2_gas: 10868)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_digger_corridor_revert_not_edge_hexx() {
    let _ = H::corridor(7, 7, 0, 24, EMPTY_7X7, 'seed');
}
