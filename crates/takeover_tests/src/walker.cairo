//! `generators::walker` of 1.8.0 against `hexx::generators::walker`: `Walker::generate`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, every
//! step count of `STEPS`. The walker has no order; its moves go by blocks of 18 (one pool) and
//! by 3 within a block, and one permutation serves 36 moves. The counts cover no step, one step,
//! every remainder modulo 3, the remainders 0, 1, 2, 3, 16 and 17 modulo 18 (not the others:
//! fix loop 1 corrects a comment that claimed every one), the 72 moves of exactly two
//! permutations, and a walk of 250 moves that draws from seven.

use hexx::generators::walker::Walker as H;
use origami_hexmap::generators::walker::Walker as O;
use crate::common::generator_seed;

/// The step counts.
pub const STEPS: [u16; 10] = [0, 1, 2, 3, 17, 18, 19, 37, 72, 250];

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

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 318727635)]
fn test_walker_generate_3x3() {
    check_generate(3, 3, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 316466271)]
fn test_walker_generate_7x7() {
    check_generate(7, 7, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 324285327)]
fn test_walker_generate_15x15() {
    check_generate(15, 15, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 323999391)]
fn test_walker_generate_15x16() {
    check_generate(15, 16, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 324357798)]
fn test_walker_generate_17x14() {
    check_generate(17, 14, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 324541926)]
fn test_walker_generate_19x13() {
    check_generate(19, 13, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 324655998)]
fn test_walker_generate_25x10() {
    check_generate(25, 10, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 320024553)]
fn test_walker_generate_83x3() {
    check_generate(83, 3, 0, 64);
}

/// `Walker::generate`, every step count of `STEPS`. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 325960959)]
fn test_walker_generate_3x83() {
    check_generate(3, 83, 0, 64);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_walker_generate_revert_dimension_origami() {
    let _ = O::generate(16, 16, 100, 'seed');
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_walker_generate_revert_dimension_hexx() {
    let _ = H::generate(16, 16, 100, 'seed');
}
