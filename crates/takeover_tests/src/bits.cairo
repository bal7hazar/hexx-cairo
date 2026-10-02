//! `helpers::bits` of 1.8.0 against `hexx::board::bits`: the constants `TWO_POW_128`,
//! `TWO_POW_32`, `TWO_POW_64`, `BYTES_ONE`, `TWO_POW_120`, the tables `POW`, `INV`, `POW128`,
//! the 18 functions of `Bits`, and the `Set` implementations `WideSet` and `SmallSet`.
//!
//! The values: 256 seeded words (tag `'bits'`) and the boundaries 0, 1, `2^128 - 1`, `2^128`,
//! `2^250`, reduced to each function's domain where it has one (below `2^251` for a bitmap, a
//! limb for a `u128`).

use hexx::board::bits as h;
use hexx::board::bits::{Bits as H, SmallSet as HSmall, WideSet as HWide};
use origami_hexmap::helpers::bits as o;
use origami_hexmap::helpers::bits::{Bits as O, SmallSet as OSmall, WideSet as OWide};
use crate::common::{two_pow, word};

/// Seeded values per test.
const VALUES: u32 = 256;

/// The values: 256 seeded words below `2^251`, then the 5 boundaries.
fn values() -> Array<u256> {
    let top = two_pow(251) - 1;
    let mut values: Array<u256> = array![];
    let mut index: u32 = 0;
    while index != VALUES {
        values.append(word('bits', index) & top);
        index += 1;
    }
    values.append(0);
    values.append(1);
    values.append(0xffffffffffffffffffffffffffffffff);
    values.append(two_pow(128));
    values.append(two_pow(250));
    values
}

/// The limbs: the low and high limbs of the values, and `2^128 - 1`.
fn limbs() -> Array<u128> {
    let mut limbs: Array<u128> = array![];
    for value in values() {
        limbs.append(value.low);
        limbs.append(value.high);
    }
    limbs.append(0xffffffffffffffffffffffffffffffff);
    limbs
}

/// A seeded bit index in `[0, bound)` for input `index` (tag `'index'`).
fn index_below(index: u32, bound: u32) -> u8 {
    let value: u256 = word('index', index);
    (value.low % bound.into()).try_into().unwrap()
}

fn felt(value: u256) -> felt252 {
    value.try_into().unwrap()
}

#[test]
#[available_gas(l2_gas: 6836)]
fn test_bits_constants() {
    assert(o::TWO_POW_128 == h::TWO_POW_128, 'TWO_POW_128');
    assert(o::TWO_POW_32 == h::TWO_POW_32, 'TWO_POW_32');
    assert(o::TWO_POW_64 == h::TWO_POW_64, 'TWO_POW_64');
    assert(o::BYTES_ONE == h::BYTES_ONE, 'BYTES_ONE');
    let (lhs, rhs): (u128, u128) = (o::TWO_POW_120.into(), h::TWO_POW_120.into());
    assert(lhs == rhs, 'TWO_POW_120');
}

/// Every index of `POW` (252), `INV` (252) and `POW128` (128).
#[test]
#[available_gas(l2_gas: 2194238)]
fn test_bits_tables() {
    assert(o::POW.span().len() == h::POW.span().len(), 'POW length');
    assert(o::INV.span().len() == h::INV.span().len(), 'INV length');
    assert(o::POW128.span().len() == h::POW128.span().len(), 'POW128 length');
    let mut index: u32 = 0;
    while index != 252 {
        assert(*o::POW.span().at(index) == *h::POW.span().at(index), 'POW');
        assert(*o::INV.span().at(index) == *h::INV.span().at(index), 'INV');
        if index < 128 {
            assert(*o::POW128.span().at(index) == *h::POW128.span().at(index), 'POW128');
        }
        index += 1;
    }
}

/// Every exponent, 0 to 251.
#[test]
#[available_gas(l2_gas: 1632960)]
fn test_bits_pow_inv() {
    let mut exp: u8 = 0;
    while exp != 252 {
        assert(O::pow(exp) == H::pow(exp), 'pow');
        assert(O::inv(exp) == H::inv(exp), 'inv');
        exp += 1;
    }
}

/// Every pair of consecutive limbs, and every pair of the limb boundaries.
#[test]
#[available_gas(l2_gas: 9429672)]
fn test_bits_bitwise() {
    let limbs = limbs();
    let count = limbs.len();
    let mut index: u32 = 0;
    while index != count {
        let (lhs, rhs) = (*limbs.at(index), *limbs.at((index + 1) % count));
        assert(O::bitwise(lhs, rhs) == H::bitwise(lhs, rhs), 'bitwise');
        index += 1;
    }
    let bounds: [u128; 3] = [0, 1, 0xffffffffffffffffffffffffffffffff];
    for lhs in bounds.span() {
        for rhs in bounds.span() {
            assert(O::bitwise(*lhs, *rhs) == H::bitwise(*lhs, *rhs), 'bitwise bounds');
        }
    }
}

/// Every pair of consecutive values, and every pair of the boundaries.
#[test]
#[available_gas(l2_gas: 10377155)]
fn test_bits_and_or_xor() {
    let values = values();
    let count = values.len();
    let mut pairs: Array<(u256, u256)> = array![];
    let mut index: u32 = 0;
    while index != count {
        pairs.append((*values.at(index), *values.at((index + 1) % count)));
        index += 1;
    }
    let mut left = VALUES;
    while left != count {
        let mut right = VALUES;
        while right != count {
            pairs.append((*values.at(left), *values.at(right)));
            right += 1;
        }
        left += 1;
    }
    for (lhs, rhs) in pairs {
        assert(O::and(lhs, rhs) == H::and(lhs, rhs), 'and');
        assert(O::or(lhs, rhs) == H::or(lhs, rhs), 'or');
        assert(O::xor(lhs, rhs) == H::xor(lhs, rhs), 'xor');
    }
}

/// Every value with a seeded shift `count`, reduced below `2^(251 - count)` so that the result
/// stays below `2^251`; `shr_exact` on the shifted value (its `count` low bits are zero).
#[test]
#[available_gas(l2_gas: 111585296)]
fn test_bits_shl_shr_exact() {
    let mut index: u32 = 0;
    for value in values() {
        let count = index_below(index, 252);
        let value = value % two_pow(251 - count.into());
        let shifted = felt(value * two_pow(count.into()));
        assert(O::shl(felt(value), count) == H::shl(felt(value), count), 'shl');
        assert(O::shr_exact(shifted, count) == H::shr_exact(shifted, count), 'shr_exact');
        index += 1;
    }
}

/// Every value.
#[test]
#[available_gas(l2_gas: 4857571)]
fn test_bits_to_felt() {
    for value in values() {
        assert(O::to_felt(value) == H::to_felt(value), 'to_felt');
    }
}

/// The values `[first, last)` of `values` at every index, 0 to 251.
fn check_get(first: u32, last: u32) {
    let values = values();
    let mut position = first;
    while position != last {
        let value = *values.at(position);
        let mut index: u8 = 0;
        while index != 252 {
            assert(O::get(value, index) == H::get(value, index), 'get');
            index += 1;
        }
        position += 1;
    }
}

/// The first 128 seeded values at every index, 0 to 251.
#[test]
#[available_gas(l2_gas: 353536989)]
fn test_bits_get_0() {
    check_get(0, 128);
}

/// The last 128 seeded values and the 5 boundaries at every index, 0 to 251.
#[test]
#[available_gas(l2_gas: 367329432)]
fn test_bits_get_1() {
    check_get(128, VALUES + 5);
}

/// Every value with a seeded index at most 250, the bit cleared for `set` and set for `unset`.
#[test]
#[available_gas(l2_gas: 58744888)]
fn test_bits_set_unset() {
    let mut index: u32 = 0;
    for value in values() {
        let bit = index_below(1000 + index, 251);
        let power = two_pow(bit.into());
        let clear = felt(value & ~power);
        let full = felt(value | power);
        assert(O::set(clear, bit) == H::set(clear, bit), 'set');
        assert(O::unset(full, bit) == H::unset(full, bit), 'unset');
        index += 1;
    }
}

/// Every value.
#[test]
#[available_gas(l2_gas: 215782668)]
fn test_bits_popcount() {
    for value in values() {
        assert(O::popcount(value) == H::popcount(value), 'popcount');
        assert(O::popcount_sparse(value) == H::popcount_sparse(value), 'popcount_sparse');
    }
}

/// Every limb.
#[test]
#[available_gas(l2_gas: 22604260)]
fn test_bits_limb_functions() {
    for limb in limbs() {
        assert(O::popcount_small(limb) == H::popcount_small(limb), 'popcount_small');
        assert(O::top_byte(limb) == H::top_byte(limb), 'top_byte');
        assert(O::low_byte(limb) == H::low_byte(limb), 'low_byte');
        assert(O::byte_counts(limb) == H::byte_counts(limb), 'byte_counts');
    }
}

/// `WideSet`: every value, paired with a seeded subset of itself (for `sub`) and with a one-hot
/// target (for `hits`), in both limbs (for `limb`).
#[test]
#[available_gas(l2_gas: 65038204)]
fn test_bits_wide_set() {
    let mut index: u32 = 0;
    for value in values() {
        let other = word('subset', index) & value;
        let target = two_pow(index_below(2000 + index, 251).into());
        let value_felt = felt(value);
        assert(OWide::from_felt(value_felt) == HWide::from_felt(value_felt), 'wide from_felt');
        assert(OWide::from_wide(value) == HWide::from_wide(value), 'wide from_wide');
        assert(OWide::to_felt(value) == HWide::to_felt(value), 'wide to_felt');
        assert(OWide::and(value, other) == HWide::and(value, other), 'wide and');
        assert(OWide::sub(value, other) == HWide::sub(value, other), 'wide sub');
        assert(OWide::is_empty(value) == HWide::is_empty(value), 'wide is_empty');
        assert(OWide::hits(value, target) == HWide::hits(value, target), 'wide hits');
        assert(OWide::limb(value, false) == HWide::limb(value, false), 'wide limb low');
        assert(OWide::limb(value, true) == HWide::limb(value, true), 'wide limb high');
        index += 1;
    }
}

/// `SmallSet`: every limb, paired with a seeded subset of itself and with a one-hot target.
#[test]
#[available_gas(l2_gas: 106514988)]
fn test_bits_small_set() {
    let mut index: u32 = 0;
    for limb in limbs() {
        let other = word('subset', 5000 + index).low & limb;
        let target: u128 = two_pow(index_below(3000 + index, 128).into()).low;
        let wide: u256 = u256 { low: limb, high: index.into() };
        let limb_felt: felt252 = limb.into();
        assert(OSmall::from_felt(limb_felt) == HSmall::from_felt(limb_felt), 'small from_felt');
        assert(OSmall::from_wide(wide) == HSmall::from_wide(wide), 'small from_wide');
        assert(OSmall::to_felt(limb) == HSmall::to_felt(limb), 'small to_felt');
        assert(OSmall::and(limb, other) == HSmall::and(limb, other), 'small and');
        assert(OSmall::sub(limb, other) == HSmall::sub(limb, other), 'small sub');
        assert(OSmall::is_empty(limb) == HSmall::is_empty(limb), 'small is_empty');
        assert(OSmall::hits(limb, target) == HSmall::hits(limb, target), 'small hits');
        assert(OSmall::limb(limb, false) == HSmall::limb(limb, false), 'small limb low');
        assert(OSmall::limb(limb, true) == HSmall::limb(limb, true), 'small limb high');
        index += 1;
    }
}
