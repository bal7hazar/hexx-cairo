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
use origami_hexmap::helpers::layout::LayoutTrait;
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

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x3`.
#[test]
#[available_gas(l2_gas: 18113175)]
fn test_spreader_generate_3x3() {
    check_generate(3, 3, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `7x7`.
#[test]
#[available_gas(l2_gas: 53107736)]
fn test_spreader_generate_7x7() {
    check_generate(7, 7, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x15`.
#[test]
#[available_gas(l2_gas: 206183337)]
fn test_spreader_generate_15x15() {
    check_generate(15, 15, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `15x16`.
#[test]
#[available_gas(l2_gas: 218971740)]
fn test_spreader_generate_15x16() {
    check_generate(15, 16, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `17x14`.
#[test]
#[available_gas(l2_gas: 218462135)]
fn test_spreader_generate_17x14() {
    check_generate(17, 14, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `19x13`.
#[test]
#[available_gas(l2_gas: 223700787)]
fn test_spreader_generate_19x13() {
    check_generate(19, 13, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `25x10`.
#[test]
#[available_gas(l2_gas: 222766856)]
fn test_spreader_generate_25x10() {
    check_generate(25, 10, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `83x3`.
#[test]
#[available_gas(l2_gas: 121069501)]
fn test_spreader_generate_83x3() {
    check_generate(83, 3, 0, 64);
}

/// `Spreader::generate` on `common::input_grid`, a seeded count and the full count. Seeds 0 to 63
/// on `3x83`.
#[test]
#[available_gas(l2_gas: 125130367)]
fn test_spreader_generate_3x83() {
    check_generate(3, 83, 0, 64);
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

/// All 128 tiles of a 16x8 or 8x16 board, the last board of the single-limb path.
const FULL_128: felt252 = 0xffffffffffffffffffffffffffffffff;

/// `Spreader::generate` on the boards of exactly 128 tiles, 16x8 and 8x16 (fix loop 1, finding 4:
/// the branch `size == 128` of the grid check): the empty mask (count 0), the full mask of the
/// 128 tiles, the interior, and 8 caves of order 3; on each mask the count 0, the full count and
/// 8 seeded counts (tag `'count128'`).
#[test]
#[available_gas(l2_gas: 72876981)]
fn test_spreader_generate_128_tiles() {
    let mut input: u32 = 0;
    for (width, height) in [(16_u8, 8_u8), (8, 16)].span() {
        let (width, height) = (*width, *height);
        let mut masks: Array<felt252> = array![0, FULL_128, LayoutTrait::interior(width, height)];
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
            for count in counts {
                let seed = generator_seed(800000 + input);
                let lhs = O::generate(grid, width, height, count, seed);
                let rhs = H::generate(grid, width, height, count, seed);
                assert(lhs == rhs, 'generate');
                input += 1;
            }
        }
    }
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

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 20633)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_small_bit_128_origami() {
    let _ = O::generate(EMPTY_7X7 + 0x100000000000000000000000000000000, 7, 7, 1, 'seed');
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 20633)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_small_bit_128_hexx() {
    let _ = H::generate(EMPTY_7X7 + 0x100000000000000000000000000000000, 7, 7, 1, 'seed');
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 66603)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_128_tiles_bit_128_origami() {
    let _ = O::generate(FULL_128 + 0x100000000000000000000000000000000, 16, 8, 1, 'seed');
}

/// A grid with bit 128 set on a board of at most 128 tiles: rejected through its high limb (fix
/// loop 1, finding 4).
#[test]
#[available_gas(l2_gas: 66603)]
#[should_panic(expected: 'Spreader: invalid grid')]
fn test_spreader_generate_revert_128_tiles_bit_128_hexx() {
    let _ = H::generate(FULL_128 + 0x100000000000000000000000000000000, 16, 8, 1, 'seed');
}
