//! Gas benchmarks of the mirror items of milestone L-M1, 100 repetitions per test.
//! Per-call cost = (test - matching baseline) / 100, see `GAS.md`. The operands are the worst case
//! of the function (the longest branch: `z` the largest component, a wrapping rotation, negative
//! components for `unsigned_abs`).

use hexx::conversions::{HexConversionsTrait, OffsetHexMode};
use hexx::direction::edge_direction::EdgeDirectionTrait;
use hexx::hex::HexTrait;
use hexx::orientation::HexOrientation;

const REPS: u8 = 100;

// Baselines

/// The loop and the accumulator alone.
#[test]
#[available_gas(l2_gas: 149195)]
fn bench_mirror_baseline_loop() {
    let mut acc: felt252 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc += n.into();
    }
    assert!(acc == 4950);
}

/// The loop, the accumulator and the two operands `(-n, -n)` and `(n, n)`.
#[test]
#[available_gas(l2_gas: 476690)]
fn bench_mirror_baseline_operands() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.x + b.y;
    }
    assert!(acc == 0);
}

// Hex

#[test]
#[available_gas(l2_gas: 389372)]
fn bench_hex_new() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let h = HexTrait::new(0 - n.into(), n.into());
        acc += h.x + h.y;
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 476690)]
fn bench_hex_x_y() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.x() + b.y();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 692906)]
fn bench_hex_z() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.z() + b.z();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 784382)]
fn bench_hex_const_sub() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.const_sub(b).x + b.const_sub(a).y;
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 2000597)]
fn bench_hex_length() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.length() - b.length();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 2488175)]
fn bench_hex_ulength() {
    let mut acc: u32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.ulength() + b.ulength();
    }
    assert!(acc == 19800);
}

#[test]
#[available_gas(l2_gas: 2308289)]
fn bench_hex_distance_to() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.distance_to(b) - b.distance_to(a);
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 2795657)]
fn bench_hex_unsigned_distance_to() {
    let mut acc: u32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        acc += a.unsigned_distance_to(b) + b.unsigned_distance_to(a);
    }
    assert!(acc != 0);
}

// EdgeDirection
//
// Runtime operands: the six directions of `iter()` in turn, and an offset that varies with the
// repetition (`255 - rep`), so that the compiler cannot fold a call. 17 repetitions of the six
// directions: 102 calls per test; per call = (test - baseline) / 102.

#[test]
#[available_gas(l2_gas: 546507)]
fn bench_mirror_baseline_direction() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.index() ^ offset;
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 529721)]
fn bench_mirror_baseline_into_hex() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            let y: i32 = d.index().into();
            acc = acc ^ y.try_into().unwrap_or(0);
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 677918)]
fn bench_edge_direction_into_hex() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.into_hex().y.try_into().unwrap_or(0);
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 737680)]
fn bench_edge_direction_const_neg() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.const_neg().index() ^ offset;
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 699838)]
fn bench_edge_direction_clockwise() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.clockwise().index() ^ offset;
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 746605)]
fn bench_edge_direction_counter_clockwise() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.counter_clockwise().index() ^ offset;
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 723667)]
fn bench_edge_direction_rotate_cw() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.rotate_cw(offset).index();
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 779254)]
fn bench_edge_direction_rotate_ccw() {
    let mut acc: u8 = 0;
    let mut rep: u8 = 0;
    while rep != 17 {
        let offset: u8 = 255 - rep;
        let mut all = EdgeDirectionTrait::iter();
        while let Some(d) = all.pop_front() {
            let d = *d;
            acc = acc ^ d.rotate_ccw(offset).index();
        }
        rep += 1;
    }
    assert!(acc != 200);
}

#[test]
#[available_gas(l2_gas: 546945)]
fn bench_edge_direction_iter() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ (*EdgeDirectionTrait::iter().at((n % 6).into())).index();
    }
    assert!(acc != 200);
}

// Offset conversions and orientation

#[test]
#[available_gas(l2_gas: 1985109)]
fn bench_hex_to_offset_coordinates() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexTrait::new(0 - n.into(), 0 - n.into());
        let b = HexTrait::new(n.into(), n.into());
        let [col, _] = a.to_offset_coordinates(OffsetHexMode::Even, HexOrientation::Pointy);
        let [_, row] = b.to_offset_coordinates(OffsetHexMode::Odd, HexOrientation::Flat);
        acc += col + row;
    }
    assert!(acc != 1);
}

#[test]
#[available_gas(l2_gas: 1985109)]
fn bench_hex_from_offset_coordinates() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let a = HexConversionsTrait::from_offset_coordinates(
            [0 - n.into(), 0 - n.into()], OffsetHexMode::Even, HexOrientation::Pointy,
        );
        let b = HexConversionsTrait::from_offset_coordinates(
            [n.into(), n.into()], OffsetHexMode::Odd, HexOrientation::Flat,
        );
        acc += a.x + b.y;
    }
    assert!(acc != 1);
}

#[test]
#[available_gas(l2_gas: 159695)]
fn bench_orientation_not() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let o = !HexOrientation::Pointy;
        if o == HexOrientation::Flat {
            acc += 1;
        }
    }
    assert!(acc == REPS);
}
