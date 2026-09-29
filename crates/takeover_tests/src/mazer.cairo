//! `generators::mazer` of 1.8.0 against `hexx::generators::mazer`: `Mazer::generate`,
//! `errors::MAZER_INVALID_ORDER`.
//!
//! Inputs: 64 seeds (`common::generator_seed`) on the 9 dimensions of `common::DIMENSIONS`, both
//! orders the function accepts, 0 and 1.

use hexx::generators::mazer as h;
use hexx::generators::mazer::Mazer as H;
use origami_hexmap::generators::mazer as o;
use origami_hexmap::generators::mazer::Mazer as O;
use crate::common::generator_seed;

/// Order `order` on the seeds `[first, last)`.
fn check_generate(width: u8, height: u8, order: u8, first: u32, last: u32) {
    let mut index = first;
    while index != last {
        let seed = generator_seed(index);
        let lhs = O::generate(width, height, order, seed);
        let rhs = H::generate(width, height, order, seed);
        assert(lhs == rhs, 'generate');
        index += 1;
    }
}

fn check_generate_0(width: u8, height: u8, first: u32, last: u32) {
    check_generate(width, height, 0, first, last);
}

fn check_generate_1(width: u8, height: u8, first: u32, last: u32) {
    check_generate(width, height, 1, first, last);
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_mazer_errors() {
    assert(o::errors::MAZER_INVALID_ORDER == h::errors::MAZER_INVALID_ORDER, 'errors');
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 12544000)]
fn test_mazer_generate_order_0_3x3() {
    check_generate_0(3, 3, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 65703648)]
fn test_mazer_generate_order_0_7x7() {
    check_generate_0(7, 7, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 362081541)]
fn test_mazer_generate_order_0_15x15() {
    check_generate_0(15, 15, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 388744428)]
fn test_mazer_generate_order_0_15x16() {
    check_generate_0(15, 16, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 383508277)]
fn test_mazer_generate_order_0_17x14() {
    check_generate_0(17, 14, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 398142827)]
fn test_mazer_generate_order_0_19x13() {
    check_generate_0(19, 13, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 396342803)]
fn test_mazer_generate_order_0_25x10() {
    check_generate_0(25, 10, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 305646254)]
fn test_mazer_generate_order_0_83x3() {
    check_generate_0(83, 3, 0, 64);
}

/// `Mazer::generate`, order 0. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 336374987)]
fn test_mazer_generate_order_0_3x83() {
    check_generate_0(3, 83, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `3x3`.
#[test]
#[available_gas(l2_gas: 12544000)]
fn test_mazer_generate_order_1_3x3() {
    check_generate_1(3, 3, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `7x7`.
#[test]
#[available_gas(l2_gas: 48692371)]
fn test_mazer_generate_order_1_7x7() {
    check_generate_1(7, 7, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `15x15`.
#[test]
#[available_gas(l2_gas: 199724144)]
fn test_mazer_generate_order_1_15x15() {
    check_generate_1(15, 15, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `15x16`.
#[test]
#[available_gas(l2_gas: 223943259)]
fn test_mazer_generate_order_1_15x16() {
    check_generate_1(15, 16, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `17x14`.
#[test]
#[available_gas(l2_gas: 215338669)]
fn test_mazer_generate_order_1_17x14() {
    check_generate_1(17, 14, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `19x13`.
#[test]
#[available_gas(l2_gas: 241531641)]
fn test_mazer_generate_order_1_19x13() {
    check_generate_1(19, 13, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `25x10`.
#[test]
#[available_gas(l2_gas: 235141140)]
fn test_mazer_generate_order_1_25x10() {
    check_generate_1(25, 10, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `83x3`.
#[test]
#[available_gas(l2_gas: 338439854)]
fn test_mazer_generate_order_1_83x3() {
    check_generate_1(83, 3, 0, 64);
}

/// `Mazer::generate`, order 1. Seeds 0 to 63 on `3x83`.
#[test]
#[available_gas(l2_gas: 209152991)]
fn test_mazer_generate_order_1_3x83() {
    check_generate_1(3, 83, 0, 64);
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_mazer_generate_revert_order_origami() {
    let _ = O::generate(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Mazer: order > 1 not supported')]
fn test_mazer_generate_revert_order_hexx() {
    let _ = H::generate(7, 7, 2, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_mazer_generate_revert_dimension_origami() {
    let _ = O::generate(7, 2, 0, 'seed');
}

#[test]
#[available_gas(l2_gas: 16296)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_mazer_generate_revert_dimension_hexx() {
    let _ = H::generate(7, 2, 0, 'seed');
}
