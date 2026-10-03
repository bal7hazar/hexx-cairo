//! `hex/impls`: the operators of `Hex` (`src/hex/impls.rs`), as corelib impls, and the named
//! counterparts of those Cairo cannot express on a `Hex` (`HexOpsTrait`, D-143).
//!
//! Cairo's arithmetic traits are homogeneous: `Add`, `Sub`, `Mul`, `Div`, `Rem` of `Hex` by `Hex`
//! and their assignment forms are impls; `Add<i32>`, `Sub<i32>`, `Add`/`Sub` of a direction,
//! `Div<i32>` and `Rem<i32>` are the methods of `HexOpsTrait` (`Mul<i32>` is
//! `HexTrait::mul_scalar`).
//! Excluded (plan §4.4, §14 #43): the bitwise and shift operators, the heterogeneous assignment
//! operators, every `f32` operand. `Sum` and `Product` are not here: corelib's `core::iter::Sum`
//! and `Product` declare `+Iterator<I>[Item: A]`, and implementing them needs the crate's
//! experimental feature `associated_item_constraints` (deferred: `PLAN.md`, "Deferred").
//!
//! An impl is found where its trait or its type is declared, or where it is imported: these live in
//! `hexx::hex::impls`, so a consumer imports the ones it uses (`use hexx::hex::impls::{HexAdd,
//! HexOpsTrait};`), as for the `Neg` of the direction types.
//!
//! Every operation whose result leaves `i32` **panics**, where `hexx` panics in a debug build and
//! wraps in a release build (plan §3.1).

use core::ops::{AddAssign, DivAssign, MulAssign, RemAssign, SubAssign};
use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
use crate::hex::{Hex, HexTrait};

/// `self + rhs`, component by component.
///
/// Mirrors `impl Add<Self> for Hex` (`src/hex/impls.rs:16`).
///
/// #### Panics
///
/// When a component of the sum leaves `i32`.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexAdd of Add<Hex> {
    #[inline]
    fn add(lhs: Hex, rhs: Hex) -> Hex {
        lhs.const_add(rhs)
    }
}

/// `self - rhs`, component by component.
///
/// Mirrors `impl Sub<Self> for Hex` (`src/hex/impls.rs:96`).
///
/// #### Panics
///
/// When a component of the difference leaves `i32`.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexSub of Sub<Hex> {
    #[inline]
    fn sub(lhs: Hex, rhs: Hex) -> Hex {
        lhs.const_sub(rhs)
    }
}

/// `self * rhs`, component by component.
///
/// Mirrors `impl Mul<Self> for Hex` (`src/hex/impls.rs:164`).
///
/// #### Panics
///
/// When a component of the product leaves `i32`.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexMul of Mul<Hex> {
    #[inline]
    fn mul(lhs: Hex, rhs: Hex) -> Hex {
        Hex { x: lhs.x * rhs.x, y: lhs.y * rhs.y }
    }
}

/// `self / rhs`, component by component, truncated toward zero as Rust's integer division.
///
/// Mirrors `impl Div<Self> for Hex` (`src/hex/impls.rs:230`).
///
/// #### Panics
///
/// When a component of `rhs` is zero, or for `i32::MIN / -1` (as `hexx` does in every build).
///
/// #### Deviations
///
/// None.
pub impl HexDiv of Div<Hex> {
    #[inline]
    fn div(lhs: Hex, rhs: Hex) -> Hex {
        Hex { x: lhs.x / rhs.x, y: lhs.y / rhs.y }
    }
}

/// `self - (self / rhs) * rhs`, component by component: the remainder of the truncated division,
/// with the sign of `self`.
///
/// Mirrors `impl Rem<Self> for Hex` (`src/hex/impls.rs:286`).
///
/// #### Panics
///
/// Where `Div` does: a zero component of `rhs`, or `i32::MIN / -1`.
///
/// #### Deviations
///
/// None.
pub impl HexRem of Rem<Hex> {
    #[inline]
    fn rem(lhs: Hex, rhs: Hex) -> Hex {
        Hex { x: lhs.x % rhs.x, y: lhs.y % rhs.y }
    }
}

/// `-self`.
///
/// Mirrors `impl Neg for Hex` (`src/hex/impls.rs:318`).
///
/// #### Panics
///
/// When a component is `i32::MIN`.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexNeg of Neg<Hex> {
    #[inline]
    fn neg(a: Hex) -> Hex {
        a.const_neg()
    }
}

/// `self += rhs`.
///
/// Mirrors `impl AddAssign for Hex` (`src/hex/impls.rs:55`).
///
/// #### Panics
///
/// Where `Add` does.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexAddAssign of AddAssign<Hex, Hex> {
    #[inline]
    fn add_assign(ref self: Hex, rhs: Hex) {
        self = self.const_add(rhs);
    }
}

/// `self -= rhs`.
///
/// Mirrors `impl SubAssign for Hex` (`src/hex/impls.rs:135`).
///
/// #### Panics
///
/// Where `Sub` does.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexSubAssign of SubAssign<Hex, Hex> {
    #[inline]
    fn sub_assign(ref self: Hex, rhs: Hex) {
        self = self.const_sub(rhs);
    }
}

/// `self *= rhs`.
///
/// Mirrors `impl MulAssign for Hex` (`src/hex/impls.rs:196`).
///
/// #### Panics
///
/// Where `Mul` does.
///
/// #### Deviations
///
/// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
/// exactly where the debug build does.
pub impl HexMulAssign of MulAssign<Hex, Hex> {
    #[inline]
    fn mul_assign(ref self: Hex, rhs: Hex) {
        self = HexMul::mul(self, rhs);
    }
}

/// `self /= rhs`.
///
/// Mirrors `impl DivAssign for Hex` (`src/hex/impls.rs:265`).
///
/// #### Panics
///
/// Where `Div` does.
///
/// #### Deviations
///
/// None.
pub impl HexDivAssign of DivAssign<Hex, Hex> {
    #[inline]
    fn div_assign(ref self: Hex, rhs: Hex) {
        self = HexDiv::div(self, rhs);
    }
}

/// `self %= rhs`.
///
/// Mirrors `impl RemAssign for Hex` (`src/hex/impls.rs:304`).
///
/// #### Panics
///
/// Where `Rem` does.
///
/// #### Deviations
///
/// None.
pub impl HexRemAssign of RemAssign<Hex, Hex> {
    #[inline]
    fn rem_assign(ref self: Hex, rhs: Hex) {
        self = HexRem::rem(self, rhs);
    }
}

/// The named counterparts of the operators of `Hex` that Cairo cannot express: a scalar or a
/// direction as the right operand (Cairo's arithmetic traits are homogeneous).
pub trait HexOpsTrait {
    /// Adds `rhs` to both components.
    ///
    /// Mirrors `impl Add<i32> for Hex` (`src/hex/impls.rs:25`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Add<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn add_scalar(self: Hex, rhs: i32) -> Hex;

    /// Subtracts `rhs` from both components.
    ///
    /// Mirrors `impl Sub<i32> for Hex` (`src/hex/impls.rs:105`).
    ///
    /// #### Panics
    ///
    /// When a component of the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Sub<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn sub_scalar(self: Hex, rhs: i32) -> Hex;

    /// The neighbour coordinates of `rhs` added to `self`.
    ///
    /// Mirrors `impl Add<EdgeDirection> for Hex` (`src/hex/impls.rs:38`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Add<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn add_direction(self: Hex, rhs: EdgeDirection) -> Hex;

    /// The neighbour coordinates of `rhs` subtracted from `self`.
    ///
    /// Mirrors `impl Sub<EdgeDirection> for Hex` (`src/hex/impls.rs:117`).
    ///
    /// #### Panics
    ///
    /// When a component of the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Sub<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn sub_direction(self: Hex, rhs: EdgeDirection) -> Hex;

    /// The diagonal neighbour coordinates of `rhs` added to `self`.
    ///
    /// Mirrors `impl Add<VertexDirection> for Hex` (`src/hex/impls.rs:46`), computed as
    /// `self.const_add(rhs.into_hex())` (plan §8: not through `add_diag_dir`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Add<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn add_diagonal(self: Hex, rhs: VertexDirection) -> Hex;

    /// The diagonal neighbour coordinates of `rhs` subtracted from `self`.
    ///
    /// Mirrors `impl Sub<VertexDirection> for Hex` (`src/hex/impls.rs:125`).
    ///
    /// #### Panics
    ///
    /// When a component of the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Sub<T>` is homogeneous. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn sub_diagonal(self: Hex, rhs: VertexDirection) -> Hex;

    /// `self` rescaled to the length `n = L / rhs` (`L = self.length()`, truncated toward zero):
    /// the coordinate nearest the point `(x·n / L, y·n / L)` by `Hex::round`'s rule, computed
    /// exactly. Each component is rounded half away from zero; the component with the larger
    /// remainder (compared with `>=`, `x` first) is corrected by `round(r_a + r_b / 2)`. `ZERO`
    /// gives `ZERO`.
    ///
    /// Mirrors `impl Div<i32> for Hex` (`src/hex/impls.rs:241`).
    ///
    /// #### Panics
    ///
    /// When `rhs` is zero, and where `length` panics.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Div<T>` is homogeneous. `hexx` computes the point in `f32`
    /// (`ZERO.lerp(self, n as f32 / L as f32)`, `src/hex/mod.rs:973`) and rounds it in `f32`
    /// (`:474-484`); this port computes the same point and the same rule on exact rationals. They
    /// differ where `f32` error moves `hexx`'s point across a rounding boundary: 44 of the 157,464
    /// pairs of `[-40, 40]²` by `[-12, 12] \ {0}` (each a hexround tie), and most points of length
    /// beyond `2^20`; every pair compared is listed in `docs/deviations/div_scalar.md` (generated
    /// by `tools/refgen`).
    fn div_scalar(self: Hex, rhs: i32) -> Hex;

    /// `self - self.div_scalar(rhs).mul_scalar(rhs)`.
    ///
    /// Mirrors `impl Rem<i32> for Hex` (`src/hex/impls.rs:295`).
    ///
    /// #### Panics
    ///
    /// Where `div_scalar` panics, and when the product or the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A named method: Cairo's `Rem<T>` is homogeneous. It inherits the deviation of `div_scalar`,
    /// on the same pairs (`docs/deviations/div_scalar.md`).
    fn rem_scalar(self: Hex, rhs: i32) -> Hex;
}

pub impl HexOpsImpl of HexOpsTrait {
    #[inline]
    fn add_scalar(self: Hex, rhs: i32) -> Hex {
        Hex { x: self.x + rhs, y: self.y + rhs }
    }

    #[inline]
    fn sub_scalar(self: Hex, rhs: i32) -> Hex {
        Hex { x: self.x - rhs, y: self.y - rhs }
    }

    #[inline]
    fn add_direction(self: Hex, rhs: EdgeDirection) -> Hex {
        self.const_add(rhs.into_hex())
    }

    #[inline]
    fn sub_direction(self: Hex, rhs: EdgeDirection) -> Hex {
        self.const_sub(rhs.into_hex())
    }

    #[inline]
    fn add_diagonal(self: Hex, rhs: VertexDirection) -> Hex {
        self.const_add(rhs.into_hex())
    }

    #[inline]
    fn sub_diagonal(self: Hex, rhs: VertexDirection) -> Hex {
        self.const_sub(rhs.into_hex())
    }

    fn div_scalar(self: Hex, rhs: i32) -> Hex {
        // [Compute] The new length, panicking on `rhs = 0` as `hexx`'s integer division does
        let length = self.length();
        let n = length / rhs;
        // `n = 0` is the point `ZERO`; it is also the only case of `L = 0`
        if n == 0 {
            return HexTrait::ZERO;
        }
        // [Compute] The point `(x·n / L, y·n / L)`: `|x·n| < 2^62`, exact in `i64`
        let d: i64 = length.into();
        let (nx, ny): (i64, i64) = (self.x.into() * n.into(), self.y.into() * n.into());
        let (mut x, rx) = RescaleTrait::round(nx, d);
        let (mut y, ry) = RescaleTrait::round(ny, d);
        // [Compute] `Hex::round`'s correction of the larger remainder, `x` first at a tie
        if RescaleTrait::abs(rx) >= RescaleTrait::abs(ry) {
            x += RescaleTrait::correction(2 * rx + ry, d);
        } else {
            y += RescaleTrait::correction(2 * ry + rx, d);
        }
        Hex { x: x.try_into().unwrap(), y: y.try_into().unwrap() }
    }

    #[inline]
    fn rem_scalar(self: Hex, rhs: i32) -> Hex {
        self.const_sub(self.div_scalar(rhs).mul_scalar(rhs))
    }
}

/// The exact rounding of `div_scalar`, private: what `f32::round` and the correction of
/// `Hex::round` (`src/hex/mod.rs:474-484`) are on the rational `n / d`, `d > 0`.
#[generate_trait]
impl RescaleImpl of RescaleTrait {
    /// `n / d` rounded half away from zero, and the remainder `n - q·d`, in `[-d/2, d/2]`.
    #[inline]
    fn round(n: i64, d: i64) -> (i64, i64) {
        let q = n / d;
        let r = n - q * d;
        if 2 * r >= d {
            (q + 1, r - d)
        } else if -2 * r >= d {
            (q - 1, r + d)
        } else {
            (q, r)
        }
    }

    /// `round(s / 2d)` for `|s| ≤ 3d/2`: `-1`, `0` or `1`.
    #[inline]
    fn correction(s: i64, d: i64) -> i64 {
        if s >= d {
            1
        } else if -s >= d {
            -1
        } else {
            0
        }
    }

    #[inline]
    fn abs(v: i64) -> i64 {
        if v < 0 {
            -v
        } else {
            v
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::hex::HexTrait;
    use super::{HexAdd, HexAddAssign, HexDiv, HexMul, HexNeg, HexOpsTrait, HexRem, HexSub};

    /// Scope 2's regression cases, by the rule itself: `ZERO` for `ZERO`, `rhs > L`, `rhs = ±1`.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_div_scalar_regressions() {
        let zero = HexTrait::ZERO;
        assert!(zero.div_scalar(1) == zero && zero.div_scalar(-1) == zero);
        assert!(zero.div_scalar(7) == zero);
        let h = HexTrait::new(7, -3);
        assert!(h.div_scalar(8) == zero && h.div_scalar(-8) == zero);
        assert!(h.div_scalar(1) == h && h.div_scalar(-1) == -h);
        assert!(h.rem_scalar(1) == zero && h.rem_scalar(-1) == zero);
        assert!(HexTrait::new(3, 0).div_scalar(2) == HexTrait::new(1, 0));
        assert!(HexTrait::new(1, 1).div_scalar(2) == HexTrait::new(0, 1));
    }

    /// `rhs = 0` panics, as `hexx`'s integer division `L / 0` does.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_div_scalar_zero() {
        let _ = HexTrait::new(0, 0).div_scalar(0);
    }

    /// The exact point of `div_scalar` is a rescale: on every `Hex` of `[-6, 6]²` and every `rhs`
    /// of `[-6, 6] \ {0}`, each cubic component of the result is within one tile of the point
    /// `self·n / L`, and `rhs = 1` is the identity (the oracle: plain cubic arithmetic).
    #[test]
    #[available_gas(l2_gas: 141040862)]
    fn test_div_scalar_oracle() {
        let mut x: i32 = -6;
        while x <= 6 {
            let mut y: i32 = -6;
            while y <= 6 {
                let h = HexTrait::new(x, y);
                let l = h.length();
                let mut k: i32 = -6;
                while k <= 6 {
                    if k != 0 {
                        let r = h.div_scalar(k);
                        let n = l / k;
                        // `|r·L − self·n| ≤ L` on each of `x`, `y`, `z`: the nearest tile is
                        // within half a tile of the point on each cubic axis, the hexround
                        // correction within one
                        let [rx, ry, rz] = r.to_cubic_array();
                        let [hx, hy, hz] = h.to_cubic_array();
                        assert!(BoundTrait::within(rx * l - hx * n, l));
                        assert!(BoundTrait::within(ry * l - hy * n, l));
                        assert!(BoundTrait::within(rz * l - hz * n, l));
                    }
                    k += 1;
                }
                assert!(h.div_scalar(1) == h);
                y += 1;
            }
            x += 1;
        }
    }

    #[generate_trait]
    impl BoundImpl of BoundTrait {
        fn within(v: i32, l: i32) -> bool {
            v <= l && -v <= l
        }
    }

    /// The operators agree with their named forms and with each other.
    #[test]
    #[available_gas(l2_gas: 186291)]
    fn test_operators() {
        let a = HexTrait::new(7, -3);
        let b = HexTrait::new(-2, 5);
        assert!(a + b == a.const_add(b) && a - b == a.const_sub(b));
        assert!(a * b == HexTrait::new(-14, -15));
        assert!(a / b == HexTrait::new(-3, 0) && a % b == HexTrait::new(1, -3));
        assert!(-a == a.const_neg());
        let mut c = a;
        c += b;
        assert!(c == a + b);
        let all = EdgeDirectionTrait::ALL_DIRECTIONS.span();
        let diagonals = VertexDirectionTrait::ALL_DIRECTIONS.span();
        let mut i = 0;
        while i < 6 {
            assert!(a.add_direction(*all.at(i)) == a.neighbor(*all.at(i)));
            assert!(a.sub_direction(*all.at(i)) == a.neighbor((*all.at(i)).const_neg()));
            assert!(a.add_diagonal(*diagonals.at(i)).sub_diagonal(*diagonals.at(i)) == a);
            i += 1;
        }
        assert!(a.add_scalar(4).sub_scalar(4) == a);
    }

    // Benchmarks of M2-T3 (LIB-06), 100 repetitions per test, one call per repetition: per call =
    // (test − matching baseline) / 100. Targets (`L`, `U = ceil(1.25 L)`; the brief's table, from
    // the L-M1 measurements of `bench_mirror` and M2-T0's), written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `Add`, `Sub`, `Mul` (`Hex`), `add_scalar`, `sub_scalar` | 2,930 | 3,663 |
    // | `add_direction`, `sub_direction`, `add_diagonal`, `sub_diagonal` | 4,341 | 5,427 |
    // | `Div`, `Rem` (`Hex`) | 3,230 | 4,038 |
    // | `div_scalar` (a hexround tie, `L = 40`) | 28,957 | 36,197 |
    // | `rem_scalar` (same) | 34,817 | 43,522 |

    const REPS: u8 = 100;

    /// The loop, the accumulator and the two operands `(-n - 1, -n - 1)` and `(n + 1, n + 1)`
    /// (no zero component: the divisor of `Div` and `Rem`).
    #[test]
    #[available_gas(l2_gas: 643230)]
    fn bench_hex_ops_baseline_operands() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.x + b.y;
        }
        assert!(acc == 0);
    }

    #[test]
    #[available_gas(l2_gas: 798063)]
    fn bench_hex_ops_add() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += (a + b).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 798063)]
    fn bench_hex_ops_sub() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += (a - b).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 798063)]
    fn bench_hex_ops_mul() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += (a * b).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1542345)]
    fn bench_hex_ops_div() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += (a / b).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1542345)]
    fn bench_hex_ops_rem() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += (a % b).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 818853)]
    fn bench_hex_ops_add_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.add_scalar(7).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 818853)]
    fn bench_hex_ops_sub_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let b = HexTrait::new(1 + n.into(), 1 + n.into());
            acc += a.sub_scalar(7).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 910088)]
    fn bench_hex_ops_add_direction() {
        let directions = EdgeDirectionTrait::ALL_DIRECTIONS.span();
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let d = *directions.at((n % 6).into());
            acc += a.add_direction(d).x;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 910088)]
    fn bench_hex_ops_sub_direction() {
        let directions = EdgeDirectionTrait::ALL_DIRECTIONS.span();
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let d = *directions.at((n % 6).into());
            acc += a.sub_direction(d).x;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 910088)]
    fn bench_hex_ops_add_diagonal() {
        let directions = VertexDirectionTrait::ALL_DIRECTIONS.span();
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let d = *directions.at((n % 6).into());
            acc += a.add_diagonal(d).x;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 910088)]
    fn bench_hex_ops_sub_diagonal() {
        let directions = VertexDirectionTrait::ALL_DIRECTIONS.span();
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let d = *directions.at((n % 6).into());
            acc += a.sub_diagonal(d).x;
        }
        assert!(acc != 1);
    }

    /// The loop, the accumulator, a direction of each type, and the operand of the direction
    /// forms.
    #[test]
    #[available_gas(l2_gas: 677933)]
    fn bench_hex_ops_baseline_direction() {
        let directions = EdgeDirectionTrait::ALL_DIRECTIONS.span();
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), -1 - n.into());
            let d = *directions.at((n % 6).into());
            acc += a.x + d.index().into();
        }
        assert!(acc != 1);
    }

    /// The loop, the accumulator and the operand of `div_scalar`: `(40, -20 - z)` by `3`, a
    /// hexround tie on `y` (the point `(13, -6.5)`), `z = n / 128 = 0`.
    #[test]
    #[available_gas(l2_gas: 497648)]
    fn bench_hex_ops_baseline_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let z: i32 = (n / 128).into();
            let h = HexTrait::new(40, -20 - z);
            acc += h.y + 3;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 4983195)]
    fn bench_hex_ops_div_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let z: i32 = (n / 128).into();
            let h = HexTrait::new(40, -20 - z);
            acc += h.div_scalar(3).y + 3;
        }
        assert!(acc == (-6 + 3) * 100);
    }

    #[test]
    #[available_gas(l2_gas: 5301282)]
    fn bench_hex_ops_rem_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let z: i32 = (n / 128).into();
            let h = HexTrait::new(40, -20 - z);
            acc += h.rem_scalar(3).y + 3;
        }
        assert!(acc == (-2 + 3) * 100);
    }
}
