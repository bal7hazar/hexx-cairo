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

/// The boundaries of the brief for a felt input: 0, 1, `2^128 - 1`, `2^128`, `2^250`, and `-1`
/// (the largest felt).
fn felt_boundaries() -> Array<felt252> {
    array![
        0, 1, 0xffffffffffffffffffffffffffffffff, 0x100000000000000000000000000000000,
        0x400000000000000000000000000000000000000000000000000000000000000, -1,
    ]
}

/// The seeds: 256 seeded values (tag `'rng'`), then the boundaries of `felt_boundaries`.
fn seeds() -> Array<felt252> {
    let mut seeds: Array<felt252> = array![];
    let mut index: u32 = 0;
    while index != 256 {
        seeds.append(seed('rng', index));
        index += 1;
    }
    for boundary in felt_boundaries() {
        seeds.append(boundary);
    }
    seeds
}

/// 256 seeded values and the boundaries 0, 1, `2^128 - 1`, `2^128`, `2^250`, `-1` (fix loop 1,
/// finding 3).
#[test]
#[available_gas(l2_gas: 2998215)]
fn test_rng_new() {
    for seed in seeds() {
        assert_rngs(@O::new(seed), @H::new(seed));
    }
}

/// 256 seeded pairs (tag `'mix'`), and every pair of the boundaries 0, 1, `2^128 - 1`, `2^128`,
/// `2^250`, `-1` (36 pairs).
#[test]
#[available_gas(l2_gas: 5808168)]
fn test_rng_mix() {
    let mut index: u32 = 0;
    while index != 256 {
        let (lhs, rhs) = (seed('mix', 2 * index), seed('mix', 2 * index + 1));
        assert(O::mix(lhs, rhs) == H::mix(lhs, rhs), 'mix');
        index += 1;
    }
    let bounds = felt_boundaries();
    for lhs in bounds.span() {
        for rhs in bounds.span() {
            assert(O::mix(*lhs, *rhs) == H::mix(*lhs, *rhs), 'mix bounds');
        }
    }
}

/// The draws from a generator whose pool is a boundary of its `u128` domain (fix loop 1, finding
/// 3): the boundaries of the brief adapted to a pool, 0, 1, `2^128 - 1` (`2^128` and `2^250` are
/// not `u128`), with `2^64 - 1` and `2^64` on both sides of the refill threshold. Every seed of
/// `seeds` (262) with the pool `k % 5`; from each state, one call of `draw` (a seeded bound, tag
/// `'bound'`), `draw6`, `draw_byte` and `next_below` (a seeded bound in `[1, 255]`), `shuffle6`
/// and `refill`, the returned value and the generator compared after each.
#[test]
#[available_gas(l2_gas: 22946070)]
fn test_rng_pool_boundaries() {
    let pools: [u128; 5] = [
        0, 1, 0xffffffffffffffff, 0x10000000000000000, 0xffffffffffffffffffffffffffffffff,
    ];
    let mut index: u32 = 0;
    for seed in seeds() {
        let pool = *pools.span().at(index % 5);
        let bound = word('bound', 10000 + index).low;
        let bound: NonZero<u128> = (if bound == 0 {
            1
        } else {
            bound
        }).try_into().unwrap();
        let byte: u8 = (index % 255 + 1).try_into().unwrap();
        let nonzero: NonZero<u8> = byte.try_into().unwrap();
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        assert(lhs.draw(bound) == rhs.draw(bound), 'draw');
        assert_rngs(@lhs, @rhs);
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        assert(lhs.draw6() == rhs.draw6(), 'draw6');
        assert_rngs(@lhs, @rhs);
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        assert(lhs.draw_byte(nonzero) == rhs.draw_byte(nonzero), 'draw_byte');
        assert_rngs(@lhs, @rhs);
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        assert(lhs.next_below(byte) == rhs.next_below(byte), 'next_below');
        assert_rngs(@lhs, @rhs);
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        assert(lhs.shuffle6() == rhs.shuffle6(), 'shuffle6');
        assert_rngs(@lhs, @rhs);
        let (mut lhs, mut rhs) = (ORng { seed, pool }, HRng { seed, pool });
        lhs.refill();
        rhs.refill();
        assert_rngs(@lhs, @rhs);
        index += 1;
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

/// 256 seeded pools (tag `'pool'`, both limbs), and the boundaries of the brief adapted to the
/// `u128` domain of a pool: 0, 1, `2^128 - 1` (`2^128` and `2^250` are not `u128`), with 215 and
/// 216 on both sides of the divisor.
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
