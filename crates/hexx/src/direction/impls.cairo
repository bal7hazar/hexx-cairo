//! The operators of the two direction types (`src/direction/impls.rs`): `Neg` for both,
//! `mul_scalar` for the counterpart of `Mul<i32>`. `Shl<u8>` and `Shr<u8>` have nothing to add:
//! `rotate_ccw` and `rotate_cw` are their bodies (plan §4.4).

use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
use crate::hex::{Hex, HexTrait};

/// The opposite direction, as the `-` operator.
///
/// Mirrors `impl Neg for EdgeDirection` (`src/direction/impls.rs:13`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The operator is a trait impl that Cairo resolves from the scope: a consumer imports
/// `EdgeDirectionNeg`
/// (`use hexx::direction::impls::EdgeDirectionNeg;`) to write `-direction`.
pub impl EdgeDirectionNeg of Neg<EdgeDirection> {
    #[inline]
    fn neg(a: EdgeDirection) -> EdgeDirection {
        a.const_neg()
    }
}

/// The opposite direction, as the `-` operator.
///
/// Mirrors `impl Neg for VertexDirection` (`src/direction/impls.rs:5`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The operator is a trait impl that Cairo resolves from the scope: a consumer imports
/// `VertexDirectionNeg`
/// (`use hexx::direction::impls::VertexDirectionNeg;`) to write `-direction`.
pub impl VertexDirectionNeg of Neg<VertexDirection> {
    #[inline]
    fn neg(a: VertexDirection) -> VertexDirection {
        a.const_neg()
    }
}

/// The operators of `EdgeDirection` that Cairo writes as named methods.
pub trait EdgeDirectionOpsTrait {
    /// The neighbour coordinates scaled by `rhs`: `into_hex() * rhs`.
    ///
    /// Mirrors `impl Mul<i32> for EdgeDirection` (`src/direction/impls.rs:53`).
    ///
    /// #### Panics
    ///
    /// When a component of the product leaves `i32` (`Hex::mul_scalar`); `hexx` wraps in a release
    /// build and panics in a debug build.
    ///
    /// #### Deviations
    ///
    /// Cairo has no heterogeneous `Mul`: a named method, `mul_scalar`.
    fn mul_scalar(self: EdgeDirection, rhs: i32) -> Hex;
}

pub impl EdgeDirectionOpsImpl of EdgeDirectionOpsTrait {
    #[inline]
    fn mul_scalar(self: EdgeDirection, rhs: i32) -> Hex {
        self.into_hex().mul_scalar(rhs)
    }
}

/// The operators of `VertexDirection` that Cairo writes as named methods.
pub trait VertexDirectionOpsTrait {
    /// The diagonal neighbour coordinates scaled by `rhs`: `into_hex() * rhs`.
    ///
    /// Mirrors `impl Mul<i32> for VertexDirection` (`src/direction/impls.rs:61`).
    ///
    /// #### Panics
    ///
    /// When a component of the product leaves `i32` (`Hex::mul_scalar`); `hexx` wraps in a release
    /// build and panics in a debug build.
    ///
    /// #### Deviations
    ///
    /// Cairo has no heterogeneous `Mul`: a named method, `mul_scalar`.
    fn mul_scalar(self: VertexDirection, rhs: i32) -> Hex;
}

pub impl VertexDirectionOpsImpl of VertexDirectionOpsTrait {
    #[inline]
    fn mul_scalar(self: VertexDirection, rhs: i32) -> Hex {
        self.into_hex().mul_scalar(rhs)
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::hex::HexTrait;
    use super::{
        EdgeDirectionNeg, EdgeDirectionOpsTrait, VertexDirectionNeg, VertexDirectionOpsTrait,
    };

    /// `-d` is the direction three steps away, and `d * n` is the coordinates scaled: the plain
    /// oracle is the sum of `n` copies of the coordinates.
    #[test]
    #[available_gas(l2_gas: 1250498)]
    fn test_direction_operators_oracle() {
        let edges = EdgeDirectionTrait::iter();
        let vertices = VertexDirectionTrait::iter();
        let mut i: u8 = 0;
        while i < 6 {
            let e = *edges.at(i.into());
            let v = *vertices.at(i.into());
            assert((-e).index() == (i + 3) % 6, 'edge neg');
            assert((-v).index() == (i + 3) % 6, 'vertex neg');
            let mut sum_e = HexTrait::new(0, 0);
            let mut sum_v = HexTrait::new(0, 0);
            let mut n: u8 = 0;
            while n < 12 {
                assert(e.mul_scalar(n.into()) == sum_e, 'edge mul_scalar');
                assert(v.mul_scalar(n.into()) == sum_v, 'vertex mul_scalar');
                sum_e = sum_e.const_add(e.into_hex());
                sum_v = sum_v.const_add(v.into_hex());
                n += 1;
            }
            assert(e.mul_scalar(-1) == e.into_hex().const_neg(), 'edge mul_scalar -1');
            assert(v.mul_scalar(-1) == v.into_hex().const_neg(), 'vertex mul_scalar -1');
            i += 1;
        }
    }

    // Benchmarks of M2-T1 (LIB-06), 17 repetitions of the six directions per test (102 calls),
    // per call = (test − baseline) / 102. Targets (`L`, `U = ceil(1.25 L)`): `into_hex` 1,411 +
    // `Hex::mul_scalar` as M2-T0 measured it (`bench_hex_mul_scalar` less
    // `bench_hex_baseline_operands`, per call 1,476), written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `EdgeDirection::mul_scalar`, `VertexDirection::mul_scalar` | 2,887 | 3,609 |

    #[test]
    #[available_gas(l2_gas: 405468)]
    fn bench_direction_ops_baseline() {
        let mut acc: i32 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let scalar: i32 = 3 - rep.into();
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc += d.index().into() + scalar;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 722400)]
    fn bench_edge_direction_mul_scalar() {
        let mut acc: i32 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let scalar: i32 = 3 - rep.into();
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc += d.mul_scalar(scalar).x + scalar;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 722400)]
    fn bench_vertex_direction_mul_scalar() {
        let mut acc: i32 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let scalar: i32 = 3 - rep.into();
            let mut all = VertexDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                acc += d.mul_scalar(scalar).x + scalar;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }
}
