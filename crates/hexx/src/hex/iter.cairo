//! `hex/iter`: the extension of a span of `Hex` (`src/hex/iter.rs`), the counterpart of `hexx`'s
//! `HexIterExt` on `Iterator<Item = Hex>`: Cairo has no iterator trait, so it is implemented for
//! `Span<Hex>`. The private `ExactSizeHexIterator` of `hexx` has no counterpart: a `Span` knows
//! its length.

use crate::bounds::{HexBounds, HexBoundsTrait};
use crate::hex::impls::HexOpsTrait;
use crate::hex::{Hex, HexTrait};

/// Extension trait for a span of `Hex`.
///
/// Counterpart of `HexIterExt` (`src/hex/iter.rs:4`), the name `HexSpanExt` of the parity table.
pub trait HexSpanExt {
    /// The mean (average) value of the span: the sum of its hexes divided by their count (at
    /// least 1), `Hex::ZERO` for the empty span.
    ///
    /// Mirrors `HexIterExt::average` (`src/hex/iter.rs:17`).
    ///
    /// #### Panics
    ///
    /// When a coordinate of the sum leaves `i32`, or where `div_scalar` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the deviation of `div_scalar` (M2-T3): `sum / count` is `hexx`'s `Div<i32>`, the
    /// rescale of `Hex` by its length, which `hexx` computes in `f32` and this port computes
    /// exactly; the result differs from `hexx`'s where `div_scalar` does (the pairs listed in
    /// `docs/deviations/div_scalar.md`). Note that it is not the arithmetic mean: it is the sum
    /// rescaled to `length / count`. `hexx` wraps in a release build and panics in a debug build
    /// (plan §3.1); this port panics exactly where the debug build does.
    fn average(self: Span<Hex>) -> Hex;

    /// The centre (centroid) value of the span: the centre of its bounds, `Hex::ZERO` for the
    /// empty span.
    ///
    /// Mirrors `HexIterExt::center` (`src/hex/iter.rs:31`).
    ///
    /// #### Panics
    ///
    /// Where `bounds` does.
    ///
    /// #### Deviations
    ///
    /// None.
    fn center(self: Span<Hex>) -> Hex;

    /// The smallest bounds containing every hexagon of the span: `HexBounds::from_span`; the
    /// origin with radius 0 for the empty span.
    ///
    /// Mirrors `HexIterExt::bounds` (`src/hex/iter.rs:46`).
    ///
    /// #### Panics
    ///
    /// Where `HexBounds::from_span` does.
    ///
    /// #### Deviations
    ///
    /// None.
    fn bounds(self: Span<Hex>) -> HexBounds;
}

pub impl HexSpanExtImpl of HexSpanExt {
    fn average(self: Span<Hex>) -> Hex {
        let mut span = self;
        let mut sum = HexTrait::ZERO;
        let mut count: i32 = 0;
        while let Some(hex) = span.pop_front() {
            count += 1;
            sum = sum.const_add(*hex);
        }
        // Avoid division by zero
        sum.div_scalar(if count > 1 {
            count
        } else {
            1
        })
    }

    #[inline]
    fn center(self: Span<Hex>) -> Hex {
        self.bounds().center
    }

    #[inline]
    fn bounds(self: Span<Hex>) -> HexBounds {
        HexBoundsTrait::from_span(self)
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::bounds::HexBoundsTrait;
    use crate::hex::{Hex, HexTrait};
    use super::HexSpanExt;

    /// `hexx`'s documented examples: the average, centre and bounds of `ZERO.range(10)`; the
    /// empty span gives the origin.
    #[test]
    #[available_gas(l2_gas: 7997819)]
    fn test_span_ext() {
        let span = HexTrait::ZERO.range(10);
        assert!(span.average() == HexTrait::ZERO);
        assert!(span.center() == HexTrait::ZERO);
        let bounds = span.bounds();
        assert!(bounds.center == HexTrait::ZERO && bounds.radius == 10);

        let empty: Span<Hex> = array![].span();
        assert!(empty.average() == HexTrait::ZERO);
        assert!(empty.center() == HexTrait::ZERO);
        assert!(empty.bounds() == HexBoundsTrait::from_radius(0));

        let one = array![HexTrait::new(3, -5)].span();
        assert!(one.average() == HexTrait::new(3, -5));
    }

    /// Oracle: the span of a bounds' corners has those bounds, and the centre of a symmetric span
    /// is its centre.
    #[test]
    #[available_gas(l2_gas: 187415)]
    fn test_span_ext_oracle() {
        let bounds = HexBoundsTrait::new(HexTrait::new(7, -4), 5);
        let corners = bounds.corners();
        assert!(corners.span().bounds() == bounds);
        assert!(corners.span().center() == bounds.center);
    }

    // Benchmarks of M2-T5 (LIB-06), budgets placeholders until CI pins them (LIB-04i). Targets
    // (`L`, `U = ceil(1.25 L)`), 16 points: `bounds` and `center` 168,904 / 211,130, `average`
    // 92,317 / 115,397.

    #[generate_trait]
    impl FixtureImpl of FixtureTrait {
        fn span16() -> Span<Hex> {
            let mut hexes = array![];
            let mut i: i32 = 0;
            while i < 16 {
                hexes.append(HexTrait::new(i * 3 - 20, 17 - i * 2));
                i += 1;
            }
            hexes.span()
        }
    }

    #[test]
    #[available_gas(l2_gas: 97986)]
    fn bench_iter_baseline() {
        assert!(FixtureTrait::span16().len() == 16);
    }

    #[test]
    #[available_gas(l2_gas: 201212)]
    fn bench_iter_average() {
        assert!(FixtureTrait::span16().average().x != 1000);
    }

    #[test]
    #[available_gas(l2_gas: 252378)]
    fn bench_iter_center() {
        assert!(FixtureTrait::span16().center().x != 1000);
    }

    #[test]
    #[available_gas(l2_gas: 252378)]
    fn bench_iter_bounds() {
        assert!(FixtureTrait::span16().bounds().radius != 1000);
    }
}
