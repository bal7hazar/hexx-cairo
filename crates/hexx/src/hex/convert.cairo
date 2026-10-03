//! `hex/convert`: the conversions of `Hex` (`src/hex/convert.rs`): the `u64` packing and the
//! conversions from an `i32` pair. The `f32` conversions are excluded (plan §4.4); the `glam`
//! ones (`IVec2`, `IVec3`) belong to the companion package of L-M3.

use crate::hex::{Hex, HexTrait};

/// `2^32`: the weight of the high half of the `u64` packing.
const HIGH: u64 = 0x1_0000_0000;

/// `2^31`: the sign bit of a half.
const SIGN: u64 = 0x8000_0000;

/// The `u64` packing of `Hex`.
pub trait HexConvertTrait {
    /// Unpacks a `u64`: `x` from the most significant 32 bits, `y` from the least significant 32
    /// bits, each read as a two's-complement `i32`.
    ///
    /// Mirrors `Hex::from_u64` (`src/hex/convert.rs:76`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn from_u64(value: u64) -> Hex;

    /// Packs into a `u64`: `x` in the most significant 32 bits, `y` in the least significant 32
    /// bits, each as its two's-complement `u32`.
    ///
    /// Mirrors `Hex::as_u64` (`src/hex/convert.rs:99`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn as_u64(self: Hex) -> u64;
}

pub impl HexConvertImpl of HexConvertTrait {
    #[inline]
    fn from_u64(value: u64) -> Hex {
        let (high, low) = DivRem::div_rem(value, HIGH.try_into().unwrap());
        Hex { x: HalfTrait::signed(high), y: HalfTrait::signed(low) }
    }

    #[inline]
    fn as_u64(self: Hex) -> u64 {
        HalfTrait::unsigned(self.x) * HIGH + HalfTrait::unsigned(self.y)
    }
}

/// An `(x, y)` tuple as a `Hex`.
///
/// Mirrors `impl From<(i32, i32)> for Hex` (`src/hex/convert.rs:4`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Cairo's `Into<(i32, i32), Hex>` is the form of Rust's `From`.
pub impl HexFromTuple of Into<(i32, i32), Hex> {
    #[inline]
    fn into(self: (i32, i32)) -> Hex {
        let (x, y) = self;
        HexTrait::new(x, y)
    }
}

/// An `[x, y]` array as a `Hex`.
///
/// Mirrors `impl From<[i32; 2]> for Hex` (`src/hex/convert.rs:11`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Cairo's `Into<[i32; 2], Hex>` is the form of Rust's `From`.
pub impl HexFromArray of Into<[i32; 2], Hex> {
    #[inline]
    fn into(self: [i32; 2]) -> Hex {
        HexTrait::from_array(self)
    }
}

/// The two's-complement halves of the packing, private: what `as i32` and `as u32` are in Rust.
#[generate_trait]
impl HalfImpl of HalfTrait {
    /// A `u32` value (`< 2^32`, in a `u64`) read as a two's-complement `i32`.
    #[inline]
    fn signed(half: u64) -> i32 {
        if half >= SIGN {
            // `half - 2^32` is in `[-2^31, -1]`: built from `half - 2^31` to stay in `i32`
            let offset: i32 = (half - SIGN).try_into().unwrap();
            offset - 0x7fff_ffff - 1
        } else {
            half.try_into().unwrap()
        }
    }

    /// An `i32` as its two's-complement `u32`, in a `u64`.
    #[inline]
    fn unsigned(v: i32) -> u64 {
        if v < 0 {
            // `v + 2^31` is in `[0, 2^31)`
            let offset: u64 = (v + 0x7fff_ffff + 1).try_into().unwrap();
            offset + SIGN
        } else {
            v.try_into().unwrap()
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::hex::{Hex, HexTrait};
    use super::{HexConvertTrait, HexFromArray, HexFromTuple};

    /// The example of `hexx`'s documentation (`src/hex/convert.rs:68-74`, `:90-97`), and the
    /// conversions from a pair.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_convert_examples() {
        assert!(HexConvertTrait::from_u64(0x000000AA_FFFFFF45) == HexTrait::new(0xAA, -0xBB));
        assert!(HexTrait::new(0xAA, -0xBB).as_u64() == 0x000000AA_FFFFFF45);
        let h: Hex = (3, -4).into();
        assert!(h == HexTrait::new(3, -4));
        let h: Hex = [3, -4].into();
        assert!(h == HexTrait::new(3, -4));
    }

    // Benchmarks of M2-T3 (LIB-06), 100 repetitions per test, one call per repetition: per call =
    // (test − baseline) / 100, on negative components (the longest branch). Targets (`L`,
    // `U = ceil(1.25 L)`, the brief's table), written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `from_u64`, `as_u64` | 6,180 (6 operations) | 7,725 |

    const REPS: u8 = 100;

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_convert_baseline() {
        let mut acc: u64 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -2 - n.into());
            let v: u64 = 0xffff_ff00_ffff_ff00 + n.into();
            acc += v % 2 + a.x.try_into().unwrap_or(1);
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_as_u64() {
        let mut acc: u64 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -2 - n.into());
            let v: u64 = 0xffff_ff00_ffff_ff00 + n.into();
            acc += v % 2 + a.as_u64() % 2;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_from_u64() {
        let mut acc: u64 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -2 - n.into());
            let v: u64 = 0xffff_ff00_ffff_ff00 + n.into();
            acc += v % 2 + HexConvertTrait::from_u64(v).x.try_into().unwrap_or(1);
        }
        assert!(acc != 1);
    }
}
