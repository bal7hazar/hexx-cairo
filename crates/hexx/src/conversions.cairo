//! The offset coordinate conversions of `Hex`, the mirror of `hexx`'s `src/conversions.rs`.
//!
//! `OffsetHexMode` and the two conversions of milestone L-M1: they define the mapping between a
//! `Hex` and a board index (plan §3.5). The doubled and hexmod conversions land with L-M2.
//!
//! `hexx` writes `i32::midpoint(v, v & 1)` and `(v - (v & 1)) / 2`. Both numerators are even, so
//! the divisions are exact: they are the ceiling and the floor of `v / 2`, computed here from the
//! truncating division of Cairo without ever forming `v + 1` (which would leave `i32` for
//! `i32::MAX`, where `hexx`'s `midpoint` does not).

use crate::hex::Hex;
use crate::orientation::HexOrientation;

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
