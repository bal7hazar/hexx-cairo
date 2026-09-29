//! `generators::spreader` of 1.8.0 against `hexx::generators::spreader`: `Spreader::generate`,
//! `errors::{SPREADER_NOT_ENOUGH_PLACE, SPREADER_INVALID_GRID}`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, the
//! grid `common::input_grid` of the seed, a seeded count (tag `'count'`, at most the number of
//! walkable tiles) and the full count; then every board of `fixtures::boards`, entrances
//! included, with 8 seeded counts and 0.

use hexx::generators::spreader as h;
use hexx::generators::spreader::Spreader as H;
use origami_hexmap::generators::spreader as o;
use origami_hexmap::generators::spreader::Spreader as O;
use crate::common::{below, generator_seed, input_grid, tiles};
use crate::fixtures::{EMPTY_17X14, EMPTY_7X7, boards};

/// A seeded count and the full count on the seeds `[first, last)`.
fn check_generate(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let grid = input_grid(width, height, index);
        let total = tiles(grid).len();
        let count: u8 = below('count', index, total + 1).try_into().unwrap();
        let full: u8 = total.try_into().unwrap();
        for count in [count, full].span() {
            let lhs = O::generate(grid, width, height, *count, seed);
            let rhs = H::generate(grid, width, height, *count, seed);
            assert(lhs == rhs, 'generate');
        }
        index += 1;
    }
}

/// 8 seeded counts and 0 on the boards `[first, last)` of `fixtures::boards`.
fn check_generate_boards(first: u32, last: u32) {
    let boards = boards();
    let mut index = first;
    while index != last {
        let board = *boards.at(index);
        let total = tiles(board.grid).len();
        let mut draw: u32 = 0;
        while draw != 9 {
            let count: u8 = if draw == 8 {
                0
            } else {
                below('count', 1000 * (index + 1) + draw, total + 1).try_into().unwrap()
            };
            let seed = generator_seed(1000 * (index + 1) + draw);
            let lhs = O::generate(board.grid, board.width, board.height, count, seed);
            let rhs = H::generate(board.grid, board.width, board.height, count, seed);
            assert(lhs == rhs, 'generate');
            draw += 1;
        }
        index += 1;
    }
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_spreader_errors() {
    assert(o::errors::SPREADER_NOT_ENOUGH_PLACE == h::errors::SPREADER_NOT_ENOUGH_PLACE, 'place');
    assert(o::errors::SPREADER_INVALID_GRID == h::errors::SPREADER_INVALID_GRID, 'grid');
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 5921212)]
fn test_spreader_generate_3x3_0() {
    check_generate(3, 3, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 6236676)]
fn test_spreader_generate_3x3_1() {
    check_generate(3, 3, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 5987376)]
fn test_spreader_generate_3x3_2() {
    check_generate(3, 3, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 17027537)]
fn test_spreader_generate_7x7_0() {
    check_generate(7, 7, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 18875861)]
fn test_spreader_generate_7x7_1() {
    check_generate(7, 7, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 17238528)]
fn test_spreader_generate_7x7_2() {
    check_generate(7, 7, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 67120748)]
fn test_spreader_generate_15x15_0() {
    check_generate(15, 15, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 71282763)]
fn test_spreader_generate_15x15_1() {
    check_generate(15, 15, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 67811915)]
fn test_spreader_generate_15x15_2() {
    check_generate(15, 15, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 70159072)]
fn test_spreader_generate_15x16_0() {
    check_generate(15, 16, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 75618773)]
fn test_spreader_generate_15x16_1() {
    check_generate(15, 16, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 73225984)]
fn test_spreader_generate_15x16_2() {
    check_generate(15, 16, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 71096520)]
fn test_spreader_generate_17x14_0() {
    check_generate(17, 14, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 75326674)]
fn test_spreader_generate_17x14_1() {
    check_generate(17, 14, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 72073130)]
fn test_spreader_generate_17x14_2() {
    check_generate(17, 14, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 73337590)]
fn test_spreader_generate_19x13_0() {
    check_generate(19, 13, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 76707466)]
fn test_spreader_generate_19x13_1() {
    check_generate(19, 13, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 73689920)]
fn test_spreader_generate_19x13_2() {
    check_generate(19, 13, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 72937987)]
fn test_spreader_generate_25x10_0() {
    check_generate(25, 10, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 76200064)]
fn test_spreader_generate_25x10_1() {
    check_generate(25, 10, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 73662994)]
fn test_spreader_generate_25x10_2() {
    check_generate(25, 10, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 39619055)]
fn test_spreader_generate_83x3_0() {
    check_generate(83, 3, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 39623509)]
fn test_spreader_generate_83x3_1() {
    check_generate(83, 3, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 41859025)]
fn test_spreader_generate_83x3_2() {
    check_generate(83, 3, 43, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 20
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 41410238)]
fn test_spreader_generate_3x83_0() {
    check_generate(3, 83, 0, 21);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 21 to 42
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 43345631)]
fn test_spreader_generate_3x83_1() {
    check_generate(3, 83, 21, 43);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 43 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 40406588)]
fn test_spreader_generate_3x83_2() {
    check_generate(3, 83, 43, 64);
}

/// `Spreader::generate`, 8 seeded counts per board, entrances included. Boards 0 to 9 of
/// `fixtures::boards` (the fixtures of 1.8.0).
#[test]
#[available_gas(l2_gas: 39466745)]
fn test_spreader_generate_fixtures() {
    check_generate_boards(0, 10);
}

/// `Spreader::generate`, 8 seeded counts per board, entrances included. Boards 10 to 41 of
/// `fixtures::boards` (the generated boards).
#[test]
#[available_gas(l2_gas: 154812330)]
fn test_spreader_generate_boards() {
    check_generate_boards(10, 42);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 67653)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_spreader_generate_revert_not_enough_place_origami() {
    let _ = O::generate(EMPTY_7X7, 7, 7, 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 67653)]
#[should_panic(expected: 'Spreader: not enough place')]
fn test_spreader_generate_revert_not_enough_place_hexx() {
    let _ = H::generate(EMPTY_7X7, 7, 7, 26, 'seed');
}

#[test]
#[available_gas(l2_gas: 21578)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_invalid_grid_small_origami() {
    let _ = O::generate(EMPTY_7X7 + 0x2000000000000, 7, 7, 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 21578)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_invalid_grid_small_hexx() {
    let _ = H::generate(EMPTY_7X7 + 0x2000000000000, 7, 7, 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 77963)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_invalid_grid_wide_origami() {
    let _ = O::generate(
        EMPTY_17X14 + 0x400000000000000000000000000000000000000000000000000000000000,
        17,
        14,
        1,
        'seed',
    );
}

#[test]
#[available_gas(l2_gas: 77963)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_invalid_grid_wide_hexx() {
    let _ = H::generate(
        EMPTY_17X14 + 0x400000000000000000000000000000000000000000000000000000000000,
        17,
        14,
        1,
        'seed',
    );
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_spreader_generate_revert_dimension_origami() {
    let _ = O::generate(EMPTY_7X7, 2, 7, 1, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_spreader_generate_revert_dimension_hexx() {
    let _ = H::generate(EMPTY_7X7, 2, 7, 1, 'seed');
}
