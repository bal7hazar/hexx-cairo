//! The offset coordinate conversions of `Hex`, the mirror of `hexx`'s `src/conversions.rs`.
//!
//! `OffsetHexMode` and the two conversions of milestone L-M1: they define the mapping between a
//! `Hex` and a board index (plan §3.5). `DoubledHexMode`, the doubled and the hexmod conversions
//! of L-M2 (M2-T3).
//!
//! `hexx` writes `i32::midpoint(v, v & 1)` and `(v - (v & 1)) / 2`. Both numerators are even, so
//! the divisions are exact: they are the ceiling and the floor of `v / 2`, computed here from the
//! truncating division of Cairo without ever forming `v + 1` (which would leave `i32` for
//! `i32::MAX`, where `hexx`'s `midpoint` does not).

use crate::hex::{Hex, HexShiftTrait, HexTrait};
use crate::orientation::HexOrientation;

/// Which axis of a doubled grid is doubled: the width (columns, the default) or the height (rows).
///
/// Mirrors `hexx::conversions::DoubledHexMode` (`src/conversions.rs:12`), its variants
/// `DoubledWidth` (`:15`, the default) and `DoubledHeight` (`:17`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// `Serde` and `Hash` are derived as a matter of course (plan §2.3).
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
pub enum DoubledHexMode {
    #[default]
    DoubledWidth,
    DoubledHeight,
}

/// Which rows or columns of an offset grid are shoved: the even ones or the odd ones.
///
/// Mirrors `hexx::conversions::OffsetHexMode` (`src/conversions.rs:29`), its variants `Even`
/// (`:34`) and `Odd` (`:39`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// `Serde` and `Hash` are derived as a matter of course (plan §2.3).
#[derive(Copy, Drop, Serde, PartialEq, Debug, Hash)]
pub enum OffsetHexMode {
    Even,
    Odd,
}

/// The offset conversions, on `Hex`.
#[generate_trait]
pub impl HexConversionsImpl of HexConversionsTrait {
    /// Converts `self` to offset coordinates `[column, row]` according to `mode` and
    /// `orientation`.
    ///
    /// Mirrors `Hex::to_offset_coordinates` (`src/conversions.rs:65`).
    ///
    /// #### Panics
    ///
    /// When the offset coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics.
    /// A `[i32; 2]` is returned as `[i32; 2]`, `[column, row]`.
    fn to_offset_coordinates(
        self: Hex, mode: OffsetHexMode, orientation: HexOrientation,
    ) -> [i32; 2] {
        match orientation {
            HexOrientation::Flat => [self.x, self.y + OffsetHalfTrait::shove(self.x, mode)],
            HexOrientation::Pointy => [self.x + OffsetHalfTrait::shove(self.y, mode), self.y],
        }
    }

    /// Converts offset coordinates `[column, row]` back to a `Hex` according to `mode` and
    /// `orientation`.
    ///
    /// Mirrors `Hex::from_offset_coordinates` (`src/conversions.rs:142`).
    ///
    /// #### Panics
    ///
    /// When the axial coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics.
    fn from_offset_coordinates(
        offset: [i32; 2], mode: OffsetHexMode, orientation: HexOrientation,
    ) -> Hex {
        let [col, row] = offset;
        match orientation {
            HexOrientation::Flat => Hex { x: col, y: row - OffsetHalfTrait::shove(col, mode) },
            HexOrientation::Pointy => Hex { x: col - OffsetHalfTrait::shove(row, mode), y: row },
        }
    }

    /// Converts `self` to doubled coordinates `[column, row]`: `[2x + y, y]` for
    /// `DoubledWidth`, `[x, 2y + x]` for `DoubledHeight`.
    ///
    /// Mirrors `Hex::to_doubled_coordinates` (`src/conversions.rs:50`).
    ///
    /// #### Panics
    ///
    /// When `2x`, `2y` or the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn to_doubled_coordinates(self: Hex, mode: DoubledHexMode) -> [i32; 2] {
        match mode {
            DoubledHexMode::DoubledWidth => [2 * self.x + self.y, self.y],
            DoubledHexMode::DoubledHeight => [self.x, 2 * self.y + self.x],
        }
    }

    /// Converts doubled coordinates `[column, row]` back to a `Hex`: `((col - row) / 2, row)`
    /// for `DoubledWidth`, `(col, (row - col) / 2)` for `DoubledHeight`, the division truncated
    /// toward zero as `hexx`'s, also on a pair that is not a valid doubled coordinate (an odd
    /// difference).
    ///
    /// Mirrors `Hex::from_doubled_coordinates` (`src/conversions.rs:128`).
    ///
    /// #### Panics
    ///
    /// When the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn from_doubled_coordinates(doubled: [i32; 2], mode: DoubledHexMode) -> Hex {
        let [col, row] = doubled;
        match mode {
            DoubledHexMode::DoubledWidth => HexTrait::new((col - row) / 2, row),
            DoubledHexMode::DoubledHeight => HexTrait::new(col, (row - col) / 2),
        }
    }

    /// The hexmod index of `self` in a hexagon of radius `range` around the origin:
    /// `(y + shift·x) mod area`, `area = range_count(range)`, `shift = 3·range + 2`, the modulo
    /// Euclidean (in `0..area`); a coordinate outside the hexagon wraps.
    ///
    /// Mirrors `Hex::to_hexmod_coordinates` (`src/conversions.rs:92`).
    ///
    /// #### Panics
    ///
    /// When `range_count(range)` leaves `u32` or `i32` (`range ≥ 26_755`), and when
    /// `y + shift·x` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` casts `range_count(range)` and `shift(range)` with `as i32`: from `range = 26_755`
    /// the area wraps to a negative `i32` there and its result is not an index of the hexagon;
    /// this port panics. Elsewhere `hexx` wraps in a release build and panics in a debug build
    /// (plan §3.1); this port panics exactly where the debug build does. `rem_euclid` is written
    /// out.
    fn to_hexmod_coordinates(self: Hex, range: u32) -> u32 {
        let area: i32 = HexTrait::range_count(range).try_into().unwrap();
        let shift: i32 = HexShiftTrait::shift(range).try_into().unwrap();
        let r = (self.y + shift * self.x) % area;
        let r = if r < 0 {
            r + area
        } else {
            r
        };
        r.try_into().unwrap()
    }

    /// The `Hex` of the hexmod index `coord` in a hexagon of radius `range` around the origin,
    /// the inverse of `to_hexmod_coordinates` on `0..range_count(range)`.
    ///
    /// Mirrors `Hex::from_hexmod_coordinates` (`src/conversions.rs:110`).
    ///
    /// #### Panics
    ///
    /// When `coord`, `range` or `shift(range)` exceeds `i32::MAX`, and when an intermediate value
    /// leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` casts `coord`, `range` and `shift(range)` with `as i32`: a value above `i32::MAX`
    /// wraps there (a `coord` beyond `i32::MAX` becomes negative) and panics here. Elsewhere
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn from_hexmod_coordinates(coord: u32, range: u32) -> Hex {
        let shift: i32 = HexShiftTrait::shift(range).try_into().unwrap();
        let range: i32 = range.try_into().unwrap();
        let coord: i32 = coord.try_into().unwrap();
        let ms = (coord + range) / shift;
        let mcs = (coord + 2 * range) / (shift - 1);
        HexTrait::new(
            ms * (range + 1) + mcs * -range, coord + ms * (-2 * range - 1) + mcs * (-range - 1),
        )
    }
}

/// The amount by which a line is shoved, private: half of the other coordinate, rounded up for
/// `Even` (`midpoint(v, v & 1)`) and down for `Odd` (`(v - (v & 1)) / 2`).
#[generate_trait]
impl OffsetHalfImpl of OffsetHalfTrait {
    #[inline]
    fn shove(v: i32, mode: OffsetHexMode) -> i32 {
        let half = v / 2;
        let odd = v % 2;
        match mode {
            OffsetHexMode::Even => if odd > 0 {
                half + 1
            } else {
                half
            },
            OffsetHexMode::Odd => if odd < 0 {
                half - 1
            } else {
                half
            },
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::hex::HexTrait;
    use super::{DoubledHexMode, HexConversionsTrait};

    /// The deviation of `to_hexmod_coordinates`: from `range = 26_755` the area exceeds
    /// `i32::MAX`; `hexx` wraps it with `as i32`, this port panics.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_to_hexmod_coordinates_area_beyond_i32() {
        let _ = HexTrait::new(0, 0).to_hexmod_coordinates(26_755);
    }

    /// The largest radius whose area fits `i32` converts.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_to_hexmod_coordinates_largest_area() {
        assert!(HexTrait::new(0, 0).to_hexmod_coordinates(26_754) == 0);
    }

    /// The deviation of `from_hexmod_coordinates`: a `coord` above `i32::MAX` wraps in `hexx` and
    /// panics here.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_from_hexmod_coordinates_coord_beyond_i32() {
        let _ = HexConversionsTrait::from_hexmod_coordinates(0x8000_0000, 1);
    }

    /// The round trips of `hexx`'s own tests (`src/conversions.rs`, `doubled_coordinates`,
    /// `hexmod_coordinates`), on every hex of radius 6.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_conversions_round_trips() {
        let mut x: i32 = -6;
        while x <= 6 {
            let mut y: i32 = -6;
            while y <= 6 {
                let h = HexTrait::new(x, y);
                if h.length() <= 6 {
                    for mode in array![
                        DoubledHexMode::DoubledWidth, DoubledHexMode::DoubledHeight,
                    ] {
                        let doubled = h.to_doubled_coordinates(mode);
                        assert!(HexConversionsTrait::from_doubled_coordinates(doubled, mode) == h);
                    }
                    let coord = h.to_hexmod_coordinates(6);
                    assert!(HexConversionsTrait::from_hexmod_coordinates(coord, 6) == h);
                }
                y += 1;
            }
            x += 1;
        }
    }

    // Benchmarks of M2-T3 (LIB-06), 100 repetitions per test, one call per repetition: per call =
    // (test − baseline) / 100, at radius 6. Targets (`L`, `U = ceil(1.25 L)`, the brief's table;
    // the doubled conversions are at most two operations and need none), written before the
    // first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `to_hexmod_coordinates` | 11,400 | 14,250 |
    // | `from_hexmod_coordinates` | 14,560 | 18,200 |

    const REPS: u8 = 100;

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hexmod_baseline() {
        let (mut acc_i, mut acc_u): (i32, u32) = (0, 0);
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = HexTrait::new(-1 - n.into(), 2);
            let coord: u32 = n.into();
            acc_i += h.x;
            acc_u += coord;
        }
        assert!(acc_i != 1 && acc_u != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_to_hexmod_coordinates() {
        let (mut acc_i, mut acc_u): (i32, u32) = (0, 0);
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = HexTrait::new(-1 - n.into(), 2);
            acc_i += h.x;
            acc_u += h.to_hexmod_coordinates(6);
        }
        assert!(acc_i != 1 && acc_u != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_from_hexmod_coordinates() {
        let (mut acc_i, mut acc_u): (i32, u32) = (0, 0);
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let coord: u32 = n.into();
            acc_i += HexConversionsTrait::from_hexmod_coordinates(coord, 6).x;
            acc_u += coord;
        }
        assert!(acc_i != 1 && acc_u != 1);
    }
}
