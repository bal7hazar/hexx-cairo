//! `hex/euclidean`: the squared Euclidean length and distance of `Hex` (`src/hex/euclidean.rs`),
//! exact integers. `euclidean_length` and `euclidean_distance_to` are excluded (`f32` results,
//! plan §4.4, D-13, §14 #43); `circular_range` is M2-T4's `circular_range_squared`.

use crate::hex::{Hex, HexTrait};

/// The squared Euclidean items of `Hex`.
pub trait HexEuclideanTrait {
    /// The squared Euclidean distance from the origin, in the Cartesian frame of unit hexagons:
    /// `x² + y² + x·y`.
    ///
    /// Mirrors `Hex::squared_euclidean_length` (`src/hex/euclidean.rs:20`).
    ///
    /// #### Panics
    ///
    /// When a square, a partial sum or the product leaves `i32`, in `hexx`'s order: `x²`, `y²`,
    /// `x² + y²`, `x·y`, the total.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn squared_euclidean_length(self: Hex) -> i32;

    /// The squared Euclidean distance from `self` to `rhs`: the squared Euclidean length of
    /// `rhs - self`.
    ///
    /// Mirrors `Hex::squared_euclidean_distance_to` (`src/hex/euclidean.rs:65`).
    ///
    /// #### Panics
    ///
    /// When `rhs - self` or its squared Euclidean length leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn squared_euclidean_distance_to(self: Hex, rhs: Hex) -> i32;
}

pub impl HexEuclideanImpl of HexEuclideanTrait {
    #[inline]
    fn squared_euclidean_length(self: Hex) -> i32 {
        self.x * self.x + self.y * self.y + self.x * self.y
    }

    #[inline]
    fn squared_euclidean_distance_to(self: Hex, rhs: Hex) -> i32 {
        rhs.const_sub(self).squared_euclidean_length()
    }
}
