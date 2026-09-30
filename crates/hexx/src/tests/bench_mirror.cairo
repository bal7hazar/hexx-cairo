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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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

/// The loop, the accumulator and a direction of index `n mod 6`... taken from the constants.
#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_mirror_baseline_direction() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let d = EdgeDirectionTrait::X_NEG_Y;
        let e = EdgeDirectionTrait::NEG_X_Y;
        acc = acc ^ d.index();
        acc = acc ^ e.index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_index() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        let d = EdgeDirectionTrait::X_NEG_Y;
        let e = EdgeDirectionTrait::NEG_X_Y;
        acc = acc ^ d.index();
        acc = acc ^ e.index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_iter() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ (*EdgeDirectionTrait::iter().at(5)).index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_into_hex() {
    let mut acc: i32 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc += EdgeDirectionTrait::X_NEG_Y.into_hex().x + EdgeDirectionTrait::NEG_X_Y.into_hex().y;
    }
    assert!(acc == 200);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_const_neg() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ EdgeDirectionTrait::X_NEG_Y.const_neg().index();
        acc = acc ^ EdgeDirectionTrait::NEG_X_Y.const_neg().index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_clockwise() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ EdgeDirectionTrait::X_NEG_Y.clockwise().index();
        acc = acc ^ EdgeDirectionTrait::NEG_X_Y.clockwise().index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_counter_clockwise() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ EdgeDirectionTrait::X.counter_clockwise().index();
        acc = acc ^ EdgeDirectionTrait::NEG_X_Y.counter_clockwise().index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_rotate_cw() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ EdgeDirectionTrait::X_NEG_Y.rotate_cw(255).index();
        acc = acc ^ EdgeDirectionTrait::NEG_X_Y.rotate_cw(255).index();
    }
    assert!(acc == 0);
}

#[test]
#[available_gas(l2_gas: 1000000000)]
fn bench_edge_direction_rotate_ccw() {
    let mut acc: u8 = 0;
    let mut n = REPS;
    while n != 0 {
        n -= 1;
        acc = acc ^ EdgeDirectionTrait::X_NEG_Y.rotate_ccw(255).index();
        acc = acc ^ EdgeDirectionTrait::NEG_X_Y.rotate_ccw(255).index();
    }
    assert!(acc == 0);
}

// Offset conversions and orientation

#[test]
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
#[available_gas(l2_gas: 1000000000)]
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
