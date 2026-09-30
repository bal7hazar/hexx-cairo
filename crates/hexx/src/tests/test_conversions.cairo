//! Tests of the offset conversions (`conversions.cairo`) and of `HexOrientation`
//! (`orientation.cairo`) against a plain oracle. The golden vectors from the crate are in
//! `crates/hexx/tests/golden_conversions.cairo`.

use hexx::conversions::{HexConversionsTrait, OffsetHexMode};
use hexx::hex::{Hex, HexTrait};
use hexx::orientation::HexOrientation;

/// The oracle: `v & 1` as `hexx` writes it, for a small `v` (the bit of two's complement), with
/// the divisions of the redblobgames formulas on numerators that are even.
fn oracle_shove(v: i32, mode: OffsetHexMode) -> i32 {
    let bit: i32 = if v % 2 == 0 {
        0
    } else {
        1
    };
    match mode {
        OffsetHexMode::Even => (v + bit) / 2,
        OffsetHexMode::Odd => (v - bit) / 2,
    }
}

fn oracle_to_offset(h: Hex, mode: OffsetHexMode, orientation: HexOrientation) -> [i32; 2] {
    match orientation {
        HexOrientation::Flat => [h.x, h.y + oracle_shove(h.x, mode)],
        HexOrientation::Pointy => [h.x + oracle_shove(h.y, mode), h.y],
    }
}

fn check(mode: OffsetHexMode, orientation: HexOrientation) {
    let mut x: i32 = -9;
    while x <= 9 {
        let mut y: i32 = -9;
        while y <= 9 {
            let h = HexTrait::new(x, y);
            let offset = h.to_offset_coordinates(mode, orientation);
            assert(offset == oracle_to_offset(h, mode, orientation), 'to_offset');
            assert(
                HexConversionsTrait::from_offset_coordinates(offset, mode, orientation) == h,
                'round trip',
            );
            y += 1;
        }
        x += 1;
    }
}

#[test]
#[available_gas(l2_gas: 10128048)]
fn test_offset_even_pointy() {
    check(OffsetHexMode::Even, HexOrientation::Pointy);
}

#[test]
#[available_gas(l2_gas: 9810150)]
fn test_offset_even_flat() {
    check(OffsetHexMode::Even, HexOrientation::Flat);
}

#[test]
#[available_gas(l2_gas: 10128048)]
fn test_offset_odd_pointy() {
    check(OffsetHexMode::Odd, HexOrientation::Pointy);
}

#[test]
#[available_gas(l2_gas: 9810150)]
fn test_offset_odd_flat() {
    check(OffsetHexMode::Odd, HexOrientation::Flat);
}

/// Numerators of `i32::MAX` and `i32::MIN` never leave `i32`: `hexx`'s `midpoint` does not
/// either, and the port does not form `v + 1`.
#[test]
#[available_gas(l2_gas: 14406)]
fn test_offset_extreme_rows_do_not_overflow() {
    let h = HexTrait::new(-1073741824, 2147483647);
    assert(
        h.to_offset_coordinates(OffsetHexMode::Even, HexOrientation::Pointy) == [0, 2147483647],
        'even pointy at MAX',
    );
    assert(
        HexConversionsTrait::from_offset_coordinates(
            [0, 2147483647], OffsetHexMode::Even, HexOrientation::Pointy,
        ) == h,
        'from even pointy at MAX',
    );
    let h = HexTrait::new(1073741823, -2147483648);
    assert(
        h.to_offset_coordinates(OffsetHexMode::Odd, HexOrientation::Pointy) == [-1, -2147483648],
        'odd pointy at MIN',
    );
}

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_offset_panics_when_the_column_leaves_i32() {
    let _ = HexTrait::new(2147483647, 2)
        .to_offset_coordinates(OffsetHexMode::Even, HexOrientation::Pointy);
}

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_offset_from_panics_when_the_axial_coordinate_leaves_i32() {
    let _ = HexConversionsTrait::from_offset_coordinates(
        [-2147483648, 2], OffsetHexMode::Even, HexOrientation::Pointy,
    );
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_orientation_default_and_not() {
    let default: HexOrientation = Default::default();
    assert(default == HexOrientation::Flat, 'the default is Flat');
    assert(!HexOrientation::Flat == HexOrientation::Pointy, '!Flat');
    assert(!HexOrientation::Pointy == HexOrientation::Flat, '!Pointy');
    assert(!!default == default, '!!');
}
