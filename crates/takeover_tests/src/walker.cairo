//! `generators::walker` of 1.8.0 against `hexx::generators::walker`: `Walker::generate`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, every
//! step count of `STEPS` (the walker has no order: the counts cover no step, one step, each
//! remainder of its blocks of 3 and of 18 moves, and long walks).

use hexx::generators::walker::Walker as H;
use origami_hexmap::generators::walker::Walker as O;
use crate::common::generator_seed;

/// The step counts.
pub const STEPS: [u16; 10] = [0, 1, 2, 3, 17, 18, 19, 37, 250, 1000];

/// Every step count on the seeds `[first, last)`.
fn check_generate(width: u8, height: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        for steps in STEPS.span() {
            let lhs = O::generate(width, height, *steps, seed);
            let rhs = H::generate(width, height, *steps, seed);
            assert(lhs == rhs, 'generate');
        }
        index += 1;
    }
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `3x3`.
#[test]
#[available_gas(l2_gas: 293799413)]
fn test_walker_generate_3x3_0() {
    check_generate(3, 3, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `3x3`.
#[test]
#[available_gas(l2_gas: 307818985)]
fn test_walker_generate_3x3_1() {
    check_generate(3, 3, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 293922557)]
fn test_walker_generate_3x3_2() {
    check_generate(3, 3, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `7x7`.
#[test]
#[available_gas(l2_gas: 291384749)]
fn test_walker_generate_7x7_0() {
    check_generate(7, 7, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `7x7`.
#[test]
#[available_gas(l2_gas: 305313433)]
fn test_walker_generate_7x7_1() {
    check_generate(7, 7, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 291504974)]
fn test_walker_generate_7x7_2() {
    check_generate(7, 7, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `15x15`.
#[test]
#[available_gas(l2_gas: 298196477)]
fn test_walker_generate_15x15_0() {
    check_generate(15, 15, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `15x15`.
#[test]
#[available_gas(l2_gas: 312407800)]
fn test_walker_generate_15x15_1() {
    check_generate(15, 15, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 298282850)]
fn test_walker_generate_15x15_2() {
    check_generate(15, 15, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `15x16`.
#[test]
#[available_gas(l2_gas: 298451417)]
fn test_walker_generate_15x16_0() {
    check_generate(15, 16, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `15x16`.
#[test]
#[available_gas(l2_gas: 313084483)]
fn test_walker_generate_15x16_1() {
    check_generate(15, 16, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 298301372)]
fn test_walker_generate_15x16_2() {
    check_generate(15, 16, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `17x14`.
#[test]
#[available_gas(l2_gas: 298782503)]
fn test_walker_generate_17x14_0() {
    check_generate(17, 14, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `17x14`.
#[test]
#[available_gas(l2_gas: 312601399)]
fn test_walker_generate_17x14_1() {
    check_generate(17, 14, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 298725467)]
fn test_walker_generate_17x14_2() {
    check_generate(17, 14, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `19x13`.
#[test]
#[available_gas(l2_gas: 298872131)]
fn test_walker_generate_19x13_0() {
    check_generate(19, 13, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `19x13`.
#[test]
#[available_gas(l2_gas: 313020643)]
fn test_walker_generate_19x13_1() {
    check_generate(19, 13, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 299104832)]
fn test_walker_generate_19x13_2() {
    check_generate(19, 13, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `25x10`.
#[test]
#[available_gas(l2_gas: 299226191)]
fn test_walker_generate_25x10_0() {
    check_generate(25, 10, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `25x10`.
#[test]
#[available_gas(l2_gas: 313732774)]
fn test_walker_generate_25x10_1() {
    check_generate(25, 10, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 299211071)]
fn test_walker_generate_25x10_2() {
    check_generate(25, 10, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `83x3`.
#[test]
#[available_gas(l2_gas: 294706004)]
fn test_walker_generate_83x3_0() {
    check_generate(83, 3, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `83x3`.
#[test]
#[available_gas(l2_gas: 309630907)]
fn test_walker_generate_83x3_1() {
    check_generate(83, 3, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 295684247)]
fn test_walker_generate_83x3_2() {
    check_generate(83, 3, 43, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 20 on `3x83`.
#[test]
#[available_gas(l2_gas: 300739157)]
fn test_walker_generate_3x83_0() {
    check_generate(3, 83, 0, 21);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 21 to 42 on `3x83`.
#[test]
#[available_gas(l2_gas: 316017595)]
fn test_walker_generate_3x83_1() {
    check_generate(3, 83, 21, 43);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 43 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 300709631)]
fn test_walker_generate_3x83_2() {
    check_generate(3, 83, 43, 64);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_walker_generate_revert_dimension_origami() {
    let _ = O::generate(16, 16, 100, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_walker_generate_revert_dimension_hexx() {
    let _ = H::generate(16, 16, 100, 'seed');
}
