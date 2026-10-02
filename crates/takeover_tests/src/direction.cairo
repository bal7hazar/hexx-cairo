//! `types::direction` of 1.8.0 against `hexx::board::direction`: `DIRECTION_COUNT`,
//! `DIRECTION_SIZE`, `DirectionTrait::{opposite, next, pop_front}`, `DirectionIntoU8`,
//! `U8TryIntoDirection`.

use hexx::board::direction as h;
use origami_hexmap::helpers::layout::LayoutTrait;
use origami_hexmap::helpers::rng::PERMUTATIONS;
use origami_hexmap::types::direction as o;
use crate::common::{
    hexx_direction, hexx_index, origami_direction, origami_index, query_positions, word,
};

#[test]
#[available_gas(l2_gas: 6836)]
fn test_direction_constants() {
    assert(o::DIRECTION_COUNT == h::DIRECTION_COUNT, 'count');
    let (lhs, rhs): (u32, u32) = (o::DIRECTION_SIZE.into(), h::DIRECTION_SIZE.into());
    assert(lhs == rhs, 'size');
}

/// Every direction.
#[test]
#[available_gas(l2_gas: 32676)]
fn test_direction_opposite() {
    let mut index: u8 = 0;
    while index != 6 {
        let lhs = o::DirectionTrait::opposite(origami_direction(index));
        let rhs = h::DirectionTrait::opposite(hexx_direction(index));
        assert(origami_index(lhs) == hexx_index(rhs), 'opposite');
        index += 1;
    }
}

/// Every direction.
#[test]
#[available_gas(l2_gas: 27846)]
fn test_direction_into_u8() {
    let mut index: u8 = 0;
    while index != 6 {
        let lhs: u8 = o::DirectionIntoU8::into(origami_direction(index));
        let rhs: u8 = h::DirectionIntoU8::into(hexx_direction(index));
        assert(lhs == rhs, 'into');
        index += 1;
    }
}

/// Every `u8`.
#[test]
#[available_gas(l2_gas: 1322528)]
fn test_direction_try_into() {
    let mut value: u16 = 0;
    while value != 256 {
        let byte: u8 = value.try_into().unwrap();
        let lhs = o::U8TryIntoDirection::try_into(byte);
        let rhs = h::U8TryIntoDirection::try_into(byte);
        match (lhs, rhs) {
            (Some(lhs), Some(rhs)) => assert(origami_index(lhs) == hexx_index(rhs), 'try_into'),
            (None, None) => {},
            _ => panic!("try_into {}", value),
        }
        value += 1;
    }
}

/// Every position of the queries (`common::query_positions`) in every direction whose
/// neighbour lies in the board (the domain of `next`), with the parity of its row.
#[test]
#[available_gas(l2_gas: 104410224)]
fn test_direction_next() {
    for (width, height, position) in query_positions() {
        let odd = (position / width) % 2 == 1;
        let mut index: u8 = 0;
        while index != 6 {
            let inside = LayoutTrait::neighbor(width, height, position, origami_direction(index));
            if inside.is_some() {
                let lhs = o::DirectionTrait::next(origami_direction(index), position, width, odd);
                let rhs = h::DirectionTrait::next(hexx_direction(index), position, width, odd);
                assert(lhs == rhs, 'next');
            }
            index += 1;
        }
    }
}

/// The 720 packed permutations of 1.8.0, 6 pops each, then 256 seeded `u32` (tag
/// `'directions'`) and the boundaries 0 and `2^32 - 1`, 8 pops each.
#[test]
#[available_gas(l2_gas: 53464879)]
fn test_direction_pop_front() {
    let mut inputs: Array<(u32, u32)> = array![];
    for permutation in PERMUTATIONS.span() {
        inputs.append((*permutation, 6));
    }
    let mut index: u32 = 0;
    while index != 256 {
        let value: u32 = (word('directions', index).low % 0x100000000).try_into().unwrap();
        inputs.append((value, 8));
        index += 1;
    }
    inputs.append((0, 8));
    inputs.append((0xffffffff, 8));
    for (value, pops) in inputs {
        let (mut lhs, mut rhs) = (value, value);
        let mut count = pops;
        while count != 0 {
            let left = o::DirectionTrait::pop_front(ref lhs);
            let right = h::DirectionTrait::pop_front(ref rhs);
            assert(origami_index(left) == hexx_index(right), 'pop_front');
            assert(lhs == rhs, 'pop_front rest');
            count -= 1;
        }
    }
}
