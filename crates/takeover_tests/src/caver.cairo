//! `generators::caver` of 1.8.0 against `hexx::generators::caver`: `Caver::{generate,
//! keep_component}`, `errors::CAVER_POSITION_NOT_FLOOR`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, every
//! order from 0 to 5.

use hexx::generators::caver as h;
use hexx::generators::caver::Caver as H;
use origami_hexmap::generators::caver as o;
use origami_hexmap::generators::caver::Caver as O;
use crate::common::{below, generator_seed, input_grid, tiles};
use crate::fixtures::EMPTY_7X7;

/// Orders 0 to 5 on the seeds `[first, last)`.
fn check_generate(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let mut order: u8 = 0;
        while order != 6 {
            let lhs = O::generate(width, height, order, seed);
            let rhs = H::generate(width, height, order, seed);
            assert(lhs == rhs, 'generate');
            order += 1;
        }
        index += 1;
    }
}

/// The component of a seeded floor tile (tag `'floor'`) of `common::input_grid`, on the seeds
/// `[first, last)`; a grid without floor tile has no input.
fn check_keep_component(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let grid = input_grid(width, height, index);
        let floor = tiles(grid);
        if floor.len() != 0 {
            let from = *floor.at(below('floor', index, floor.len()));
            let lhs = O::keep_component(grid, width, height, from);
            let rhs = H::keep_component(grid, width, height, from);
            assert(lhs == rhs, 'keep_component');
        }
        index += 1;
    }
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_caver_errors() {
    assert(o::errors::CAVER_POSITION_NOT_FLOOR == h::errors::CAVER_POSITION_NOT_FLOOR, 'errors');
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `3x3`.
#[test]
#[available_gas(l2_gas: 15911528)]
fn test_caver_generate_3x3_0() {
    check_generate(3, 3, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `3x3`.
#[test]
#[available_gas(l2_gas: 16668396)]
fn test_caver_generate_3x3_1() {
    check_generate(3, 3, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 15911528)]
fn test_caver_generate_3x3_2() {
    check_generate(3, 3, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `7x7`.
#[test]
#[available_gas(l2_gas: 15911528)]
fn test_caver_generate_7x7_0() {
    check_generate(7, 7, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `7x7`.
#[test]
#[available_gas(l2_gas: 16668396)]
fn test_caver_generate_7x7_1() {
    check_generate(7, 7, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 15911528)]
fn test_caver_generate_7x7_2() {
    check_generate(7, 7, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `15x15`.
#[test]
#[available_gas(l2_gas: 29410538)]
fn test_caver_generate_15x15_0() {
    check_generate(15, 15, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `15x15`.
#[test]
#[available_gas(l2_gas: 30810216)]
fn test_caver_generate_15x15_1() {
    check_generate(15, 15, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 29410538)]
fn test_caver_generate_15x15_2() {
    check_generate(15, 15, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `15x16`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_15x16_0() {
    check_generate(15, 16, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `15x16`.
#[test]
#[available_gas(l2_gas: 30787116)]
fn test_caver_generate_15x16_1() {
    check_generate(15, 16, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_15x16_2() {
    check_generate(15, 16, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `17x14`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_17x14_0() {
    check_generate(17, 14, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `17x14`.
#[test]
#[available_gas(l2_gas: 30787116)]
fn test_caver_generate_17x14_1() {
    check_generate(17, 14, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_17x14_2() {
    check_generate(17, 14, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `19x13`.
#[test]
#[available_gas(l2_gas: 29410538)]
fn test_caver_generate_19x13_0() {
    check_generate(19, 13, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `19x13`.
#[test]
#[available_gas(l2_gas: 30810216)]
fn test_caver_generate_19x13_1() {
    check_generate(19, 13, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 29410538)]
fn test_caver_generate_19x13_2() {
    check_generate(19, 13, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `25x10`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_25x10_0() {
    check_generate(25, 10, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `25x10`.
#[test]
#[available_gas(l2_gas: 30787116)]
fn test_caver_generate_25x10_1() {
    check_generate(25, 10, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 29388488)]
fn test_caver_generate_25x10_2() {
    check_generate(25, 10, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `83x3`.
#[test]
#[available_gas(l2_gas: 27804626)]
fn test_caver_generate_83x3_0() {
    check_generate(83, 3, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `83x3`.
#[test]
#[available_gas(l2_gas: 29146239)]
fn test_caver_generate_83x3_1() {
    check_generate(83, 3, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 27846101)]
fn test_caver_generate_83x3_2() {
    check_generate(83, 3, 43, 64);
}

/// `Caver::generate`, orders 0 to 5. Seeds 0 to 20 on `3x83`.
#[test]
#[available_gas(l2_gas: 28335506)]
fn test_caver_generate_3x83_0() {
    check_generate(3, 83, 0, 21);
}

/// `Caver::generate`, orders 0 to 5. Seeds 21 to 42 on `3x83`.
#[test]
#[available_gas(l2_gas: 29783295)]
fn test_caver_generate_3x83_1() {
    check_generate(3, 83, 21, 43);
}

/// `Caver::generate`, orders 0 to 5. Seeds 43 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 28428410)]
fn test_caver_generate_3x83_2() {
    check_generate(3, 83, 43, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `3x3`.
#[test]
#[available_gas(l2_gas: 10681753)]
fn test_caver_keep_component_3x3() {
    check_keep_component(3, 3, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `7x7`.
#[test]
#[available_gas(l2_gas: 44384700)]
fn test_caver_keep_component_7x7() {
    check_keep_component(7, 7, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `15x15`.
#[test]
#[available_gas(l2_gas: 213146760)]
fn test_caver_keep_component_15x15() {
    check_keep_component(15, 15, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `15x16`.
#[test]
#[available_gas(l2_gas: 227980587)]
fn test_caver_keep_component_15x16() {
    check_keep_component(15, 16, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `17x14`.
#[test]
#[available_gas(l2_gas: 229208379)]
fn test_caver_keep_component_17x14() {
    check_keep_component(17, 14, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `19x13`.
#[test]
#[available_gas(l2_gas: 236213045)]
fn test_caver_keep_component_19x13() {
    check_keep_component(19, 13, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `25x10`.
#[test]
#[available_gas(l2_gas: 233886629)]
fn test_caver_keep_component_25x10() {
    check_keep_component(25, 10, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `83x3`.
#[test]
#[available_gas(l2_gas: 121147127)]
fn test_caver_keep_component_83x3() {
    check_keep_component(83, 3, 0, 64);
}

/// `Caver::keep_component` on `common::input_grid` from a seeded floor tile. Seeds 0 to 63 on
/// `3x83`.
#[test]
#[available_gas(l2_gas: 126436246)]
fn test_caver_keep_component_3x83() {
    check_keep_component(3, 83, 0, 64);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_caver_generate_revert_dimension_origami() {
    let _ = O::generate(2, 7, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_caver_generate_revert_dimension_hexx() {
    let _ = H::generate(2, 7, 3, 'seed');
}

#[test]
#[available_gas(l2_gas: 45912)]
#[should_panic(expected: 'Caver: position not floor')]
fn test_caver_keep_component_revert_wall_origami() {
    let _ = O::keep_component(EMPTY_7X7, 7, 7, 0);
}

#[test]
#[available_gas(l2_gas: 45912)]
#[should_panic(expected: 'Caver: position not floor')]
fn test_caver_keep_component_revert_wall_hexx() {
    let _ = H::keep_component(EMPTY_7X7, 7, 7, 0);
}

#[test]
#[available_gas(l2_gas: 20017)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_caver_keep_component_revert_dimension_origami() {
    let _ = O::keep_component(EMPTY_7X7, 2, 7, 8);
}

#[test]
#[available_gas(l2_gas: 20017)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_caver_keep_component_revert_dimension_hexx() {
    let _ = H::keep_component(EMPTY_7X7, 2, 7, 8);
}
