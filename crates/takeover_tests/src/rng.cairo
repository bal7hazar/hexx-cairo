//! `helpers::rng` of 1.8.0 against `hexx::board::rng`: `Rng`, the 9 functions of `RngTrait`
//! (`new`, `mix`, `draw`, `draw6`, `draw_byte`, `next_below`, `shuffle6`, `split216`, `refill`)
//! and the table `PERMUTATIONS`.
//!
//! A generator is compared whole (`seed` and `pool`) after every call: 64 seeds (tag `'rng'`),
//! 32 draws each, so that every draw crosses several refills.

use hexx::board::rng as h;
use hexx::board::rng::{Rng as HRng, RngTrait as H};
use origami_hexmap::helpers::rng as o;
use origami_hexmap::helpers::rng::{Rng as ORng, RngTrait as O};
use crate::common::{SEEDS, seed, word};

/// Draws per seed.
const DRAWS: u32 = 32;

fn assert_rngs(lhs: @ORng, rhs: @HRng) {
    assert(*lhs.seed == *rhs.seed, 'rng seed');
    assert(*lhs.pool == *rhs.pool, 'rng pool');
}

/// Every index of the table, 720.
#[test]
#[available_gas(l2_gas: 2896373)]
fn test_rng_permutations() {
    assert(o::PERMUTATIONS.span().len() == h::PERMUTATIONS.span().len(), 'length');
    let mut index: u32 = 0;
    while index != 720 {
        assert(*o::PERMUTATIONS.span().at(index) == *h::PERMUTATIONS.span().at(index), 'table');
        index += 1;
    }
}

/// 64 seeds, and the boundaries 0 and `-1`.
#[test]
#[available_gas(l2_gas: 761542)]
fn test_rng_new() {
    let mut seeds: Array<felt252> = array![0, -1];
    let mut index: u32 = 0;
    while index != SEEDS {
        seeds.append(seed('rng', index));
        index += 1;
    }
    for seed in seeds {
        assert_rngs(@O::new(seed), @H::new(seed));
    }
}

/// 256 seeded pairs (tag `'mix'`), and the pairs of the boundaries 0, 1, `-1`.
#[test]
#[available_gas(l2_gas: 5668073)]
fn test_rng_mix() {
    let mut index: u32 = 0;
    while index != 256 {
        let (lhs, rhs) = (seed('mix', 2 * index), seed('mix', 2 * index + 1));
        assert(O::mix(lhs, rhs) == H::mix(lhs, rhs), 'mix');
        index += 1;
    }
    let bounds: [felt252; 3] = [0, 1, -1];
    for lhs in bounds.span() {
        for rhs in bounds.span() {
            assert(O::mix(*lhs, *rhs) == H::mix(*lhs, *rhs), 'mix bounds');
        }
    }
}

/// 64 seeds, 32 draws each; bound `k` of a seed: 1, 2, 6, 251, `2^64`, `2^128 - 1`, then
/// seeded bounds (tag `'bound'`).
#[test]
#[available_gas(l2_gas: 50850314)]
fn test_rng_draw() {
    let bounds: [u128; 6] = [1, 2, 6, 251, 0x10000000000000000, 0xffffffffffffffffffffffffffffffff];
    let mut index: u32 = 0;
    while index != SEEDS {
        let seed = seed('rng', index);
        let (mut lhs, mut rhs) = (O::new(seed), H::new(seed));
        let mut draw: u32 = 0;
        while draw != DRAWS {
            let bound: u128 = if draw < 6 {
                *bounds.span().at(draw)
            } else {
                let value = word('bound', index * 100 + draw).low;
                if value == 0 {
                    1
                } else {
                    value
                }
            };
            let bound: NonZero<u128> = bound.try_into().unwrap();
            assert(lhs.draw(bound) == rhs.draw(bound), 'draw');
            assert_rngs(@lhs, @rhs);
            draw += 1;
        }
        index += 1;
    }
}

/// 64 seeds, 32 draws each.
#[test]
#[available_gas(l2_gas: 21058500)]
fn test_rng_draw6() {
    let mut index: u32 = 0;
    while index != SEEDS {
        let seed = seed('rng', index);
        let (mut lhs, mut rhs) = (O::new(seed), H::new(seed));
        let mut draw: u32 = 0;
        while draw != DRAWS {
            assert(lhs.draw6() == rhs.draw6(), 'draw6');
            assert_rngs(@lhs, @rhs);
            draw += 1;
        }
        index += 1;
    }
}

/// 64 seeds, 32 draws each, the bound running over 1 to 255 (`(8 * seed + draw) % 255 + 1`).
#[test]
#[available_gas(l2_gas: 44208465)]
fn test_rng_draw_byte_next_below() {
    let mut index: u32 = 0;
    while index != SEEDS {
        let seed = seed('rng', index);
        let (mut lhs, mut rhs) = (O::new(seed), H::new(seed));
        let (mut left, mut right) = (O::new(seed), H::new(seed));
        let mut draw: u32 = 0;
        while draw != DRAWS {
            let bound: u8 = ((8 * index + draw) % 255 + 1).try_into().unwrap();
            let nonzero: NonZero<u8> = bound.try_into().unwrap();
            assert(lhs.draw_byte(nonzero) == rhs.draw_byte(nonzero), 'draw_byte');
            assert_rngs(@lhs, @rhs);
            assert(left.next_below(bound) == right.next_below(bound), 'next_below');
            assert_rngs(@left, @right);
            draw += 1;
        }
        index += 1;
    }
}

/// 64 seeds, 32 shuffles each.
#[test]
#[available_gas(l2_gas: 29050999)]
fn test_rng_shuffle6() {
    let mut index: u32 = 0;
    while index != SEEDS {
        let seed = seed('rng', index);
        let (mut lhs, mut rhs) = (O::new(seed), H::new(seed));
        let mut draw: u32 = 0;
        while draw != DRAWS {
            assert(lhs.shuffle6() == rhs.shuffle6(), 'shuffle6');
            assert_rngs(@lhs, @rhs);
            draw += 1;
        }
        index += 1;
    }
}

/// 256 seeded pools (tag `'pool'`, both limbs) and the boundaries 0, 1, 215, 216,
/// `2^128 - 1`.
#[test]
#[available_gas(l2_gas: 2719328)]
fn test_rng_split216() {
    let mut pools: Array<u128> = array![0, 1, 215, 216, 0xffffffffffffffffffffffffffffffff];
    let mut index: u32 = 0;
    while index != 128 {
        let value = word('pool', index);
        pools.append(value.low);
        pools.append(value.high);
        index += 1;
    }
    for pool in pools {
        assert(O::split216(pool) == H::split216(pool), 'split216');
    }
}

/// 64 seeds, 8 refills each, the generator compared after each.
#[test]
#[available_gas(l2_gas: 5626155)]
fn test_rng_refill() {
    let mut index: u32 = 0;
    while index != SEEDS {
        let seed = seed('rng', index);
        let (mut lhs, mut rhs) = (O::new(seed), H::new(seed));
        let mut count: u32 = 0;
        while count != 8 {
            lhs.refill();
            rhs.refill();
            assert_rngs(@lhs, @rhs);
            count += 1;
        }
        index += 1;
    }
}
