//! `Hex`: an axial hexagonal coordinate on `i32`, the mirror of `hexx::Hex` (`src/hex/mod.rs`).
//!
//! Every operation whose result leaves `i32` **panics** with Cairo's native message, where `hexx`
//! panics in a debug build and wraps in a release build (plan §3.1). The cubic coordinate is
//! `z = -x - y`, computed as `hexx` computes it (`src/hex/mod.rs:274-276`), so it panics exactly
//! where a debug build of `hexx` does.
//!
//! The compass of `hexx` (y down) is kept verbatim by `EdgeDirection`; `Hex` itself has no
//! orientation. This file holds the items of milestone L-M1 (plan §8), `line_to` (M1-T6)
//! included; the rest of `src/hex/mod.rs` lands with L-M2.

/// An axial hexagonal coordinate.
///
/// Mirrors `hexx::Hex` (`src/hex/mod.rs:69`), with its public fields `x` (`:71`) and `y` (`:73`).
///
/// #### Panics
///
/// None: a struct holds any `i32` pair.
///
/// #### Deviations
///
/// Derives `Serde`, `Debug`, `Default`, `Hash` as a matter of course (plan §2.3); `Debug` prints
/// the fields, not `x`, `y` and `z` as `hexx` does (L-M2).
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
pub struct Hex {
    pub x: i32,
    pub y: i32,
}

/// The items of `impl Hex` of milestone L-M1.
pub trait HexTrait {
    /// `(0, 0)`.
    ///
    /// Mirrors `Hex::ZERO` (`src/hex/mod.rs:97`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ZERO: Hex;

    /// The six edge neighbours, in `EdgeDirection` order: `X`, `Y`, `NEG_X_Y`, `NEG_X`, `NEG_Y`,
    /// `X_NEG_Y`, that is `(1, 0)`, `(0, 1)`, `(-1, 1)`, `(-1, 0)`, `(0, -1)`, `(1, -1)`.
    ///
    /// Mirrors `Hex::NEIGHBORS_COORDS` (`src/hex/mod.rs:159`), a `[Hex; 6]` read by
    /// `EdgeDirection::into_hex`.
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEIGHBORS_COORDS: [Hex; 6];

    /// Instantiates a hexagon from axial coordinates.
    ///
    /// Mirrors `Hex::new` (`src/hex/mod.rs:208`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(x: i32, y: i32) -> Hex;

    /// The `x` coordinate.
    ///
    /// Mirrors `Hex::x` (`src/hex/mod.rs:256`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn x(self: Hex) -> i32;

    /// The `y` coordinate.
    ///
    /// Mirrors `Hex::y` (`src/hex/mod.rs:264`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn y(self: Hex) -> i32;

    /// The cubic `z` coordinate, `-x - y`.
    ///
    /// Mirrors `Hex::z` (`src/hex/mod.rs:274`).
    ///
    /// #### Panics
    ///
    /// When `-x`, or `-x - y`, leaves `i32` (for example `x = i32::MIN`, or `x = 0` and
    /// `y = i32::MIN`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn z(self: Hex) -> i32;

    /// Subtracts `rhs` from `self`, component by component.
    ///
    /// Mirrors `Hex::const_sub` (`src/hex/mod.rs:449`). Cairo has no `const fn`: this is the
    /// plain function behind the `-` operator of L-M2, and what `distance_to` calls.
    ///
    /// #### Panics
    ///
    /// When a component of the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn const_sub(self: Hex, rhs: Hex) -> Hex;

    /// The length of the coordinate, its distance from the origin, as a signed integer:
    /// `max(|x|, |y|, |z|)`.
    ///
    /// Mirrors `Hex::length` (`src/hex/mod.rs:568`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`, or when a component is `i32::MIN` (its absolute value has no
    /// `i32`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn length(self: Hex) -> i32;

    /// The length of the coordinate as an unsigned integer.
    ///
    /// Mirrors `Hex::ulength` (`src/hex/mod.rs:594`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (the computation of `z`);
    /// this port panics. `i32::MIN` as a component is fine: its unsigned absolute value is
    /// `2^31`, as in `hexx`.
    fn ulength(self: Hex) -> u32;

    /// The distance from `self` to `rhs` in hexagonal space, as a signed integer.
    ///
    /// Mirrors `Hex::distance_to` (`src/hex/mod.rs:615`).
    ///
    /// #### Panics
    ///
    /// When `const_sub` or `length` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn distance_to(self: Hex, rhs: Hex) -> i32;

    /// The distance from `self` to `rhs` in hexagonal space, as an unsigned integer.
    ///
    /// Mirrors `Hex::unsigned_distance_to` (`src/hex/mod.rs:625`).
    ///
    /// #### Panics
    ///
    /// When `const_sub` or `ulength` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn unsigned_distance_to(self: Hex, rhs: Hex) -> u32;

    /// Every coordinate of the line from `self` to `other`: `N + 1` coordinates,
    /// `N = self.unsigned_distance_to(other)`, both ends included. Element `i` is the tile
    /// nearest the point `self + (i / N)·(other − self)`; at an exact tie between two tiles (an
    /// even `N` only), the one with the smaller `y`, and on the same row the larger `x` (plan
    /// §6.6, the game's rule: the lower tile index of the board). Exact integer arithmetic, no
    /// division: `x` is rounded half up and `y` half down, each by an accumulator. The line is
    /// symmetric (`b.line_to(a)` is `a.line_to(b)` reversed) and translation-invariant.
    ///
    /// Mirrors `Hex::line_to` (`src/hex/mod.rs:903`).
    ///
    /// #### Panics
    ///
    /// Where `self.unsigned_distance_to(other)` panics, as `hexx` does in a debug build: when a
    /// component of `self − other`, or its `z`, leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. The exact integer line of plan §6.6, where
    /// `hexx` converts both ends to `f32` (`:906`), interpolates in `f32` (`:908`) and rounds
    /// (`:474-483`). Three sources of difference: an exact tie, resolved here by the game's rule
    /// (`hexx`'s `f32` rule is neither symmetric nor translation-invariant); the `f32` rounding of
    /// an end beyond `2^24` (`(16_777_217, 0) → (16_777_218, 0)`: `hexx` starts at
    /// `(16_777_216, 0)`); and the `f32` rounding of the interpolation, which moves a sample
    /// across the edge of its tile even below `2^24` (`(8_000_000, 0) → (8_000_001, 6)`: sample 2
    /// is `(8_000_000, 2)`, `hexx` returns `(8_000_001, 2)`). No identity domain is claimed:
    /// identical to `hexx` on every non-tie pair of the window 15 × 16 in the mirror frame and on
    /// the seeded sample of `[-40, 40]²`; every pair of the compared sets where both differ is
    /// listed in `docs/deviations/line_ties.md` (generated by `tools/refgen`).
    fn line_to(self: Hex, other: Hex) -> Span<Hex>;
}

pub impl HexImpl of HexTrait {
    const ZERO: Hex = Hex { x: 0, y: 0 };
    const NEIGHBORS_COORDS: [Hex; 6] = [
        Hex { x: 1, y: 0 }, Hex { x: 0, y: 1 }, Hex { x: -1, y: 1 }, Hex { x: -1, y: 0 },
        Hex { x: 0, y: -1 }, Hex { x: 1, y: -1 },
    ];

    #[inline]
    fn new(x: i32, y: i32) -> Hex {
        Hex { x, y }
    }

    #[inline]
    fn x(self: Hex) -> i32 {
        self.x
    }

    #[inline]
    fn y(self: Hex) -> i32 {
        self.y
    }

    #[inline]
    fn z(self: Hex) -> i32 {
        -self.x - self.y
    }

    #[inline]
    fn const_sub(self: Hex, rhs: Hex) -> Hex {
        Hex { x: self.x - rhs.x, y: self.y - rhs.y }
    }

    fn length(self: Hex) -> i32 {
        let x = HexMathTrait::abs(self.x);
        let y = HexMathTrait::abs(self.y);
        let z = HexMathTrait::abs(self.z());
        HexMathTrait::max3(x, y, z)
    }

    fn ulength(self: Hex) -> u32 {
        let x = HexMathTrait::unsigned_abs(self.x);
        let y = HexMathTrait::unsigned_abs(self.y);
        let z = HexMathTrait::unsigned_abs(self.z());
        HexMathTrait::max3(x, y, z)
    }

    #[inline]
    fn distance_to(self: Hex, rhs: Hex) -> i32 {
        self.const_sub(rhs).length()
    }

    #[inline]
    fn unsigned_distance_to(self: Hex, rhs: Hex) -> u32 {
        self.const_sub(rhs).ulength()
    }

    fn line_to(self: Hex, other: Hex) -> Span<Hex> {
        // [Compute] The distance, panicking where `hexx`'s `unsigned_distance_to` does
        let delta = self.const_sub(other);
        let distance = delta.ulength();
        let mut line = array![self];
        if distance == 0 {
            return line.span();
        }
        // [Compute] One accumulator per axis: the magnitude `m` of the move after `i` steps is
        // `round(i·d / N)`, `e = 2·i·d + N − c − 2·N·m` stays in `0..2N`, and `c = 1`
        // rounds a tie down. `x` ties toward the larger `x`, `y` toward the smaller `y`.
        let n: u64 = distance.into();
        let (step_x, dx, mut ex) = if delta.x < 0 {
            (1, HexMathTrait::unsigned_abs(delta.x), n)
        } else {
            (-1, HexMathTrait::unsigned_abs(delta.x), n - 1)
        };
        let (step_y, dy, mut ey) = if delta.y < 0 {
            (1, HexMathTrait::unsigned_abs(delta.y), n - 1)
        } else {
            (-1, HexMathTrait::unsigned_abs(delta.y), n)
        };
        let (dx, dy): (u64, u64) = (2 * dx.into(), 2 * dy.into());
        let (tx, ty) = (2 * n - dx, 2 * n - dy);
        // [Compute] Each step moves `x` and `y` toward `other`: no `i32` leaves the endpoints
        let (mut x, mut y) = (self.x, self.y);
        let mut step: u32 = 0;
        while step != distance {
            if ex >= tx {
                ex -= tx;
                x += step_x;
            } else {
                ex += dx;
            }
            if ey >= ty {
                ey -= ty;
                y += step_y;
            } else {
                ey += dy;
            }
            line.append(Hex { x, y });
            step += 1;
        }
        line.span()
    }
}

/// The scalar helpers of `length` and `ulength`: private, what `i32::abs`, `i32::unsigned_abs`
/// and the three-way maximum of `src/hex/mod.rs:568-607` are in Rust.
#[generate_trait]
impl HexMathImpl of HexMathTrait {
    /// `|v|`, panicking on `i32::MIN` as `i32::abs` does in a debug build.
    #[inline]
    fn abs(v: i32) -> i32 {
        if v < 0 {
            -v
        } else {
            v
        }
    }

    /// `|v|` as a `u32`, exact on `i32::MIN` (`i32::unsigned_abs`).
    #[inline]
    fn unsigned_abs(v: i32) -> u32 {
        if v < 0 {
            // `-(v + 1)` is in `0..=i32::MAX` for every negative `v`.
            let magnitude: u32 = (-(v + 1)).try_into().unwrap();
            magnitude + 1
        } else {
            v.try_into().unwrap()
        }
    }

    /// The largest of three values, in the branch order of `hexx`.
    #[inline]
    fn max3<T, +PartialOrd<T>, +Copy<T>, +Drop<T>>(x: T, y: T, z: T) -> T {
        if x >= y && x >= z {
            x
        } else if y >= x && y >= z {
            y
        } else {
            z
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use super::{Hex, HexTrait};

    #[generate_trait]
    impl Line of LineTrait {
        /// The line reversed.
        fn reversed(line: Span<Hex>) -> Span<Hex> {
            let mut back = array![];
            let mut i = line.len();
            while i != 0 {
                i -= 1;
                back.append(*line.at(i));
            }
            back.span()
        }
    }

    /// R-N5-5 (audit pass 2, finding 25): no tie, `N = 7`; sample 2 is `(8_000_000, 2)` exactly,
    /// where `hexx` returns `(8_000_001, 2)` (`docs/deviations/line_ties.md`).
    #[test]
    #[available_gas(l2_gas: 63378)]
    fn test_hex_line_to_regression_r_n5_5() {
        let line = HexTrait::new(8_000_000, 0).line_to(HexTrait::new(8_000_001, 6));
        assert!(line.len() == 8);
        assert!(*line.at(2) == HexTrait::new(8_000_000, 2));
        assert!(*line.at(7) == HexTrait::new(8_000_001, 6));
    }

    /// R-N5-6 (audit pass 1, finding 8): beyond `2^24` the ends are exact, where `hexx` starts at
    /// `(16_777_216, 0)`.
    #[test]
    #[available_gas(l2_gas: 29285)]
    fn test_hex_line_to_regression_r_n5_6() {
        let line = HexTrait::new(16_777_217, 0).line_to(HexTrait::new(16_777_218, 0));
        assert!(line == array![HexTrait::new(16_777_217, 0), HexTrait::new(16_777_218, 0)].span());
    }

    /// The ends: one element for a coordinate with itself, `N + 1` elements, `self` first and
    /// `other` last, and the extremes of `i32` where the difference stays in `i32`.
    #[test]
    #[available_gas(l2_gas: 228260)]
    fn test_hex_line_to_ends() {
        let a = HexTrait::new(-3, 7);
        assert!(a.line_to(a) == array![a].span());
        let max: i32 = 0x7fffffff;
        let ends: [(Hex, Hex); 3] = [
            (HexTrait::new(0, 0), HexTrait::new(5, 0)),
            (HexTrait::new(max - 3, 0), HexTrait::new(max, -3)),
            (HexTrait::new(-max, 1), HexTrait::new(-max + 2, -1)),
        ];
        for (a, b) in ends.span() {
            let line = a.line_to(*b);
            assert!(line.len() == a.unsigned_distance_to(*b) + 1);
            assert!(*line.at(0) == *a);
            assert!(*line.at(line.len() - 1) == *b);
        }
    }

    /// The tie rule: `Δ = (3, 3)` has a tie at every odd step, resolved to the smaller `y`; on a
    /// row, `Δ = (−1, 2)` ties at its midpoint to the larger `x` (R-N5-2 in the mirror frame).
    #[test]
    #[available_gas(l2_gas: 98721)]
    fn test_hex_line_to_ties() {
        let line = HexTrait::new(0, 0).line_to(HexTrait::new(3, 3));
        let expected = array![
            HexTrait::new(0, 0), HexTrait::new(1, 0), HexTrait::new(1, 1), HexTrait::new(2, 1),
            HexTrait::new(2, 2), HexTrait::new(3, 2), HexTrait::new(3, 3),
        ];
        assert!(line == expected.span());
        let line = HexTrait::new(-5, 3).line_to(HexTrait::new(-6, 5));
        assert!(
            line == array![HexTrait::new(-5, 3), HexTrait::new(-5, 4), HexTrait::new(-6, 5)].span(),
        );
    }

    /// Symmetric and translation-invariant, on every pair of `[-3, 3]²`.
    #[test]
    #[available_gas(l2_gas: 559857627)]
    fn test_hex_line_to_symmetry_translation() {
        let shift = HexTrait::new(1_000_003, -999_997);
        let mut ax: i32 = -3;
        while ax != 4 {
            let mut ay: i32 = -3;
            while ay != 4 {
                let a = HexTrait::new(ax, ay);
                let mut bx: i32 = -3;
                while bx != 4 {
                    let mut by: i32 = -3;
                    while by != 4 {
                        let b = HexTrait::new(bx, by);
                        let line = a.line_to(b);
                        assert!(LineTrait::reversed(b.line_to(a)) == line);
                        let moved = HexTrait::new(ax + shift.x, ay + shift.y)
                            .line_to(HexTrait::new(bx + shift.x, by + shift.y));
                        let mut i = 0;
                        while i != line.len() {
                            let h = *line.at(i);
                            assert!(*moved.at(i) == HexTrait::new(h.x + shift.x, h.y + shift.y));
                            i += 1;
                        }
                        by += 1;
                    }
                    bx += 1;
                }
                ay += 1;
            }
            ax += 1;
        }
    }

    /// The panics of `unsigned_distance_to`: a difference that leaves `i32`.
    #[test]
    #[available_gas(l2_gas: 16086)]
    #[should_panic]
    fn test_hex_line_to_revert_overflow() {
        let max: i32 = 0x7fffffff;
        HexTrait::new(max, 0).line_to(HexTrait::new(-1, 0));
    }
}
