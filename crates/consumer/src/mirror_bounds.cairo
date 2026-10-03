//! The call sites of `HexBounds` and the span extension (`hexx::bounds`, `hexx::hex::iter`),
//! written by M2-T5 (LIB-06): one per public item, so that the tracked class size follows them.

/// `HexBounds` and `HexSpanExt` of milestone L-M2.
#[starknet::contract]
pub mod HexxBounds {
    use hexx::bounds::{HexBounds, HexBoundsTrait};
    use hexx::hex::Hex;
    use hexx::hex::iter::HexSpanExt;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn constructors(
        self: @ContractState, center: Hex, radius: u32, min: Hex, max: Hex,
    ) -> Span<HexBounds> {
        array![
            HexBoundsTrait::new(center, radius), HexBoundsTrait::from_radius(radius),
            HexBoundsTrait::from_min_max(min, max), HexBoundsTrait::positive_radius(radius),
        ]
            .span()
    }

    #[external(v0)]
    fn queries(self: @ContractState, bounds: HexBounds, hex: Hex) -> (bool, usize, u32) {
        (bounds.is_in_bounds(hex), bounds.hex_count(), bounds.hex_count32())
    }

    #[external(v0)]
    fn spans(self: @ContractState, a: HexBounds, b: HexBounds) -> (Span<Hex>, Span<Hex>) {
        (a.all_coords(), a.intersecting_with(b))
    }

    #[external(v0)]
    fn wrapping(self: @ContractState, bounds: HexBounds, hex: Hex) -> (Hex, Hex) {
        (bounds.wrap_local(hex), bounds.wrap(hex))
    }

    #[external(v0)]
    fn corners(self: @ContractState, bounds: HexBounds) -> [Hex; 6] {
        bounds.corners()
    }

    #[external(v0)]
    fn from_span(self: @ContractState, span: Span<Hex>) -> HexBounds {
        HexBoundsTrait::from_span(span)
    }

    #[external(v0)]
    fn span_ext(self: @ContractState, span: Span<Hex>) -> (Hex, Hex, HexBounds) {
        (span.average(), span.center(), span.bounds())
    }
}
