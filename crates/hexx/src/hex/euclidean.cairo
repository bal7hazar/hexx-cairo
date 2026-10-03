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

#[cfg(test)]
mod tests {
    // Local imports

    use crate::hex::HexTrait;
    use super::HexEuclideanTrait;

    /// The partial sum `x² + y²` leaves `i32` although the total would not: `hexx` panics there
    /// in a debug build, and so does this port.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    #[should_panic]
    fn test_squared_euclidean_length_partial_sum() {
        let _ = HexTrait::new(40000, -40000).squared_euclidean_length();
    }

    /// The oracle: the six neighbours are at squared distance 1, the six diagonals at 3, and the
    /// distance is symmetric.
    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn test_squared_euclidean_oracle() {
        let a = HexTrait::new(5, -7);
        let neighbors = a.all_neighbors().span();
        let diagonals = HexTrait::DIAGONAL_COORDS.span();
        let mut i = 0;
        while i < 6 {
            assert!(a.squared_euclidean_distance_to(*neighbors.at(i)) == 1);
            assert!((*diagonals.at(i)).squared_euclidean_length() == 3);
            assert!((*neighbors.at(i)).squared_euclidean_distance_to(a) == 1);
            i += 1;
        }
    }

    // Benchmarks of M2-T3 (LIB-06), 100 repetitions per test, one call per repetition: per call =
    // (test − baseline) / 100. Targets (`L`, `U = ceil(1.25 L)`, the brief's table; the length is
    // `squared_euclidean_distance_to` less `const_sub`), written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `squared_euclidean_length` | 5,150 (5 operations) | 6,438 |
    // | `squared_euclidean_distance_to` | 8,080 | 10,100 |

    const REPS: u8 = 100;

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_euclidean_baseline() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_squared_euclidean_length() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.squared_euclidean_length() + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1000000000)]
    fn bench_hex_squared_euclidean_distance_to() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.squared_euclidean_distance_to(b) + b.y;
        }
        assert!(acc != 1);
    }
}
